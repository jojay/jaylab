#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib/Get-JaylabPbkdf2Response.ps1')
# Öffentlicher Testvektor der Herstellerbeschreibung, keine echten Zugangsdaten.
$actual = Get-JaylabPbkdf2Response -Challenge '2$10000$5A1711$2000$5A1722' -Password '1example!'
$expected = '5A1722$1798a1672bca7c6463d6b245f82b53703b0f50813401b03e4045a5861e689adb'
if ($actual -cne $expected) { throw 'PBKDF2-Testvektor stimmt nicht überein.' }
foreach ($challenge in @('legacy', '2$0$AA$2000$BB', '2$10$XYZ$20$BB', '2$3000000$AA$20$BB')) {
    $rejected = $false
    try { $null = Get-JaylabPbkdf2Response -Challenge $challenge -Password 'test' }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'Ungültige Challenge wurde nicht abgewiesen.' }
}
Write-Output 'Bestanden: öffentlicher PBKDF2-v2-Testvektor und Ablehnung ungültiger Challenges. Keine Geräteanmeldung ausgeführt.'
