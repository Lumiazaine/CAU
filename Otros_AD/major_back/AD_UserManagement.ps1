#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script principal para la gestión de altas de usuarios en Active Directory
.DESCRIPTION
    Sistema modular para gestionar altas normalizadas, traslados y compaginadas
    de usuarios en el dominio justicia.junta-andalucia.es
.AUTHOR
    CAU - Centro de Atención a Usuarios
.VERSION
    1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CSVFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_UserManagement"
)

$ErrorActionPreference = "Continue"

# Configurar logging antes de importar módulos
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogPath "AD_UserManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    Write-Host $LogEntry
    if ($LogFile -and (Test-Path (Split-Path $LogFile -Parent))) {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    }
}

try {
    Write-Log "Iniciando carga de módulos" "INFO"
    
    # Importar módulos con manejo de errores individual
    $ModulesToLoad = @(
        "UOManager.psm1",
        "PasswordManager.psm1", 
        "UserSearch.psm1",
        "CSVValidation.psm1",
        "SamAccountNameGenerator.psm1",
        "DomainStructureManager.psm1",
        "UserTemplateManager.psm1",
        "TransferManager.psm1"
    )
    
    foreach ($ModuleName in $ModulesToLoad) {
        $ModulePath = Join-Path "$ScriptPath\Modules" $ModuleName
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force
                Write-Log "Módulo cargado: $ModuleName" "INFO"
            } catch {
                Write-Log "Error cargando módulo $ModuleName`: $($_.Exception.Message)" "ERROR"
                # Continuar con otros módulos
            }
        } else {
            Write-Log "Módulo no encontrado: $ModulePath" "WARNING"
        }
    }
    
    # Intentar cargar módulos opcionales (que pueden no existir aún)
    $OptionalModules = @(
        "NormalizedUserCreation.psm1",
        "CompoundUserCreation.psm1"
    )
    
    foreach ($ModuleName in $OptionalModules) {
        $ModulePath = Join-Path "$ScriptPath\Modules" $ModuleName
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force
                Write-Log "Módulo opcional cargado: $ModuleName" "INFO"
            } catch {
                Write-Log "Error cargando módulo opcional $ModuleName`: $($_.Exception.Message)" "WARNING"
            }
        } else {
            Write-Log "Módulo opcional no encontrado: $ModuleName (esto es normal si no se ha implementado aún)" "INFO"
        }
    }
    
    Write-Log "Iniciando procesamiento de altas de usuarios" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $WhatIf" "INFO"
    
    # Validar archivo CSV antes de procesar
    Write-Log "Validando archivo CSV..." "INFO"
    $CSVValidation = Test-CSVFile -CSVPath $CSVFile -Delimiter ";"
    
    Show-ValidationSummary -ValidationSummary $CSVValidation
    
    if (-not $CSVValidation.IsValid) {
        Write-Log "El archivo CSV contiene errores. Proceso abortado." "ERROR"
        throw "Errores de validación en el archivo CSV. Corrija los errores e intente de nuevo."
    }
    
    if ($CSVValidation.Warnings.Count -gt 0) {
        Write-Log "Se encontraron $($CSVValidation.Warnings.Count) advertencias en el CSV" "WARNING"
    }
    
    # Inicializar módulo UOManager si está disponible
    if (Get-Command "Initialize-UOManager" -ErrorAction SilentlyContinue) {
        Initialize-UOManager
        Write-Log "Módulo UO inicializado correctamente" "INFO"
    } else {
        Write-Log "Función Initialize-UOManager no disponible - módulo UOManager no cargado" "WARNING"
    }
    
    $Users = $CSVValidation.ValidatedData
    Write-Log "Datos validados: $($Users.Count) registros válidos para procesar" "INFO"
    
    $ProcessedCount = 0
    $ErrorCount = 0
    
    foreach ($User in $Users) {
        try {
            Write-Log "Procesando usuario: $($User.Nombre) $($User.Apellidos)" "INFO"
            
            switch ($User.TipoAlta.ToUpper()) {
                "NORMALIZADA" {
                    Write-Log "Procesando alta normalizada" "INFO"
                    if (Get-Command "New-NormalizedUser" -ErrorAction SilentlyContinue) {
                        New-NormalizedUser -UserData $User -WhatIf:$WhatIf
                    } else {
                        Write-Log "Función New-NormalizedUser no disponible - funcionalidad no implementada aún" "WARNING"
                        $ErrorCount++
                        continue
                    }
                }
                "TRASLADO" {
                    Write-Log "Procesando traslado" "INFO"
                    if (Get-Command "Start-UserTransferProcess" -ErrorAction SilentlyContinue) {
                        $TransferResult = Start-UserTransferProcess -UserData $User -WhatIf:$WhatIf
                        if (-not $TransferResult) {
                            Write-Log "Error en el proceso de traslado para $($User.Nombre) $($User.Apellidos)" "ERROR"
                            $ErrorCount++
                            continue
                        }
                    } else {
                        Write-Log "Función Start-UserTransferProcess no disponible - módulo TransferManager no cargado" "ERROR"
                        $ErrorCount++
                        continue
                    }
                }
                "COMPAGINADA" {
                    Write-Log "Procesando alta compaginada" "INFO"
                    if (Get-Command "Add-CompoundUserMembership" -ErrorAction SilentlyContinue) {
                        Add-CompoundUserMembership -UserData $User -WhatIf:$WhatIf
                    } else {
                        Write-Log "Función Add-CompoundUserMembership no disponible - funcionalidad no implementada aún" "WARNING"
                        $ErrorCount++
                        continue
                    }
                }
                default {
                    Write-Log "Tipo de alta no válido: $($User.TipoAlta)" "WARNING"
                    $ErrorCount++
                    continue
                }
            }
            
            $ProcessedCount++
            Write-Log "Usuario procesado correctamente" "INFO"
            
        } catch {
            Write-Log "Error procesando usuario $($User.Nombre) $($User.Apellidos): $($_.Exception.Message)" "ERROR"
            $ErrorCount++
        }
        
        Write-Progress -Activity "Procesando usuarios" -Status "Procesado: $ProcessedCount, Errores: $ErrorCount" -PercentComplete (($ProcessedCount + $ErrorCount) / $Users.Count * 100)
    }
    
    Write-Log "Proceso completado. Usuarios procesados: $ProcessedCount, Errores: $ErrorCount" "INFO"
    
} catch {
    Write-Log "Error crítico en el script principal: $($_.Exception.Message)" "ERROR"
    throw
}