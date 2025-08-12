#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script de prueba para verificar que los modulos se cargan correctamente
#>

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DE CARGA DE MODULOS ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Cargando UOManager..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\UOManager.psm1" -Force
    Write-Host "UOManager cargado exitosamente" -ForegroundColor Green
    
    Write-Host "Cargando PasswordManager..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force
    Write-Host "PasswordManager cargado exitosamente" -ForegroundColor Green
    
    Write-Host "Cargando UserSearch..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force
    Write-Host "UserSearch cargado exitosamente" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "=== PRUEBA DE FUNCIONES BASICAS ===" -ForegroundColor Cyan
    
    Write-Host "Probando Get-StandardPassword..." -ForegroundColor Yellow
    try {
        $StandardPassword = Get-StandardPassword
        Write-Host "Contraseña standard actual: $StandardPassword" -ForegroundColor White
    } catch {
        Write-Host "Error probando Get-StandardPassword: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Verificando comandos disponibles del modulo PasswordManager..." -ForegroundColor Yellow
        $Commands = Get-Command -Module PasswordManager
        if ($Commands) {
            Write-Host "Comandos disponibles:" -ForegroundColor Green
            $Commands | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        } else {
            Write-Host "No se encontraron comandos exportados del modulo PasswordManager" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Todos los modulos se cargaron correctamente!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}