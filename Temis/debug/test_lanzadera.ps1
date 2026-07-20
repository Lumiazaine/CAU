$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

Write-Host "--- Autenticando ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

Write-Host "--- Lanzadera.do?id=2 (Temis) ---" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 0 -ErrorAction Stop
    Write-Host ("Status: " + $r.StatusCode)
    $loc = $r.Headers['Location']
    if ($loc) { Write-Host "Location: $loc" -ForegroundColor Green }
    $cookies = $r.Headers['Set-Cookie']
    if ($cookies) { Write-Host "Cookies: $cookies" -ForegroundColor Yellow }
    $text = $r.Content.Substring(0, [Math]::Min(1000, $r.Content.Length))
    Write-Host "Content: $text"
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        Write-Host "Redirect: $($_.Exception.Response.Headers['Location'])" -ForegroundColor Green
    } else {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
}
