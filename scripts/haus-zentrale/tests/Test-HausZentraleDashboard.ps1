#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$hzDir = Split-Path -Parent $PSScriptRoot
$generatorPath = Join-Path $hzDir 'build_grafana_dashboard.ps1'
$devicesPath = Join-Path $hzDir 'devices.json'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw "ASSERTION FEHLGESCHLAGEN: $Message"
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )
    if ($Actual -cne $Expected) {
        throw "ASSERTION FEHLGESCHLAGEN ($Message): erwartet='$Expected', gefunden='$Actual'"
    }
}

function Get-AllPanelsFlat {
    param($Dashboard)
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $Dashboard.panels) {
        $all.Add($p)
        if ($p.type -eq 'row' -and $p.Contains('panels') -and $p.panels) {
            foreach ($sp in $p.panels) {
                $all.Add($sp)
            }
        }
    }
    return $all
}

function Test-GridNoOverlap {
    param(
        [object[]]$Panels,
        [string]$ScopeName
    )
    for ($i = 0; $i -lt $Panels.Count; $i++) {
        $a = $Panels[$i]
        $ga = $a.gridPos
        Assert-True ($ga.x -ge 0 -and $ga.w -ge 1 -and ($ga.x + $ga.w) -le 24 -and $ga.h -ge 1 -and $ga.y -ge 0) `
            "$ScopeName`: ungültige gridPos bei '$($a.title)' (x=$($ga.x), y=$($ga.y), w=$($ga.w), h=$($ga.h))"
        for ($j = $i + 1; $j -lt $Panels.Count; $j++) {
            $b = $Panels[$j]
            $gb = $b.gridPos
            $overlapX = ($ga.x -lt ($gb.x + $gb.w)) -and ($gb.x -lt ($ga.x + $ga.w))
            $overlapY = ($ga.y -lt ($gb.y + $gb.h)) -and ($gb.y -lt ($ga.y + $ga.h))
            Assert-True (-not ($overlapX -and $overlapY)) `
                "$ScopeName`: gridPos-Überlappung zwischen '$($a.title)' und '$($b.title)'"
        }
    }
}

function Get-OverrideColorMap {
    param($Panel)
    $map = [ordered]@{}
    foreach ($ov in $Panel.fieldConfig.overrides) {
        if ($ov.matcher.id -eq 'byName') {
            foreach ($prop in $ov.properties) {
                if ($prop.id -eq 'color' -and $prop.value.mode -eq 'fixed') {
                    $map[$ov.matcher.options] = $prop.value.fixedColor
                }
            }
        }
    }
    return $map
}

Assert-True (Test-Path -LiteralPath $generatorPath) "Generator fehlt: $generatorPath"
Assert-True (Test-Path -LiteralPath $devicesPath) "Geräteverzeichnis fehlt: $devicesPath"

$devices = Get-Content -Raw -LiteralPath $devicesPath | ConvertFrom-Json

# 1. Schnittstellen- und Datei-Ausgabeprüfung (UTF-8 ohne BOM)
$payload = & $generatorPath
Assert-True ($null -ne $payload) 'Generator liefert $null zurück.'
Assert-Equal $payload.folderUid '' 'folderUid muß leer sein'
Assert-Equal $payload.overwrite $true 'overwrite muß $true sein'
Assert-True (-not [string]::IsNullOrWhiteSpace($payload.message)) 'message darf nicht leer sein'

