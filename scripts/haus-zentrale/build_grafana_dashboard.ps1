#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Erzeugt das Grafana-API-Payload-Objekt für das Dashboard „Jaylab Haus-Zentrale“
# aus dem kanonischen Gerätekatalog (scripts/haus-zentrale/devices.json).
# Deutsche Texte und Kommentare in Rechtschreibung von vor 1996.

$devicesPath = Join-Path $PSScriptRoot 'devices.json'
if (-not (Test-Path -LiteralPath $devicesPath)) {
    throw "Kanonische Gerätekonfiguration fehlt: $devicesPath"
}
$devices = Get-Content -Raw -LiteralPath $devicesPath | ConvertFrom-Json

$script:NextPanelId = 1
function Get-NextPanelId {
    $id = $script:NextPanelId
    $script:NextPanelId++
    return $id
}

function New-DatasourceRef {
    return [ordered]@{
        type = 'influxdb'
        uid  = 'f7QzURA7k'
    }
}

function New-FluxTarget {
    param(
        [Parameter(Mandatory)][string]$RefId,
        [Parameter(Mandatory)][string]$Query
    )
    return [ordered]@{
        datasource = New-DatasourceRef
        query      = $Query
        refId      = $RefId
    }
}

function New-ColorOverride {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$HexColor
    )
    return [ordered]@{
        matcher = [ordered]@{
            id      = 'byName'
            options = $Name
        }
        properties = @(
            [ordered]@{
                id    = 'color'
                value = [ordered]@{
                    fixedColor = $HexColor
                    mode       = 'fixed'
                }
            }
        )
    }
}

function New-FieldOverride {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Properties
    )
    return [ordered]@{
        matcher = [ordered]@{
            id      = 'byName'
            options = $Name
        }
        properties = @($Properties)
    }
}

function New-ThresholdSteps {
    param([object[]]$Steps)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($s in $Steps) {
        $list.Add([ordered]@{
            color = $s.color
            value = $s.value
        })
    }
    return $list.ToArray()
}

function New-FluxDeviceNameFn {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [string]$FnName = 'deviceName',
        [string]$IdProp = 'deviceId',
        [string]$NameProp = 'canonicalName',
        [string]$FallbackExpr = 'id'
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("$FnName = (id) =>")
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $prefix = if ($i -eq 0) { '  if' } else { '  else if' }
        $idVal = $item.$IdProp
        $nameVal = $item.$NameProp
        $lines.Add("$prefix id == `"$idVal`" then `"$nameVal`"")
    }
    $lines.Add("  else $FallbackExpr")
    return ($lines -join "`n")
}

function New-FluxDeviceIdOrExpr {
    param([Parameter(Mandatory)][string[]]$DeviceIds)
    $parts = $DeviceIds | ForEach-Object { "    r[`"deviceId`"] == `"$_`"" }
    return ($parts -join " or`n")
}

function New-TimeseriesPanel {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable]$GridPos,
        [Parameter(Mandatory)][object[]]$Targets,
        [Parameter(Mandatory)][string]$Unit,
        [string]$Description = '',
        [object[]]$Overrides = @(),
        [object[]]$ThresholdSteps = @(@{ color = 'green'; value = $null }),
        [string]$ThresholdStyleMode = 'off',
        [string]$DrawStyle = 'line',
        [int]$FillOpacity = 0,
        [Nullable[double]]$Min = $null,
        [Nullable[double]]$Max = $null,
        [string]$TimeFrom = '',
        [string[]]$LegendCalcs = @('lastNotNull', 'min', 'max')
    )
    $defaults = [ordered]@{
        color = [ordered]@{
            mode = 'palette-classic'
        }
        custom = [ordered]@{
            axisCenteredZero  = $false
            axisColorMode     = 'text'
            axisLabel         = ''
            axisPlacement     = 'auto'
            barAlignment      = 0
            drawStyle         = $DrawStyle
            fillOpacity       = $FillOpacity
            gradientMode      = 'none'
            hideFrom          = [ordered]@{
                legend  = $false
                tooltip = $false
                viz     = $false
            }
            lineInterpolation = 'linear'
            lineWidth         = 1
            pointSize         = 5
            scaleDistribution = [ordered]@{
                type = 'linear'
            }
            showPoints        = 'auto'
            spanNulls         = $false
            stacking          = [ordered]@{
                group = 'A'
                mode  = 'none'
            }
            thresholdsStyle   = [ordered]@{
                mode = $ThresholdStyleMode
            }
        }
        mappings   = @()
        thresholds = [ordered]@{
            mode  = 'absolute'
            steps = @(New-ThresholdSteps -Steps $ThresholdSteps)
        }
        unit       = $Unit
    }
    if ($null -ne $Min) { $defaults['min'] = $Min }
    if ($null -ne $Max) { $defaults['max'] = $Max }

    $panel = [ordered]@{
        datasource  = New-DatasourceRef
        description = $Description
        fieldConfig = [ordered]@{
            defaults  = $defaults
            overrides = @($Overrides)
        }
        gridPos     = $GridPos
        id          = (Get-NextPanelId)
        options     = [ordered]@{
            legend = [ordered]@{
                calcs       = @($LegendCalcs)
                displayMode = 'table'
                placement   = 'bottom'
                showLegend  = $true
            }
            tooltip = [ordered]@{
                mode = 'single'
                sort = 'none'
            }
        }
        targets     = @($Targets)
        title       = $Title
        type        = 'timeseries'
    }
    if (-not [string]::IsNullOrWhiteSpace($TimeFrom)) {
        $panel['timeFrom'] = $TimeFrom
    }
    return $panel
}

function New-StatPanel {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable]$GridPos,
        [Parameter(Mandatory)][object[]]$Targets,
        [string]$Description = '',
        [string]$Unit = 'none',
        [Nullable[int]]$Decimals = $null,
        [string]$ColorMode = 'background',
        [string]$GraphMode = 'none',
        [string]$Orientation = 'auto',
        [string]$TextMode = 'value_and_name',
        [string]$ReduceFields = '',
        [string]$NoValue = '–',
        [object[]]$Mappings = @(),
        [object[]]$ThresholdSteps = @(@{ color = 'green'; value = $null }),
        [object[]]$Overrides = @()
    )
    $defaults = [ordered]@{
        color      = [ordered]@{
            mode = 'thresholds'
        }
        mappings   = @($Mappings)
        noValue    = $NoValue
        thresholds = [ordered]@{
            mode  = 'absolute'
            steps = @(New-ThresholdSteps -Steps $ThresholdSteps)
        }
        unit       = $Unit
    }
    if ($null -ne $Decimals) {
        $defaults['decimals'] = $Decimals
    }
    return [ordered]@{
        datasource  = New-DatasourceRef
        description = $Description
        fieldConfig = [ordered]@{
            defaults  = $defaults
            overrides = @($Overrides)
        }
        gridPos     = $GridPos
        id          = (Get-NextPanelId)
        options     = [ordered]@{
            colorMode     = $ColorMode
            graphMode     = $GraphMode
            justifyMode   = 'center'
            orientation   = $Orientation
            reduceOptions = [ordered]@{
                calcs  = @('lastNotNull')
                fields = $ReduceFields
                values = $false
            }
            text          = [ordered]@{}
            textMode      = $TextMode
        }
        targets     = @($Targets)
        title       = $Title
        type        = 'stat'
    }
}

function New-TablePanel {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable]$GridPos,
        [Parameter(Mandatory)][object[]]$Targets,
        [string]$Description = '',
        [object[]]$Overrides = @(),
        [object[]]$Transformations = @(),
        [string]$NoValue = '–'
    )
    return [ordered]@{
        datasource  = New-DatasourceRef
        description = $Description
        fieldConfig = [ordered]@{
            defaults  = [ordered]@{
                color      = [ordered]@{
                    mode = 'thresholds'
                }
                custom     = [ordered]@{
                    align       = 'auto'
                    cellOptions = [ordered]@{
                        type = 'auto'
                    }
                    inspect     = $false
                }
                mappings   = @()
                noValue    = $NoValue
                thresholds = [ordered]@{
                    mode  = 'absolute'
                    steps = @(New-ThresholdSteps -Steps @(@{ color = 'text'; value = $null }))
                }
            }
            overrides = @($Overrides)
        }
        gridPos         = $GridPos
        id              = (Get-NextPanelId)
        options         = [ordered]@{
            cellHeight = 'sm'
            footer     = [ordered]@{
                countRows = $false
                fields    = ''
                reducer   = @('sum')
                show      = $false
            }
            showHeader = $true
        }
        targets         = @($Targets)
        title           = $Title
        transformations = @($Transformations)
        type            = 'table'
    }
}

function New-RowPanel {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][bool]$Collapsed,
        [object[]]$ChildPanels = @()
    )
    $rowPanels = if ($Collapsed) { @($ChildPanels) } else { @() }
    return [ordered]@{
        collapsed = $Collapsed
        gridPos   = [ordered]@{
            h = 1
            w = 24
            x = 0
            y = $Y
        }
        id        = (Get-NextPanelId)
        panels    = @($rowPanels)
        title     = $Title
        type      = 'row'
    }
}

function New-ApplianceStatusPanel {
    param(
        [Parameter(Mandatory)]$Plug,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][hashtable]$GridPos,
        [string]$Description = ''
    )
    $devId = $Plug.deviceId
    $runLabel = $Plug.applianceConfig.runningLabel

    $qState = @"
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "stateCode" and r["deviceId"] == "$devId")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: int(v: r._value), _field: "Zustand" }))
  |> group(columns: ["_field"])
