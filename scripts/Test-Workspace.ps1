#requires -Version 7.0
[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$problems = [System.Collections.Generic.List[string]]::new()

function Add-Problem([string]$Message) { $problems.Add($Message) }

function Get-IPv4Number([string]$Address) {
    $ip = [System.Net.IPAddress]::Parse($Address)
    if ($ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Keine IPv4-Adresse: $Address"
    }
    $bytes = $ip.GetAddressBytes()
    return ([uint64]$bytes[0] -shl 24) + ([uint64]$bytes[1] -shl 16) +
        ([uint64]$bytes[2] -shl 8) + [uint64]$bytes[3]
}

try {
    $inventory = Get-Content -Raw -LiteralPath (Join-Path $Root 'inventory/infrastruktur.json') |
        ConvertFrom-Json -AsHashtable
    if ($inventory.schemaVersion -ne 1) { Add-Problem 'Inventar: unbekannte Schemaversion.' }
    if ($inventory.intent.segmentation -ne 'physisch-ohne-vlans') {
        Add-Problem 'Inventar widerspricht dem Architekturziel ohne VLANs.'
    }
    $deviceIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($device in $inventory.devices) {
        if (-not $device.id -or -not $deviceIds.Add($device.id)) {
            Add-Problem "Leere oder doppelte Geräte-ID: $($device.id)"
        }
        if ($device.address) { $null = [System.Net.IPAddress]::Parse($device.address) }
        foreach ($port in $device.ports) {
            if ($port -isnot [long] -and $port -isnot [int]) {
                Add-Problem "Port ist keine Zahl: $($device.id) / $port"
            } elseif ($port -lt 1 -or $port -gt 65535) {
                Add-Problem "Port außerhalb des Bereichs: $($device.id) / $port"
            }
        }
    }
    if (-not $deviceIds.Contains($inventory.intent.routerHost)) {
        Add-Problem 'Routerhost fehlt im Geräteinventar.'
    }
    $segmentIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $networks = [System.Collections.Generic.List[object]]::new()
    foreach ($segment in $inventory.segments) {
        if (-not $segment.id -or -not $segmentIds.Add($segment.id)) {
            Add-Problem "Leere oder doppelte Segment-ID: $($segment.id)"
        }
        $cidr = $segment.ipv4Cidr.Split('/')
        if ($cidr.Count -ne 2 -or [int]$cidr[1] -lt 0 -or [int]$cidr[1] -gt 32) {
            throw "Ungültiges IPv4-Netz: $($segment.ipv4Cidr)"
        }
        $mask = ([uint64]4294967295 -shl (32 - [int]$cidr[1])) -band [uint64]4294967295
        $network = (Get-IPv4Number $cidr[0]) -band $mask
        if ($network -ne (Get-IPv4Number $cidr[0])) {
            Add-Problem "IPv4-Netz enthält Hostbits: $($segment.ipv4Cidr)"
        }
        foreach ($other in $networks) {
            $commonMask = $mask -band $other.Mask
            if (($network -band $commonMask) -eq ($other.Network -band $commonMask)) {
                Add-Problem "Überlappende Segmente: $($segment.id) und $($other.Id)"
            }
        }
        $networks.Add(@{ Id = $segment.id; Network = $network; Mask = $mask })
        foreach ($field in @('gatewayV4', 'dnsV4')) {
            if (((Get-IPv4Number $segment[$field]) -band $mask) -ne $network) {
                Add-Problem "$($segment.id): $field liegt außerhalb des Segments."
            }
        }
        $v6 = $segment.ipv6Cidr.Split('/')
        if ($v6.Count -ne 2 -or [int]$v6[1] -lt 0 -or [int]$v6[1] -gt 128 -or
            [System.Net.IPAddress]::Parse($v6[0]).AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            Add-Problem "Ungültiges IPv6-Netz: $($segment.ipv6Cidr)"
        }
    }
    if ($inventory.physicalPorts.Count -ne $inventory.intent.physicalPortCount) {
        Add-Problem 'Portbestand stimmt nicht mit der physischen Portzahl überein.'
    }
    $portIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($port in $inventory.physicalPorts) {
        if (-not $port.id -or -not $portIds.Add($port.id)) { Add-Problem 'Doppelte oder leere Port-ID.' }
        if (-not $deviceIds.Contains($port.host)) { Add-Problem "Port ohne bekannten Host: $($port.id)" }
        if ($port.peerDevice -and -not $deviceIds.Contains($port.peerDevice)) {
            Add-Problem "Unbekanntes Gegenstück: $($port.id) / $($port.peerDevice)"
        }
        if ($port.segment -and $port.segment -ne 'wan' -and -not $segmentIds.Contains($port.segment)) {
            Add-Problem "Unbekanntes Segment: $($port.id) / $($port.segment)"
        }
        if ($port.verified) {
            foreach ($field in @('hostInterface', 'mac', 'peerDevice', 'peerPort', 'segment')) {
                if (-not $port[$field]) { Add-Problem "Bestätigter Port ohne $field`: $($port.id)" }
            }
        }
    }
} catch { Add-Problem "Inventar: $($_.Exception.Message)" }

$skillRoot = Join-Path $Root '.agents/skills'
$skills = @(Get-ChildItem -LiteralPath $skillRoot -Directory)
if ($skills.Count -eq 0) { Add-Problem 'Keine Projektskills gefunden.' }
foreach ($skill in $skills) {
    try {
        $body = Get-Content -Raw -LiteralPath (Join-Path $skill.FullName 'SKILL.md')
        $header = [regex]::Match($body, '\A---\r?\n(?<yaml>.*?)\r?\n---\r?\n', 'Singleline')
        if (-not $header.Success) { throw 'YAML-Kopf fehlt.' }
        # Die Projektskills verwenden bewußt nur zwei einfache YAML-Felder.
        $fields = @{}
        foreach ($line in ($header.Groups['yaml'].Value -split '\r?\n')) {
            if ($line -notmatch '^(name|description):\s*(.+)$') { throw "Ungültiges Metadatenfeld: $line" }
            $key = $Matches[1]
            if ($fields.ContainsKey($key)) { throw "Doppeltes Metadatenfeld: $key" }
            $fields[$key] = $Matches[2]
        }
        if ($fields.name -cne $skill.Name -or $fields.name.Length -gt 64 -or
            $fields.name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw 'Skillname ungültig.' }
        $description = $fields.description | ConvertFrom-Json
        if ($description -isnot [string] -or -not $description.Trim() -or
            $description.Length -gt 1024 -or $description -match '[<>]') {
            throw 'Skillbeschreibung ungültig.'
        }
        if ($body -match '\[TODO:') { throw 'Unfertige Skillvorlage.' }
        $ui = Get-Content -Raw -LiteralPath (Join-Path $skill.FullName 'agents/openai.yaml')
        foreach ($field in @('display_name', 'short_description', 'default_prompt')) {
            $match = [regex]::Match($ui, "(?m)^  ${field}: (.+)$")
            if (-not $match.Success) { throw "UI-Feld fehlt: $field" }
            $value = $match.Groups[1].Value | ConvertFrom-Json
            if (-not $value) { throw "Leeres UI-Feld: $field" }
            if ($field -eq 'short_description' -and ($value.Length -lt 25 -or $value.Length -gt 64)) {
                throw 'UI-Kurzbeschreibung außerhalb von 25 bis 64 Zeichen.'
            }
            if ($field -eq 'default_prompt' -and -not $value.Contains('$' + $skill.Name)) {
                throw 'UI-Einstieg nennt den Skill nicht.'
            }
        }
    } catch { Add-Problem "$($skill.Name): $($_.Exception.Message)" }
}

$markdown = @(
    Get-ChildItem -LiteralPath $Root -File -Filter '*.md'
    Get-ChildItem -LiteralPath (Join-Path $Root 'docs'), $skillRoot -Recurse -File -Filter '*.md'
)
foreach ($file in $markdown) {
    $body = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($link in [regex]::Matches($body, '\[[^\]]*\]\((?<target>[^)]+)\)')) {
        $target = $link.Groups['target'].Value
        if ($target -match '^(https?://|#|mailto:)') { continue }
        $target = ($target -split '#', 2)[0]
        if (-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $target))) {
            Add-Problem "Defekter Verweis in $($file.Name): $target"
        }
    }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Root 'scripts') -File -Filter '*.ps1') {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) { Add-Problem "$($file.Name): $($parseError.Message)" }
}

if ($problems.Count -gt 0) {
    foreach ($problem in $problems) { Write-Output "FEHLER: $problem" }
    exit 1
}
Write-Output "Workspace geprüft: Inventar, $($skills.Count) Skills, Verweise und PowerShell-Syntax in Ordnung. Keine Netzprüfung ausgeführt."
