$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
Write-Host ("Certificado: " + $cert.Subject) -ForegroundColor Cyan

$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

# Paso 1: Visitar Inicio.do para establecer sesion
Write-Host "--- Paso 1: Inicio.do ---" -ForegroundColor Yellow
$r1 = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
Write-Host ("Status: " + $r1.StatusCode)
$c1 = $r1.Headers['Set-Cookie']
if ($c1) { Write-Host "Cookies: $c1" -ForegroundColor Green }

# Paso 2: AccesoCertificado.do con la misma sesion
Write-Host "--- Paso 2: AccesoCertificado.do ---" -ForegroundColor Yellow
$r2 = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
Write-Host ("Status: " + $r2.StatusCode)
$c2 = $r2.Headers['Set-Cookie']
if ($c2) { Write-Host "Cookies: $c2" -ForegroundColor Green }
$text2 = $r2.Content.Substring(0, [Math]::Min(500, $r2.Content.Length))
Write-Host "Content: $text2"

# Paso 3: Submit CallAuthenticationServlet
Write-Host "--- Paso 3: CallAuthenticationServlet ---" -ForegroundColor Yellow
$r3 = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST
Write-Host ("Status: " + $r3.StatusCode)
$c3 = $r3.Headers['Set-Cookie']
if ($c3) { Write-Host "Cookies: $c3" -ForegroundColor Green }
$text3 = $r3.Content.Substring(0, [Math]::Min(1000, $r3.Content.Length))
Write-Host "Content: $text3"

# Paso 4: Ir a Login.do para verificar sesion
Write-Host "--- Paso 4: Login.do ---" -ForegroundColor Yellow
$r4 = Invoke-WebRequest -Uri "$base/Login.do" -UseBasicParsing -WebSession $ses -Certificate $cert
Write-Host ("Status: " + $r4.StatusCode)
$c4 = $r4.Headers['Set-Cookie']
if ($c4) { Write-Host "Cookies: $c4" -ForegroundColor Green }
if ($r4.Content -match 'cerrarSesion|Cerrar sesión|Salir|ModificarPassword') {
    Write-Host "SESION ESTABLECIDA!" -ForegroundColor Green
} else {
    $text4 = $r4.Content.Substring(0, [Math]::Min(500, $r4.Content.Length))
    Write-Host "Content: $text4"
}