"@
    $qPower = @"
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "power" and r["deviceId"] == "$devId")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: "Leistung" }))
  |> group(columns: ["_field"])
"@
    $qCycleKwh = @"
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "cycleEnergyWh" and r["deviceId"] == "$devId")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value) / 1000.0, _field: "Zyklus" }))
  |> group(columns: ["_field"])
"@
    $qCycleMin = @"
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "cycleDurationMin" and r["deviceId"] == "$devId")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: "Dauer" }))
  |> group(columns: ["_field"])
"@
    $qFinished = @"
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "finishedAtEpoch" and r["deviceId"] == "$devId")
  |> filter(fn: (r) => float(v: r._value) > 0.0)
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value) * 1000.0, _field: "Letztes Ende" }))
  |> group(columns: ["_field"])
"@

    $stateMappings = @(
        [ordered]@{
            options = [ordered]@{
                '0' = [ordered]@{ color = '#6E7681'; index = 0; text = 'Aus' }
                '1' = [ordered]@{ color = '#3274D9'; index = 1; text = 'Bereit' }
                '2' = [ordered]@{ color = '#FF9830'; index = 2; text = $runLabel }
                '3' = [ordered]@{ color = '#37872D'; index = 3; text = 'Fertig' }
            }
            type    = 'value'
        }
    )
    $stateThresholds = @{
        mode  = 'absolute'
        steps = @(New-ThresholdSteps -Steps @(
            @{ color = '#6E7681'; value = $null },
            @{ color = '#3274D9'; value = 1 },
            @{ color = '#FF9830'; value = 2 },
            @{ color = '#37872D'; value = 3 }
        ))
    }

    $overrides = @(
        (New-FieldOverride -Name 'Zustand' -Properties @(
            [ordered]@{ id = 'mappings'; value = @($stateMappings) },
            [ordered]@{ id = 'thresholds'; value = $stateThresholds }
        )),
        (New-FieldOverride -Name 'Leistung' -Properties @(
            [ordered]@{ id = 'unit'; value = 'watt' },
            [ordered]@{ id = 'decimals'; value = 1 },
            [ordered]@{
                id    = 'thresholds'
                value = [ordered]@{
                    mode  = 'absolute'
                    steps = @(New-ThresholdSteps -Steps @(
                        @{ color = '#37474F'; value = $null },
                        @{ color = '#FF9830'; value = [double]$Plug.applianceConfig.startThresholdW }
                    ))
                }
            }
        )),
        (New-FieldOverride -Name 'Zyklus' -Properties @(
            [ordered]@{ id = 'unit'; value = 'kwatth' },
            [ordered]@{ id = 'decimals'; value = 3 },
            [ordered]@{
                id    = 'thresholds'
                value = [ordered]@{
                    mode  = 'absolute'
                    steps = @(New-ThresholdSteps -Steps @(@{ color = '#37474F'; value = $null }))
                }
            }
        )),
        (New-FieldOverride -Name 'Dauer' -Properties @(
            [ordered]@{ id = 'unit'; value = 'm' },
            [ordered]@{ id = 'decimals'; value = 0 },
            [ordered]@{
                id    = 'thresholds'
                value = [ordered]@{
                    mode  = 'absolute'
                    steps = @(New-ThresholdSteps -Steps @(@{ color = '#37474F'; value = $null }))
                }
            }
        )),
        (New-FieldOverride -Name 'Letztes Ende' -Properties @(
            [ordered]@{ id = 'unit'; value = 'dateTimeFromNow' },
            [ordered]@{
                id    = 'thresholds'
                value = [ordered]@{
                    mode  = 'absolute'
                    steps = @(New-ThresholdSteps -Steps @(@{ color = '#2E4A3E'; value = $null }))
                }
            }
        ))
    )

    return New-StatPanel -Title $Title -Description $Description -GridPos $GridPos `
        -Orientation 'horizontal' -ReduceFields '/.*/' -Targets @(
            (New-FluxTarget -RefId 'A' -Query $qState),
            (New-FluxTarget -RefId 'B' -Query $qPower),
            (New-FluxTarget -RefId 'C' -Query $qCycleKwh),
            (New-FluxTarget -RefId 'D' -Query $qCycleMin),
            (New-FluxTarget -RefId 'E' -Query $qFinished)
        ) -Overrides $overrides
}

# =========================================================================
# Gerätemengen aus devices.json vorbereiten
# =========================================================================
$climateSensors = @($devices.climateSensors)
$shcClimate = @($climateSensors | Where-Object { $_.bucket -eq 'shcbucket' })
$aqaraSensors = @($climateSensors | Where-Object { $_.bucket -eq 'zigbee2mqtt' })
$trvSensors = @($climateSensors | Where-Object { $_.hasValve -eq $true })
$humiditySensors = @($climateSensors | Where-Object { $_.hasHumidity -eq $true })
$shcHumidity = @($humiditySensors | Where-Object { $_.bucket -eq 'shcbucket' })
$contacts = @($devices.contacts)
$roomContacts = @($contacts | Where-Object { $null -ne $_.matrixRoom -and $_.matrixRoom -ne '' })
$smartPlugs = @($devices.smartPlugs)
$matrixRooms = @($devices.matrixRooms | Sort-Object sortOrder)

$plugWasch = $smartPlugs | Where-Object { $_.canonicalName -eq 'Waschmaschine' } | Select-Object -First 1
$plugCreality = $smartPlugs | Where-Object { $_.canonicalName -eq 'Creality' } | Select-Object -First 1
$otherPlugs = @($smartPlugs | Where-Object { $_.canonicalName -notin @('Waschmaschine', 'Creality') })

$sensorById = @{}
foreach ($s in $climateSensors) { $sensorById[$s.deviceId] = $s }

# =========================================================================
# ROW 1: Auf einen Blick (collapsed: false)
# =========================================================================
$row1 = New-RowPanel -Title 'Auf einen Blick' -Y 0 -Collapsed $false

$pWashStatus = New-ApplianceStatusPanel -Plug $plugWasch -Title 'Waschmaschine — Status' `
    -Description 'Aktueller Zustand (Aus / Bereit / Läuft / Fertig), Leistung und letzter Waschgang' `
    -GridPos @{ x = 0; y = 1; w = 10; h = 4 }

$washStartW = [double]$plugWasch.applianceConfig.startThresholdW
$washStopW = [double]$plugWasch.applianceConfig.stopThresholdW
$washDevId = $plugWasch.deviceId
$qWash6h = @"
from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "power" and r["deviceId"] == "$washDevId")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: "Waschmaschine" }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
$pWashCurve = New-TimeseriesPanel -Title 'Waschmaschine — 6h Leistung' `
    -Description "Leistungsaufnahme der letzten 6 Stunden inkl. Schwellenwerte ($washStopW W / $washStartW W)" `
    -GridPos @{ x = 0; y = 5; w = 10; h = 6 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qWash6h)) `
    -Unit 'watt' -Min 0 -TimeFrom '6h' `
    -ThresholdStyleMode 'dashed' `
    -ThresholdSteps @(
        @{ color = 'green'; value = $null },
        @{ color = 'yellow'; value = $washStopW },
        @{ color = 'orange'; value = $washStartW }
    ) `
    -Overrides @((New-ColorOverride -Name $plugWasch.canonicalName -HexColor $plugWasch.color))

$pCreality = New-ApplianceStatusPanel -Plug $plugCreality -Title 'Creality (3D-Drucker)' `
    -Description 'Aktueller Druckzustand (Aus / Bereit / Druckt / Fertig), Leistung und letzter Druckzyklus' `
    -GridPos @{ x = 10; y = 1; w = 6; h = 5 }

$otherPlugRows = ($otherPlugs | ForEach-Object {
    "  { deviceId: `"$($_.deviceId)`", name: `"$($_.canonicalName)`", available: -1.0, switchOn: -1.0, power: -1.0 }"
}) -join ",`n"
$otherPlugFilter = New-FluxDeviceIdOrExpr -DeviceIds @($otherPlugs | ForEach-Object { $_.deviceId })
$qOtherPlugs = @"
import "array"
import "math"

anchor = array.from(rows: [
$otherPlugRows
])

dh = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "deviceHealth" and r["_field"] == "available")
  |> filter(fn: (r) =>
$otherPlugFilter)
  |> last()
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: "", available: float(v: r._value), switchOn: -1.0, power: -1.0 }))

pmSwitch = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "switchOn")
  |> filter(fn: (r) =>
$otherPlugFilter)
  |> last()
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: "", available: -1.0, switchOn: float(v: r._value), power: -1.0 }))

pmPower = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "power")
  |> filter(fn: (r) =>
$otherPlugFilter)
  |> last()
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: "", available: -1.0, switchOn: -1.0, power: float(v: r._value) }))

union(tables: [anchor, dh, pmSwitch, pmPower])
  |> group(columns: ["deviceId"])
  |> reduce(
    identity: { name: "", available: -1.0, switchOn: -1.0, power: -1.0 },
    fn: (r, accumulator) => ({
      name: if r.name != "" then r.name else accumulator.name,
      available: if r.available >= 0.0 then r.available else accumulator.available,
      switchOn: if r.switchOn >= 0.0 then r.switchOn else accumulator.switchOn,
      power: if r.power >= 0.0 then r.power else accumulator.power
    })
  )
  |> map(fn: (r) => ({
    _time: now(),
    _field: r.name,
    _value:
      if r.available == 0.0 then "Nicht erreichbar"
      else if r.switchOn == 0.0 then "Aus"
      else if r.switchOn == 1.0 and r.power >= 0.0 then "Ein (" + string(v: math.round(x: r.power * 10.0) / 10.0) + " W)"
      else if r.switchOn == 1.0 then "Ein"
      else "–"
  }))
  |> group()
  |> sort(columns: ["_field"])
  |> group(columns: ["_field"])
