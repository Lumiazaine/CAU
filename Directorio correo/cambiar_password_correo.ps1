param(
    [Parameter(Mandatory=$true)]
    [string]$TargetUser,
    [string]$NewPassword,
    [switch]$WhatIf,
    [switch]$Interno
)

$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "cambiar_password_correo.log"
$script:DEBUG_DIR = Join-Path $script:SCRIPT_DIR "debug"
$script:BASE = "https://directorio.juntadeandalucia.es/myServlets/es.sadesi.admdirectorio.servlets"
$script:ENV_FILE = Join-Path $env:USERPROFILE ".env"

function Get-Credentials {
    $envFile = $script:ENV_FILE
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -Encoding UTF8 | ForEach-Object { $_.Trim() }
        $user = ($content | Where-Object { $_ -match '^ADMIN_USER=(.+)$' } | ForEach-Object { $Matches[1] }) -join ''
        $pass = ($content | Where-Object { $_ -match '^ADMIN_PASS=(.+)$' } | ForEach-Object { $Matches[1] }) -join ''
        if ($user -and $pass) {
            Write-Log "Credenciales cargadas desde $envFile" "INFO"
            return @{ User = $user; Pass = $pass }
        }
        Write-Log "El archivo $envFile no contiene ADMIN_USER y ADMIN_PASS" "WARN"
    }
    return $null
}

function Save-Credentials {
    param([string]$User, [string]$Pass)
    $lines = @(
        "ADMIN_USER=$User",
        "ADMIN_PASS=$Pass"
    )
    $lines | Set-Content -Path $script:ENV_FILE -Encoding UTF8
    Write-Log "Credenciales guardadas en $($script:ENV_FILE)" "OK"
}

function Get-CredentialsInteractive {
    Write-Log "Solicitando credenciales manualmente..." "WARN"
    $user = Read-Host "Usuario administrador"
    $pass = Read-Host "Contrasena" -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $save = Read-Host "Guardar credenciales para proxima vez? (s/N)"
    if ($save -eq 's' -or $save -eq 'S') {
        Save-Credentials -User $user -Pass $plainPass
    }
    return @{ User = $user; Pass = $plainPass }
}

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

function Extract-Token {
    param([string]$Html)
    if ($Html -match 'name="tokenParametro"\s*value="([^"]+)"') { return $Matches[1] }
    if ($Html -match '"tokenParametro"\s*:\s*"([^"]+)"') { return $Matches[1] }
    return $null
}

function Extract-FormField {
    param([string]$Html, [string]$FieldName)
    $pattern = 'name="' + [regex]::Escape($FieldName) + '"\s*value="([^"]*)"'
    if ($Html -match $pattern) { return $Matches[1] }
    return ""
}

$script:ERROR_COUNT = 0

if (-not $NewPassword) {
    $month = Get-Date -Format "MM"
    $year = Get-Date -Format "yy"
    $NewPassword = "Justicia.$month$year"
}

Clear-Host
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  DIRECTORIO CORREO - Cambiar Contrasena" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Log "Nueva contrasena destino: $NewPassword" "INFO"
Write-Log "Usuario destino: $TargetUser" "INFO"
if ($WhatIf) { Write-Log "MODO WHATIF" "WARN" }
Write-Host ""

$session = $null
$script:ADMIN_USER = $null
$script:ADMIN_PASS = $null
$maxLoginAttempts = 3

