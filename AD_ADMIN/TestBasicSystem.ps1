#Requires -Version 5.1

<#
.SYNOPSIS
    Script de prueba básico para verificar el sistema sin ActiveDirectory
.DESCRIPTION
    Prueba los componentes básicos del sistema sin requerir conectividad AD
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TestCSV = "ejemplos_traslados.csv"
)

$ErrorActionPreference = "Continue"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== PRUEBA BÁSICA DEL SISTEMA ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Función de logging simple
    function Write-TestLog {
        param([string]$Message, [string]$Level = "INFO")
        $TimeStamp = Get-Date -Format "HH:mm:ss"
        $Color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
        Write-Host "[$TimeStamp] [$Level] $Message" -ForegroundColor $Color
    }
    
    Write-TestLog "Iniciando pruebas básicas" "INFO"
    
    # Probar módulos uno por uno
    $ModulesToTest = @(
        @{ Name = "CSVValidation"; Path = "Modules\CSVValidation.psm1"; Essential = $true },
        @{ Name = "SamAccountNameGenerator"; Path = "Modules\SamAccountNameGenerator.psm1"; Essential = $true },
        @{ Name = "PasswordManager"; Path = "Modules\PasswordManager.psm1"; Essential = $false },
        @{ Name = "DomainStructureManager"; Path = "Modules\DomainStructureManager.psm1"; Essential = $false },
        @{ Name = "UserTemplateManager"; Path = "Modules\UserTemplateManager.psm1"; Essential = $false },
        @{ Name = "TransferManager"; Path = "Modules\TransferManager.psm1"; Essential = $false }
    )
    
    $LoadedModules = @()
    $FailedModules = @()
    
    foreach ($Module in $ModulesToTest) {
        $ModulePath = Join-Path $ScriptPath $Module.Path
        
        Write-TestLog "Probando módulo: $($Module.Name)" "INFO"
        
        if (-not (Test-Path $ModulePath)) {
            Write-TestLog "Archivo no encontrado: $ModulePath" "WARNING"
            if ($Module.Essential) {
                $FailedModules += $Module.Name
            }
            continue
        }
        
        try {
            Import-Module $ModulePath -Force
            Write-TestLog "✅ Módulo $($Module.Name) cargado correctamente" "SUCCESS"
            $LoadedModules += $Module.Name
        } catch {
            Write-TestLog "❌ Error cargando $($Module.Name): $($_.Exception.Message)" "ERROR"
            if ($Module.Essential) {
                $FailedModules += $Module.Name
            }
        }
    }
    
    Write-Host ""
    Write-TestLog "=== RESUMEN DE CARGA DE MÓDULOS ===" "INFO"
    Write-TestLog "Módulos cargados: $($LoadedModules.Count)" "SUCCESS"
    Write-TestLog "Módulos fallidos: $($FailedModules.Count)" "$(if ($FailedModules.Count -gt 0) { 'ERROR' } else { 'SUCCESS' })"
    
    if ($LoadedModules.Count -gt 0) {
        Write-Host "Módulos cargados:" -ForegroundColor Green
        foreach ($Module in $LoadedModules) {
            Write-Host "  ✅ $Module" -ForegroundColor Green
        }
    }
    
    if ($FailedModules.Count -gt 0) {
        Write-Host "Módulos fallidos:" -ForegroundColor Red
        foreach ($Module in $FailedModules) {
            Write-Host "  ❌ $Module" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Probar validación de CSV si está disponible
    if ("CSVValidation" -in $LoadedModules) {
        Write-TestLog "=== PRUEBA DE VALIDACIÓN CSV ===" "INFO"
        
        $CSVPath = Join-Path $ScriptPath $TestCSV
        if (Test-Path $CSVPath) {
            try {
                $ValidationResult = Test-CSVFile -CSVPath $CSVPath
                Write-TestLog "✅ Validación CSV ejecutada" "SUCCESS"
                Write-TestLog "Filas válidas: $($ValidationResult.ValidRows)/$($ValidationResult.TotalRows)" "INFO"
                
                if ($ValidationResult.Errors.Count -gt 0) {
                    Write-TestLog "Errores encontrados: $($ValidationResult.Errors.Count)" "WARNING"
                }
                
                if ($ValidationResult.Warnings.Count -gt 0) {
                    Write-TestLog "Advertencias encontradas: $($ValidationResult.Warnings.Count)" "WARNING"
                }
                
            } catch {
                Write-TestLog "Error en validacion CSV: $($_.Exception.Message)" "ERROR"
            }
        } else {
            Write-TestLog "Archivo CSV no encontrado: $CSVPath" "WARNING"
        }
    }
    
    # Probar generador de SamAccountName si está disponible
    if ("SamAccountNameGenerator" -in $LoadedModules) {
        Write-TestLog "=== PRUEBA DE GENERACION SAMACCOUNTNAME ===" "INFO"
        
        $TestNames = @(
            @{ Name = "Juan"; Surname = "García López" },
            @{ Name = "María Luisa"; Surname = "Rodríguez Martín" }
        )
        
        foreach ($TestName in $TestNames) {
            try {
                # Usar un dominio de prueba ficticio
                $TestDomain = "test.local"
                
                Write-TestLog "Probando: $($TestName.Name) $($TestName.Surname)" "INFO"
                
                # Probar funciones de limpieza y generación de iniciales
                $CleanGiven = Clean-TextForSamAccountName -Text $TestName.Name
                $CleanSurname = Clean-TextForSamAccountName -Text $TestName.Surname
                $Initials = Get-NameInitials -Name $CleanGiven
                
                Write-TestLog "  Nombre limpio: $CleanGiven" "INFO"
                Write-TestLog "  Apellidos limpios: $CleanSurname" "INFO"
                Write-TestLog "  Iniciales: $Initials" "INFO"
                
                # Construir nombre básico
                $SurnamesParts = $CleanSurname -split '\s+' | Where-Object { $_ -ne '' }
                $FirstSurname = $SurnamesParts[0]
                $BasicName = $Initials + $FirstSurname
                
                Write-TestLog "  SamAccountName basico: $BasicName" "SUCCESS"
                
            } catch {
                Write-TestLog "Error probando generacion: $($_.Exception.Message)" "ERROR"
            }
        }
    }
    
    # Probar contraseña estándar si está disponible
    if (Get-Command "Get-StandardPassword" -ErrorAction SilentlyContinue) {
        Write-TestLog "=== PRUEBA DE CONTRASENA ESTANDAR ===" "INFO"
        
        try {
            $StandardPassword = Get-StandardPassword
            Write-TestLog "Contrasena estandar: $StandardPassword" "SUCCESS"
        } catch {
            Write-TestLog "Error obteniendo contrasena estandar: $($_.Exception.Message)" "ERROR"
        }
    }
    
    Write-Host ""
    Write-TestLog "=== RESULTADO FINAL ===" "INFO"
    
    if ($FailedModules.Count -eq 0) {
        Write-TestLog "Todos los modulos esenciales funcionan correctamente" "SUCCESS"
        Write-TestLog "El sistema esta listo para pruebas con Active Directory" "SUCCESS"
    } else {
        Write-TestLog "Hay modulos esenciales que fallan" "ERROR"
        Write-TestLog "Corrija los errores antes de usar el sistema completo" "ERROR"
    }
    
} catch {
    Write-Host "Error crítico en las pruebas: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalles: $($_.ScriptStackTrace)" -ForegroundColor Red
}