"@
$plugStatusMappings = @(
    [ordered]@{
        options = [ordered]@{
            'Aus'              = [ordered]@{ color = '#6E7681'; index = 0 }
            'Nicht erreichbar' = [ordered]@{ color = '#EAB839'; index = 1 }
            '–'                = [ordered]@{ color = '#4A5568'; index = 2 }
        }
        type    = 'value'
    },
    [ordered]@{
        options = [ordered]@{
            pattern = '^Ein.*'
            result  = [ordered]@{ color = '#37872D'; index = 3 }
        }
        type    = 'regex'
    }
)
$pOtherPlugs = New-StatPanel -Title 'Weitere Steckdosen (ZS Kompressor & Springer)' `
    -Description 'Aktueller Schaltzustand, Leistung und Erreichbarkeit für ZS Kompressor und Springer' `
    -GridPos @{ x = 10; y = 6; w = 6; h = 5 } `
    -Orientation 'horizontal' -ReduceFields '/.*/' `
    -Mappings $plugStatusMappings `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qOtherPlugs))

$contactNameFn = New-FluxDeviceNameFn -Items $contacts
$contactBaseFlux = @"
$contactNameFn

base = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "contactStatus" and (r["_field"] == "isOpen" or r["_field"] == "available"))
  |> last()
  |> keep(columns: ["deviceId", "_field", "_value"])
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: deviceName(id: r.deviceId), _field: r._field, _value: int(v: r._value) }))
  |> group(columns: ["deviceId", "name"])
  |> pivot(rowKey: ["deviceId", "name"], columnKey: ["_field"], valueColumn: "_value")
  |> group()
  |> sort(columns: ["name"])

anchor = array.from(rows: [{ deviceId: "_none_", openCnt: 0, availCnt: 0, unavailCnt: 0, openNames: "", unavailNames: "" }])

stats = base
  |> map(fn: (r) => ({
    deviceId: r.deviceId,
    openCnt: if exists r.isOpen and r.isOpen == 1 then 1 else 0,
    availCnt: if exists r.available and r.available == 1 then 1 else 0,
    unavailCnt: if not exists r.available or r.available != 1 then 1 else 0,
    openNames: if exists r.isOpen and r.isOpen == 1 then r.name else "",
    unavailNames: if not exists r.available or r.available != 1 then r.name else ""
  }))
"@
$contactReduceBody = @"
union(tables: [anchor, stats])
  |> group()
  |> reduce(
    identity: { openCnt: 0, availCnt: 0, unavailCnt: 0, openNames: "", unavailNames: "" },
    fn: (r, accumulator) => ({
      openCnt: accumulator.openCnt + r.openCnt,
      availCnt: accumulator.availCnt + r.availCnt,
      unavailCnt: accumulator.unavailCnt + r.unavailCnt,
      openNames: if not exists r.openNames or r.openNames == "" then accumulator.openNames else if accumulator.openNames == "" then r.openNames else accumulator.openNames + ", " + r.openNames,
      unavailNames: if not exists r.unavailNames or r.unavailNames == "" then accumulator.unavailNames else if accumulator.unavailNames == "" then r.unavailNames else accumulator.unavailNames + ", " + r.unavailNames
    })
  )
"@

$qDoorsSummary = @"
import "array"
$contactBaseFlux
$contactReduceBody
  |> map(fn: (r) => ({
    _time: now(),
    _value: string(v: r.openCnt) + " offen (von " + string(v: r.availCnt) + " erreichbar)",
    _field: "Status"
  }))
  |> group(columns: ["_field"])
"@
$qDoorsOpen = @"
import "array"
$contactBaseFlux
$contactReduceBody
  |> map(fn: (r) => ({
    _time: now(),
    _value: if r.openCnt > 0 then r.openNames else "Keine",
    _field: "Offen"
  }))
  |> group(columns: ["_field"])
"@
$qDoorsUnavail = @"
import "array"
$contactBaseFlux
$contactReduceBody
  |> map(fn: (r) => ({
    _time: now(),
    _value: if r.unavailCnt > 0 then string(v: r.unavailCnt) + ": " + r.unavailNames else "0",
    _field: "Nicht erreichbar"
  }))
  |> group(columns: ["_field"])
"@

$doorsOverrides = @(
    (New-FieldOverride -Name 'Status' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        pattern = '^0 offen.*'
                        result  = [ordered]@{ color = '#37872D'; index = 0 }
                    }
                    type    = 'regex'
                },
                [ordered]@{
                    options = [ordered]@{
                        pattern = '^[1-9][0-9]* offen.*'
                        result  = [ordered]@{ color = '#F2495C'; index = 1 }
                    }
                    type    = 'regex'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Offen' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        'Keine' = [ordered]@{ color = '#37872D'; index = 0 }
                    }
                    type    = 'value'
                },
                [ordered]@{
                    options = [ordered]@{
                        pattern = '^.+$'
                        result  = [ordered]@{ color = '#F2495C'; index = 1 }
                    }
                    type    = 'regex'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Nicht erreichbar' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        '0' = [ordered]@{ color = '#37872D'; index = 0 }
                    }
                    type    = 'value'
                },
                [ordered]@{
                    options = [ordered]@{
                        pattern = '^[1-9].*'
                        result  = [ordered]@{ color = '#EAB839'; index = 1 }
                    }
                    type    = 'regex'
                }
            )
        }
    ))
)

$pDoorsStat = New-StatPanel -Title 'Fenster & Türen' `
    -Description 'Offene und nicht erreichbare Kontakte aus contactStatus (alle 9 Kontakte)' `
    -GridPos @{ x = 16; y = 1; w = 8; h = 5 } `
    -Orientation 'horizontal' -ReduceFields '/.*/' `
    -Targets @(
        (New-FluxTarget -RefId 'A' -Query $qDoorsSummary),
        (New-FluxTarget -RefId 'B' -Query $qDoorsOpen),
        (New-FluxTarget -RefId 'C' -Query $qDoorsUnavail)
    ) -Overrides $doorsOverrides

$qAlarmArmed = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "securityStatus" and r["service"] == "IntrusionDetectionControl" and r["_field"] == "armed")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: int(v: r._value), _field: "Alarmsystem" }))
  |> group(columns: ["_field"])
'@
$qAlarmActive = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "securityStatus" and r["service"] == "SurveillanceAlarm" and r["_field"] == "alarmActive")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: int(v: r._value), _field: "Alarmstatus" }))
  |> group(columns: ["_field"])
'@
$qPresence = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "securityStatus" and r["service"] == "PresenceSimulationConfiguration" and r["_field"] == "presenceSimEnabled")
  |> last()
  |> map(fn: (r) => ({ _time: r._time, _value: int(v: r._value), _field: "Anwesenheit" }))
  |> group(columns: ["_field"])
'@
$alarmOverrides = @(
    (New-FieldOverride -Name 'Alarmsystem' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        '0' = [ordered]@{ color = '#37872D'; index = 0; text = 'Unscharf' }
                        '1' = [ordered]@{ color = '#3274D9'; index = 1; text = 'Scharf' }
                        '2' = [ordered]@{ color = '#FF9830'; index = 2; text = 'Aktivierung' }
                    }
                    type    = 'value'
                }
            )
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#37872D'; value = $null },
                    @{ color = '#3274D9'; value = 1 },
                    @{ color = '#FF9830'; value = 2 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Alarmstatus' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        '0' = [ordered]@{ color = '#37872D'; index = 0; text = 'Kein Alarm' }
                        '1' = [ordered]@{ color = '#F2495C'; index = 1; text = 'ALARM' }
                    }
                    type    = 'value'
                }
            )
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#37872D'; value = $null },
                    @{ color = '#F2495C'; value = 1 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Anwesenheit' -Properties @(
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        '0' = [ordered]@{ color = '#6E7681'; index = 0; text = 'Aus' }
                        '1' = [ordered]@{ color = '#37872D'; index = 1; text = 'Aktiv' }
                    }
                    type    = 'value'
                }
            )
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#6E7681'; value = $null },
                    @{ color = '#37872D'; value = 1 }
                ))
            }
        }
    ))
)
$pAlarm = New-StatPanel -Title 'Alarmsystem & Anwesenheit' `
    -Description 'Zustand von Alarmsystem, Sirene und Anwesenheitssimulation' `
    -GridPos @{ x = 16; y = 6; w = 4; h = 5 } `
    -Orientation 'vertical' -ReduceFields '/.*/' `
    -Targets @(
        (New-FluxTarget -RefId 'A' -Query $qAlarmArmed),
        (New-FluxTarget -RefId 'B' -Query $qAlarmActive),
        (New-FluxTarget -RefId 'C' -Query $qPresence)
    ) -Overrides $alarmOverrides

$aqTempOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($aqaraSensors | ForEach-Object { $_.deviceId })
$aqWarnAnchorRows = ($aqaraSensors | ForEach-Object {
    "  { deviceId: `"$($_.deviceId)`", _field: `"seed`", _value: 0.0, ageH: 99999.0 }"
}) -join ",`n"
$healthWarnBase = @"
import "array"

knownAq = array.from(rows: [
$aqWarnAnchorRows
])

