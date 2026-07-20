$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
Write-Host ("Certificado: " + $cert.Subject) -ForegroundColor Cyan

$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

# Authenticate
Write-Host "--- Autenticando ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

# Login.do authenticated page
Write-Host "--- Login.do (autenticado) ---" -ForegroundColor Yellow
$r = Invoke-WebRequest -Uri "$base/Login.do" -UseBasicParsing -WebSession $ses -Certificate $cert
Write-Host ("Status: " + $r.StatusCode)

# Look for application links or Lanzadera
$content = $r.Content
if ($content -match 'Lanzadera.do\?id=(\d+)') {
    $matches | ForEach-Object { Write-Host "Lanzadera link: id=$($Matches[1])" -ForegroundColor Green }
}
# Check for Temis
if ($content -match 'temis|Temis|TEMIS') {
    Write-Host "TEMIS FOUND in page!" -ForegroundColor Green
}
# Check for app names
$apps = [regex]::Matches($content, 'startClick\("?(\d+)"?\)')
if ($apps.Count -gt 0) {
    $apps | ForEach-Object { Write-Host "App ID: $($_.Groups[1].Value)" -ForegroundColor Yellow }
}
# Save the HTML
$content | Out-File "C:\Users\CAU\CAU\Temis\debug\04_Login_autenticado.html" -Encoding UTF8
Write-Host "HTML guardado en debug/04_Login_autenticado.html"

# Try to get the apps menu
Write-Host "--- Buscando aplicaciones ---" -ForegroundColor Yellow
$r2 = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$r2.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\05_Inicio_autenticado.html" -Encoding UTF8
Write-Host "HTML guardado en debug/05_Inicio_autenticado.html"
