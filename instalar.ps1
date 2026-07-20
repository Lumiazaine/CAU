param([switch]$WhatIf)

$functions = @'

Set-Location $env:USERPROFILE

# Temis - Cambio de contrasena
function temis ([string]$TemisUser) {
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Lumiazaine/CAU/refs/heads/main/Temis/cambiar_password_temis.ps1"))) -TemisUser $TemisUser
}

# Directorio Correo - Cambio de contrasena
function ldap ([string]$correo) {
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Lumiazaine/CAU/refs/heads/main/Directorio%20correo/cambiar_password_correo.ps1"))) -TargetUser $correo
}
'@

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  INSTALACION - Scripts CAU" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF] No se realizaran cambios" -ForegroundColor Yellow
    Write-Host "[WHATIF] Perfil de destino: $PROFILE" -ForegroundColor Yellow
    Write-Host "[WHATIF] Funciones a anhadir: temis, ldap" -ForegroundColor Yellow
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
if ($content -match 'function temis\b' -and $content -match 'function ldap\b') {
    Write-Host "  Las funciones 'temis' y 'ldap' ya existen en el perfil" -ForegroundColor Yellow
} else {
    Add-Content -Path $PROFILE -Value $functions -Encoding UTF8
    Write-Host "  Funciones 'temis' y 'ldap' anh adidas al perfil" -ForegroundColor Green
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
Write-Host "  ldap mangeles.mas" -ForegroundColor Cyan
Write-Host "  ldap usuario.ius" -ForegroundColor Cyan
Write-Host "  ldap usuario -Interno" -ForegroundColor Cyan
Write-Host "  temis 45601168 -WhatIf" -ForegroundColor Cyan
Write-Host "  ldap mangeles.mas -WhatIf" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTA: Cierra y abre de nuevo PowerShell si la recarga no funciona." -ForegroundColor Yellow
