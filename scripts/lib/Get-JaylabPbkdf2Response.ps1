function Get-JaylabPbkdf2Response {
    param([Parameter(Mandatory)][string]$Challenge, [Parameter(Mandatory)][string]$Password)
    if ($Challenge -notmatch '^2\$[0-9]+\$[0-9A-Fa-f]+\$[0-9]+\$[0-9A-Fa-f]+$') {
        throw 'Keine unterstützte PBKDF2-v2-Challenge.'
    }
    $parts = $Challenge.Split('$')
    $iterations1 = [int]$parts[1]
    $iterations2 = [int]$parts[3]
    if ($iterations1 -lt 1 -or $iterations1 -gt 2000000 -or
        $iterations2 -lt 1 -or $iterations2 -gt 2000000) { throw 'Iterationszahl außerhalb des Prüfbereichs.' }
    $salt1 = [Convert]::FromHexString($parts[2])
    $salt2 = [Convert]::FromHexString($parts[4])
    $passwordBytes = [Text.Encoding]::UTF8.GetBytes($Password)
    $hash1 = $null
    $hash2 = $null
    try {
        $hash1 = [Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
            $passwordBytes, $salt1, $iterations1, [Security.Cryptography.HashAlgorithmName]::SHA256, 32)
        $hash2 = [Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2(
            $hash1, $salt2, $iterations2, [Security.Cryptography.HashAlgorithmName]::SHA256, 32)
        return $parts[4] + '$' + [Convert]::ToHexString($hash2).ToLowerInvariant()
    } finally {
        [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
        if ($hash1) { [Array]::Clear($hash1, 0, $hash1.Length) }
        if ($hash2) { [Array]::Clear($hash2, 0, $hash2.Length) }
    }
}
