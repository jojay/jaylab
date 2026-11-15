#requires -Version 7.0
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Dieses Werkzeug benötigt Windows-DPAPI.'}
$root=Split-Path -Parent $PSScriptRoot
$directory=Join-Path $root '.local/pki/automation-2026'
$config=Join-Path $root '.local/access/ssh_config_wsl'
if($config -notmatch '^([A-Za-z]):[\\/](.*)$'){throw 'Absoluter Windows-Pfad erforderlich.'}
$wslConfig='/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')
$credential=Import-Clixml -LiteralPath (Join-Path $directory 'nodered-read-token.clixml')
$payload=$null
try {
 $payload=@{script=Get-Content -Raw (Join-Path $PSScriptRoot 'Test-JaylabNodeRed.py');token=$credential.GetNetworkCredential().Password;ca=Get-Content -Raw (Join-Path $directory 'automation-ca.pem')} | ConvertTo-Json -Compress
 $command='pct exec 105 -- python3 -c ''import json,sys; payload=json.load(sys.stdin); exec(compile(payload["script"],"jaylab-nodered-check","exec"))'''
 $payload | & wsl.exe --exec ssh -F $wslConfig jaylab-proxmox $command
 if($LASTEXITCODE -ne 0){throw "Node-RED-API-Prüfung fehlgeschlagen: $LASTEXITCODE"}
} finally {$payload=$null;$credential=$null}
