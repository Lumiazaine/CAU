$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

Write-Host "--- Autenticando en Escritorio ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

Write-Host "--- Lanzando Temis via Lanzadera ---" -ForegroundColor Yellow
# Follow redirect, allow up to 10 redirects - but we need to see the URL after redirect
$r = $null
try {
    $r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10 -ErrorAction Stop
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$temisUrl = $r.BaseResponse.ResponseUri.AbsoluteUri
Write-Host "Temis URL: $temisUrl" -ForegroundColor Green

# The response should be Temis with session established, but we're on HTTP now
# Let's extract the JSESSIONID cookie from Temis
$cookies = [System.Net.CookieCollection]::new()
$cookies.Add($r.BaseResponse.Cookies)
Write-Host "Cookies:"
$cookies | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value)" }

# Save the Temis page to see what we have
$r.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\06_Temis_autenticado.html" -Encoding UTF8
Write-Host "Temis page saved to debug/06_Temis_autenticado.html"
Write-Host ("Content length: " + $r.Content.Length)

# Check if we have the search form
if ($r.Content -match 'consulta|usuario|Usuario|b.squeda|Buscar') {
    Write-Host "Temis SEARCH PAGE!" -ForegroundColor Green
}
