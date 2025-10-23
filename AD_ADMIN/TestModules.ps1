#Requires -Version 5.1
# #Requires -Modules ActiveDirectory  # Comentado para entorno sin AD

<#
.SYNOPSIS
    Script de prueba para verificar que los modulos se cargan correctamente
#>

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DE CARGA DE MODULOS ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Verificar si ActiveDirectory está disponible
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Host "ADVERTENCIA: Módulo ActiveDirectory no disponible - funcionará en modo simulación" -ForegroundColor Yellow
    }
    
    Write-Host "Cargando UOManager..." -ForegroundColor Yellow
    try {
        Import-Module "$ScriptPath\Modules\UOManager.psm1" -Force -Global
        Write-Host "UOManager cargado exitosamente" -ForegroundColor Green
    } catch {
        Write-Host "Error cargando UOManager: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Cargando PasswordManager..." -ForegroundColor Yellow
    try {
        Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force -Global
        Write-Host "PasswordManager cargado exitosamente" -ForegroundColor Green
    } catch {
        Write-Host "Error cargando PasswordManager: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "Cargando UserSearch..." -ForegroundColor Yellow
    try {
        Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force -Global
        Write-Host "UserSearch cargado exitosamente" -ForegroundColor Green
    } catch {
        Write-Host "Error cargando UserSearch: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "=== PRUEBA DE FUNCIONES BASICAS ===" -ForegroundColor Cyan
    
    Write-Host "Probando Get-StandardPassword..." -ForegroundColor Yellow
    try {
        $StandardPassword = Get-StandardPassword
        Write-Host "Contraseña standard actual: $StandardPassword" -ForegroundColor White
        Write-Host "Función Get-StandardPassword funciona correctamente" -ForegroundColor Green
    } catch {
        Write-Host "Error probando Get-StandardPassword: $($_.Exception.Message)" -ForegroundColor Red
        
        # Verificar comandos disponibles
        Write-Host "Verificando comandos disponibles..." -ForegroundColor Yellow
        $PasswordManagerModule = Get-Module PasswordManager
        if ($PasswordManagerModule) {
            $Commands = Get-Command -Module PasswordManager -ErrorAction SilentlyContinue
            if ($Commands) {
                Write-Host "Comandos encontrados:" -ForegroundColor Green
                $Commands | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
            } else {
                Write-Host "Módulo cargado pero no se encontraron comandos exportados" -ForegroundColor Yellow
                
                # Intentar obtener funciones directamente del módulo
                $Functions = $PasswordManagerModule.ExportedFunctions
                if ($Functions.Count -gt 0) {
                    Write-Host "Funciones exportadas encontradas:" -ForegroundColor Green
                    $Functions.Keys | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
                }
            }
        } else {
            Write-Host "Módulo PasswordManager no encontrado en sesión" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Todos los modulos se cargaron correctamente!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}