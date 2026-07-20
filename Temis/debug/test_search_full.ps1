$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

# Auth
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

# Launch Temis
$r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10
Write-Host "Temis URL: $($r.BaseResponse.ResponseUri.AbsoluteUri)"

# Show all cookies in the session
Write-Host "=== Cookies ===" -ForegroundColor Yellow
$ses.Cookies.GetCookies('http://temis.justicia.junta-andalucia.es') | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value) (domain=$($_.Domain))" }
$ses.Cookies.GetCookies('https://escritoriojudicial.justicia.junta-andalucia.es') | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value) (domain=$($_.Domain))" }

# Open UsuarioConsulta GET - establish Temis session
Write-Host "=== GET UsuarioConsulta.do ===" -ForegroundColor Yellow
$r1 = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert
Write-Host "Status: $($r1.StatusCode) Len: $($r1.Content.Length)"
if ($r1.Content -match 'B.squeda|consulta|usuario') { Write-Host "OK - Search page" -ForegroundColor Green }

# Check cookies again
Write-Host "=== Cookies despues ===" -ForegroundColor Yellow
$ses.Cookies.GetCookies('http://temis.justicia.junta-andalucia.es') | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value)" }

# Search
Write-Host "=== POST buscar_dos ===" -ForegroundColor Yellow
$r2 = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST -Body @{
    usuario = '15402487'
    accion = 'buscar_dos'
    busquedaAbierta = 'false'
    busquedaSegundaAbierta = 'true'
}
$r2.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\10_SearchRaw2.html" -Encoding UTF8
Write-Host "Status: $($r2.StatusCode) Len: $($r2.Content.Length)"

if ($r2.Content -match 'codigoUsuario') {
    Write-Host "codigoUsuario encontrado!" -ForegroundColor Green
    [regex]::Matches($r2.Content, 'name="codigoUsuario"\s*value="(\d+)"') | ForEach-Object { Write-Host "  codigoUsuario=$($_.Groups[1].Value)" }
    [regex]::Matches($r2.Content, '<input[^>]*codigoUsuario[^>]*value="(\d+)"') | ForEach-Object { Write-Host "  input codigoUsuario=$($_.Groups[1].Value)" }
} elseif ($r2.Content -match 'Excepci.n|error|Error|error') {
    Write-Host "ERROR en respuesta!" -ForegroundColor Red
    $text = $r2.Content.Substring(0, [Math]::Min(500, $r2.Content.Length))
    Write-Host $text -ForegroundColor Gray
}
