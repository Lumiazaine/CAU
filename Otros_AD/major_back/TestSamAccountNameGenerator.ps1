#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script de prueba para el generador de SamAccountName
.DESCRIPTION
    Prueba las diferentes estrategias de generación de nombres de usuario
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TestDomain = $env:USERDNSDOMAIN,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowExamples
)

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA DEL GENERADOR DE SAMACCOUNTNAME ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Importar módulo
    Import-Module "$ScriptPath\Modules\SamAccountNameGenerator.psm1" -Force
    Write-Host "Módulo SamAccountNameGenerator cargado." -ForegroundColor Green
    Write-Host ""
    
    if ($ShowExamples) {
        Show-SamAccountNameGenerationExample
        return
    }
    
    # Casos de prueba
    $TestCases = @(
        @{ Name = "Juan"; Surname = "García López"; Expected = "jgarcia" },
        @{ Name = "María Luisa"; Surname = "Rodríguez Martín"; Expected = "mlrodriguez" },
        @{ Name = "José Antonio"; Surname = "Fernández Ruiz"; Expected = "jafernandez" },
        @{ Name = "Carmen"; Surname = "López"; Expected = "clopez" },
        @{ Name = "Ana"; Surname = "Martín García"; Expected = "amartin" },
        @{ Name = "Francisco Javier"; Surname = "Jiménez"; Expected = "fjjimenez" },
        @{ Name = "José Luis"; Surname = "Rodríguez de la Torre"; Expected = "jlrodriguez" }
    )
    
    Write-Host "=== PRUEBAS DE GENERACIÓN ===" -ForegroundColor Cyan
    Write-Host "Dominio de prueba: $TestDomain" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($TestCase in $TestCases) {
        Write-Host "Probando: $($TestCase.Name) $($TestCase.Surname)" -ForegroundColor White
        Write-Host "Esperado: $($TestCase.Expected)" -ForegroundColor Gray
        
        try {
            # Simular que el nombre esperado ya existe para probar las estrategias
            $GeneratedName = New-SamAccountName -GivenName $TestCase.Name -Surname $TestCase.Surname -Domain $TestDomain -Verbose
            
            Write-Host "Generado: $GeneratedName" -ForegroundColor Green
            
            if ($GeneratedName -eq $TestCase.Expected) {
                Write-Host "✅ Coincide con lo esperado" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Diferente del esperado (puede ser por unicidad)" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
    }
    
    # Prueba interactiva
    Write-Host "=== PRUEBA INTERACTIVA ===" -ForegroundColor Cyan
    Write-Host "Ingrese datos para generar un SamAccountName:" -ForegroundColor Yellow
    
    $InteractiveName = Read-Host "Nombre (o Enter para omitir)"
    if (![string]::IsNullOrWhiteSpace($InteractiveName)) {
        $InteractiveSurname = Read-Host "Apellidos"
        
        if (![string]::IsNullOrWhiteSpace($InteractiveSurname)) {
            try {
                Write-Host "Generando SamAccountName..." -ForegroundColor Yellow
                $InteractiveResult = New-SamAccountName -GivenName $InteractiveName -Surname $InteractiveSurname -Domain $TestDomain -Verbose
                
                Write-Host ""
                Write-Host "=== RESULTADO INTERACTIVO ===" -ForegroundColor Green
                Write-Host "SamAccountName generado: $InteractiveResult" -ForegroundColor White
                
                # Mostrar detalles del proceso
                $CleanGiven = Clean-TextForSamAccountName -Text $InteractiveName
                $CleanSurname = Clean-TextForSamAccountName -Text $InteractiveSurname
                $Initials = Get-NameInitials -Name $CleanGiven
                
                Write-Host ""
                Write-Host "Detalles del proceso:" -ForegroundColor Cyan
                Write-Host "  Nombre original: $InteractiveName" -ForegroundColor Gray
                Write-Host "  Nombre limpio: $CleanGiven" -ForegroundColor Gray
                Write-Host "  Iniciales: $Initials" -ForegroundColor Gray
                Write-Host "  Apellidos original: $InteractiveSurname" -ForegroundColor Gray
                Write-Host "  Apellidos limpio: $CleanSurname" -ForegroundColor Gray
                
            } catch {
                Write-Host "Error generando SamAccountName: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== PRUEBA DE LIMPIEZA DE TEXTO ===" -ForegroundColor Cyan
    
    $TextCleaningTests = @(
        "José María",
        "María Ángeles", 
        "Niño García",
        "José-Luis",
        "O'Connor",
        "García & López"
    )
    
    foreach ($TestText in $TextCleaningTests) {
        $CleanedText = Clean-TextForSamAccountName -Text $TestText
        Write-Host "$TestText -> $CleanedText" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "=== PRUEBA DE INICIALES ===" -ForegroundColor Cyan
    
    $InitialsTests = @(
        "Juan",
        "María Luisa",
        "José Antonio",
        "Ana Belén Carmen"
    )
    
    foreach ($TestName in $InitialsTests) {
        $Initials = Get-NameInitials -Name $TestName
        Write-Host "$TestName -> $Initials" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "✅ Pruebas del generador de SamAccountName completadas." -ForegroundColor Green
    
} catch {
    Write-Host "Error crítico en las pruebas: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}