#Requires -Version 5.1

<#
.SYNOPSIS
    Script de prueba para el sistema de validación de CSV
.DESCRIPTION
    Prueba las validaciones de los nuevos campos del CSV
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TestCSVFile = "ejemplos_traslados.csv"
)

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DEL SISTEMA DE VALIDACIÓN CSV ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Importar módulo
    Import-Module "$ScriptPath\Modules\CSVValidation.psm1" -Force
    Write-Host "Módulo CSVValidation cargado." -ForegroundColor Green
    Write-Host ""
    
    # Probar archivo CSV existente
    $CSVPath = Join-Path $ScriptPath $TestCSVFile
    
    if (Test-Path $CSVPath) {
        Write-Host "=== VALIDANDO ARCHIVO EXISTENTE ===" -ForegroundColor Cyan
        Write-Host "Archivo: $CSVPath" -ForegroundColor Yellow
        
        $ValidationResult = Test-CSVFile -CSVPath $CSVPath
        Show-ValidationSummary -ValidationSummary $ValidationResult
        
        if ($ValidationResult.IsValid) {
            Write-Host "Datos validados disponibles para procesamiento:" -ForegroundColor Green
            foreach ($ValidUser in $ValidationResult.ValidatedData) {
                Write-Host "  - $($ValidUser.TipoAlta): $($ValidUser.Nombre) $($ValidUser.Apellidos) -> $($ValidUser.Oficina)" -ForegroundColor White
            }
        }
    } else {
        Write-Host "Archivo $CSVPath no encontrado. Creando casos de prueba..." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "=== PRUEBAS DE VALIDACIÓN INDIVIDUAL ===" -ForegroundColor Cyan
    
    # Casos de prueba individuales
    $TestCases = @(
        @{
            Name = "Caso válido - TRASLADO"
            Data = [PSCustomObject]@{
                TipoAlta = "TRASLADO"
                Nombre = "Juan"
                Apellidos = "García López"
                Email = "juan.garcia@juntadeandalucia.es"
                Telefono = "12345678A"
                Oficina = "Sevilla Centro"
                Descripcion = "Tramitador"
                AD = "jgarcia"
            }
        },
        @{
            Name = "Caso válido - NORMALIZADA"
            Data = [PSCustomObject]@{
                TipoAlta = "NORMALIZADA"
                Nombre = "María Luisa"
                Apellidos = "Martín García"
                Email = ""
                Telefono = "87654321B"
                Oficina = "Málaga Norte"
                Descripcion = "LAJ"
                AD = ""
            }
        },
        @{
            Name = "Error - TipoAlta vacío"
            Data = [PSCustomObject]@{
                TipoAlta = ""
                Nombre = "Carmen"
                Apellidos = "López"
                Email = "carmen@test.com"
                Telefono = "555-1234"
                Oficina = "Granada"
                Descripcion = "Juez"
                AD = ""
            }
        },
        @{
            Name = "Error - TipoAlta inválido"
            Data = [PSCustomObject]@{
                TipoAlta = "INVALIDO"
                Nombre = "Pedro"
                Apellidos = "Ruiz"
                Email = "pedro@test.com"
                Telefono = "555-5678"
                Oficina = "Cádiz"
                Descripcion = "Auxilio"
                AD = ""
            }
        },
        @{
            Name = "Error - Campos obligatorios vacíos"
            Data = [PSCustomObject]@{
                TipoAlta = "NORMALIZADA"
                Nombre = ""
                Apellidos = ""
                Email = "test@test.com"
                Telefono = "555-9999"
                Oficina = ""
                Descripcion = ""
                AD = ""
            }
        },
        @{
            Name = "Error - TRASLADO sin Email ni AD"
            Data = [PSCustomObject]@{
                TipoAlta = "TRASLADO"
                Nombre = "Ana"
                Apellidos = "Fernández"
                Email = ""
                Telefono = "555-0000"
                Oficina = "Huelva"
                Descripcion = "Gestor"
                AD = ""
            }
        },
        @{
            Name = "Advertencia - Email mal formateado"
            Data = [PSCustomObject]@{
                TipoAlta = "NORMALIZADA"
                Nombre = "Luis"
                Apellidos = "Moreno"
                Email = "email-incorrecto"
                Telefono = "555-1111"
                Oficina = "Jaén"
                Descripcion = "Letrado"
                AD = ""
            }
        },
        @{
            Name = "Advertencia - Descripción no estándar"
            Data = [PSCustomObject]@{
                TipoAlta = "NORMALIZADA"
                Nombre = "Rosa"
                Apellidos = "Jiménez"
                Email = "rosa@test.com"
                Telefono = "555-2222"
                Oficina = "Almería"
                Descripcion = "Puesto Personalizado"
                AD = ""
            }
        }
    )
    
    foreach ($TestCase in $TestCases) {
        Write-Host "`nProbando: $($TestCase.Name)" -ForegroundColor Yellow
        
        $ValidationResult = Test-CSVUserData -UserData $TestCase.Data
        
        Write-Host "  Estado: $(if ($ValidationResult.IsValid) { 'VÁLIDO' } else { 'INVÁLIDO' })" -ForegroundColor $(if ($ValidationResult.IsValid) { 'Green' } else { 'Red' })
        
        if ($ValidationResult.Errors.Count -gt 0) {
            Write-Host "  Errores:" -ForegroundColor Red
            foreach ($Error in $ValidationResult.Errors) {
                Write-Host "    ❌ $Error" -ForegroundColor Red
            }
        }
        
        if ($ValidationResult.Warnings.Count -gt 0) {
            Write-Host "  Advertencias:" -ForegroundColor Yellow
            foreach ($Warning in $ValidationResult.Warnings) {
                Write-Host "    ⚠️  $Warning" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== PRUEBA DE VALIDACIÓN DE CSV COMPLETO ===" -ForegroundColor Cyan
    
    # Crear un CSV de prueba con errores
    $TestCSVContent = @"
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
TRASLADO;Juan;García López;juan.garcia@test.com;12345678A;Sevilla Centro;Tramitador;jgarcia
NORMALIZADA;María;;maria@test.com;87654321B;Málaga Norte;LAJ;
INVALIDO;Pedro;Ruiz;pedro@test.com;555-1234;Cádiz;Auxilio;
;Carmen;López;carmen@test.com;555-5678;Granada;Juez;
TRASLADO;;;;555-9999;;;
"@
    
    $TestCSVPath = Join-Path $ScriptPath "test_validation.csv"
    $TestCSVContent | Out-File -FilePath $TestCSVPath -Encoding UTF8
    
    Write-Host "Archivo de prueba creado: $TestCSVPath" -ForegroundColor Yellow
    
    $FullCSVValidation = Test-CSVFile -CSVPath $TestCSVPath
    Show-ValidationSummary -ValidationSummary $FullCSVValidation
    
    # Limpiar archivo de prueba
    if (Test-Path $TestCSVPath) {
        Remove-Item $TestCSVPath -Force
        Write-Host "Archivo de prueba eliminado." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "✅ Pruebas de validación CSV completadas." -ForegroundColor Green
    
} catch {
    Write-Host "Error crítico en las pruebas: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}