$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

Write-Host "--- Autenticando ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

# Follow the redirect with proper error handling for 301/302
Write-Host "--- Lanzadera.do?id=2 (Temis, siguiendo redirects) ---" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10 -ErrorAction Stop
    Write-Host ("Final Status: " + $r.StatusCode) -ForegroundColor Green
    Write-Host ("Final URI: " + $r.BaseResponse.ResponseUri.AbsoluteUri) -ForegroundColor Green
    $cookies = $r.Headers['Set-Cookie']
    if ($cookies) { Write-Host "Cookies: $cookies" -ForegroundColor Yellow }
    $text = $r.Content.Substring(0, [Math]::Min(1500, $r.Content.Length))
    Write-Host "Content: $text"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host ("StatusCode: " + $_.Exception.Response.StatusCode)
    }
}
