param(
    [Parameter(Mandatory=$true)]
    [string]$TemisUser,
    [string]$NewPassword,
    [switch]$WhatIf,
    [switch]$ShowBrowser
)

$script:LOG_FILE = Join-Path $PSScriptRoot "cambiar_password_temis.log"
$script:DEBUG_DIR = Join-Path $PSScriptRoot "debug"
$script:ERROR_COUNT = 0
$script:ESC_URL = "https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio"
$script:TEMIS_URL = "http://temis.justicia.junta-andalucia.es/Temis"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "HH:mm:ss"
    $prefix = "[$time] [$Level]"
    switch ($Level) {
        "OK"    { Write-Host "$prefix $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "$prefix $Message" -ForegroundColor Red; $script:ERROR_COUNT++ }
        "WARN"  { Write-Host "$prefix $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "$prefix $Message" -ForegroundColor Cyan }
        default { Write-Host "$prefix $Message" }
    }
    $logLine = "$(Get-Date -Format 'yyyy-MM-dd') $prefix $Message"
    Add-Content -Path $script:LOG_FILE -Value $logLine -Encoding UTF8
}

function Get-Certificate {
    $certs = Get-ChildItem Cert:\CurrentUser\My | Where-Object {
        $_.Subject -match '\d{8}[A-Z]' -and $_.NotAfter -gt (Get-Date)
    } | Sort-Object NotAfter -Descending
    $cert = $certs | Select-Object -First 1
    if (-not $cert) {
        Write-Log "No se encontro certificado con DNI en Subject, usando el primero valido" "WARN"
        $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.NotAfter -gt (Get-Date) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    }
    if (-not $cert) {
        Write-Log "No se encontro certificado valido, usando el primero disponible" "WARN"
        $cert = Get-ChildItem Cert:\CurrentUser\My | Select-Object -First 1
    }
    if (-not $cert) { throw "No se encontró ningún certificado digital en el almacén" }
    Write-Log "Certificado: $($cert.Subject) (válido hasta $($cert.NotAfter))" "INFO"
    return $cert
}

function Test-Url {
    param([string]$Url)
    try {
        $req = [System.Net.WebRequest]::Create($Url)
        $req.Method = "HEAD"
        $req.Timeout = 5000
        $req.GetResponse().Dispose()
        return $true
    } catch { return $false }
}

function Extract-FormFields {
    param([string]$Html)
    $fields = @{}
    $formMatch = [regex]::Match($Html, '(?s)<form[^>]*UsuarioGuardarModificar[^>]*>(.*?)</form>')
    if (-not $formMatch.Success) {
        $formMatch = [regex]::Match($Html, '(?s)<form[^>]*>(.*?)</form>')
    }
    if (-not $formMatch.Success) { return $fields }

    $formHtml = $formMatch.Groups[1].Value

    $inputPattern = '<input[^>]*name="([^"]*)"[^>]*>'
    $matches = [regex]::Matches($formHtml, $inputPattern)
    foreach ($m in $matches) {
        $name = $m.Groups[1].Value
        $valMatch = [regex]::Match($m.Value, 'value="([^"]*)"')
        $fields[$name] = if ($valMatch.Success) { $valMatch.Groups[1].Value } else { '' }
    }

    $selectPattern = '<select[^>]*name="([^"]*)"[^>]*>(.*?)</select>'
    $smatches = [regex]::Matches($formHtml, $selectPattern)
    foreach ($m in $smatches) {
        $name = $m.Groups[1].Value
        $optionPattern = '<option[^>]*value="([^"]*)"[^>]*selected[^>]*>'
        $om = [regex]::Match($m.Groups[2].Value, $optionPattern)
        if ($om.Success) { $fields[$name] = $om.Groups[1].Value }
        else {
            $firstOption = [regex]::Match($m.Groups[2].Value, '<option[^>]*value="([^"]*)"')
            if ($firstOption.Success) { $fields[$name] = $firstOption.Groups[1].Value }
        }
    }

    $textareaPattern = '<textarea[^>]*name="([^"]*)"[^>]*>(.*?)</textarea>'
    $tmatches = [regex]::Matches($formHtml, $textareaPattern)
    foreach ($m in $tmatches) {
        $val = $m.Groups[2].Value -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&quot;','"' -replace '&lt;','<' -replace '&gt;','>' -replace '&#(\d+);', { [char]::ConvertFromUtf32([int]$args[0].Groups[1].Value) }
        $fields[$m.Groups[1].Value] = $val
    }

    return $fields
}

Clear-Host
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  TEMIS - Anular Contrasena" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if (-not $NewPassword) {
    $month = Get-Date -Format "MM"
    $year = Get-Date -Format "yy"
    $NewPassword = "Justicia$month$year"
}
Write-Log "Nueva contrasena destino: $NewPassword" "INFO"
Write-Log "Usuario destino: $TemisUser" "INFO"
if ($WhatIf) { Write-Log "MODO WHATIF - No se realizaran cambios reales" "WARN" }
Write-Host ""

