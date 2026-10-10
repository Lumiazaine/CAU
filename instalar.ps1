param([switch]$WhatIf)

$functions = @'

# Los atajos ejecutan esta copia revisada; no descargan codigo mutable al usarlos.
$global:CAUInstallRoot = '__CAU_ROOT__'

# Temis - Cambio de contrasena
function temis {
    param([string]$TemisUser, [Security.SecureString]$NewPassword, [switch]$WhatIf, [switch]$ShowBrowser, [string]$TemisEndpoint, [string]$CertificateThumbprint)
    & (Join-Path $global:CAUInstallRoot 'Temis/cambiar_password_temis.ps1') @PSBoundParameters
}

# Directorio Correo - Cambio de contrasena
function ldap {
    param([string]$correo, [Security.SecureString]$NewPassword, [switch]$PersistCredentials, [switch]$WhatIf, [switch]$Interno)
    $parameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
        if ($key -eq 'correo') { $parameters['TargetUser'] = $correo }
        else { $parameters[$key] = $PSBoundParameters[$key] }
    }
    & (Join-Path $global:CAUInstallRoot 'Directorio correo/cambiar_password_correo.ps1') @parameters
}

# Directorio Correo - TUI
function lazydirectory {
    param([switch]$WhatIf, [switch]$PersistCredentials)
    & (Join-Path $global:CAUInstallRoot 'lazydirectory/lazydirectory.ps1') @PSBoundParameters
}
'@
if (-not $PSScriptRoot) { throw 'Ejecuta instalar.ps1 desde una copia local revisada del repositorio.' }
$functions = $functions.Replace('__CAU_ROOT__', $PSScriptRoot.Replace("'", "''"))

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  INSTALACION - Scripts CAU" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF] No se realizaran cambios" -ForegroundColor Yellow
    Write-Host "[WHATIF] Perfil de destino: $PROFILE" -ForegroundColor Yellow
    Write-Host "[WHATIF] Funciones a anhadir: temis, ldap, lazydirectory" -ForegroundColor Yellow
    Write-Host ""
    exit
}

Write-Host "[1/3] Configurando ExecutionPolicy..." -ForegroundColor Cyan
$current = Get-ExecutionPolicy -Scope CurrentUser
if ($current -eq 'Unrestricted') {
    Write-Host "  ExecutionPolicy ya es Unrestricted" -ForegroundColor Green
} else {
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    Write-Host "  ExecutionPolicy cambiado a Unrestricted" -ForegroundColor Green
}

Write-Host "[2/3] Creando perfil de PowerShell..." -ForegroundColor Cyan
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    $null = New-Item -ItemType Directory -Path $profileDir -Force
    Write-Host "  Directorio creado: $profileDir" -ForegroundColor Green
}
if (-not (Test-Path $PROFILE)) {
    $null = New-Item -Path $PROFILE -ItemType File -Force
    Write-Host "  Perfil creado: $PROFILE" -ForegroundColor Green
} else {
    Write-Host "  Perfil existente: $PROFILE" -ForegroundColor Green
}

Write-Host "[3/3] Anhadiendo funciones al perfil..." -ForegroundColor Cyan
$content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($content -and $content.Contains($functions.Trim())) {
    Write-Host "  Los atajos locales ya existen en el perfil" -ForegroundColor Yellow
} else {
    # Una nueva definicion reemplaza tambien los atajos remotos de instalaciones anteriores.
    Add-Content -Path $PROFILE -Value $functions -Encoding UTF8
    Write-Host "  Atajos locales actualizados: temis, ldap y lazydirectory" -ForegroundColor Green
}

Write-Host ""
Write-Host "Recargando perfil..." -ForegroundColor Cyan
. $PROFILE

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  INSTALACION COMPLETADA" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Uso:" -ForegroundColor White
Write-Host "  temis 45601168" -ForegroundColor Cyan
Write-Host "  ldap usuario.ejemplo" -ForegroundColor Cyan
Write-Host "  ldap usuario.ius" -ForegroundColor Cyan
Write-Host "  ldap usuario -Interno" -ForegroundColor Cyan
Write-Host "  lazydirectory" -ForegroundColor Cyan
Write-Host "  temis 45601168 -WhatIf" -ForegroundColor Cyan
Write-Host "  ldap usuario.ejemplo -WhatIf" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTA: Cierra y abre de nuevo PowerShell si la recarga no funciona." -ForegroundColor Yellow
