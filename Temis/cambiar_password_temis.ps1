param(
    [Parameter(Mandatory=$true)]
    [string]$TemisUser,
    [Security.SecureString]$NewPassword,
    [string]$TemisEndpoint,
    [string]$CertificateThumbprint,
    [switch]$WhatIf,
    [switch]$ShowBrowser
)

$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "cambiar_password_temis.log"
$script:DEBUG_DIR = Join-Path $script:SCRIPT_DIR "debug"

$script:ERROR_COUNT = 0
$script:CertificateThumbprint = $CertificateThumbprint
$script:ESC_URL = "https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio"
$script:TEMIS_URL = "http://temis.justicia.junta-andalucia.es/Temis"

if ($TemisEndpoint) { $script:TEMIS_URL = $TemisEndpoint.TrimEnd('/') }

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

function Assert-PasswordEndpoint {
    param([string]$Url)
    $endpoint = $null
    if (-not [Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$endpoint) -or
        $endpoint.Scheme -ne 'https' -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) {
        throw 'Cambio bloqueado: configure un endpoint HTTPS aprobado mediante -TemisEndpoint; no se envia ninguna clave por HTTP.'
    }
}

function Get-Certificate {
    $now = Get-Date
    $certs = @(Get-ChildItem Cert:\CurrentUser\My -ErrorAction Stop | Where-Object {
        $_.HasPrivateKey -and $_.NotBefore -le $now -and $_.NotAfter -gt $now
    })
    if ($script:CertificateThumbprint) {
        $certs = @($certs | Where-Object { $_.Thumbprint -eq $script:CertificateThumbprint })
    }
    if ($certs.Count -ne 1) {
        throw 'Se requiere un unico certificado vigente con clave privada; especifique -CertificateThumbprint si hay varios.'
    }
    return $certs[0]
}

function Invoke-PasswordPost {
    param([string]$Uri,[hashtable]$Fields,[Security.SecureString]$NewPassword)
    Assert-PasswordEndpoint $Uri
    if (-not $NewPassword -or $NewPassword.Length -eq 0) { throw 'La clave segura no puede estar vacia.' }
    $body = $Fields.Clone()
    $ptr = [IntPtr]::Zero
    try {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        $body['nuevaPassword'] = $plain
        $body['nuevaPassword2'] = $plain
        if ($body.ContainsKey('pwd_modificacion')) {
            $body['pwd_modificacion'] = $plain
            $body['pwd2_modificacion'] = $plain
        }
        # No redirecciones: una respuesta HTTPS no puede reenviar el cuerpo a HTTP.
        $null = Invoke-WebRequest -Uri $Uri -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $body -MaximumRedirection 0 -ErrorAction Stop
    } catch {
        # Ni HTML, ni excepciones de transporte (pueden reflejar el secreto).
        throw 'No se pudo completar el envio seguro. Compruebe el servicio por un canal aprobado; no reintente automaticamente.'
    } finally {
        $body.Clear()
        $plain = $null
        if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
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
        $fields[$name] = if ($valMatch.Success) { [System.Net.WebUtility]::HtmlDecode($valMatch.Groups[1].Value) } else { '' }
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
        $val = [System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value)
        $fields[$m.Groups[1].Value] = $val
    }

    return $fields
}

Clear-Host
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  TEMIS - Anular Contrasena" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) { Write-Host 'WHATIF - No se realizan peticiones, registros ni cambios'; return }
Assert-PasswordEndpoint $script:TEMIS_URL
Assert-PasswordEndpoint $script:ESC_URL
$ownedSecret = $false
try {
if (-not $NewPassword) { $NewPassword = Read-Host 'Nueva clave' -AsSecureString; $ownedSecret = $true }
if ($NewPassword.Length -eq 0) { throw 'La clave segura no puede estar vacia.' }
Write-Log 'Inicio del cambio seguro' 'INFO'

Write-Log "Verificando conectividad..." "INFO"
if (-not (Test-Url "$script:ESC_URL/Inicio.do") -or -not (Test-Url "$script:TEMIS_URL/UsuarioConsulta.do")) {
    Write-Log "No se puede acceder a los servidores. Verifica conexion VPN." "ERROR"
    throw 'Servicio no disponible.'
}
Write-Log "Conectividad OK" "OK"
Write-Host ""

Write-Log "Obteniendo certificado digital..." "INFO"
$cert = Get-Certificate
Write-Log 'Certificado vigente seleccionado' 'OK'

$webSession = $null

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

$formFields = Extract-FormFields -Html $modResult.Content
if ($formFields.Count -eq 0) { throw 'No se pudieron extraer los campos del formulario' }
$formFields['accion'] = 'anular'
$formFields['usuario'] = $TemisUser
$formFields['cambiarIdPassword'] = '3'
Invoke-PasswordPost -Uri "$script:TEMIS_URL/UsuarioGuardarModificar.do" -Fields $formFields -NewPassword $NewPassword
Invoke-PasswordPost -Uri "$script:ESC_URL/RealizarModificarPassword.do" -Fields @{usuario=($TemisUser -replace '[A-Z]$', '');password='';aceptar2='Aceptar'} -NewPassword $NewPassword
Write-Log 'Peticiones enviadas; confirme el resultado por el canal aprobado.' 'INFO'

} catch {
    if ($_.Exception.Message -eq "whatif") { 
        Write-Log "WHATIF - No se realizaron cambios" "OK"
    } else {
        Write-Log 'Cambio no completado; puede haber cambios parciales. Verifique por el canal aprobado.' 'ERROR'
    }
} finally {
    if ($ownedSecret -and $NewPassword) { $NewPassword.Dispose() }
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
