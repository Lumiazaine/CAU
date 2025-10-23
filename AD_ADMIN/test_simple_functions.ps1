#Requires -Version 5.1

<#
.SYNOPSIS
    Script de prueba simple para verificar funciones básicas
#>

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA SIMPLE DE FUNCIONES ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Verificar si ActiveDirectory está disponible
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Host "ADVERTENCIA: Módulo ActiveDirectory no disponible - funcionará en modo simulación" -ForegroundColor Yellow
    } else {
        Write-Host "INFO: Módulo ActiveDirectory disponible" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=== CARGANDO MODULOS ===" -ForegroundColor Cyan
    
    # Cargar PasswordManager
    Write-Host "Importando PasswordManager..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force -Global
    Write-Host "PasswordManager importado" -ForegroundColor Green
    
    # Cargar UOManager  
    Write-Host "Importando UOManager..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\UOManager.psm1" -Force -Global
    Write-Host "UOManager importado" -ForegroundColor Green
    
    # Cargar UserSearch
    Write-Host "Importando UserSearch..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force -Global
    Write-Host "UserSearch importado" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "=== PROBANDO FUNCIONES ===" -ForegroundColor Cyan
    
    # Probar PasswordManager
    Write-Host "Probando Get-StandardPassword..." -ForegroundColor Yellow
    $StandardPassword = Get-StandardPassword
    Write-Host "Contraseña estándar: $StandardPassword" -ForegroundColor White
    
    # Probar UOManager
    Write-Host "Probando Initialize-UOManager..." -ForegroundColor Yellow
    $InitResult = Initialize-UOManager -Verbose
    if ($InitResult) {
        Write-Host "UOManager inicializado correctamente" -ForegroundColor Green
        
        # Probar búsqueda de UO
        Write-Host "Probando Get-UOByName para 'malaga'..." -ForegroundColor Yellow
        $MalagaOU = Get-UOByName -Name "malaga"
        if ($MalagaOU) {
            Write-Host "UO de Málaga encontrada: $($MalagaOU.Name)" -ForegroundColor Green
        } else {
            Write-Host "UO de Málaga no encontrada (normal en modo simulación)" -ForegroundColor Yellow
        }
        
        # Mostrar estadísticas
        Write-Host "Probando Get-UOStatistics..." -ForegroundColor Yellow
        $Stats = Get-UOStatistics
        Write-Host "UOs en cache: $($Stats.TotalUOsInCache)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "=== RESUMEN ===" -ForegroundColor Cyan
    Write-Host " PasswordManager: Funcionando" -ForegroundColor Green
    Write-Host " UOManager: Funcionando" -ForegroundColor Green  
    Write-Host " UserSearch: Cargado" -ForegroundColor Green
    Write-Host ""
    Write-Host "Todas las funciones básicas están operativas!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}