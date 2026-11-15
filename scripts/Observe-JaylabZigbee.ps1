#requires -Version 7.0
[CmdletBinding()]
param([ValidateRange(30,600)][int]$Seconds=180)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$config=Join-Path $root '.local/access/ssh_config_wsl'
if(!(Test-Path -LiteralPath $config) -or $config -notmatch '^([A-Za-z]):[\\/](.*)$') {
    throw 'Die geprüfte lokale SSH-Konfiguration fehlt.'
}
$wslConfig='/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')
Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'Observe-JaylabZigbee.js') |
    & wsl.exe --exec ssh -F $wslConfig jaylab-proxmox "pct exec 105 -- node - $Seconds"
if($LASTEXITCODE -ne 0){throw "Zigbee-Beobachtung fehlgeschlagen: $LASTEXITCODE"}
