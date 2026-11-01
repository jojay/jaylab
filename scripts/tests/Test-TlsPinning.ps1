#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scripts = Split-Path -Parent $PSScriptRoot
if (-not ('JaylabTlsCertificate' -as [type])) {
    Add-Type -Path (Join-Path $scripts 'lib/JaylabTlsCertificate.cs')
}
$rsa = [Security.Cryptography.RSA]::Create(2048)
$request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
    'CN=offline-test', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
    [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$now = [DateTimeOffset]::UtcNow
$valid = $request.CreateSelfSigned($now.AddDays(-1), $now.AddDays(1))
$expired = $request.CreateSelfSigned($now.AddDays(-3), $now.AddDays(-2))
$future = $request.CreateSelfSigned($now.AddDays(2), $now.AddDays(3))
try {
    $hash = $valid.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256)
    $pin = [JaylabTlsCertificate]::new('192.168.20.4', 49443, $hash)
    $errors = [Net.Security.SslPolicyErrors]::RemoteCertificateChainErrors -bor
        [Net.Security.SslPolicyErrors]::RemoteCertificateNameMismatch
    foreach ($case in @(
        @{ Uri = 'https://192.168.20.4:49443/'; Expected = $true },
        @{ Uri = 'https://192.168.20.5:49443/'; Expected = $false },
        @{ Uri = 'https://192.168.20.4:443/'; Expected = $false },
        @{ Uri = 'http://192.168.20.4:49443/'; Expected = $false }
    )) {
        $message = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $case.Uri)
        try {
            if ($pin.VerifyHttp($message, $valid, $null, $errors) -ne $case.Expected) {
                throw "Zielbindung fehlgeschlagen: $($case.Uri)"
            }
        } finally { $message.Dispose() }
    }
    $message = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, 'https://192.168.20.4:49443/')
    try {
        $wrong = [JaylabTlsCertificate]::new('192.168.20.4', 49443, ('0' * 64))
        $empty = [JaylabTlsCertificate]::new('192.168.20.4', 49443, $null)
        if ($wrong.VerifyHttp($message, $valid, $null, $errors) -or
            $empty.VerifyHttp($message, $valid, $null, $errors) -or
            $pin.VerifyHttp($message, $null, $null, $errors)) {
            throw 'Fehlendes oder falsches Zertifikat wurde angenommen.'
        }
        foreach ($certificate in @($expired, $future)) {
            $timePin = [JaylabTlsCertificate]::new('192.168.20.4', 49443,
                $certificate.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256))
            if ($timePin.VerifyHttp($message, $certificate, $null, $errors)) {
                throw 'Zeitlich ungültiges Zertifikat wurde angenommen.'
            }
        }
    } finally { $message.Dispose() }
} finally {
    $valid.Dispose(); $expired.Dispose(); $future.Dispose(); $rsa.Dispose()
}
Write-Output 'Bestanden: feste Bindung an Zertifikat, HTTPS, Adresse und Port sowie Gültigkeitszeit. Keine Netzverbindung und keine Zugangsdaten verwendet.'
