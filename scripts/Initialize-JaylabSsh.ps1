#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$directory = Join-Path $root '.local/tools/sshnet'
$null = New-Item -ItemType Directory -Force -Path $directory
$sshFramework = if ([Environment]::Version.Major -ge 10) { 'net10.0' }
    elseif ([Environment]::Version.Major -ge 9) { 'net9.0' } else { 'net8.0' }
$packages = @(
    @{ Id = 'ssh.net'; Version = '2026.0.0'; Framework = $sshFramework; Assembly = 'Renci.SshNet.dll' },
    @{ Id = 'bouncycastle.cryptography'; Version = '2.7.0'; Framework = 'net6.0'; Assembly = 'BouncyCastle.Cryptography.dll' },
    @{ Id = 'microsoft.extensions.logging.abstractions'; Version = '8.0.3'; Framework = 'net8.0'; Assembly = 'Microsoft.Extensions.Logging.Abstractions.dll' }
)
$manifest = @()
foreach ($package in $packages) {
    $name = $package.Id + '.' + $package.Version
    $url = 'https://api.nuget.org/v3-flatcontainer/' + $package.Id + '/' + $package.Version + '/' + $name + '.nupkg'
    $file = Join-Path $directory ($name + '.nupkg')
    $registration = 'https://api.nuget.org/v3/registration5-gz-semver2/' + $package.Id + '/' + $package.Version + '.json'
    $leaf = Invoke-RestMethod -Uri $registration
    if (([uri]$leaf.catalogEntry).Host -cne 'api.nuget.org') { throw 'Unerwarteter NuGet-Kataloghost.' }
    $catalog = Invoke-RestMethod -Uri $leaf.catalogEntry
    if ($catalog.packageHashAlgorithm -cne 'SHA512') { throw 'Unerwartetes NuGet-Hashverfahren.' }
    $expectedHash = ([string]$catalog.packageHash).Trim()
    if (-not (Test-Path -LiteralPath $file)) { Invoke-WebRequest -Uri $url -OutFile $file }
    $bytes = [Convert]::FromHexString((Get-FileHash -LiteralPath $file -Algorithm SHA512).Hash)
    if ([Convert]::ToBase64String($bytes) -cne $expectedHash) {
        throw "NuGet-Prüfsumme stimmt nicht: $name"
    }
    $unpacked = Join-Path $directory $name
    [IO.Compression.ZipFile]::ExtractToDirectory($file, $unpacked, $true)
    $assembly = Join-Path $unpacked ('lib/' + $package.Framework + '/' + $package.Assembly)
    if (-not (Test-Path -LiteralPath $assembly)) { throw "Bibliothek fehlt: $assembly" }
    $manifest += [ordered]@{
        id = $package.Id; version = $package.Version; source = $url
        sha512 = $expectedHash; assembly = $assembly
    }
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $directory 'manifest.json')
Write-Output 'SSH.NET und Abhängigkeiten lokal bereitgestellt und gegen die NuGet-Paketprüfsummen geprüft.'
