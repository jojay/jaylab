#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('fritz-mesh','fritz-cable','repeater-1','repeater-2')][string[]]$DeviceId = @('fritz-mesh','fritz-cable'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$inventory = Get-Content -Raw -LiteralPath (Join-Path $root 'inventory/infrastruktur.json') | ConvertFrom-Json
if (-not ('JaylabTlsCertificate' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'lib/JaylabTlsCertificate.cs')
}
$directory = Join-Path $root '.local/access/fritz-certificates'
$null = New-Item -ItemType Directory -Force -Path $directory
$results = @()
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    foreach ($port in @(443,49443)) {
        $observation = [JaylabTlsCertificate]::Probe($device.address, $port)
        if ($observation.PublicCertificate) {
            [IO.File]::WriteAllBytes((Join-Path $directory ($id + '-' + $port + '.cer')), $observation.PublicCertificate)
        }
        $results += [ordered]@{
            device = $id; address = $device.address; port = $port
            sha256 = $observation.Sha256; subject = $observation.Subject; issuer = $observation.Issuer
            notBeforeUtc = $observation.NotBeforeUtc; notAfterUtc = $observation.NotAfterUtc
            policyErrors = $observation.PolicyErrors; errorType = $observation.ErrorType
            trusted = $false; authenticationAttempted = $false
        }
    }
}
$results | ConvertTo-Json -Depth 4