aqBase = from(bucket: "zigbee2mqtt")
  |> range(start: -365d)
  |> filter(fn: (r) => r["_field"] == "battery" or r["_field"] == "voltage" or r["_field"] == "linkquality" or r["_field"] == "poweroutagecount" or r["_field"] == "temp")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> last()
  |> group()
  |> map(fn: (r) => ({
    deviceId: r.deviceId,
    _field: r._field,
    _value: float(v: r._value),
    ageH: float(v: uint(v: now()) - uint(v: r._time)) / 3600000000000.0
  }))

aqWarn = union(tables: [knownAq, aqBase])
  |> group(columns: ["deviceId"])
  |> reduce(
    identity: { bat: -1.0, ageH: 99999.0 },
    fn: (r, accumulator) => ({
      bat: if r._field == "battery" then r._value else accumulator.bat,
      ageH: if r.ageH < accumulator.ageH then r.ageH else accumulator.ageH
    })
  )
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, warn: if r.ageH > 6.0 or r.bat < 25.0 then 1 else 0 }))
  |> filter(fn: (r) => r.warn == 1)
  |> keep(columns: ["deviceId", "warn"])

shcWarn = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "deviceHealth" and (r["_field"] == "available" or r["_field"] == "faultCount"))
  |> last()
  |> keep(columns: ["deviceId", "_field", "_value"])
  |> map(fn: (r) => ({ deviceId: r.deviceId, _field: r._field, _value: int(v: r._value) }))
  |> group(columns: ["deviceId"])
  |> pivot(rowKey: ["deviceId"], columnKey: ["_field"], valueColumn: "_value")
  |> group()
  |> map(fn: (r) => ({
    deviceId: r.deviceId,
    warn: if (exists r.available and r.available == 0) or (exists r.faultCount and r.faultCount > 0) then 1 else 0
  }))
  |> filter(fn: (r) => r.warn == 1)

zeroAnchor = array.from(rows: [{ deviceId: "_none_", warn: 0 }])
"@

$qHealthTotal = @"
$healthWarnBase
union(tables: [zeroAnchor, aqWarn, shcWarn])
  |> group()
  |> sum(column: "warn")
  |> map(fn: (r) => ({ _time: now(), _value: r.warn, _field: "Gesamt" }))
  |> group(columns: ["_field"])
"@
$qHealthShc = @"
$healthWarnBase
union(tables: [zeroAnchor, shcWarn])
  |> group()
  |> sum(column: "warn")
  |> map(fn: (r) => ({ _time: now(), _value: r.warn, _field: "SHC" }))
  |> group(columns: ["_field"])
"@
$qHealthAq = @"
$healthWarnBase
union(tables: [zeroAnchor, aqWarn])
  |> group()
  |> sum(column: "warn")
  |> map(fn: (r) => ({ _time: now(), _value: r.warn, _field: "Aqara" }))
  |> group(columns: ["_field"])
"@
$pHealthStat = New-StatPanel -Title 'Auffällige Geräte' `
    -Description 'Summe nicht erreichbarer/gestörter SHC-Geräte (deviceHealth) und überfälliger/batterieschwacher Aqara-Sensoren (> 6 h oder < 25 %)' `
    -GridPos @{ x = 20; y = 6; w = 4; h = 5 } `
    -Orientation 'vertical' -Decimals 0 -ReduceFields '/.*/' `
    -ThresholdSteps @(
        @{ color = '#37872D'; value = $null },
        @{ color = '#EAB839'; value = 1 },
        @{ color = '#F2495C'; value = 3 }
    ) `
    -Targets @(
        (New-FluxTarget -RefId 'A' -Query $qHealthTotal),
        (New-FluxTarget -RefId 'B' -Query $qHealthShc),
        (New-FluxTarget -RefId 'C' -Query $qHealthAq)
    )

# =========================================================================
# ROW 2: Heizung & Raumklima (collapsed: false)
# =========================================================================
$row2 = New-RowPanel -Title 'Heizung & Raumklima' -Y 11 -Collapsed $false

# --- Raum-Matrix (11 Klimaräume) ---
$matrixOrderRows = ($matrixRooms | ForEach-Object {
    "  { Sortierung: $($_.sortOrder), Raum: `"$($_.matrixRoom)`" }"
}) -join ",`n"
$qMatrixRooms = @"
import "array"
array.from(rows: [
$matrixOrderRows
])
"@

# Ist °C: aus devices.json matrixRooms abgeleitet (24h-Frischeregel, Raumthermostat primär in E2 Wohn-/Eßzimmer)
$shcPrimaryItems = [System.Collections.Generic.List[object]]::new()
$shcDualFallbackItems = [System.Collections.Generic.List[object]]::new()
$shcMultiFallbackRooms = [System.Collections.Generic.List[object]]::new()
$aqaraRoomItems = [System.Collections.Generic.List[object]]::new()

foreach ($mr in $matrixRooms) {
    $prim = $sensorById[$mr.primaryTempId]
    if ($prim.bucket -eq 'shcbucket') {
        $shcPrimaryItems.Add([pscustomobject]@{ deviceId = $prim.deviceId; room = $mr.matrixRoom })
    } elseif ($prim.bucket -eq 'zigbee2mqtt') {
        $aqaraRoomItems.Add([pscustomobject]@{ deviceId = $prim.deviceId; room = $mr.matrixRoom })
    }
    $fbs = @($mr.fallbackTempIds)
    if ($fbs.Count -eq 1) {
        $shcDualFallbackItems.Add([pscustomobject]@{ deviceId = $fbs[0]; room = $mr.matrixRoom })
    } elseif ($fbs.Count -gt 1) {
        $shcMultiFallbackRooms.Add([pscustomobject]@{ room = $mr.matrixRoom; ids = $fbs })
    }
}

$fnPrimaryShc = New-FluxDeviceNameFn -Items @($shcPrimaryItems) -FnName 'roomPrimaryShc' -NameProp 'room' -FallbackExpr '""'
$fnFallbackShc = New-FluxDeviceNameFn -Items @($shcDualFallbackItems) -FnName 'roomFallbackShc' -NameProp 'room' -FallbackExpr '""'
$fnRoomAqara = New-FluxDeviceNameFn -Items @($aqaraRoomItems) -FnName 'roomAqara' -NameProp 'room' -FallbackExpr '""'