Write-Log "Verificando conectividad..." "INFO"
if (-not (Test-Url "$script:ESC_URL/Inicio.do") -or -not (Test-Url "$script:TEMIS_URL/UsuarioConsulta.do")) {
    Write-Log "No se puede acceder a los servidores. Verifica conexion VPN." "ERROR"
    exit 1
}
Write-Log "Conectividad OK" "OK"
Write-Host ""

Write-Log "Obteniendo certificado digital..." "INFO"
$cert = Get-Certificate
Write-Log ("Certificado: " + $cert.Subject) "OK"

$webSession = $null
try {

Write-Log "Paso 1/5: Autenticando en Escritorio Judicial..." "INFO"
$null = Invoke-WebRequest -Uri "$script:ESC_URL/Inicio.do" -UseBasicParsing -SessionVariable webSession -Certificate $cert
Write-Log "Sesion iniciada en Escritorio" "OK"

$null = Invoke-WebRequest -Uri "$script:ESC_URL/AccesoCertificado.do" -UseBasicParsing -WebSession $webSession -Certificate $cert
Write-Log "AccesoCertificado.do cargado" "OK"

$r = Invoke-WebRequest -Uri "$script:ESC_URL/CallAuthenticationServlet" -UseBasicParsing -WebSession $webSession -Certificate $cert -Method POST
Write-Log "Autenticacion con certificado completada" "OK"
Write-Host ""

Write-Log "Paso 2/5: Accediendo a Temis..." "INFO"
$r = Invoke-WebRequest -Uri "$script:ESC_URL/Lanzadera.do?id=2" -UseBasicParsing -WebSession $webSession -Certificate $cert -MaximumRedirection 10
Write-Log ("Temis accesible: " + $r.BaseResponse.ResponseUri.AbsoluteUri) "OK"
Write-Host ""

Write-Log "Paso 3/5: Buscando usuario $TemisUser..." "INFO"
$null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $webSession -Certificate $cert

$searchFields = @{
    codigoPartidoJudicial = ''
    codigoMunicipioPart = ''
    codigoOrganismo = ''
    codigoUsuario = ''
    codigosUsuarios = ''
    usuario = ''
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
if ($TemisUser -match '^\d{8}[A-Z]$') {
    $dniNum = $TemisUser.Substring(0, 8)
    $searchFields['usuario'] = $dniNum
    $searchFields['dni'] = $TemisUser
    $searchFields['codigoDocumento'] = 'D'
} else {
    $searchFields['usuario'] = $TemisUser
}
$searchResult = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $webSession -Certificate $cert -Method POST -Body $searchFields
$codigoUsuario = $null
foreach ($match in [regex]::Matches($searchResult.Content, 'name="codigoUsuario"\s*value="(\d+)"')) {
    $codigoUsuario = $match.Groups[1].Value
}
if (-not $codigoUsuario) {
    if ($WhatIf) { Write-Log "WHATIF - usuario no encontrado en busqueda simulada" "WARN"; throw "whatif" }
    Write-Log "No se encontro el usuario $TemisUser" "ERROR"
    throw "user_not_found"
}
Write-Log ("Usuario encontrado! codigoUsuario=$codigoUsuario") "OK"
Write-Host ""

Write-Log "Paso 4/5: Abriendo ficha del usuario..." "INFO"
$modResult = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $webSession -Certificate $cert -Method POST -Body @{
    codigoUsuario = $codigoUsuario
    accion = 'modificarDos'
}
Write-Log "Ficha cargada correctamente" "OK"

if ($WhatIf) {
    Write-Log "WHATIF - No se realizara el cambio de contrasena" "WARN"
    Write-Log "Para continuar sin -WhatIf, el siguiente paso seria:" "INFO"
    Write-Log "  1. POST a UsuarioGuardarModificar.do con accion=anular (Temis)" "INFO"
    Write-Log "  2. POST a RealizarModificarPassword.do (Escritorio Judicial)" "INFO"
    throw "whatif"
}

Write-Log "Paso 5/5: Anulando contrasena..." "INFO"
$formFields = Extract-FormFields -Html $modResult.Content
if ($formFields.Count -eq 0) {
    Write-Log "No se pudieron extraer los campos del formulario" "ERROR"
    throw "form_parse_error"
}
$formFields['accion'] = 'anular'
$formFields['usuario'] = $TemisUser
$formFields['cambiarIdPassword'] = '3'

Write-Log ("Campos extraidos: " + $formFields.Count) "OK"
$result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioGuardarModificar.do" -UseBasicParsing -WebSession $webSession -Certificate $cert -Method POST -Body $formFields
$result.Content | Out-File (Join-Path $PSScriptRoot "debug\11_ResultadoAnular.html") -Encoding UTF8
Write-Log "Peticion enviada a UsuarioGuardarModificar.do" "OK"

if ($result.Content -match 'errores|Error|error|Exception|excepci.n') {
    Write-Log "Posible error en la respuesta" "WARN"
    $text = $result.Content.Substring(0, [Math]::Min(500, $result.Content.Length))
    Write-Log "Respuesta: $text" "INFO"
}
if ($result.Content -match 'contrase.a.*correcta|cambio.*correcto|password.*ok|OK|correctamente') {
    Write-Log "Contrasena anulada correctamente!" "OK"
}

Write-Log "Paso 6/6: Estableciendo contrasena en Escritorio Judicial..." "INFO"
$escPassFields = @{
    usuario = ($TemisUser -replace '[A-Z]$', '')
    password = ''
    nuevaPassword = $NewPassword
    nuevaPassword2 = $NewPassword
    aceptar2 = 'Aceptar'
}
$escResult = Invoke-WebRequest -Uri "$script:ESC_URL/RealizarModificarPassword.do" -UseBasicParsing -WebSession $webSession -Certificate $cert -Method POST -Body $escPassFields
$escResult.Content | Out-File (Join-Path $PSScriptRoot "debug\12_ResultadoEscritorio.html") -Encoding UTF8
Write-Log "Respuesta recibida de Escritorio Judicial" "OK"

if ($escResult.Content -match 'errores|Error|error|Exception|excepci.n') {
    Write-Log "Posible error en Escritorio Judicial" "WARN"
    $text = $escResult.Content.Substring(0, [Math]::Min(500, $escResult.Content.Length))
    Write-Log "Respuesta: $text" "INFO"
}
if ($escResult.Content -match 'correctamente|contrase.a.*cambiad|operaci.n.*correcta|OK') {
    Write-Log "Contrasena establecida correctamente en Escritorio Judicial!" "OK"
}

$rtext = $result.Content.Substring(0, [Math]::Min(200, $result.Content.Length)) -replace "`n"," " -replace "`r",""
Write-Log "Respuesta final Temis: $rtext" "INFO"

Write-Log "Proceso completado" "OK"

} catch {
    if ($_.Exception.Message -eq "whatif") { 
        Write-Log "WHATIF - No se realizaron cambios" "OK"
    } else {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
if ($WhatIf) {
    Write-Host "  WHATIF - No se realizaron cambios" -ForegroundColor Yellow
} elseif ($script:ERROR_COUNT -eq 0) {
    Write-Host "  PROCESO COMPLETADO" -ForegroundColor Green
} else {
    Write-Host "  PROCESO CON ERRORES ($script:ERROR_COUNT)" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
