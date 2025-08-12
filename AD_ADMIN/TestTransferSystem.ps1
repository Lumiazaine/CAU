#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script de prueba para el sistema de traslados de usuarios
.DESCRIPTION
    Permite probar el sistema de traslados con datos de ejemplo
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_TransferTest"
)

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DEL SISTEMA DE TRASLADOS ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Importar módulos necesarios
    Write-Host "Cargando módulos..." -ForegroundColor Yellow
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\DomainStructureManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\UserTemplateManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\TransferManager.psm1" -Force
    
    Write-Host "Módulos cargados correctamente." -ForegroundColor Green
    Write-Host ""
    
    # Obtener todos los dominios disponibles
    Write-Host "=== PRUEBA 1: OBTENER DOMINIOS DISPONIBLES ===" -ForegroundColor Cyan
    $AllDomains = Get-AllAvailableDomains
    
    Write-Host "Dominios encontrados:" -ForegroundColor Green
    foreach ($Domain in $AllDomains) {
        $Status = if ($Domain.Available) { "[DISPONIBLE]" } else { "[NO ACCESIBLE]" }
        $Color = if ($Domain.Available) { "Green" } else { "Red" }
        Write-Host "  $Status $($Domain.Name) ($($Domain.NetBIOSName))" -ForegroundColor $Color
    }
    Write-Host ""
    
    # Probar búsqueda de usuario por email
    Write-Host "=== PRUEBA 2: BUSQUEDA DE USUARIO POR EMAIL ===" -ForegroundColor Cyan
    $TestEmail = Read-Host "Ingrese un email de prueba para buscar (o Enter para usar 'test@example.com')"
    if ([string]::IsNullOrWhiteSpace($TestEmail)) {
        $TestEmail = "test@example.com"
    }
    
    Write-Host "Buscando usuario con email: $TestEmail" -ForegroundColor Yellow
    $FoundUser = Find-UserByEmail -Email $TestEmail
    
    if ($FoundUser) {
        Write-Host "Usuario encontrado:" -ForegroundColor Green
        Write-Host "  Nombre: $($FoundUser.DisplayName)" -ForegroundColor White
        Write-Host "  Usuario: $($FoundUser.SamAccountName)" -ForegroundColor Gray
        Write-Host "  Dominio: $($FoundUser.SourceDomain)" -ForegroundColor Magenta
        Write-Host "  Descripción: $($FoundUser.Description)" -ForegroundColor Yellow
    } else {
        Write-Host "No se encontró usuario con ese email." -ForegroundColor Red
    }
    Write-Host ""
    
    # Probar detección de provincias
    Write-Host "=== PRUEBA 3: DETECCIÓN DE PROVINCIAS ===" -ForegroundColor Cyan
    $TestDomains = @("malaga.justicia.junta-andalucia.es", "sevilla.justicia.junta-andalucia.es", "cadiz.justicia.junta-andalucia.es")
    $TestOffices = @("Málaga Centro", "Sevilla Norte", "Cádiz Juzgados")
    
    foreach ($TestDomain in $TestDomains) {
        $Province = Get-ProvinceFromDomain -Domain $TestDomain
        Write-Host "Dominio: $TestDomain -> Provincia: $Province" -ForegroundColor White
    }
    
    foreach ($TestOffice in $TestOffices) {
        $Province = Get-ProvinceFromOffice -Office $TestOffice
        Write-Host "Oficina: $TestOffice -> Provincia: $Province" -ForegroundColor White
    }
    Write-Host ""
    
    # Probar búsqueda de usuarios plantilla
    Write-Host "=== PRUEBA 4: BUSQUEDA DE USUARIOS PLANTILLA ===" -ForegroundColor Cyan
    $TestDescriptions = @("Tramitador", "Auxilio", "LAJ", "Juez")
    $TestTargetOffice = "Málaga Centro"
    
    foreach ($Domain in ($AllDomains | Where-Object { $_.Available })) {
        Write-Host "Probando en dominio: $($Domain.Name)" -ForegroundColor Magenta
        
        foreach ($Description in $TestDescriptions) {
            Write-Host "  Buscando plantilla con descripción: $Description" -ForegroundColor Yellow
            $TemplateUser = Find-TemplateUserByDescription -Description $Description -TargetOffice $TestTargetOffice -Domain $Domain.Name
            
            if ($TemplateUser) {
                Write-Host "    Encontrado: $($TemplateUser.DisplayName)" -ForegroundColor Green
            } else {
                Write-Host "    No encontrado" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
    # Probar proceso completo de traslado (simulado)
    if ($FoundUser) {
        Write-Host "=== PRUEBA 5: PROCESO COMPLETO DE TRASLADO (SIMULADO) ===" -ForegroundColor Cyan
        
        $TestUserData = [PSCustomObject]@{
            Nombre = "Test"
            Apellidos = "Usuario"
            Email = $TestEmail
            Telefono = "555-1234"
            Oficina = $TestTargetOffice
            TipoAlta = "TRASLADO"
        }
        
        Write-Host "Datos de prueba:" -ForegroundColor Yellow
        Write-Host "  Nombre: $($TestUserData.Nombre) $($TestUserData.Apellidos)" -ForegroundColor White
        Write-Host "  Email: $($TestUserData.Email)" -ForegroundColor Gray
        Write-Host "  Oficina destino: $($TestUserData.Oficina)" -ForegroundColor Gray
        Write-Host "  Modo WhatIf: $WhatIf" -ForegroundColor $(if ($WhatIf) { "Yellow" } else { "Red" })
        Write-Host ""
        
        if ($WhatIf) {
            Write-Host "Ejecutando proceso de traslado en modo simulación..." -ForegroundColor Yellow
            $TransferResult = Start-UserTransferProcess -UserData $TestUserData -WhatIf:$WhatIf
            
            if ($TransferResult) {
                Write-Host "Proceso de traslado completado exitosamente (simulación)." -ForegroundColor Green
            } else {
                Write-Host "Error en el proceso de traslado (simulación)." -ForegroundColor Red
            }
        } else {
            Write-Host "ADVERTENCIA: Modo WhatIf desactivado. El traslado se ejecutaría realmente." -ForegroundColor Red
            $Confirm = Read-Host "¿Desea continuar con el traslado real? (escriba 'SI' para confirmar)"
            
            if ($Confirm -eq "SI") {
                Write-Host "Ejecutando proceso de traslado real..." -ForegroundColor Red
                $TransferResult = Start-UserTransferProcess -UserData $TestUserData -WhatIf:$false
                
                if ($TransferResult) {
                    Write-Host "Proceso de traslado completado exitosamente." -ForegroundColor Green
                } else {
                    Write-Host "Error en el proceso de traslado." -ForegroundColor Red
                }
            } else {
                Write-Host "Operación cancelada." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "=== PRUEBA 5: OMITIDA ===" -ForegroundColor Yellow
        Write-Host "No se encontró usuario para probar el proceso completo." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=== PRUEBAS COMPLETADAS ===" -ForegroundColor Green
    Write-Host "Todas las pruebas del sistema de traslados han finalizado." -ForegroundColor White
    
} catch {
    Write-Host "Error crítico en las pruebas: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}