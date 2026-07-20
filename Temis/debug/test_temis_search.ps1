$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
$base = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio'

Write-Host "--- Autenticando en Escritorio ---" -ForegroundColor Yellow
$null = Invoke-WebRequest -Uri "$base/Inicio.do" -UseBasicParsing -SessionVariable 'ses' -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/AccesoCertificado.do" -UseBasicParsing -WebSession $ses -Certificate $cert
$null = Invoke-WebRequest -Uri "$base/CallAuthenticationServlet" -UseBasicParsing -WebSession $ses -Certificate $cert -Method POST

Write-Host "--- Lanzando Temis via Lanzadera ---" -ForegroundColor Yellow
$r = Invoke-WebRequest -Uri "$base/Lanzadera.do?id=2" -UseBasicParsing -WebSession $ses -Certificate $cert -MaximumRedirection 10
$temisUrl = $r.BaseResponse.ResponseUri.AbsoluteUri
Write-Host "Temis URL: $temisUrl" -ForegroundColor Green

# Extract the final cookies
$allCookies = @{}
if ($ses.Cookies) {
    $ses.Cookies.GetCookies('http://temis.justicia.junta-andalucia.es') | ForEach-Object { 
        $allCookies[$_.Name] = $_.Value
        Write-Host "Temis cookie: $($_.Name)=$($_.Value)" -ForegroundColor Yellow
    }
}

# Navigate to UsuarioConsulta.do
Write-Host "--- Buscando usuario en Temis ---" -ForegroundColor Yellow
$uri = "http://temis.justicia.junta-andalucia.es/Temis/UsuarioConsulta.do"
try {
    $r2 = Invoke-WebRequest -Uri $uri -UseBasicParsing -WebSession $ses -Certificate $cert
    Write-Host ("Status: " + $r2.StatusCode) -ForegroundColor Green
    $r2.Content | Out-File "C:\Users\CAU\CAU\Temis\debug\07_UsuarioConsulta.html" -Encoding UTF8
    $text = $r2.Content.Substring(0, [Math]::Min(1000, $r2.Content.Length))
    Write-Host "Content: $text"
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