try {

for ($attempt = 1; $attempt -le $maxLoginAttempts; $attempt++) {

    if ($attempt -eq 1) {
        $creds = Get-Credentials
        if (-not $creds) { $creds = Get-CredentialsInteractive }
    } else {
        Write-Log "Reintentando login (intento $attempt/$maxLoginAttempts)..." "WARN"
        Write-Log "Introduzca credenciales correctas" "WARN"
        $creds = Get-CredentialsInteractive
    }
    $script:ADMIN_USER = $creds.User
    $script:ADMIN_PASS = $creds.Pass

    Write-Log "Paso 1/5: Obteniendo token de login..." "INFO"
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginInicial" -UseBasicParsing -SessionVariable session
    $token = Extract-Token $r.Content
    if (-not $token) { throw "No se pudo extraer token de login" }
    Write-Log "Token obtenido" "OK"

    Write-Log "Paso 2/5: Iniciando sesion como $script:ADMIN_USER..." "INFO"
    $body = @{
        accionInicial = 'inicio'
        tokenParametro = $token
        administrador = $script:ADMIN_USER
        clave = $script:ADMIN_PASS
        login = 'Entrar'
    }
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginInicial" -UseBasicParsing -WebSession $session -Method POST -Body $body
    $token = Extract-Token $r.Content
    if (-not $token) {
        if ($r.Content -match 'error|Error|incorrecto|incorrecta') {
            if ($attempt -lt $maxLoginAttempts) { continue }
            throw "Credenciales incorrectas tras $maxLoginAttempts intentos"
        }
        $token = Extract-Token ($r.Content -replace '\\n', '')
    }
    Write-Log "Sesion iniciada" "OK"
    break
}

Write-Log "Paso 3/5: Seleccionando modo administrador..." "INFO"
$body = @{
    botonPulsado = 'administrarRamas'
    dnEmpleado = 'uid=just9.sandetel.ext,o=sandetel,o=empleados,o=juntadeandalucia,c=es'
    datoAuxiliar = ''
    esUsuarioGuia = 'NO'
    tokenParametro = $token
    employeeType = 'externo'
}
$r = Invoke-WebRequest -Uri "$script:BASE.LoginUsuario" -UseBasicParsing -WebSession $session -Method POST -Body $body
$token = Extract-Token $r.Content
if (-not $token) { throw "No se pudo extraer token tras seleccionar modo admin" }
Write-Log "Modo admin seleccionado" "OK"

$ramaLdap = $(if ($Interno -or $TargetUser -match '\.ius') { 'ius' } else { 'jus' })
Write-Log "Paso 4/5: Seleccionando rama LDAP ($ramaLdap)..." "INFO"
$body = @{
    botonPulsado = 'administrarRama'
    dnEmpleado = 'uid=just9.sandetel.ext,o=sandetel,o=empleados,o=juntadeandalucia,c=es'
    datoAuxiliar = ''
    esUsuarioGuia = 'NO'
    tokenParametro = $token
    employeeType = 'externo'
    ramaLdap = $ramaLdap
}
$r = Invoke-WebRequest -Uri "$script:BASE.LoginUsuario" -UseBasicParsing -WebSession $session -Method POST -Body $body
$token = Extract-Token $r.Content
if (-not $token) { throw "No se pudo extraer token tras seleccionar rama" }
Write-Log "Rama $ramaLdap seleccionada" "OK"

if ($WhatIf) {
    Write-Log "WHATIF - Buscando y modificando usuario omitido" "WARN"
    throw "whatif"
}

Write-Log "Paso 5/5: Buscando usuario $TargetUser..." "INFO"
$r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $session
$token = Extract-Token $r.Content
if (-not $token) { throw "No se pudo extraer token de UsuariosMain" }

$esInterno = $Interno -or $TargetUser -match '\.ius'
Write-Log ("Tipo busqueda: " + $(if ($esInterno) { "INTERNO (.ius)" } else { "SIRHUS (jus)" })) "INFO"
$ldapO = $(if ($esInterno) { 'ius' } else { 'jus' })

$body = @{
    accion = 'consulta'
    botonPulsado = ''
    datoAuxiliar = ''
    tokenParametro = $token
    filtroAtributo = 'identificador'
    filtroTipoBusqueda = 'empezando'
    filtroValor = $TargetUser
    marcarSirhus = $(if ($esInterno) { 'NO' } else { 'SI' })
    marcarInternos = $(if ($esInterno) { 'SI' } else { 'NO' })
    marcarExternos = 'NO'
    marcarGenericos = 'NO'
    marcarNA = 'NO'
    numUsuariosAntiguo = '25'
    numUsuarios = '25'
}
if ($esInterno) { $body['seleccionarInternos'] = 'on' }
else { $body['seleccionarSirhus'] = 'on' }
$r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $session -Method POST -Body $body
$token = Extract-Token $r.Content

$dn = $null
if ($r.Content -match 'name="dn"\s*value="([^"]+)"') { $dn = $Matches[1] }
if (-not $dn) {
    $dn = "uid=$TargetUser,o=$ldapO,o=empleados,o=juntadeandalucia,c=es"
    Write-Log "Usuario no encontrado en busqueda - usando DN construido: $dn" "WARN"
} else {
    Write-Log ("Usuario encontrado. DN: $dn") "OK"
}

Write-Log "Cambiando contrasena a $NewPassword..." "INFO"
$body2 = @{
    accion = 'modificacion'
    botonPulsado = 'confirmarPassword'
    datoAuxiliar = '0'
    tokenParametro = $token
    filtroAtributo = 'identificador'
    filtroTipoBusqueda = 'empezando'
    filtroValor = $TargetUser
    marcarSirhus = $(if ($esInterno) { 'NO' } else { 'SI' })
    marcarInternos = $(if ($esInterno) { 'SI' } else { 'NO' })
    marcarExternos = 'NO'
    marcarGenericos = 'NO'
    marcarNA = 'NO'
    numUsuariosAntiguo = '25'
    numUsuarios = '25'
}
if ($esInterno) { $body2['seleccionarInternos'] = 'on' }
else { $body2['seleccionarSirhus'] = 'on' }

$body2 += @{
    usuarioWindows = 'NO'
    passCaducadoCP = 'NO'
    dn = $dn
    pwd_modificacion = $NewPassword
    pwd2_modificacion = $NewPassword
}
$r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $session -Method POST -Body $body2

if ($r2.Content -match 'actualiz.+correctamente|mensaje_ok') {
    Write-Log "Contrasena cambiada correctamente a $NewPassword" "OK"
} elseif ($r2.Content -match 'error|Error|incorrecto') {
    Write-Log "Posible error al cambiar la contrasena" "WARN"
}

Write-Log "Proceso completado" "OK"

} catch {
    if ($_.Exception.Message -eq "whatif") {
        Write-Log "WHATIF - No se realizaron cambios" "OK"
    } else {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
if ($WhatIf) {
    Write-Host "  WHATIF - No se realizaron cambios" -ForegroundColor Yellow
} elseif ($script:ERROR_COUNT -eq 0) {
    Write-Host "  PROCESO COMPLETADO" -ForegroundColor Green
} else {
    Write-Host "  PROCESO CON ERRORES ($script:ERROR_COUNT)" -ForegroundColor Red
}
Write-Host "============================================" -ForegroundColor Yellow
