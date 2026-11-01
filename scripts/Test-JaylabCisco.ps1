#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('cisco16', 'cisco8', 'cisco162')][string[]]$DeviceId = @('cisco16', 'cisco8', 'cisco162'),
    [switch]$ProbeOnly,
    [switch]$AuthenticationMethodsOnly,
    [switch]$ReadIdentity
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (($ProbeOnly -and ($AuthenticationMethodsOnly -or $ReadIdentity)) -or
    ($AuthenticationMethodsOnly -and $ReadIdentity)) { throw 'Prüfmodi einzeln verwenden.' }
$root = Split-Path -Parent $PSScriptRoot
$inventory = Get-Content -Raw -LiteralPath (Join-Path $root 'inventory/infrastruktur.json') | ConvertFrom-Json
$approvals = @{}
if (-not $ProbeOnly) {
    $approvalFile = Join-Path $root '.local/access/cisco-hostkeys-approved.json'
    if (-not (Test-Path -LiteralPath $approvalFile)) {
        throw 'Cisco-Hostschlüssel noch nicht bestätigt. Kein Kennwort gelesen und keine Verbindung aufgebaut.'
    }
    $approvals = Get-Content -Raw -LiteralPath $approvalFile | ConvertFrom-Json -AsHashtable
    foreach ($id in $DeviceId) {
        $device = @($inventory.devices | Where-Object id -eq $id)[0]
        if (-not $approvals.ContainsKey($id) -or -not $approvals[$id].approved -or
            $approvals[$id].address -cne $device.address -or
            $approvals[$id].fingerprint -notmatch '^SHA256:[A-Za-z0-9+/]{43}$') {
            throw "Kein bestätigter Hostschlüssel für $id. Kein Kennwort gelesen."
        }
    }
}
$libraryRoot = Join-Path $root '.local/tools/sshnet'
$sshFramework = if ([Environment]::Version.Major -ge 10) { 'net10.0' }
    elseif ([Environment]::Version.Major -ge 9) { 'net9.0' } else { 'net8.0' }
