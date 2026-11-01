#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('repeater-1','repeater-2')][string[]]$DeviceId = @('repeater-1','repeater-2'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$approvalFile = Join-Path $root '.local/access/repeater-certificates-approved.json'
if (-not (Test-Path -LiteralPath $approvalFile)) {
    throw 'Repeater-Zertifikate noch nicht bestätigt. Keine Zugangsdaten gelesen oder gesendet.'
}
$approvals = Get-Content -Raw -LiteralPath $approvalFile | ConvertFrom-Json -AsHashtable
$inventory = Get-Content -Raw -LiteralPath (Join-Path $root 'inventory/infrastruktur.json') | ConvertFrom-Json
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    if (-not $approvals.ContainsKey($id) -or $approvals[$id].approved -isnot [bool] -or
        -not $approvals[$id].approved -or $approvals[$id].address -cne $device.address -or
        $approvals[$id].port -ne 443 -or $approvals[$id].sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Kein passendes bestätigtes Repeater-Zertifikat für $id. Keine Zugangsdaten gelesen."
    }
}
if (-not ('JaylabTlsCertificate' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'lib/JaylabTlsCertificate.cs')
}
. (Join-Path $PSScriptRoot 'lib/Get-JaylabPbkdf2Response.ps1')

function Invoke-RepeaterSession($Client, [hashtable]$Fields) {
    $request = [Net.Http.HttpRequestMessage]::new()
    $request.RequestUri = [uri]::new('login_sid.lua?version=2', [UriKind]::Relative)
    if ($null -eq $Fields) { $request.Method = [Net.Http.HttpMethod]::Get }
    else {
        $request.Method = [Net.Http.HttpMethod]::Post
        $form = [Collections.Generic.Dictionary[string,string]]::new()
        foreach ($entry in $Fields.GetEnumerator()) { $form.Add($entry.Key, [string]$entry.Value) }
        $request.Content = [Net.Http.FormUrlEncodedContent]::new($form)
    }
    $response = $null
    try {
        $response = $Client.SendAsync($request).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw "RepeaterSession HTTP=$([int]$response.StatusCode)" }
        return [xml]$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    } finally {
        if ($response) { $response.Dispose() }
        $request.Dispose()
    }
}

$results = @()
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    $pin = [JaylabTlsCertificate]::new($device.address, 443, $approvals[$id].sha256)
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $handler.UseCookies = $false
    $handler.AllowAutoRedirect = $false
    $handler.SslProtocols = [Security.Authentication.SslProtocols]::Tls12 -bor [Security.Authentication.SslProtocols]::Tls13
    $handler.ServerCertificateCustomValidationCallback =
        [Func[Net.Http.HttpRequestMessage,Security.Cryptography.X509Certificates.X509Certificate2,
              Security.Cryptography.X509Certificates.X509Chain,Net.Security.SslPolicyErrors,bool]]$pin.VerifyHttp
    $client = [Net.Http.HttpClient]::new($handler)
    $client.BaseAddress = [uri]('https://' + $device.address + '/')
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    $client.MaxResponseContentBufferSize = 262144
    $sid = $null
    $credential = $null
    $result = [ordered]@{ device = $id; address = $device.address; authenticated = $false; status = 'pruefung-fehlgeschlagen'; logoutSucceeded = $null }
    try {
        $initial = Invoke-RepeaterSession $client $null
        if ([int]$initial.SessionInfo.BlockTime -gt 0) {
            throw 'RepeaterSession Sperrzeit aktiv; kein Anmeldeversuch.'
        }
        if ($initial.SessionInfo.SID -match '^[A-Fa-f0-9]{16}$' -and $initial.SessionInfo.SID -ne '0000000000000000') {
            throw 'RepeaterSession Zugang ohne Kennwort; gesondert prüfen.'
        }
        $credential = Import-Clixml -LiteralPath (Join-Path $root ('.local/access/credentials/' + $id + '.clixml'))
        if ($credential -isnot [pscredential] -or $credential.UserName -cne 'password-only') {
            throw 'RepeaterSession erwartet einen mit -PasswordOnly hinterlegten Zugang.'
        }
        $proof = Get-JaylabPbkdf2Response -Challenge $initial.SessionInfo.Challenge `
            -Password $credential.GetNetworkCredential().Password
        $login = Invoke-RepeaterSession $client @{ username = ''; response = $proof }
        $proof = $null
        if ($login.SessionInfo.SID -notmatch '^[A-Fa-f0-9]{16}$' -or $login.SessionInfo.SID -eq '0000000000000000') {
            throw 'RepeaterSession Anmeldung abgewiesen; kein weiterer Versuch.'
        }
        $sid = $login.SessionInfo.SID
        $verified = Invoke-RepeaterSession $client @{ sid = $sid }
        if ($verified.SessionInfo.SID -ine $sid) { throw 'RepeaterSession Sitzungsprüfung fehlgeschlagen.' }
        $rights = [ordered]@{}
        foreach ($name in $verified.SelectNodes('/SessionInfo/Rights/Name')) {
            $access = $name.NextSibling
            if ($access -and $access.Name -eq 'Access' -and $access.InnerText -match '^[012]$') {
                $rights[$name.InnerText] = [int]$access.InnerText
            }
        }
        $result.authenticated = $true
        $result.status = 'web-sitzung-geprueft'
        $result.rights = $rights
    } catch {
        $result.errorType = $_.Exception.GetBaseException().GetType().FullName
        if ($_.Exception.Message -match '^RepeaterSession (HTTP=\d+|Sperrzeit aktiv; kein Anmeldeversuch\.|Anmeldung abgewiesen; kein weiterer Versuch\.)$') {
            $result.actionStatus = $_.Exception.Message
        }
    } finally {
        if ($sid) {
            try {
                $logout = Invoke-RepeaterSession $client @{ sid = $sid; logout = '1' }
                $result.logoutSucceeded = $logout.SessionInfo.SID -eq '0000000000000000'
            } catch { $result.logoutSucceeded = $false }
        }
        $client.Dispose()
        $credential = $null
        $sid = $null
        $proof = $null
    }
    $results += $result
}
$results | ConvertTo-Json -Depth 5
