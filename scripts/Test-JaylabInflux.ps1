#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Dieses Werkzeug benötigt Windows-DPAPI.' }
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root '.local/access/credentials/influxdb.clixml'
if (!(Test-Path -LiteralPath $file)) {
    throw 'Der lokale InfluxDB-Zugang fehlt. Zuerst Set-JaylabCredential.ps1 -DeviceId influxdb ausführen.'
}
$config = Join-Path $root '.local/access/ssh_config_wsl'
if (!(Test-Path -LiteralPath $config) -or $config -notmatch '^([A-Za-z]):[\\/](.*)$') {
    throw 'Die geprüfte lokale WSL-SSH-Konfiguration fehlt.'
}
$wslConfig = '/mnt/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/')
$credential = Import-Clixml -LiteralPath $file
if ($credential -isnot [pscredential]) { throw 'Ungültige lokale Zugangsdatei.' }
$mode = if ($credential.UserName -eq 'password-only') { 'token' } else { 'password' }
$payload = $null
try {
    $payload = @{
        script = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'Test-JaylabInflux.py')
        user = $credential.UserName
        secret = $credential.GetNetworkCredential().Password
        mode = $mode
    } | ConvertTo-Json -Compress
    # All secret material travels through stdin, never argv or a temporary file.
    $command = 'pct exec 110 -- python3 -c ''import json,sys; payload=json.load(sys.stdin); exec(compile(payload["script"],"jaylab-influx-check","exec"))'''
    $payload | & wsl.exe --exec ssh -F $wslConfig jaylab-proxmox3 $command
    if ($LASTEXITCODE -ne 0) { throw "Die InfluxDB-Anmeldung endete mit Code $LASTEXITCODE; kein automatischer weiterer Versuch." }
} finally {
    $payload = $null
    $credential = $null
}
