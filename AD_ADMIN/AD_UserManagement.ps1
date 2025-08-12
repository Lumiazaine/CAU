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

$ErrorActionPreference = "Stop"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Import-Module "$ScriptPath\Modules\UOManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force
    Import-Module "$ScriptPath\Modules\DomainStructureManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\UserTemplateManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\TransferManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\NormalizedUserCreation.psm1" -Force
    Import-Module "$ScriptPath\Modules\CompoundUserCreation.psm1" -Force
    
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    
    $LogFile = Join-Path $LogPath "AD_UserManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$TimeStamp] [$Level] $Message"
        Write-Host $LogEntry
        Add-Content -Path $LogFile -Value $LogEntry
    }
    
    Write-Log "Iniciando procesamiento de altas de usuarios" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $WhatIf" "INFO"
    
    if (-not (Test-Path $CSVFile)) {
        throw "El archivo CSV no existe: $CSVFile"
    }
    
    Initialize-UOManager
    Write-Log "Módulo UO inicializado correctamente" "INFO"
    
    $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
    Write-Log "Importados $($Users.Count) registros del CSV" "INFO"
    
    $ProcessedCount = 0
    $ErrorCount = 0
    
    foreach ($User in $Users) {
        try {
            Write-Log "Procesando usuario: $($User.Nombre) $($User.Apellidos)" "INFO"
            
            switch ($User.TipoAlta.ToUpper()) {
                "NORMALIZADA" {
                    Write-Log "Procesando alta normalizada" "INFO"
                    New-NormalizedUser -UserData $User -WhatIf:$WhatIf
                }
                "TRASLADO" {
                    Write-Log "Procesando traslado" "INFO"
                    $TransferResult = Start-UserTransferProcess -UserData $User -WhatIf:$WhatIf
                    if (-not $TransferResult) {
                        Write-Log "Error en el proceso de traslado para $($User.Nombre) $($User.Apellidos)" "ERROR"
                        $ErrorCount++
                        continue
                    }
                }
                "COMPAGINADA" {
                    Write-Log "Procesando alta compaginada" "INFO"
                    Add-CompoundUserMembership -UserData $User -WhatIf:$WhatIf
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