$multiFallbackBlocks = [System.Collections.Generic.List[string]]::new()
$multiFallbackNames = [System.Collections.Generic.List[string]]::new()
for ($mi = 0; $mi -lt $shcMultiFallbackRooms.Count; $mi++) {
    $mf = $shcMultiFallbackRooms[$mi]
    $varName = "fMulti$mi"
    $multiFallbackNames.Add($varName)
    $orExpr = ($mf.ids | ForEach-Object { "r.deviceId == `"$_`"" }) -join ' or '
    $multiFallbackBlocks.Add(@"
$varName = shcBase
  |> filter(fn: (r) => $orExpr)
  |> group()
  |> mean()
  |> map(fn: (r) => ({ Raum: "$($mf.room)", prio: 2, val: float(v: r._value) }))
"@)
}
$unionTables = @('pShc', 'fDual') + @($multiFallbackNames) + @('pAqara')
$qMatrixIst = @"
$fnPrimaryShc

$fnFallbackShc

$fnRoomAqara

shcBase = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "temperature" and r["_field"] == "temp")
  |> last()
  |> keep(columns: ["_value", "deviceId"])

pShc = shcBase
  |> map(fn: (r) => ({ Raum: roomPrimaryShc(id: r.deviceId), prio: 1, val: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")

fDual = shcBase
  |> map(fn: (r) => ({ Raum: roomFallbackShc(id: r.deviceId), prio: 2, val: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")

$($multiFallbackBlocks -join "`n`n")

pAqara = from(bucket: "zigbee2mqtt")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_field"] == "temp")
  |> last()
  |> map(fn: (r) => ({ Raum: roomAqara(id: r.deviceId), prio: 1, val: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")

union(tables: [$($unionTables -join ', ')])
  |> group(columns: ["Raum"])
  |> sort(columns: ["prio"], desc: false)
  |> first(column: "val")
  |> map(fn: (r) => ({ Raum: r.Raum, "Ist °C": r.val }))
  |> group()
  |> keep(columns: ["Raum", "Ist °C"])
"@

$qMatrixSoll = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "roomClimate" and r["_field"] == "setpoint")
  |> last()
  |> map(fn: (r) => ({ Raum: r.room, "Soll °C": float(v: r._value) }))
  |> group()
  |> keep(columns: ["Raum", "Soll °C"])
'@

$valveRoomPairs = [System.Collections.Generic.List[object]]::new()
foreach ($mr in $matrixRooms) {
    foreach ($vid in $mr.valveIds) {
        $valveRoomPairs.Add([pscustomobject]@{ deviceId = $vid; room = $mr.matrixRoom })
    }
}
$fnValveRoom = New-FluxDeviceNameFn -Items @($valveRoomPairs) -FnName 'valveRoom' -NameProp 'room' -FallbackExpr '""'
$qMatrixValve = @"
$fnValveRoom

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "valveTappetState" and r["_field"] == "position")
  |> last()
  |> map(fn: (r) => ({ Raum: valveRoom(id: r.deviceId), _value: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")
  |> group(columns: ["Raum"])
  |> max()
  |> map(fn: (r) => ({ Raum: r.Raum, "Ventil %": r._value }))
  |> group()
  |> keep(columns: ["Raum", "Ventil %"])
"@

$qMatrixDemand = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "roomClimate" and (r["_field"] == "hasDemand" or r["_field"] == "boostMode" or r["_field"] == "ventilationMode" or r["_field"] == "summerMode"))
  |> last()
  |> keep(columns: ["room", "_field", "_value"])
  |> map(fn: (r) => ({ room: r.room, _field: r._field, _value: int(v: r._value) }))
  |> group(columns: ["room"])
  |> pivot(rowKey: ["room"], columnKey: ["_field"], valueColumn: "_value")
  |> group()
  |> map(fn: (r) => ({
    Raum: r.room,
    Heizbedarf:
      if exists r.boostMode and r.boostMode == 1 then "Boost"
      else if exists r.ventilationMode and r.ventilationMode == 1 then "Lüften"
      else if exists r.summerMode and r.summerMode == 1 then "Sommer"
      else if exists r.hasDemand and r.hasDemand == 1 then "Aktiv"
      else "Aus"
  }))
  |> group()
  |> keep(columns: ["Raum", "Heizbedarf"])
'@

$shcHumPairs = @($matrixRooms | Where-Object { $null -ne $_.humidityId -and $sensorById[$_.humidityId].bucket -eq 'shcbucket' } | ForEach-Object {
    [pscustomobject]@{ deviceId = $_.humidityId; room = $_.matrixRoom }
})
$aqHumPairs = @($matrixRooms | Where-Object { $null -ne $_.humidityId -and $sensorById[$_.humidityId].bucket -eq 'zigbee2mqtt' } | ForEach-Object {
    [pscustomobject]@{ deviceId = $_.humidityId; room = $_.matrixRoom }
})
$fnHumShc = New-FluxDeviceNameFn -Items $shcHumPairs -FnName 'humRoomShc' -NameProp 'room' -FallbackExpr '""'
$fnHumAq = New-FluxDeviceNameFn -Items $aqHumPairs -FnName 'humRoomAq' -NameProp 'room' -FallbackExpr '""'
$qMatrixHumidity = @"
$fnHumShc

$fnHumAq

shcHum = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "humidity" and r["_field"] == "humidity")
  |> last()
  |> map(fn: (r) => ({ Raum: humRoomShc(id: r.deviceId), val: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")

aqHum = from(bucket: "zigbee2mqtt")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_field"] == "humidity")
  |> last()
  |> map(fn: (r) => ({ Raum: humRoomAq(id: r.deviceId), val: float(v: r._value) }))
  |> filter(fn: (r) => r.Raum != "")

union(tables: [shcHum, aqHum])
  |> group(columns: ["Raum"])
  |> first(column: "val")
  |> map(fn: (r) => ({ Raum: r.Raum, "Feuchte %": r.val }))
  |> group()
  |> keep(columns: ["Raum", "Feuchte %"])
"@

$fnContactRoom = New-FluxDeviceNameFn -Items $roomContacts -FnName 'contactRoom' -NameProp 'matrixRoom' -FallbackExpr '""'
$qMatrixWindow = @"
$fnContactRoom

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "contactStatus" and r["_field"] == "state")
  |> last()
  |> map(fn: (r) => ({ Raum: contactRoom(id: r.deviceId), Fenster: r._value }))
  |> filter(fn: (r) => r.Raum != "")
  |> group()
  |> keep(columns: ["Raum", "Fenster"])
"@

$matrixTransformations = @(
    [ordered]@{
        id      = 'joinByField'
        options = [ordered]@{
            byField = 'Raum'
            mode    = 'outer'
        }
    },
    [ordered]@{
        id      = 'calculateField'
        options = [ordered]@{
            alias         = 'Diff °C'
            binary        = [ordered]@{
                left     = 'Ist °C'
                operator = '-'
                right    = 'Soll °C'
            }
            mode          = 'binary'
            replaceFields = $false
        }
    },
    [ordered]@{
        id      = 'sortBy'
        options = [ordered]@{
            fields = [ordered]@{}
            sort   = @(
                [ordered]@{
                    desc  = $false
                    field = 'Sortierung'
                }
            )
        }
    },
    [ordered]@{
        id      = 'organize'
        options = [ordered]@{
            excludeByName = [ordered]@{
                Sortierung = $true
            }
            indexByName   = [ordered]@{
                Raum        = 0
                'Ist °C'    = 1
                'Soll °C'   = 2
                'Diff °C'   = 3
                'Ventil %'  = 4
                Heizbedarf  = 5
                'Feuchte %' = 6
                Fenster     = 7
            }
            renameByName  = [ordered]@{}
        }
    }
)

$matrixOverrides = @(
    (New-FieldOverride -Name 'Raum' -Properties @(
        [ordered]@{ id = 'custom.width'; value = 190 }
    )),
    (New-FieldOverride -Name 'Ist °C' -Properties @(
        [ordered]@{ id = 'unit'; value = 'celsius' },
        [ordered]@{ id = 'decimals'; value = 1 }
    )),
    (New-FieldOverride -Name 'Soll °C' -Properties @(
        [ordered]@{ id = 'unit'; value = 'celsius' },
        [ordered]@{ id = 'decimals'; value = 1 }
    )),
    (New-FieldOverride -Name 'Diff °C' -Properties @(
        [ordered]@{ id = 'unit'; value = 'celsius' },
        [ordered]@{ id = 'decimals'; value = 1 },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-text' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#5794F2'; value = $null },
                    @{ color = '#73BF69'; value = -0.5 },
                    @{ color = '#FF9830'; value = 0.8 },
                    @{ color = '#F2495C'; value = 2.0 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Ventil %' -Properties @(
        [ordered]@{ id = 'unit'; value = 'percent' },
        [ordered]@{ id = 'min'; value = 0 },
        [ordered]@{ id = 'max'; value = 100 },
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ mode = 'gradient'; type = 'gauge' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#37872D'; value = $null },
                    @{ color = '#EAB839'; value = 35 },
                    @{ color = '#F2495C'; value = 75 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Heizbedarf' -Properties @(
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-background' }
        },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        'Aus'    = [ordered]@{ color = '#37474F'; index = 0 }
                        'Aktiv'  = [ordered]@{ color = '#FF9830'; index = 1 }
                        'Boost'  = [ordered]@{ color = '#F2495C'; index = 2 }
                        'Lüften' = [ordered]@{ color = '#3274D9'; index = 3 }
                        'Sommer' = [ordered]@{ color = '#6E7681'; index = 4 }
                    }
                    type    = 'value'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Feuchte %' -Properties @(
        [ordered]@{ id = 'unit'; value = 'humidity' },
        [ordered]@{ id = 'decimals'; value = 1 },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-text' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#FF9830'; value = $null },
                    @{ color = '#73BF69'; value = 40 },
                    @{ color = '#EAB839'; value = 60 },
                    @{ color = '#F2495C'; value = 70 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Fenster' -Properties @(
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-background' }
        },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        'CLOSED'      = [ordered]@{ color = '#37872D'; index = 0; text = 'Zu' }
                        'OPEN'        = [ordered]@{ color = '#F2495C'; index = 1; text = 'Offen' }
                        'UNAVAILABLE' = [ordered]@{ color = '#EAB839'; index = 2; text = 'Nicht erreichbar' }
                    }
                    type    = 'value'
                }
            )
        }
    ))
)

$pMatrix = New-TablePanel -Title 'Raum-Matrix (11 Klimaräume)' `
    -Description 'Live-Übersicht aller 11 Klimaräume in Stockwerksreihenfolge (24h-Frischeregel für Aqara, Raumthermostat primär in E2 Wohn-/Eßzimmer)' `
    -GridPos @{ x = 0; y = 12; w = 24; h = 13 } `
    -Targets @(
        (New-FluxTarget -RefId 'A' -Query $qMatrixRooms),
        (New-FluxTarget -RefId 'B' -Query $qMatrixIst),
        (New-FluxTarget -RefId 'C' -Query $qMatrixSoll),
        (New-FluxTarget -RefId 'D' -Query $qMatrixValve),
        (New-FluxTarget -RefId 'E' -Query $qMatrixDemand),
        (New-FluxTarget -RefId 'F' -Query $qMatrixHumidity),
        (New-FluxTarget -RefId 'G' -Query $qMatrixWindow)
    ) `
    -Transformations $matrixTransformations -Overrides $matrixOverrides

# --- Temperatur-Verlauf (17 Fühler) ---
$allTempNameFn = New-FluxDeviceNameFn -Items $climateSensors
$shcTempOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($shcClimate | ForEach-Object { $_.deviceId })
$qTempHistory = @"
$allTempNameFn

shc = from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "temperature" and r["_field"] == "temp")
  |> filter(fn: (r) =>
$shcTempOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> keep(columns: ["_time", "_value", "deviceId"])

aqara = from(bucket: "zigbee2mqtt")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_field"] == "temp")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> keep(columns: ["_time", "_value", "deviceId"])

union(tables: [shc, aqara])
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
$tempOverrides = @($climateSensors | Sort-Object canonicalName | ForEach-Object {
    New-ColorOverride -Name $_.canonicalName -HexColor $_.color
})
$pTempHistory = New-TimeseriesPanel -Title 'Temperatur-Verlauf' `
    -Description 'Alle 17 Temperaturfühler (11 Bosch SHC + 6 Aqara) mit kanonischen Namen und festen Farben' `
    -GridPos @{ x = 0; y = 25; w = 24; h = 14 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qTempHistory)) `
    -Unit 'celsius' -Overrides $tempOverrides

# --- Ventilstellung (10 TRVs) ---
$valveNameFn = New-FluxDeviceNameFn -Items $trvSensors
$valveOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($trvSensors | ForEach-Object { $_.deviceId })
$qValveHistory = @"
$valveNameFn

from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "valveTappetState" and r["_field"] == "position")
  |> filter(fn: (r) =>
$valveOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "last")
"@
$valveOverrides = @($trvSensors | Sort-Object canonicalName | ForEach-Object {
    New-ColorOverride -Name $_.canonicalName -HexColor $_.color
})
$pValveHistory = New-TimeseriesPanel -Title 'Ventilstellung' `
    -Description 'Ventilöffnung aller 10 Heizkörperthermostate (0–100 %)' `
    -GridPos @{ x = 0; y = 39; w = 12; h = 12 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qValveHistory)) `
    -Unit 'percent' -Min 0 -Max 100 -Overrides $valveOverrides

# --- Luftfeuchtigkeit (7 Feuchtefühler, Komfortzone 40–60 %) ---
$humNameFn = New-FluxDeviceNameFn -Items $humiditySensors
$shcHumOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($shcHumidity | ForEach-Object { $_.deviceId })
$qHumHistory = @"
$humNameFn

shc = from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "humidity" and r["_field"] == "humidity")
  |> filter(fn: (r) =>
$shcHumOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> keep(columns: ["_time", "_value", "deviceId"])

aqara = from(bucket: "zigbee2mqtt")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_field"] == "humidity")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> keep(columns: ["_time", "_value", "deviceId"])

union(tables: [shc, aqara])
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
$humOverrides = @($humiditySensors | Sort-Object canonicalName | ForEach-Object {
    New-ColorOverride -Name $_.canonicalName -HexColor $_.color
})
$pHumHistory = New-TimeseriesPanel -Title 'Luftfeuchtigkeit' `
    -Description 'Alle 7 Feuchtesensoren inkl. hinterlegter Komfortzone 40–60 %' `
    -GridPos @{ x = 12; y = 39; w = 12; h = 12 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qHumHistory)) `
    -Unit 'humidity' -Min 0 -Max 100 `
    -ThresholdStyleMode 'area' `
    -ThresholdSteps @(
        @{ color = 'orange'; value = $null },
        @{ color = 'green'; value = 40 },
        @{ color = 'orange'; value = 60 },
        @{ color = 'red'; value = 70 }
    ) `
    -Overrides $humOverrides

# =========================================================================
# ROW 3: Energie & Verbraucher (collapsed: true, Unter-Panels in row.panels)
# =========================================================================
$plugNameFn = New-FluxDeviceNameFn -Items $smartPlugs
$plugOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($smartPlugs | ForEach-Object { $_.deviceId })
$plugColorOverrides = @($smartPlugs | Sort-Object canonicalName | ForEach-Object {
    New-ColorOverride -Name $_.canonicalName -HexColor $_.color
})

$qPlugPowerTs = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "power")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
$pPlugPowerTs = New-TimeseriesPanel -Title 'Leistungsverlauf (W)' `
    -Description 'Momentane Leistungsaufnahme aller 4 Smart-Steckdosen' `
    -GridPos @{ x = 0; y = 52; w = 12; h = 10 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qPlugPowerTs)) `
    -Unit 'watt' -Min 0 -Overrides $plugColorOverrides

$qPlugEnergyTs = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "energyWh")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> aggregateWindow(every: 1h, fn: last, createEmpty: false)
  |> difference(nonNegative: true)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value) / 1000.0, _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "energy_kwh")
