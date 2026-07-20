$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST
$r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10
$null = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert

$searchResult = Invoke-WebRequest -Uri "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST -Body @{
    usuario = '15402487'
    accion = 'buscar_dos'
    busquedaAbierta = 'false'
    busquedaSegundaAbierta = 'true'
}

$searchResult.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\10_SearchRaw.html" -Encoding UTF8

# Find codigoUsuario
$matches = [regex]::Matches($searchResult.Content, 'codigoUsuario')
Write-Host "Found $($matches.Count) references to codigoUsuario"
$matches = [regex]::Matches($searchResult.Content, 'name="codigoUsuario"\s*')
Write-Host "Found $($matches.Count) references with name="

foreach ($m in [regex]::Matches($searchResult.Content, '(?s).{0,50}codigoUsuario.{0,50}')) {
    Write-Host ("  ..." + $m.Value.Trim() + "...") -ForegroundColor Gray
}

# Check for checkboxes
$checkboxMatch = [regex]::Matches($searchResult.Content, '<input[^>]*checkbox[^>]*codigoUsuario[^>]*>')
Write-Host "Checkbox matches: $($checkboxMatch.Count)"
foreach ($m in $checkboxMatch) { Write-Host "  $($m.Value)" }
