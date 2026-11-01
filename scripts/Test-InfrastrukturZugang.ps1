#requires -Version 7.0
[CmdletBinding()]
param(
    [string[]]$DeviceId = @(),
    [ValidateRange(100, 30000)][int]$TimeoutMilliseconds = 3000,
    [string]$InventoryPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'inventory/infrastruktur.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json
$knownIds = @($inventory.devices | ForEach-Object { $_.id })
foreach ($id in $DeviceId) {
    if ($id -notin $knownIds) { throw "Unbekannte Geräte-ID: $id. Es wurde keine Verbindung geprüft." }
}
$devices = @($inventory.devices | Where-Object { $DeviceId.Count -eq 0 -or $_.id -in $DeviceId })

# Den gesamten Prüfbestand vor dem ersten Netzaufruf validieren.
foreach ($device in $devices) {
    if ($device.address) { $null = [System.Net.IPAddress]::Parse($device.address) }
    foreach ($port in $device.ports) {
        if (($port -isnot [int] -and $port -isnot [long]) -or $port -lt 1 -or $port -gt 65535) {
            throw "Ungültiger TCP-Port: $($device.id) / $port"
        }
    }
}

$checks = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($device in $devices) {
        if (-not $device.address -or $device.ports.Count -eq 0) {
            $results.Add([pscustomobject]@{
                device = $device.id; address = $device.address; port = $null
                result = 'nicht-geprueft'; detail = 'Adresse oder TCP-Prüfport unbekannt'
            })
            continue
        }
        foreach ($port in $device.ports) {
            $client = [System.Net.Sockets.TcpClient]::new()
            $check = [pscustomobject]@{
                Device = $device.id; Address = $device.address; Port = $port
                Client = $client; Task = $null; Clock = [System.Diagnostics.Stopwatch]::StartNew()
                StartError = $null
            }
            $checks.Add($check)
            try { $check.Task = $client.ConnectAsync($device.address, [int]$port) }
            catch { $check.StartError = $_.Exception.GetBaseException().Message }
        }
    }
    foreach ($check in $checks) {
        $state = 'fehler'
        $detail = $check.StartError
        if (-not $detail) {
            try {
                $remaining = [Math]::Max(1, $TimeoutMilliseconds - [int]$check.Clock.ElapsedMilliseconds)
                if (-not $check.Task.Wait($remaining)) {
                    $state = 'zeitueberschreitung'
                    $detail = 'Kein Verbindungsaufbau innerhalb der Prüffrist'
                } else {
                    $null = $check.Task.GetAwaiter().GetResult()
                    $state = 'tcp-erreichbar'
                    $detail = 'TCP-Verbindung hergestellt; Anmeldung und Geräteidentität nicht geprüft'
                }
            } catch { $detail = $_.Exception.GetBaseException().Message }
        }
        $results.Add([pscustomobject]@{
            device = $check.Device; address = $check.Address; port = $check.Port
            result = $state; detail = $detail
        })
    }
} finally {
    foreach ($check in $checks) { $check.Client.Dispose() }
}
[pscustomobject]@{
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    kind = 'tcp-transport-only'
    results = @($results.ToArray())
} | ConvertTo-Json -Depth 5