"@
$pPlugEnergyTs = New-TimeseriesPanel -Title 'Energieverbrauch je Zeitraum (kWh)' `
    -Description 'Stündlicher Energieverbrauch aus Zählerdifferenz (geschützt gegen Zähler-Rücksetzungen)' `
    -GridPos @{ x = 12; y = 52; w = 12; h = 10 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qPlugEnergyTs)) `
    -Unit 'kwatth' -Min 0 -DrawStyle 'bars' -FillOpacity 65 `
    -LegendCalcs @('sum', 'lastNotNull', 'max') -Overrides $plugColorOverrides

# Verbraucher-Übersicht (Table)
$plugOrderIdx = 1
$plugSeedLines = [System.Collections.Generic.List[string]]::new()
$plugSwitchAnchorLines = [System.Collections.Generic.List[string]]::new()
foreach ($plug in $smartPlugs) {
    $plugSeedLines.Add("  { Sortierung: $plugOrderIdx, Verbraucher: `"$($plug.canonicalName)`", Raum: `"$($plug.room)`" }")
    $plugSwitchAnchorLines.Add("  { deviceId: `"$($plug.deviceId)`", name: `"$($plug.canonicalName)`", available: -1.0, switchOn: -1.0 }")
    $plugOrderIdx++
}
$qPlugTableSeed = @"
import "array"
array.from(rows: [
$($plugSeedLines -join ",`n")
])
"@
$qPlugTableSwitch = @"
import "array"

anchor = array.from(rows: [
$($plugSwitchAnchorLines -join ",`n")
])

dh = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "deviceHealth" and r["_field"] == "available")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> last()
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: "", available: float(v: r._value), switchOn: -1.0 }))

pm = from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "switchOn")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> last()
  |> group()
  |> map(fn: (r) => ({ deviceId: r.deviceId, name: "", available: -1.0, switchOn: float(v: r._value) }))

union(tables: [anchor, dh, pm])
  |> group(columns: ["deviceId"])
  |> reduce(
    identity: { name: "", available: -1.0, switchOn: -1.0 },
    fn: (r, accumulator) => ({
      name: if r.name != "" then r.name else accumulator.name,
      available: if r.available >= 0.0 then r.available else accumulator.available,
      switchOn: if r.switchOn >= 0.0 then r.switchOn else accumulator.switchOn
    })
  )
  |> map(fn: (r) => ({
    Verbraucher: r.name,
    Schaltzustand:
      if r.available == 0.0 then "Nicht erreichbar"
      else if r.switchOn == 1.0 then "Ein"
      else if r.switchOn == 0.0 then "Aus"
      else "–"
  }))
  |> group()
  |> keep(columns: ["Verbraucher", "Schaltzustand"])
"@
$qPlugTablePower = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "power")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> last()
  |> map(fn: (r) => ({ Verbraucher: deviceName(id: r.deviceId), "Leistung (W)": float(v: r._value) }))
  |> group()
  |> keep(columns: ["Verbraucher", "Leistung (W)"])
"@
$qPlugTableState = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "stateText")
  |> last()
  |> map(fn: (r) => ({ Verbraucher: deviceName(id: r.deviceId), Zustand: r._value }))
  |> group()
  |> keep(columns: ["Verbraucher", "Zustand"])
"@
$qPlugTableCycleKwh = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "cycleEnergyWh")
  |> last()
  |> map(fn: (r) => ({ Verbraucher: deviceName(id: r.deviceId), "Letzter Zyklus (kWh)": float(v: r._value) / 1000.0 }))
  |> group()
  |> keep(columns: ["Verbraucher", "Letzter Zyklus (kWh)"])
"@
$qPlugTableCycleMin = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "applianceState" and r["_field"] == "cycleDurationMin")
  |> last()
  |> map(fn: (r) => ({ Verbraucher: deviceName(id: r.deviceId), "Letzter Zyklus (Min.)": float(v: r._value) }))
  |> group()
  |> keep(columns: ["Verbraucher", "Letzter Zyklus (Min.)"])
"@
$qPlugTableTotalKwh = @"
$plugNameFn

from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "powerMeter" and r["_field"] == "energyWh")
  |> filter(fn: (r) =>
$plugOrExpr)
  |> last()
  |> map(fn: (r) => ({ Verbraucher: deviceName(id: r.deviceId), "Gesamt (kWh)": float(v: r._value) / 1000.0 }))
  |> group()
  |> keep(columns: ["Verbraucher", "Gesamt (kWh)"])
"@

$plugTableTransformations = @(
    [ordered]@{
        id      = 'joinByField'
        options = [ordered]@{
            byField = 'Verbraucher'
            mode    = 'outer'
        }
    },
    [ordered]@{
        id      = 'sortBy'
        options = [ordered]@{
            fields = [ordered]@{}
            sort   = @(@{ desc = $false; field = 'Sortierung' })
        }
    },
    [ordered]@{
        id      = 'organize'
        options = [ordered]@{
            excludeByName = [ordered]@{ Sortierung = $true }
            indexByName   = [ordered]@{
                Verbraucher             = 0
                Raum                    = 1
                Schaltzustand           = 2
                'Leistung (W)'          = 3
                Zustand                 = 4
                'Letzter Zyklus (kWh)'  = 5
                'Letzter Zyklus (Min.)' = 6
                'Gesamt (kWh)'          = 7
            }
            renameByName  = [ordered]@{}
        }
    }
)
$plugTableOverrides = @(
    (New-FieldOverride -Name 'Schaltzustand' -Properties @(
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-background' }
        },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        'Ein'              = [ordered]@{ color = '#37872D'; index = 0 }
                        'Aus'              = [ordered]@{ color = '#6E7681'; index = 1 }
                        'Nicht erreichbar' = [ordered]@{ color = '#EAB839'; index = 2 }
                    }
                    type    = 'value'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Leistung (W)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'watt' },
        [ordered]@{ id = 'decimals'; value = 1 }
    )),
    (New-FieldOverride -Name 'Letzter Zyklus (kWh)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'kwatth' },
        [ordered]@{ id = 'decimals'; value = 3 }
    )),
    (New-FieldOverride -Name 'Letzter Zyklus (Min.)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'm' },
        [ordered]@{ id = 'decimals'; value = 0 }
    )),
    (New-FieldOverride -Name 'Gesamt (kWh)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'kwatth' },
        [ordered]@{ id = 'decimals'; value = 2 }
    ))
)

