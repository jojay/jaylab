#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('fritz-mesh','fritz-cable')][string[]]$DeviceId = @('fritz-mesh','fritz-cable'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$approvalFile = Join-Path $root '.local/access/fritz-certificates-approved.json'
if (-not (Test-Path -LiteralPath $approvalFile)) {
    throw 'Fritzbox-Zertifikate noch nicht bestätigt. Keine Zugangsdaten gelesen oder gesendet.'
}
$approvals = Get-Content -Raw -LiteralPath $approvalFile | ConvertFrom-Json -AsHashtable
$inventory = Get-Content -Raw -LiteralPath (Join-Path $root 'inventory/infrastruktur.json') | ConvertFrom-Json
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    if (-not $approvals.ContainsKey($id) -or $approvals[$id].approved -isnot [bool] -or
        -not $approvals[$id].approved -or $approvals[$id].address -cne $device.address -or
        $approvals[$id].port -ne 49443 -or $approvals[$id].sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Kein passendes bestätigtes Zertifikat für $id. Keine Zugangsdaten gelesen."
    }
}
if (-not ('JaylabTlsCertificate' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'lib/JaylabTlsCertificate.cs')
}

function Invoke-FritzReadAction($Client, [string]$Path, [string]$Service, [string]$Action) {
    $body = '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ' +
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:' + $Action +
        ' xmlns:u="' + $Service + '" /></s:Body></s:Envelope>'
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $Path)
    $null = $request.Headers.TryAddWithoutValidation('SOAPACTION', ('"' + $Service + '#' + $Action + '"'))
    $request.Content = [Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, 'text/xml')
    $response = $null
    try {
        $response = $Client.SendAsync($request).GetAwaiter().GetResult()
        $xmlText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $xml = $null
        try { $xml = [xml]$xmlText }
        catch {
            if (-not $response.IsSuccessStatusCode) {
                throw "FritzReadAction HTTP=$([int]$response.StatusCode) SOAP=unknown"
            }
            throw 'Keine gültige SOAP-XML-Antwort.'
        }
        if (-not $response.IsSuccessStatusCode) {
            $codeNode = $xml.SelectSingleNode('//*[local-name()="errorCode"]')
            $code = if ($codeNode -and $codeNode.InnerText -match '^\d+$') { $codeNode.InnerText } else { 'unknown' }
            throw "FritzReadAction HTTP=$([int]$response.StatusCode) SOAP=$code"
        }
        return $xml
    } finally {
        if ($response) { $response.Dispose() }
        $request.Dispose()
    }
}

$results = @()
foreach ($id in $DeviceId) {
    $device = @($inventory.devices | Where-Object id -eq $id)[0]
    $approval = $approvals[$id]
    $baseUri = [uri]('https://' + $device.address + ':49443/')
    $credential = Import-Clixml -LiteralPath (Join-Path $root ('.local/access/credentials/' + $id + '.clixml'))
    if ($credential -isnot [pscredential] -or $credential.Password.Length -eq 0) {
        throw "Ungültiger lokaler Zugang für $id"
    }
    $pin = [JaylabTlsCertificate]::new($device.address, 49443, $approval.sha256)
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $handler.UseCookies = $false
    $handler.AllowAutoRedirect = $false
    $handler.PreAuthenticate = $false
    $handler.SslProtocols = [Security.Authentication.SslProtocols]::Tls12 -bor [Security.Authentication.SslProtocols]::Tls13
    $handler.ServerCertificateCustomValidationCallback =
        [Func[Net.Http.HttpRequestMessage,Security.Cryptography.X509Certificates.X509Certificate2,
              Security.Cryptography.X509Certificates.X509Chain,Net.Security.SslPolicyErrors,bool]]$pin.VerifyHttp
    $cache = [Net.CredentialCache]::new()
    # Digest ausschließlich für dieses HTTPS-Ziel; keine Kennwörter in Argumenten oder Dateien.
    $cache.Add($baseUri, 'Digest', $credential.GetNetworkCredential())
    $handler.Credentials = $cache
    $client = [Net.Http.HttpClient]::new($handler)
    $client.BaseAddress = $baseUri
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    $client.MaxResponseContentBufferSize = 262144
    $authenticated = $false
    try {
        $userResult = Invoke-FritzReadAction $client '/upnp/control/lanconfigsecurity' `
            'urn:dslforum-org:service:LANConfigSecurity:1' 'X_AVM-DE_GetCurrentUser'
        $userNode = $userResult.SelectSingleNode('//*[local-name()="NewX_AVM-DE_CurrentUsername"]')
        if (-not $userNode -or $userNode.InnerText -cne $credential.UserName) {
            throw 'CurrentUser stimmt nicht mit dem vorgesehenen Benutzer überein.'
        }
        $authenticated = $true
        $rightsNode = $userResult.SelectSingleNode('//*[local-name()="NewX_AVM-DE_CurrentUserRights"]')
        $info = Invoke-FritzReadAction $client '/upnp/control/deviceinfo' `
            'urn:dslforum-org:service:DeviceInfo:1' 'GetInfo'
        $modelNode = $info.SelectSingleNode('//*[local-name()="NewModelName"]')
        $versionNode = $info.SelectSingleNode('//*[local-name()="NewSoftwareVersion"]')
        $results += [ordered]@{
            device = $id; address = $device.address; authenticated = $true
            user = $userNode.InnerText; status = 'tr064-lesend-geprueft'
            model = $(if ($modelNode) { $modelNode.InnerText } else { $null })
            version = $(if ($versionNode) { $versionNode.InnerText } else { $null })
            rights = $(if ($rightsNode) { $rightsNode.InnerText } else { $null })
        }
    } catch {
        $results += [ordered]@{
            device = $id; address = $device.address; authenticated = $authenticated
            status = 'pruefung-fehlgeschlagen'; errorType = $_.Exception.GetBaseException().GetType().FullName
            # Nur eigene, kontrollierte Statuswerte ausgeben, keine rohen Serverantworten.
            actionStatus = $(if ($_.Exception.Message -match '^FritzReadAction HTTP=\d+ SOAP=(\d+|unknown)$') {
                $_.Exception.Message
            } else { $null })
        }
    } finally {
        $client.Dispose()
        $credential = $null
        $cache = $null
    }
}
$results | ConvertTo-Json -Depth 5
