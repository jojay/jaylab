#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Dieser Test benötigt Windows-DPAPI und NTFS-Rechte.' }
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixture = Join-Path $root ('.local/validation/credential-store-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'scripts'), (Join-Path $fixture 'inventory')
$script = Join-Path $fixture 'scripts/Set-JaylabCredential.ps1'
Copy-Item -LiteralPath (Join-Path $root 'scripts/Set-JaylabCredential.ps1') -Destination $script
$ids = @('test8', 'test16', 'test162', 'test-repeater')
@{ devices = @($ids | ForEach-Object { @{ id = $_ } }) } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'inventory/infrastruktur.json')
$secret = [guid]::NewGuid().ToString('N')
$credential = [pscredential]::new('test-jay', (ConvertTo-SecureString $secret -AsPlainText -Force))
$directory = Join-Path $fixture '.local/access/credentials'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$accessSection = [Security.AccessControl.AccessControlSections]::Access
$ownerSection = [Security.AccessControl.AccessControlSections]::Owner -bor
    [Security.AccessControl.AccessControlSections]::Group
$hashes = @{}
$ownerBefore = $null

foreach ($id in $ids) {
    $passwordOnly = $id -eq 'test-repeater'
    & $script -DeviceId $id -Credential $credential -PasswordOnly:$passwordOnly
    $file = Join-Path $directory ($id + '.clixml')
    $restored = Import-Clixml -LiteralPath $file
    $expectedUser = if ($passwordOnly) { 'password-only' } else { $credential.UserName }
    if ($restored.UserName -cne $expectedUser -or
        $restored.GetNetworkCredential().Password -cne $secret -or
        (Get-Content -Raw -LiteralPath $file).Contains($secret)) {
        throw "DPAPI-Rundlauf oder Klartextausschluß fehlgeschlagen: $id"
    }
    $acl = [IO.FileSystemAclExtensions]::GetAccessControl([IO.DirectoryInfo]::new($directory), $accessSection)
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if (-not $acl.AreAccessRulesProtected -or $rules.Count -ne 2) {
        throw 'Die DACL ist nicht auf genau Benutzer und SYSTEM begrenzt.'
    }
    foreach ($rule in $rules) {
        if ($rule.IdentityReference.Value -notin @($sid.Value, 'S-1-5-18') -or
            $rule.AccessControlType -ne 'Allow' -or $rule.FileSystemRights -ne 'FullControl') {
            throw 'Unerwartete Verzeichnisberechtigung.'
        }
    }
    $owner = [IO.FileSystemAclExtensions]::GetAccessControl([IO.DirectoryInfo]::new($directory), $ownerSection).
        GetSecurityDescriptorSddlForm($ownerSection)
    if ($ownerBefore -and $ownerBefore -cne $owner) { throw 'Eigentümer oder Gruppe wurden verändert.' }
    $ownerBefore = $owner
    foreach ($existing in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $directory $existing)).Hash -cne $hashes[$existing]) {
            throw 'Ein früher gespeicherter Zugang wurde verändert.'
        }
    }
    $hashes[$id + '.clixml'] = (Get-FileHash -LiteralPath $file).Hash
}
$rejected = $false
try { & $script -DeviceId $ids[0] -Credential $credential }
catch { $rejected = $_.Exception.Message -like '*bereits Daten hinterlegt*' }
if (-not $rejected) { throw 'Vorhandene Daten wurden nicht vor versehentlichem Überschreiben geschützt.' }
foreach ($entry in $hashes.GetEnumerator()) {
    if ((Get-FileHash -LiteralPath (Join-Path $directory $entry.Key)).Hash -cne $entry.Value) {
        throw 'Ein vorhandener Zugang wurde verändert.'
    }
}
Write-Output 'Bestanden: drei Benutzerzugänge und ein Gerätekennwort, DPAPI, begrenzte DACL, unveränderter Eigentümer und Erhalt früherer Einträge. Nur künstliche Testdaten verwendet.'