$tempJsonPath = Join-Path ([System.IO.Path]::GetTempPath()) ("hz-dashboard-test-" + [guid]::NewGuid().ToString('N') + ".json")
try {
    & $generatorPath -OutputPath $tempJsonPath | Out-Null
    Assert-True (Test-Path -LiteralPath $tempJsonPath) 'Ausgabedatei über -OutputPath wurde nicht geschrieben.'
    $bytes = [System.IO.File]::ReadAllBytes($tempJsonPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    Assert-True (-not $hasBom) 'Ausgabedatei darf keine UTF-8-BOM enthalten.'
    $jsonText = [System.Text.Encoding]::UTF8.GetString($bytes)
    $parsedFromFile = $jsonText | ConvertFrom-Json
    Assert-Equal $parsedFromFile.dashboard.uid 'jaylab-haus-zentrale' 'UID aus geschriebener JSON-Datei'
} finally {
    if (Test-Path -LiteralPath $tempJsonPath) {
        Remove-Item -LiteralPath $tempJsonPath -Force
    }
}

$dash = $payload.dashboard
$fullJson = $payload | ConvertTo-Json -Depth 100

# 2. Globale Metadaten & Kanonischer-Name-Prüfung
Assert-Equal $dash.uid 'jaylab-haus-zentrale' 'dashboard.uid'
Assert-Equal $dash.title 'Jaylab Haus-Zentrale' 'dashboard.title'
Assert-Equal $dash.time.from 'now-24h' 'dashboard.time.from'
Assert-Equal $dash.time.to 'now' 'dashboard.time.to'
Assert-Equal $dash.refresh '1m' 'dashboard.refresh'
Assert-True ($dash.tags -contains 'smart-home' -and $dash.tags -contains 'jaylab') 'dashboard.tags müssen smart-home und jaylab enthalten'

Assert-True ($fullJson -notmatch '(?i)Ela-Wandheizung') 'Ela-Wandheizung darf im gesamten Dashboard-JSON exakt 0-mal vorkommen'
Assert-True ($fullJson -match 'Springer') 'Kanonischer Name Springer muß im Dashboard vorkommen'
Assert-True ($fullJson -match 'E2 Wohn-/Eßzimmer') 'Kanonischer Raumname E2 Wohn-/Eßzimmer (vor 1996) muß vorkommen'
Assert-True ($fullJson -notmatch '\b(dass|muss|lässt|erfasst|Prozess|Abschluss)\b') 'Keine Schreibweisen von nach 1996 im Dashboard-JSON erlaubt'

$jsonDoc = [System.Text.Json.JsonDocument]::Parse($fullJson)
function Assert-JsonArrayFields {
    param($Element, [string]$Path)
    if ($Element.ValueKind -eq 'Object') {
        foreach ($prop in $Element.EnumerateObject()) {
            $childPath = "$Path.$($prop.Name)"
            if (($prop.Name -in @('panels', 'targets', 'overrides', 'mappings', 'steps', 'transformations', 'calcs', 'tags')) -or
                ($prop.Name -eq 'sort' -and $childPath -notmatch 'tooltip\.sort$')) {
                Assert-True ($prop.Value.ValueKind -eq 'Array') "JSON-Array-Kollaps bei '$childPath' ($($prop.Value.ValueKind))"
            }
            Assert-JsonArrayFields -Element $prop.Value -Path $childPath
        }
    } elseif ($Element.ValueKind -eq 'Array') {
        $i = 0
        foreach ($item in $Element.EnumerateArray()) {
            Assert-JsonArrayFields -Element $item -Path "$Path[$i]"
            $i++
        }
    }
}
Assert-JsonArrayFields -Element $jsonDoc.RootElement -Path 'root'
$jsonDoc.Dispose()

# 3. Exakt 5 Rows im Grafana-13.3.1-Format
$topRows = @($dash.panels | Where-Object { $_.type -eq 'row' })
Assert-Equal $topRows.Count 5 'Exakt 5 row-Panels erforderlich'

$expectedRows = @(
    @{ title = 'Auf einen Blick'; collapsed = $false },
    @{ title = 'Heizung & Raumklima'; collapsed = $false },
    @{ title = 'Energie & Verbraucher'; collapsed = $true },
    @{ title = 'Türen, Fenster & Wetter'; collapsed = $true },
    @{ title = 'Sensoren & Technik'; collapsed = $true }
)
for ($idx = 0; $idx -lt 5; $idx++) {
    Assert-Equal $topRows[$idx].title $expectedRows[$idx].title "Row $($idx + 1) Titel"
    Assert-Equal $topRows[$idx].collapsed $expectedRows[$idx].collapsed "Row $($idx + 1) collapsed"
}

$row1 = $topRows[0]
$row2 = $topRows[1]
$row3 = $topRows[2]
$row4 = $topRows[3]
$row5 = $topRows[4]

Assert-Equal $row1.panels.Count 0 'Offene Row 1 darf keine eingebetteten row.panels tragen'
Assert-Equal $row2.panels.Count 0 'Offene Row 2 darf keine eingebetteten row.panels tragen'
Assert-True ($row3.panels.Count -ge 3) 'Eingeklappte Row 3 muß ihre Unter-Panels in row.panels tragen'
Assert-True ($row4.panels.Count -ge 4) 'Eingeklappte Row 4 muß ihre Unter-Panels in row.panels tragen'
Assert-True ($row5.panels.Count -ge 5) 'Eingeklappte Row 5 muß ihre Unter-Panels in row.panels tragen'

Assert-Equal $row4.gridPos.y ($row3.gridPos.y + 1) 'Top-Level-y von Row 4 nach eingeklappter Row 3'
Assert-Equal $row5.gridPos.y ($row4.gridPos.y + 1) 'Top-Level-y von Row 5 nach eingeklappter Row 4'

# 4. Eindeutige Panel-IDs, Datasource und überlappungsfreies gridPos
$allPanels = Get-AllPanelsFlat -Dashboard $dash
$idSet = [System.Collections.Generic.HashSet[int]]::new()
foreach ($p in $allPanels) {
    Assert-True ($idSet.Add([int]$p.id)) "Doppelte Panel-ID: $($p.id) ($($p.title))"
    if ($p.type -ne 'row') {
        Assert-Equal $p.datasource.type 'influxdb' "Datasource-Typ bei '$($p.title)'"
        Assert-Equal $p.datasource.uid 'f7QzURA7k' "Datasource-UID bei '$($p.title)'"
        foreach ($t in $p.targets) {
            Assert-Equal $t.datasource.uid 'f7QzURA7k' "Target-Datasource-UID bei '$($p.title)'"
        }
    }
}

Test-GridNoOverlap -Panels @($dash.panels) -ScopeName 'Top-Level'
Test-GridNoOverlap -Panels @($row3.panels) -ScopeName 'Row 3 (Energie & Verbraucher)'
Test-GridNoOverlap -Panels @($row4.panels) -ScopeName 'Row 4 (Türen, Fenster & Wetter)'
Test-GridNoOverlap -Panels @($row5.panels) -ScopeName 'Row 5 (Sensoren & Technik)'

# Unter-Panels von Row 1 und Row 2 im Top-Level eindeutig verorten
$row1Panels = @($dash.panels | Where-Object { $_.type -ne 'row' -and $_.gridPos.y -gt $row1.gridPos.y -and $_.gridPos.y -lt $row2.gridPos.y })
$row2Panels = @($dash.panels | Where-Object { $_.type -ne 'row' -and $_.gridPos.y -gt $row2.gridPos.y -and $_.gridPos.y -lt $row3.gridPos.y })
Assert-True ($row1Panels.Count -ge 6) "Row 1 muß mindestens 6 Unter-Panels enthalten (gefunden: $($row1Panels.Count))"
Assert-True ($row2Panels.Count -ge 4) "Row 2 muß mindestens 4 Unter-Panels enthalten (gefunden: $($row2Panels.Count))"

# 5. Row 1 Detailprüfungen
$pWashStatus = $row1Panels | Where-Object { $_.title -eq 'Waschmaschine — Status' }
$pWashCurve = $row1Panels | Where-Object { $_.title -eq 'Waschmaschine — 6h Leistung' }
$pCreality = $row1Panels | Where-Object { $_.title -eq 'Creality (3D-Drucker)' }
$pOtherPlugs = $row1Panels | Where-Object { $_.title -eq 'Weitere Steckdosen (ZS Kompressor & Springer)' }
$pDoorsStat = $row1Panels | Where-Object { $_.title -eq 'Fenster & Türen' }
$pAlarm = $row1Panels | Where-Object { $_.title -eq 'Alarmsystem & Anwesenheit' }
$pHealthStat = $row1Panels | Where-Object { $_.title -eq 'Auffällige Geräte' }

foreach ($req in @($pWashStatus, $pWashCurve, $pCreality, $pOtherPlugs, $pDoorsStat, $pAlarm, $pHealthStat)) {
    Assert-True ($null -ne $req) 'Pflicht-Panel in Row 1 fehlt'
}
Assert-Equal $pWashCurve.timeFrom '6h' 'Waschmaschine 6h Leistung timeFrom'
$washQ = ($pWashCurve.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($washQ -match 'powerMeter' -and $washQ -match '3014F711A0000493985923FF') 'Waschmaschine-6h-Kurve muß powerMeter für Waschmaschine abfragen'
$washThreshValues = @($pWashCurve.fieldConfig.defaults.thresholds.steps | ForEach-Object { $_.value })
Assert-True (($washThreshValues -contains 4) -and ($washThreshValues -contains 10)) 'Waschmaschine-6h-Kurve braucht Schwellenlinien 4 W und 10 W'

$otherPlugsJson = $pOtherPlugs | ConvertTo-Json -Depth 50
Assert-True ($otherPlugsJson -match 'Springer' -and $otherPlugsJson -match 'ZS Kompressor' -and $otherPlugsJson -match 'deviceHealth') 'Row 1 Weitere Steckdosen braucht Springer, ZS Kompressor und deviceHealth'
Assert-Equal $pOtherPlugs.options.reduceOptions.fields '/.*/' 'Weitere Steckdosen stat braucht reduceOptions.fields = /.*/ für Stringwerte'

$doorsStatQ = ($pDoorsStat.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($doorsStatQ -match 'contactStatus') 'Row 1 Fenster & Türen muß contactStatus abfragen'
Assert-True ($doorsStatQ -notmatch 'ShutterContact') 'Row 1 Fenster & Türen darf nicht ShutterContact abfragen'
Assert-Equal $pDoorsStat.options.reduceOptions.fields '/.*/' 'Fenster & Türen stat braucht reduceOptions.fields = /.*/ für Stringwerte'
Assert-True ($doorsStatQ -match 'deviceId:\s*"_none_"' -and $doorsStatQ -match 'deviceId:\s*r\.deviceId') 'Row 1 Fenster & Türen muß deviceId vor union/reduce erhalten, damit geschlossene Kontakte nicht verworfen werden'
Assert-True ($doorsStatQ -match 'sort\(columns:\s*\["name"\]\)') 'Row 1 Fenster & Türen muß Kontakte deterministisch nach name sortieren'

$alarmQ = ($pAlarm.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($alarmQ -match 'securityStatus') 'Alarmsystem & Anwesenheit muß securityStatus abfragen'

$aqaraSensors = @($devices.climateSensors | Where-Object { $_.bucket -eq 'zigbee2mqtt' })
Assert-Equal $aqaraSensors.Count 6 'Erwartet 6 Aqara-Sensoren'

$healthStatQ = ($pHealthStat.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($healthStatQ -match 'deviceHealth' -and $healthStatQ -match 'zigbee2mqtt' -and $healthStatQ -match 'faultCount' -and $healthStatQ -match 'battery') 'Auffällige Geräte muß deviceHealth + zigbee2mqtt prüfen'
foreach ($aq in $aqaraSensors) {
    Assert-True ($healthStatQ -match "r\[`"deviceId`"\]\s*==\s*`"$($aq.deviceId)`"") "Auffällige Geräte muß Aqara-Whitelist enthalten: $($aq.deviceId)"
}
foreach ($aqField in @('battery', 'voltage', 'linkquality', 'poweroutagecount', 'temp')) {
    Assert-True ($healthStatQ -match "`"$aqField`"") "Auffällige Geräte muß lastSeen-Feld '$aqField' prüfen"
}

# 6. Row 2 Detailprüfungen & Review Focus #5
$pMatrix = $row2Panels | Where-Object { $_.title -eq 'Raum-Matrix (11 Klimaräume)' }
$pTemp = $row2Panels | Where-Object { $_.title -eq 'Temperatur-Verlauf' }
$pValve = $row2Panels | Where-Object { $_.title -eq 'Ventilstellung' }
$pHumidity = $row2Panels | Where-Object { $_.title -eq 'Luftfeuchtigkeit' }

Assert-True ($null -ne $pMatrix) 'Raum-Matrix fehlt in Row 2'
Assert-Equal $pMatrix.type 'table' 'Raum-Matrix muß type=table sein'
Assert-Equal $pMatrix.gridPos.w 24 'Raum-Matrix muß volle Breite (24) haben'
Assert-True ($pMatrix.targets.Count -ge 7) 'Raum-Matrix braucht getrennte Query-Targets je Spalte'

$t0Query = $pMatrix.targets[0].query
Assert-True ($t0Query -match 'import\s+"array"' -and $t0Query -match 'array\.from') 'Erstes Target der Raum-Matrix muß array.from für die 11 Räume liefern'
foreach ($room in $devices.matrixRooms) {
    Assert-True ($t0Query.Contains($room.matrixRoom)) "Raum-Matrix array.from fehlt Raum '$($room.matrixRoom)'"
    Assert-True ($t0Query -match "Sortierung:\s*$($room.sortOrder)\b") "Raum-Matrix array.from fehlt Sortierung $($room.sortOrder) für '$($room.matrixRoom)'"
}
$joinTrans = $pMatrix.transformations | Where-Object { $_.id -eq 'joinByField' } | Select-Object -First 1
Assert-True ($null -ne $joinTrans) 'Raum-Matrix braucht Transformation joinByField'
Assert-Equal $joinTrans.options.byField 'Raum' 'joinByField.byField'
Assert-Equal $joinTrans.options.mode 'outer' 'joinByField.mode'

$calcTrans = $pMatrix.transformations | Where-Object { $_.id -eq 'calculateField' } | Select-Object -First 1
Assert-True ($null -ne $calcTrans) 'Raum-Matrix braucht Transformation calculateField für Diff °C'
Assert-Equal $calcTrans.options.alias 'Diff °C' 'calculateField.alias'
Assert-Equal $calcTrans.options.mode 'binary' 'calculateField.mode'
Assert-Equal $calcTrans.options.binary.left 'Ist °C' 'calculateField.binary.left'
Assert-Equal $calcTrans.options.binary.operator '-' 'calculateField.binary.operator'
Assert-Equal $calcTrans.options.binary.right 'Soll °C' 'calculateField.binary.right'

$sortTrans = $pMatrix.transformations | Where-Object { $_.id -eq 'sortBy' } | Select-Object -First 1
Assert-True ($null -ne $sortTrans) 'Raum-Matrix braucht Transformation sortBy'
$orgTrans = $pMatrix.transformations | Where-Object { $_.id -eq 'organize' } | Select-Object -First 1
Assert-True ($null -ne $orgTrans) 'Raum-Matrix braucht Transformation organize zum Ausblenden von Sortierung'
Assert-True ($orgTrans.options.excludeByName.Sortierung -eq $true) 'organize muß Sortierung ausblenden'

$istTarget = $pMatrix.targets | Where-Object { $_.query -match 'Ist °C' } | Select-Object -First 1
Assert-True ($null -ne $istTarget) 'Raum-Matrix braucht Ist °C Target'
Assert-True ($istTarget.query -match 'hdm:HomeMaticIP:3014F711A000289BB85F32B0') 'Raum-Matrix Ist °C muß Raumthermostat als Primärfühler in E2 Wohn-/Eßzimmer nutzen'
Assert-True ($istTarget.query -match '-24h') 'Raum-Matrix Ist °C muß 24h-Frischeregel anwenden'
Assert-True ($istTarget.query -notmatch '-365d|-14d|-7d') 'Raum-Matrix Ist °C darf keine veralteten Mehrtagesdaten > 24h holen'
foreach ($t in $pMatrix.targets) {
    if ($t.query -match 'union\(') {
        Assert-True ($t.query -notmatch 'Status|Fenster|Heizbedarf') 'Kein typgemischtes Flux-union über float und string in Raum-Matrix'
    }
}

$fensterTarget = $pMatrix.targets | Where-Object { $_.query -match 'Fenster' } | Select-Object -First 1
Assert-True ($null -ne $fensterTarget) 'Raum-Matrix braucht Fenster-Target'
Assert-True ($fensterTarget.query -match 'contactStatus') 'Raum-Matrix Fenster-Target muß contactStatus abfragen'
Assert-True ($fensterTarget.query -notmatch 'ShutterContact') 'Raum-Matrix Fenster-Target darf nicht ShutterContact abfragen'
$matrixJson = $pMatrix | ConvertTo-Json -Depth 50
Assert-True ($matrixJson -match 'Nicht erreichbar' -and $matrixJson -match 'Offen' -and $matrixJson -match 'Zu') 'Raum-Matrix braucht Value-Mappings Offen / Zu / Nicht erreichbar'

# Temperatur-Verlauf: alle 17 Fühler & Hex-Farben
$tempQ = ($pTemp.targets | ForEach-Object { $_.query }) -join "`n"
$tempColors = Get-OverrideColorMap -Panel $pTemp
Assert-Equal $tempColors.Count 17 'Temperatur-Verlauf braucht 17 Farb-Overrides'
foreach ($s in $devices.climateSensors) {
    Assert-True ($tempQ.Contains($s.deviceId)) "Temperatur-Verlauf fehlt deviceId $($s.deviceId)"
    Assert-Equal $tempColors[$s.canonicalName] $s.color "Temperatur-Farbe für $($s.canonicalName)"
}

# Ventilstellung: alle 10 TRVs & Hex-Farben
$trvs = @($devices.climateSensors | Where-Object { $_.hasValve -eq $true })
Assert-Equal $trvs.Count 10 'Erwartet 10 TRVs in devices.json'
$valveQ = ($pValve.targets | ForEach-Object { $_.query }) -join "`n"
$valveColors = Get-OverrideColorMap -Panel $pValve
Assert-Equal $valveColors.Count 10 'Ventilstellung braucht 10 Farb-Overrides'
foreach ($v in $trvs) {
    Assert-True ($valveQ.Contains($v.deviceId)) "Ventilstellung fehlt TRV $($v.deviceId)"
    Assert-Equal $valveColors[$v.canonicalName] $v.color "Ventil-Farbe für $($v.canonicalName)"
}
Assert-Equal $pValve.fieldConfig.defaults.min 0 'Ventilstellung min=0'
Assert-Equal $pValve.fieldConfig.defaults.max 100 'Ventilstellung max=100'
Assert-Equal $pValve.fieldConfig.defaults.unit 'percent' 'Ventilstellung unit=percent'

# Luftfeuchtigkeit: alle 7 Feuchtefühler, Farben & Komfortzone 40-60 %
$hums = @($devices.climateSensors | Where-Object { $_.hasHumidity -eq $true })
Assert-Equal $hums.Count 7 'Erwartet 7 Feuchtefühler in devices.json'
$humQ = ($pHumidity.targets | ForEach-Object { $_.query }) -join "`n"
$humColors = Get-OverrideColorMap -Panel $pHumidity
Assert-Equal $humColors.Count 7 'Luftfeuchtigkeit braucht 7 Farb-Overrides'
foreach ($h in $hums) {
    Assert-True ($humQ.Contains($h.deviceId)) "Luftfeuchtigkeit fehlt Fühler $($h.deviceId)"
    Assert-Equal $humColors[$h.canonicalName] $h.color "Luftfeuchtigkeit-Farbe für $($h.canonicalName)"
}
Assert-Equal $pHumidity.fieldConfig.defaults.custom.thresholdsStyle.mode 'area' 'Luftfeuchtigkeit Komfortzone thresholdsStyle=area'
$humThreshVals = @($pHumidity.fieldConfig.defaults.thresholds.steps | ForEach-Object { $_.value })
Assert-True (($humThreshVals -contains 40) -and ($humThreshVals -contains 60)) 'Luftfeuchtigkeit Komfortzone 40-60 %'

# 7. Row 3 (Energie & Verbraucher) in row3.panels
$pPowerTs = $row3.panels | Where-Object { $_.title -eq 'Leistungsverlauf (W)' }
$pEnergyTs = $row3.panels | Where-Object { $_.title -eq 'Energieverbrauch je Zeitraum (kWh)' }
$pPlugTable = $row3.panels | Where-Object { $_.title -eq 'Verbraucher-Übersicht' }
Assert-True ($null -ne $pPowerTs -and $null -ne $pEnergyTs -and $null -ne $pPlugTable) 'Row 3 Pflicht-Panels fehlen'

foreach ($tsPlug in @($pPowerTs, $pEnergyTs)) {
    $qTxt = ($tsPlug.targets | ForEach-Object { $_.query }) -join "`n"
    $cMap = Get-OverrideColorMap -Panel $tsPlug
    Assert-Equal $cMap.Count 4 "Steckdosen-Farboverrides in $($tsPlug.title)"
    foreach ($plug in $devices.smartPlugs) {
        Assert-True ($qTxt.Contains($plug.deviceId)) "$($tsPlug.title) fehlt Steckdose $($plug.deviceId)"
        Assert-True ($qTxt.Contains($plug.canonicalName)) "$($tsPlug.title) fehlt kanonischer Name $($plug.canonicalName)"
        Assert-Equal $cMap[$plug.canonicalName] $plug.color "$($tsPlug.title) Farbe für $($plug.canonicalName)"
    }
}
$energyQ = ($pEnergyTs.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($energyQ -match 'difference\(nonNegative:\s*true\)' -and $energyQ -match 'energyWh' -and $energyQ -match '1000\.0') 'Energieverbrauch braucht difference(nonNegative: true) auf energyWh / 1000.0'
Assert-True (($pPlugTable | ConvertTo-Json -Depth 50) -match 'Springer') 'Verbraucher-Übersicht muß Springer enthalten'

# 8. Row 4 (Türen, Fenster & Wetter) in row4.panels
$pContactTimeline = $row4.panels | Where-Object { $_.title -eq 'Tür- und Fenster-Verlauf' }
$pPressNow = $row4.panels | Where-Object { $_.title -eq 'Luftdruck (aktuell)' }
$pPressTrend = $row4.panels | Where-Object { $_.title -eq 'Luftdruck 3h-Tendenz' }
$pPress7d = $row4.panels | Where-Object { $_.title -eq 'Luftdruck 7-Tage-Verlauf' }
Assert-True ($null -ne $pContactTimeline -and $null -ne $pPressNow -and $null -ne $pPressTrend -and $null -ne $pPress7d) 'Row 4 Pflicht-Panels fehlen'

Assert-Equal $pContactTimeline.type 'state-timeline' 'Tür- und Fenster-Verlauf muß state-timeline sein'
$ctQ = ($pContactTimeline.targets | ForEach-Object { $_.query }) -join "`n"
Assert-True ($ctQ -match 'contactStatus') 'Tür- und Fenster-Verlauf muß contactStatus abfragen'
Assert-True ($ctQ -notmatch 'ShutterContact') 'Tür- und Fenster-Verlauf darf nicht ShutterContact abfragen'
foreach ($c in $devices.contacts) {
    Assert-True ($ctQ.Contains($c.deviceId)) "Tür- und Fenster-Verlauf fehlt Kontakt $($c.deviceId)"
    Assert-True ($ctQ.Contains($c.canonicalName)) "Tür- und Fenster-Verlauf fehlt kanonischer Name $($c.canonicalName)"
}
$ctJson = $pContactTimeline | ConvertTo-Json -Depth 50
Assert-True ($ctJson -match 'CLOSED' -and $ctJson -match 'OPEN' -and $ctJson -match 'UNAVAILABLE') 'Tür- und Fenster-Verlauf braucht Mappings für CLOSED/OPEN/UNAVAILABLE'

Assert-Equal $pPress7d.timeFrom '7d' 'Luftdruck 7-Tage-Verlauf muß timeFrom=7d setzen'

# 9. Row 5 (Sensoren & Technik) in row5.panels
$pShcHealth = $row5.panels | Where-Object { $_.title -eq 'SHC-Gerätegesundheit' }
$pAqDiag = $row5.panels | Where-Object { $_.title -eq 'Aqara-Diagnose' }
$pAqVolt = $row5.panels | Where-Object { $_.title -eq 'Aqara Batteriespannung' }
$pAqBat = $row5.panels | Where-Object { $_.title -eq 'Aqara Batterie in %' }
$pAqLqi = $row5.panels | Where-Object { $_.title -eq 'Aqara Funkqualität (LQI)' }
Assert-True ($null -ne $pShcHealth -and $null -ne $pAqDiag -and $null -ne $pAqVolt -and $null -ne $pAqBat -and $null -ne $pAqLqi) 'Row 5 Pflicht-Panels fehlen'

$shcHealthJson = $pShcHealth | ConvertTo-Json -Depth 50
Assert-True ($shcHealthJson -match 'deviceHealth' -and $shcHealthJson -match 'AVAILABLE' -and $shcHealthJson -match 'UNDEFINED' -and $shcHealthJson -match 'UNAVAILABLE' -and $shcHealthJson -match 'faultCount' -and $shcHealthJson -match 'faultSummary') 'SHC-Gerätegesundheit unvollständig'

$aqDiagJson = $pAqDiag | ConvertTo-Json -Depth 50
Assert-True ($aqDiagJson -match 'zigbee2mqtt' -and $aqDiagJson -match 'poweroutagecount' -and $aqDiagJson -match 'linkquality' -and $aqDiagJson -match 'voltage' -and $aqDiagJson -match 'battery') 'Aqara-Diagnose unvollständig'
Assert-True ($aqDiagJson -match '"value":\s*6' -and $aqDiagJson -match '"value":\s*24') 'Aqara-Diagnose braucht Altersschwellen 6 h und 24 h'
$aqDiagQ = ($pAqDiag.targets | ForEach-Object { $_.query }) -join "`n"
foreach ($aq in $aqaraSensors) {
    Assert-True ($aqDiagQ -match "r\[`"deviceId`"\]\s*==\s*`"$($aq.deviceId)`"") "Aqara-Diagnose muß Aqara-Whitelist enthalten: $($aq.deviceId)"
}
foreach ($colName in @('Batterie %', 'Spannung mV', 'LQI', 'Neustarts')) {
    $ov = $pAqDiag.fieldConfig.overrides | Where-Object { $_.matcher.options -eq $colName } | Select-Object -First 1
    $mapProp = $ov.properties | Where-Object { $_.id -eq 'mappings' } | Select-Object -First 1
    Assert-True ($null -ne $mapProp -and ($mapProp.value | ConvertTo-Json -Depth 10 -Compress) -match '"-1"') "Aqara-Diagnose '$colName' braucht Sentinel-Mapping für -1"
}
$tempDiagOv = $pAqDiag.fieldConfig.overrides | Where-Object { $_.matcher.options -eq 'Letzter Wert °C' } | Select-Object -First 1
$tempMapProp = $tempDiagOv.properties | Where-Object { $_.id -eq 'mappings' } | Select-Object -First 1
Assert-True ($null -ne $tempMapProp -and ($tempMapProp.value | ConvertTo-Json -Depth 10 -Compress) -match '"-999"') "Aqara-Diagnose 'Letzter Wert °C' braucht Sentinel-Mapping für -999"
$ageDiagOv = $pAqDiag.fieldConfig.overrides | Where-Object { $_.matcher.options -eq 'Letzte Meldung (Alter in Std.)' } | Select-Object -First 1
$ageMapProp = $ageDiagOv.properties | Where-Object { $_.id -eq 'mappings' } | Select-Object -First 1
Assert-True ($null -ne $ageMapProp -and ($ageMapProp.value | ConvertTo-Json -Depth 10 -Compress) -match '99999') "Aqara-Diagnose 'Letzte Meldung' braucht Range-Mapping für >= 99999"

foreach ($aqTs in @($pAqVolt, $pAqBat, $pAqLqi)) {
    Assert-Equal $aqTs.timeFrom '14d' "$($aqTs.title) muß timeFrom=14d setzen"
    $aqQ = ($aqTs.targets | ForEach-Object { $_.query }) -join "`n"
    $aqCols = Get-OverrideColorMap -Panel $aqTs
    Assert-Equal $aqCols.Count 6 "$($aqTs.title) braucht 6 Aqara-Farb-Overrides"
    foreach ($aq in $aqaraSensors) {
        Assert-True ($aqQ.Contains($aq.deviceId)) "$($aqTs.title) fehlt $($aq.deviceId)"
        Assert-Equal $aqCols[$aq.canonicalName] $aq.color "$($aqTs.title) Farbe für $($aq.canonicalName)"
    }
}

# 10. Einheitliche Tabellenlegenden & A-Z-Flux-Sortierung für alle Timeseries-Panels
$allTs = @($allPanels | Where-Object { $_.type -eq 'timeseries' })
Assert-True ($allTs.Count -ge 9) "Erwartet mindestens 9 Timeseries-Panels (gefunden: $($allTs.Count))"
foreach ($ts in $allTs) {
    $leg = $ts.options.legend
    Assert-Equal $leg.displayMode 'table' "Legend displayMode in $($ts.title)"
    Assert-Equal $leg.placement 'bottom' "Legend placement in $($ts.title)"
    Assert-Equal $leg.showLegend $true "Legend showLegend in $($ts.title)"
    Assert-True (-not $leg.PSObject.Properties['sortBy']) "Keine sortBy-Eigenschaft in Legend von $($ts.title)"
    $qAll = ($ts.targets | ForEach-Object { $_.query }) -join "`n"
    Assert-True ($qAll -match '\|\>\s*group\(\)\s*\r?\n\s*\|\>\s*sort\(columns:\s*\["_field",\s*"_time"\]\)\s*\r?\n\s*\|\>\s*group\(columns:\s*\["_field"\]\)') `
        "Deterministische A-Z-Sortierung fehlt in Flux-Abfrage von '$($ts.title)'"
}

# 11. Flux-Typsicherheit über alle Panels (float-Schreibweise von Node-RED vs int-Vergleiche)
foreach ($p in $allPanels) {
    if ($p.type -eq 'row') { continue }
    foreach ($t in $p.targets) {
        $q = $t.query
        Assert-True ($q -notmatch 'r\._value\s*(==|!=|>|<|>=|<=)') `
            "Ungecasteter Vergleich auf r._value in '$($p.title)' [$($t.refId)]"
        if ($q -match 'pivot\(') {
            Assert-True ($q -match '_value:\s*(int|float|string)\(v:\s*r\._value\)') `
                "pivot() ohne explizites _value-Casting in '$($p.title)' [$($t.refId)]"
        }
        if ($q -match 'int\(v:\s*r\.faultCount\)') {
            Assert-True ($q -match 'int\(v:\s*float\(v:\s*r\.faultCount\)\)') `
                "faultCount-Parsing muß int(v: float(v: r.faultCount)) verwenden in '$($p.title)'"
        }
    }
}

Write-Output ("BESTANDEN: Dashboard 'jaylab-haus-zentrale' mit {0} Panels in 5 Rows (Rows 3-5 eingeklappt), 0 Überlappungen und allen Geräte-/Farb-/Matrix-Prüfungen verifiziert." -f $allPanels.Count)
