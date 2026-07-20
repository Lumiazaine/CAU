$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

Write-Host "--- Autenticando ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

Write-Host "--- Lanzando Temis ---" -ForegroundColor Yellow
$r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10

Write-Host "--- Abriendo UsuarioConsulta.do ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert

Write-Host "--- Buscando usuario ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST -Body @{
    usuario = '15402487'; accion = 'buscar_dos'; busquedaAbierta = 'false'; busquedaSegundaAbierta = 'true'
}

Write-Host "--- Abriendo ficha (modificarDos) ---" -ForegroundColor Yellow
$r = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST -Body @{
    codigoUsuario = '29485'; accion = 'modificarDos'
}

$r.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\09_FichaUsuario.html" -Encoding UTF8
Write-Host ("Status: " + $r.StatusCode)
Write-Host ("Length: " + $r.Content.Length)

# Look for "anular" password related fields
if ($r.Content -match 'cambiarIdPassword|anular|Anular contrase|password|Password') {
    Write-Host "Password/Anular found!" -ForegroundColor Green
}
if ($r.Content -match 'accion\s*=\s*"anular"') {
    Write-Host "accion=anular found!" -ForegroundColor Green
}
if ($r.Content -match 'cambiarIdPassword\s*=\s*"(\d+)"') {
    Write-Host "cambiarIdPassword=$($Matches[1])" -ForegroundColor Cyan
}
# Extract the form action
if ($r.Content -match '(?s)<input[^>]*name="usuario"[^>]*value="([^"]*)"') {
    Write-Host "usuario field: $($Matches[1])" -ForegroundColor Gray
}
