#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('nodered', 'mqtt', 'mqtt-tls', 'influxdb', 'shc', 'zigbee')]
    [string]$Service
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root '.local/access/ssh_config_wsl'
$knownHosts = Join-Path $root '.local/access/known_hosts'
if (!(Test-Path -LiteralPath $config) -or !(Test-Path -LiteralPath $knownHosts)) {
    throw 'Der geprüfte lokale SSH-Zugang fehlt.'
}
if ($config -notmatch '^([A-Za-z]):[\\/](.*)$') { throw 'Ein absoluter Windows-Pfad wird benötigt.' }
$wslConfig = '/mnt/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/')
$profile = 'jaylab-proxmox3'
switch ($Service) {
    'nodered' {
        $profile = 'jaylab-proxmox'
        $command = 'pct exec 105 -- systemctl show nodered -p ActiveState,User; pct exec 105 -- ip -br addr'
    }
    'mqtt' { $command = 'pct exec 107 -- systemctl show mosquitto -p ActiveState,Result; pct exec 107 -- ss -lnt; pct exec 107 -- systemctl is-active --quiet mosquitto' }
    'influxdb' { $command = 'pct exec 110 -- curl --fail --silent --show-error --max-time 8 http://127.0.0.1:8086/health' }
    'shc' {
        $profile = 'jaylab-proxmox'
        $command = 'pct exec 105 -- /usr/local/bin/node -'
    }
    'mqtt-tls' {
        $profile = 'jaylab-proxmox'
        $command = 'pct exec 105 -- /usr/local/bin/node -'
    }
    'zigbee' {
        $profile = 'jaylab-proxmox'
        $command = 'pct exec 121 -- node -'
    }
}
if ($Service -in @('shc', 'mqtt-tls', 'zigbee')) {
    $scriptName = switch ($Service) {
        'shc' { 'Test-JaylabShc.js' }
        'mqtt-tls' { 'Test-JaylabMqttTls.js' }
        'zigbee' { 'Test-JaylabZigbee.js' }
    }
    Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $scriptName) |
        & wsl.exe --exec ssh -F $wslConfig $profile $command
} else {
    & wsl.exe --exec ssh -F $wslConfig $profile $command
}
if ($LASTEXITCODE -ne 0) { throw "Die Prüfung für $Service endete mit Code $LASTEXITCODE." }