$pPlugTable = New-TablePanel -Title 'Verbraucher-Übersicht' `
    -Description 'Schaltzustand, aktuelle Leistung, letzter Wasch-/Druckzyklus und Gesamtzählerstand aller 4 Steckdosen' `
    -GridPos @{ x = 0; y = 62; w = 24; h = 7 } `
    -Targets @(
        (New-FluxTarget -RefId 'A' -Query $qPlugTableSeed),
        (New-FluxTarget -RefId 'B' -Query $qPlugTableSwitch),
        (New-FluxTarget -RefId 'C' -Query $qPlugTablePower),
        (New-FluxTarget -RefId 'D' -Query $qPlugTableState),
        (New-FluxTarget -RefId 'E' -Query $qPlugTableCycleKwh),
        (New-FluxTarget -RefId 'F' -Query $qPlugTableCycleMin),
        (New-FluxTarget -RefId 'G' -Query $qPlugTableTotalKwh)
    ) `
    -Transformations $plugTableTransformations -Overrides $plugTableOverrides

$row3 = New-RowPanel -Title 'Energie & Verbraucher' -Y 51 -Collapsed $true `
    -ChildPanels @($pPlugPowerTs, $pPlugEnergyTs, $pPlugTable)

# =========================================================================
# ROW 4: Türen, Fenster & Wetter (collapsed: true, Unter-Panels in row.panels)
# =========================================================================
$contactOrExpr = New-FluxDeviceIdOrExpr -DeviceIds @($contacts | ForEach-Object { $_.deviceId })
$qContactTimeline = @"
$contactNameFn

from(bucket: "shcbucket")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "contactStatus" and r["_field"] == "state")
  |> filter(fn: (r) =>
$contactOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: r._value, _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "last")
"@
$pContactTimeline = [ordered]@{
    datasource  = New-DatasourceRef
    description = 'Zustandsverlauf aller 9 Tür- und Fensterkontakte aus contactStatus (inkl. Nicht erreichbar)'
    fieldConfig = [ordered]@{
        defaults  = [ordered]@{
            color      = [ordered]@{ mode = 'fixed' }
            custom     = [ordered]@{
                fillOpacity = 70
                lineWidth   = 0
                spanNulls   = $true
            }
            mappings   = @(
                [ordered]@{
                    options = [ordered]@{
                        'CLOSED'      = [ordered]@{ color = '#37872D'; index = 0; text = 'Zu' }
                        'OPEN'        = [ordered]@{ color = '#F2495C'; index = 1; text = 'Offen' }
                        'UNAVAILABLE' = [ordered]@{ color = '#EAB839'; index = 2; text = 'Nicht erreichbar' }
                    }
                    type    = 'value'
                }
            )
            thresholds = [ordered]@{
                mode  = 'absolute'
                steps = @(New-ThresholdSteps -Steps @(@{ color = 'green'; value = $null }))
            }
        }
        overrides = @()
    }
    gridPos         = @{ x = 0; y = 53; w = 24; h = 9 }
    id              = (Get-NextPanelId)
    options         = [ordered]@{
        alignValue  = 'left'
        legend      = [ordered]@{
            displayMode = 'list'
            placement   = 'bottom'
            showLegend  = $true
        }
        mergeValues = $true
        rowHeight   = 0.9
        showValue   = 'auto'
        tooltip     = [ordered]@{
            mode = 'single'
            sort = 'none'
        }
    }
    targets         = @((New-FluxTarget -RefId 'A' -Query $qContactTimeline))
    title           = 'Tür- und Fenster-Verlauf'
    transformations = @()
    type            = 'state-timeline'
}

$qPressNow = @'
from(bucket: "zigbee2mqtt")
  |> range(start: -2h)
  |> filter(fn: (r) => r["_field"] == "pressure")
  |> last()
  |> group()
  |> mean()
  |> map(fn: (r) => ({ _time: now(), _value: float(v: r._value), _field: "Luftdruck" }))
  |> group(columns: ["_field"])
'@
$pPressNow = New-StatPanel -Title 'Luftdruck (aktuell)' `
    -Description 'Aktueller Mittelwert der aktiven Aqara-Sensoren' `
    -GridPos @{ x = 0; y = 62; w = 4; h = 8 } `
    -Unit 'pressurehpa' -Decimals 1 -ColorMode 'value' `
    -ThresholdSteps @(@{ color = '#5794F2'; value = $null }) `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qPressNow))

$qPressTrend = @'
import "array"

anchor = array.from(rows: [{ cur: -1.0, prev: -1.0 }])

nowP = from(bucket: "zigbee2mqtt")
  |> range(start: -90m, stop: now())
  |> filter(fn: (r) => r["_field"] == "pressure")
  |> last()
  |> group()
  |> mean()
  |> map(fn: (r) => ({ cur: float(v: r._value), prev: -1.0 }))

oldP = from(bucket: "zigbee2mqtt")
  |> range(start: -4h, stop: -150m)
  |> filter(fn: (r) => r["_field"] == "pressure")
  |> last()
  |> group()
  |> mean()
  |> map(fn: (r) => ({ cur: -1.0, prev: float(v: r._value) }))

union(tables: [anchor, nowP, oldP])
  |> group()
  |> reduce(
    identity: { cur: -1.0, prev: -1.0 },
    fn: (r, accumulator) => ({
      cur: if r.cur > 0.0 then r.cur else accumulator.cur,
      prev: if r.prev > 0.0 then r.prev else accumulator.prev
    })
  )
  |> filter(fn: (r) => r.cur > 0.0 and r.prev > 0.0)
  |> map(fn: (r) => ({ _time: now(), _value: r.cur - r.prev, _field: "Tendenz 3h" }))
  |> group(columns: ["_field"])
'@
$pPressTrend = New-StatPanel -Title 'Luftdruck 3h-Tendenz' `
    -Description 'Luftdruckänderung der letzten 3 Stunden (hPa)' `
    -GridPos @{ x = 4; y = 62; w = 4; h = 8 } `
    -Unit 'pressurehpa' -Decimals 1 -ColorMode 'value' `
    -ThresholdSteps @(
        @{ color = '#FF9830'; value = $null },
        @{ color = '#73BF69'; value = -1.5 },
        @{ color = '#5794F2'; value = 1.5 }
    ) `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qPressTrend))

$aqaraNameFn = New-FluxDeviceNameFn -Items $aqaraSensors
$aqaraColorOverrides = @($aqaraSensors | Sort-Object canonicalName | ForEach-Object {
    New-ColorOverride -Name $_.canonicalName -HexColor $_.color
})
$qPress7d = @"
$aqaraNameFn

from(bucket: "zigbee2mqtt")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_field"] == "pressure")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
$pPress7d = New-TimeseriesPanel -Title 'Luftdruck 7-Tage-Verlauf' `
    -Description '7-Tage-Luftdruckverlauf der Aqara-Sensoren' `
    -GridPos @{ x = 8; y = 62; w = 16; h = 8 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qPress7d)) `
    -Unit 'pressurehpa' -TimeFrom '7d' -Overrides $aqaraColorOverrides

$row4 = New-RowPanel -Title 'Türen, Fenster & Wetter' -Y 52 -Collapsed $true `
    -ChildPanels @($pContactTimeline, $pPressNow, $pPressTrend, $pPress7d)

# =========================================================================
# ROW 5: Sensoren & Technik (collapsed: true, Unter-Panels in row.panels)
# =========================================================================
$qShcHealth = @'
from(bucket: "shcbucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "deviceHealth")
  |> last()
  |> map(fn: (r) => ({
    _time: r._time,
    deviceId: r.deviceId,
    deviceName: r.deviceName,
    deviceModel: r.deviceModel,
    room: r.room,
    _field: r._field,
    _value: string(v: r._value)
  }))
  |> group(columns: ["deviceId", "deviceName", "deviceModel", "room"])
  |> pivot(rowKey: ["deviceId", "deviceName", "deviceModel", "room", "_time"], columnKey: ["_field"], valueColumn: "_value")
  |> group()
  |> map(fn: (r) => ({
    "Gerät": r.deviceName,
    Raum: r.room,
    Modell: r.deviceModel,
    Status: if exists r.statusText then r.statusText else "UNDEFINED",
    "Störungen": if exists r.faultCount then int(v: float(v: r.faultCount)) else 0,
    "Störungsmeldung": if exists r.faultSummary then r.faultSummary else "OK",
    "Alter (Min.)": float(v: uint(v: now()) - uint(v: r._time)) / 60000000000.0
  }))
  |> sort(columns: ["Status", "Gerät"])
'@
$shcHealthOverrides = @(
    (New-FieldOverride -Name 'Status' -Properties @(
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-background' }
        },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        'AVAILABLE'   = [ordered]@{ color = '#37872D'; index = 0 }
                        'UNDEFINED'   = [ordered]@{ color = '#EAB839'; index = 1 }
                        'UNAVAILABLE' = [ordered]@{ color = '#F2495C'; index = 2 }
                    }
                    type    = 'value'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Störungen' -Properties @(
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-text' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = (New-ThresholdSteps -Steps @(
                    @{ color = '#73BF69'; value = $null },
                    @{ color = '#F2495C'; value = 1 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Alter (Min.)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'm' },
        [ordered]@{ id = 'decimals'; value = 1 }
    ))
)
$pShcHealth = New-TablePanel -Title 'SHC-Gerätegesundheit' `
    -Description 'Alle 25 physischen Bosch-SHC-Geräte (inkl. Springer und Außenkamera 3yes) mit Status und Störungsmeldungen' `
    -GridPos @{ x = 0; y = 54; w = 24; h = 11 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qShcHealth)) `
    -Overrides $shcHealthOverrides

