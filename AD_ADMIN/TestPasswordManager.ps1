#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script de prueba especifico para el modulo PasswordManager
#>

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DEL MODULO PASSWORDMANAGER ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Importando modulo PasswordManager..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force -Verbose
    
    Write-Host "Modulo importado. Verificando comandos disponibles..." -ForegroundColor Green
    $Commands = Get-Command -Module PasswordManager -ErrorAction SilentlyContinue
    
    if ($Commands) {
        Write-Host "Comandos exportados:" -ForegroundColor Green
        $Commands | ForEach-Object { 
            Write-Host "  - $($_.Name)" -ForegroundColor White
            Write-Host "    Tipo: $($_.CommandType)" -ForegroundColor Gray
        }
    } else {
        Write-Host "PROBLEMA: No se encontraron comandos exportados" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Probando Get-StandardPassword directamente..." -ForegroundColor Yellow
    
    try {
        $Password = Get-StandardPassword
        Write-Host "Contraseña generada: $Password" -ForegroundColor Green
    } catch {
        Write-Host "Error ejecutando Get-StandardPassword: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Probando Test-PasswordComplexity..." -ForegroundColor Yellow
    
    try {
        $TestPassword = "TestPass123!"
        $Result = Test-PasswordComplexity -Password $TestPassword
        Write-Host "Resultado para '$TestPassword':" -ForegroundColor Green
        Write-Host "  Complejo: $($Result.IsComplex)" -ForegroundColor White
        Write-Host "  Puntuacion: $($Result.Score)/5" -ForegroundColor White
    } catch {
        Write-Host "Error ejecutando Test-PasswordComplexity: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error critico: $($_.Exception.Message)" -ForegroundColor Red
}