$assemblies = @(
    'bouncycastle.cryptography.2.7.0/lib/net6.0/BouncyCastle.Cryptography.dll',
    'microsoft.extensions.logging.abstractions.8.0.3/lib/net8.0/Microsoft.Extensions.Logging.Abstractions.dll',
    ('ssh.net.2026.0.0/lib/' + $sshFramework + '/Renci.SshNet.dll')
)
foreach ($relative in $assemblies) {
    $path = Join-Path $libraryRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { throw 'SSH-Bibliothek fehlt; Initialize-JaylabSsh.ps1 ausführen.' }
    $name = [Reflection.AssemblyName]::GetAssemblyName($path).Name
    if (-not @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $name }).Count) {
        $null = [Reflection.Assembly]::LoadFrom($path)
    }
}
if (-not ('JaylabSshHostKey' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'lib/JaylabSshHostKey.cs') -ReferencedAssemblies (Join-Path $libraryRoot $assemblies[2])
}
$results = @()
function Read-CiscoPrompt($Shell) {
    $text = [Text.StringBuilder]::new()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt 10) {
        if ($Shell.DataAvailable) {
            $null = $text.Append($Shell.Read())
            if ($text.Length -gt 65536) { throw 'Unerwartet umfangreiche CLI-Antwort.' }
            $clean = [regex]::Replace($text.ToString(), '\x1B\[[0-?]*[ -/]*[@-~]', '')
            if ($clean -match '(?m)^[\w.()/@:-]+[>#]\s*\z') { return $clean }
        }
        Start-Sleep -Milliseconds 100
    }
    throw 'Kein eindeutiger CLI-Prompt innerhalb der Prüffrist.'
}
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    $expected = $null
    $credential = $null
    if ($ProbeOnly) {
        # Der Prüfer verweigert jeden Schlüssel; Authentifizierung wird nie erreicht.
        $auth = [Renci.SshNet.PasswordAuthenticationMethod]::new($device.sshUser, 'unused-probe-value')
    } elseif ($AuthenticationMethodsOnly) {
        $expected = $approvals[$id].fingerprint
        $auth = [Renci.SshNet.NoneAuthenticationMethod]::new($device.sshUser)
    } else {
        $expected = $approvals[$id].fingerprint
        $credential = Import-Clixml -LiteralPath (Join-Path $root ('.local/access/credentials/' + $id + '.clixml'))
        if ($credential -isnot [pscredential] -or $credential.UserName -cne $device.sshUser) {
            throw "Ungültiger lokaler Zugang für $id"
        }
        # Nur im lokalen Prozeß für die Bibliothek entschlüsseln; nie ausgeben,
        # in Befehlszeilen übergeben oder auf Datenträger schreiben.
        $auth = [Renci.SshNet.PasswordAuthenticationMethod]::new(
            $credential.UserName, $credential.GetNetworkCredential().Password)
    }
    $connection = [Renci.SshNet.ConnectionInfo]::new($device.address, 22, $device.sshUser,
        [Renci.SshNet.AuthenticationMethod[]]@($auth))
    $connection.Timeout = [TimeSpan]::FromSeconds(8)
    # Nur der bereits beobachtete Austausch, keine globale Kompatibilitätslockerung.
    foreach ($algorithm in @($connection.KeyExchangeAlgorithms.Keys)) {
        if ($algorithm -cne 'diffie-hellman-group16-sha512') { $connection.KeyExchangeAlgorithms.Remove($algorithm) | Out-Null }
    }
    $pin = [JaylabSshHostKey]::new($expected)
    $client = [Renci.SshNet.SshClient]::new($connection)
    $handler = [EventHandler[Renci.SshNet.Common.HostKeyEventArgs]]$pin.Verify
    $client.add_HostKeyReceived($handler)
    $wasAuthenticated = $false
    try {
        $client.Connect()
        $wasAuthenticated = $client.IsConnected
        $result = [ordered]@{ device = $id; address = $device.address; fingerprint = $pin.ObservedFingerprint
            authenticated = $client.IsConnected; user = $device.sshUser; status = 'anmeldung-erfolgreich' }
        if ($ReadIdentity) {
            $shell = $client.CreateShellStream('vt100', 200, 50, 1600, 1000, 65536)
            try {
                $welcome = Read-CiscoPrompt $shell
                $shell.WriteLine('show version')
                $result.versionOutput = Read-CiscoPrompt $shell
                $shell.WriteLine('show privilege')
                $result.privilegeOutput = Read-CiscoPrompt $shell
                $result.status = 'cli-lesend-geprueft'
            } finally { $shell.Dispose() }
        }
        $results += $result
    } catch {
        if ($ProbeOnly -and $pin.ObservedFingerprint) {
            $results += [ordered]@{ device = $id; address = $device.address; fingerprint = $pin.ObservedFingerprint
                fingerprintMD5 = $pin.ObservedFingerprintMD5
                authenticated = $false; status = 'nur-beobachtet-nicht-vertraut' }
        } elseif ($AuthenticationMethodsOnly -and $pin.Matched) {
            $message = $_.Exception.GetBaseException().Message
            $methods = @([regex]::Matches($message, '\b(password|keyboard-interactive|publickey|hostbased|gssapi-with-mic)\b') |
                ForEach-Object Value | Select-Object -Unique)
            $results += [ordered]@{ device = $id; address = $device.address; fingerprint = $pin.ObservedFingerprint
                authenticated = $false; status = 'verfahren-ohne-kennwort-geprueft'; methods = $methods }
        } else {
            # Keine beliebigen Server-/Bibliotheksmeldungen mit möglicherweise sensiblen Daten ausgeben.
            $results += [ordered]@{ device = $id; address = $device.address; fingerprint = $pin.ObservedFingerprint
                authenticated = $wasAuthenticated
                status = $(if ($wasAuthenticated) { 'cli-pruefung-fehlgeschlagen' } else { 'fehlgeschlagen' })
                errorType = $_.Exception.GetBaseException().GetType().FullName }
        }
    } finally {
        $client.Dispose()
        $auth.Dispose()
        $credential = $null
    }
}
$results | ConvertTo-Json -Depth 5
