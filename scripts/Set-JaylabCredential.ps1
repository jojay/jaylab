#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$DeviceId,
    [string]$UserName,
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$PasswordOnly,
    [switch]$Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Dieses Werkzeug benötigt Windows-DPAPI.' }
if ($PasswordOnly -and $UserName) { throw '-PasswordOnly ohne -UserName verwenden.' }
$root = Split-Path -Parent $PSScriptRoot
$inventory = Get-Content -Raw -LiteralPath (Join-Path $root 'inventory/infrastruktur.json') | ConvertFrom-Json
if ($DeviceId -notin @($inventory.devices.id)) { throw "Unbekanntes Gerät: $DeviceId" }
$directory = Join-Path $root '.local/access/credentials'
$file = Join-Path $directory ($DeviceId + '.clixml')
if ((Test-Path -LiteralPath $file) -and -not $Replace) {
    throw 'Für dieses Gerät sind bereits Daten hinterlegt. Zum Ersetzen ausdrücklich -Replace verwenden.'
}
$null = New-Item -ItemType Directory -Force -Path $directory
$directoryInfo = [System.IO.DirectoryInfo]::new($directory)
$accessSection = [System.Security.AccessControl.AccessControlSections]::Access
$acl = [System.IO.FileSystemAclExtensions]::GetAccessControl($directoryInfo, $accessSection)
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
# Nur die DACL setzen. Eigentümer und Überwachungsregeln bleiben unberührt;
# insbesondere wird kein SeSecurityPrivilege für die SACL angefordert.
$acl.SetSecurityDescriptorSddlForm("D:P(A;OICI;FA;;;$($sid.Value))(A;OICI;FA;;;SY)", $accessSection)
[System.IO.FileSystemAclExtensions]::SetAccessControl($directoryInfo, $acl)

# Erst nach erfolgreicher Vorbereitung nach dem Kennwort fragen.
if (-not $Credential) {
    if ($PasswordOnly) {
        $secret = Read-Host -AsSecureString -Prompt "Vorhandenes Gerätekennwort für $DeviceId; lokal verschlüsselt speichern"
        $Credential = [pscredential]::new('password-only', $secret)
    } else {
        $prompt = @{ Message = "Vorhandener Verwaltungszugang für $DeviceId; lokal verschlüsselt speichern" }
        if ($UserName) { $prompt.UserName = $UserName }
        $Credential = Get-Credential @prompt
    }
}
if ($PasswordOnly -and $Credential) {
    # Ablagebezeichnung, kein Benutzerkonto auf dem Zielgerät.
    $Credential = [pscredential]::new('password-only', $Credential.Password)
}
if (-not $Credential -or -not $Credential.UserName -or $Credential.Password.Length -eq 0) {
    throw 'Kein vollständiger Zugang angegeben; nichts gespeichert.'
}
$Credential | Export-Clixml -LiteralPath $file -Encoding utf8 -Force
Write-Output "Zugang für $DeviceId mit Windows-DPAPI gespeichert. Nur unter diesem Windows-Konto auf diesem Rechner nutzbar. Noch keine Geräteanmeldung geprüft."