$aqDiagAnchorRows = ($aqaraSensors | ForEach-Object {
    "  { deviceId: `"$($_.deviceId)`", _field: `"seed`", _value: 0.0, ageH: 999999.0 }"
}) -join ",`n"
$qAqDiag = @"
import "array"

$aqaraNameFn

anchor = array.from(rows: [
$aqDiagAnchorRows
])

base = from(bucket: "zigbee2mqtt")
  |> range(start: -365d)
  |> filter(fn: (r) => r["_field"] == "battery" or r["_field"] == "voltage" or r["_field"] == "linkquality" or r["_field"] == "poweroutagecount" or r["_field"] == "temp")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> last()
  |> group()
  |> map(fn: (r) => ({
    deviceId: r.deviceId,
    _field: r._field,
    _value: float(v: r._value),
    ageH: float(v: uint(v: now()) - uint(v: r._time)) / 3600000000000.0
  }))

union(tables: [anchor, base])
  |> group(columns: ["deviceId"])
  |> reduce(
    identity: { bat: -1.0, volt: -1.0, lqi: -1.0, restarts: -1.0, temp: -999.0, ageH: 999999.0 },
    fn: (r, accumulator) => ({
      bat: if r._field == "battery" then r._value else accumulator.bat,
      volt: if r._field == "voltage" then r._value else accumulator.volt,
      lqi: if r._field == "linkquality" then r._value else accumulator.lqi,
      restarts: if r._field == "poweroutagecount" then r._value else accumulator.restarts,
      temp: if r._field == "temp" then r._value else accumulator.temp,
      ageH: if r.ageH < accumulator.ageH then r.ageH else accumulator.ageH
    })
  )
  |> group()
  |> map(fn: (r) => ({
    Sensor: deviceName(id: r.deviceId),
    "Batterie %": r.bat,
    "Spannung mV": r.volt,
    LQI: r.lqi,
    Neustarts: r.restarts,
    "Letzter Wert °C": r.temp,
    "Letzte Meldung (Alter in Std.)": r.ageH
  }))
  |> sort(columns: ["Sensor"])
"@
$aqDiagMissingMap = @(
    [ordered]@{
        options = [ordered]@{
            '-1' = [ordered]@{ color = '#6E7681'; index = 0; text = '–' }
        }
        type    = 'value'
    }
)
$aqDiagOverrides = @(
    (New-FieldOverride -Name 'Batterie %' -Properties @(
        [ordered]@{ id = 'unit'; value = 'percent' },
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{ id = 'mappings'; value = $aqDiagMissingMap },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-text' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = @(New-ThresholdSteps -Steps @(
                    @{ color = '#6E7681'; value = $null },
                    @{ color = '#F2495C'; value = 0 },
                    @{ color = '#EAB839'; value = 25 },
                    @{ color = '#73BF69'; value = 50 }
                ))
            }
        }
    )),
    (New-FieldOverride -Name 'Spannung mV' -Properties @(
        [ordered]@{ id = 'unit'; value = 'mvolt' },
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{ id = 'mappings'; value = $aqDiagMissingMap }
    )),
    (New-FieldOverride -Name 'LQI' -Properties @(
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{ id = 'mappings'; value = $aqDiagMissingMap }
    )),
    (New-FieldOverride -Name 'Neustarts' -Properties @(
        [ordered]@{ id = 'decimals'; value = 0 },
        [ordered]@{ id = 'mappings'; value = $aqDiagMissingMap }
    )),
    (New-FieldOverride -Name 'Letzter Wert °C' -Properties @(
        [ordered]@{ id = 'unit'; value = 'celsius' },
        [ordered]@{ id = 'decimals'; value = 2 },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        '-999' = [ordered]@{ color = '#6E7681'; index = 0; text = '–' }
                    }
                    type    = 'value'
                }
            )
        }
    )),
    (New-FieldOverride -Name 'Letzte Meldung (Alter in Std.)' -Properties @(
        [ordered]@{ id = 'unit'; value = 'h' },
        [ordered]@{ id = 'decimals'; value = 1 },
        [ordered]@{
            id    = 'mappings'
            value = @(
                [ordered]@{
                    options = [ordered]@{
                        from   = 99999
                        to     = 1000000000
                        result = [ordered]@{ color = '#F2495C'; index = 0; text = '> 365 d' }
                    }
                    type    = 'range'
                }
            )
        },
        [ordered]@{
            id    = 'custom.cellOptions'
            value = [ordered]@{ type = 'color-background' }
        },
        [ordered]@{
            id    = 'thresholds'
            value = [ordered]@{
                mode  = 'absolute'
                steps = @(New-ThresholdSteps -Steps @(
                    @{ color = '#37872D'; value = $null },
                    @{ color = '#EAB839'; value = 6 },
                    @{ color = '#F2495C'; value = 24 }
                ))
            }
        }
    ))
)
$pAqDiag = New-TablePanel -Title 'Aqara-Diagnose' `
    -Description 'Letzte Meldung, Batteriestand, Spannung, LQI und Neustarts je Aqara-Sensor (inkl. Langzeit-Stummschaltung > 24 h)' `
    -GridPos @{ x = 0; y = 65; w = 24; h = 8 } `
    -Targets @((New-FluxTarget -RefId 'A' -Query $qAqDiag)) `
    -Overrides $aqDiagOverrides

function New-AqaraDiagTimeseries {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$Unit,
        [Parameter(Mandatory)][hashtable]$GridPos
    )
    $q = @"
$aqaraNameFn

from(bucket: "zigbee2mqtt")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_field"] == "$FieldName")
  |> filter(fn: (r) =>
$aqTempOrExpr)
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({ _time: r._time, _value: float(v: r._value), _field: deviceName(id: r.deviceId) }))
  |> group()
  |> sort(columns: ["_field", "_time"])
  |> group(columns: ["_field"])
  |> yield(name: "mean")
"@
    return New-TimeseriesPanel -Title $Title -GridPos $GridPos `
        -Targets @((New-FluxTarget -RefId 'A' -Query $q)) `
        -Unit $Unit -TimeFrom '14d' -Overrides $aqaraColorOverrides
}

$pAqVolt = New-AqaraDiagTimeseries -Title 'Aqara Batteriespannung' -FieldName 'voltage' -Unit 'mvolt' `
    -GridPos @{ x = 0; y = 73; w = 8; h = 10 }
$pAqBat = New-AqaraDiagTimeseries -Title 'Aqara Batterie in %' -FieldName 'battery' -Unit 'percent' `
    -GridPos @{ x = 8; y = 73; w = 8; h = 10 }
$pAqLqi = New-AqaraDiagTimeseries -Title 'Aqara Funkqualität (LQI)' -FieldName 'linkquality' -Unit 'none' `
    -GridPos @{ x = 16; y = 73; w = 8; h = 10 }

$row5 = New-RowPanel -Title 'Sensoren & Technik' -Y 53 -Collapsed $true `
    -ChildPanels @($pShcHealth, $pAqDiag, $pAqVolt, $pAqBat, $pAqLqi)

# =========================================================================
# Gesamtes Dashboard-Objekt zusammenstellen
# =========================================================================
$dashboard = [ordered]@{
    annotations         = [ordered]@{
        list = @(
            [ordered]@{
                builtIn    = 1
                datasource = [ordered]@{
                    type = 'grafana'
                    uid  = '-- Grafana --'
                }
                enable     = $true
                hide       = $true
                iconColor  = 'rgba(0, 211, 255, 1)'
                name       = 'Annotations & Alerts'
                target     = [ordered]@{
                    limit    = 100
                    matchAny = $false
                    tags     = @()
                    type     = 'dashboard'
                }
                type       = 'dashboard'
            }
        )
    }
    editable            = $true
    fiscalYearStartMonth = 0
    graphTooltip        = 0
    links               = @()
    liveNow             = $false
    panels              = @(
        $row1,
        $pWashStatus,
        $pWashCurve,
        $pCreality,
        $pOtherPlugs,
        $pDoorsStat,
        $pAlarm,
        $pHealthStat,
        $row2,
        $pMatrix,
        $pTempHistory,
        $pValveHistory,
        $pHumHistory,
        $row3,
        $row4,
        $row5
    )
    refresh             = '1m'
    schemaVersion       = 37
    style               = 'dark'
    tags                = @('smart-home', 'jaylab')
    templating          = [ordered]@{
        list = @()
    }
    time                = [ordered]@{
        from = 'now-24h'
        to   = 'now'
    }
    timepicker          = [ordered]@{}
    timezone            = ''
    title               = 'Jaylab Haus-Zentrale'
    uid                 = 'jaylab-haus-zentrale'
    weekStart           = 'monday'
}

$payload = [ordered]@{
    dashboard = $dashboard
    folderUid = ''
    overwrite = $true
    message   = 'Deterministisches Dashboard Jaylab Haus-Zentrale (5 Rows, kanonische Namen inkl. Springer, feste Farben, A-Z-Legenden)'
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOut = [System.IO.Path]::GetFullPath($OutputPath, (Get-Location).Path)
    $parentDir = Split-Path -Parent $resolvedOut
    if (-not (Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -ItemType Directory -Force -Path $parentDir
    }
    $json = $payload | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($resolvedOut, $json, [System.Text.UTF8Encoding]::new($false))
} else {
    return $payload
}
