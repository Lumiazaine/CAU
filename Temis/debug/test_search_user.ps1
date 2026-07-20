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

Write-Host "--- Buscando usuario 15402487P ---" -ForegroundColor Yellow
$body = @{
    codigoPartidoJudicial = ''
    codigoMunicipioPart = ''
    codigoOrganismo = ''
    codigoUsuario = ''
    codigosUsuarios = ''
    usuario = '15402487'
    accion = 'buscar_dos'
    nombre = ''
    apellidos = ''
    codigoMunicipio = ''
    mayor = ''
    noResultados = ''
    partidoJudicial = ''
    organismo = ''
    cargo = ''
    busquedaAbierta = 'false'
    busquedaSegundaAbierta = 'true'
    codigoDocumento = ''
    dni = ''
    otro = ''
    mostrar = ''
    organismoHijo = ''
    listadoOrganismoHijo = ''
    codigoOrganismoPadre = ''
}

$r2 = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" `
    -UseBasicParsing -WebSession $ses -Certificate $cert `
    -Method POST -Body $body

$r2.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\08_ResultadoBusqueda.html" -Encoding UTF8
Write-Host ("Status: " + $r2.StatusCode) -ForegroundColor Green
Write-Host ("Length: " + $r2.Content.Length)

# Look for result table rows
if ($r2.Content -match '(?s)<td class="titulofondo">.*?Usuarios.*?encontrados') {
    Write-Host "Resultados encontrados!" -ForegroundColor Green
}
if ($r2.Content -match 'codigoUsuario\s*=\s*"(\d+)"') {
    Write-Host "codigoUsuario: $($Matches[1])" -ForegroundColor Cyan
}
# Check for modification links
if ($r2.Content -match 'modificar|Modificar|anular|Anular') {
    Write-Host "Modificar/Anular links found!" -ForegroundColor Yellow
}
# Check the page title
if ($r2.Content -match '<title>(.*?)</title>') {
    Write-Host "Title: $($Matches[1])" -ForegroundColor Gray
}
