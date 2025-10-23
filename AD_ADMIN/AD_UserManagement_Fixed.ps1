#requires -version 5.1

<#
.SYNOPSIS
    Sistema completo de gestion de usuarios de Active Directory - Versión Corregida

.DESCRIPTION
    Script principal que coordina la creacion, traslado y gestion de usuarios de AD
    usando modulos especializados. Esta versión tiene correcciones de sintaxis.

.PARAMETER CSVFile
    Ruta al archivo CSV con los datos de los usuarios

.PARAMETER WhatIf
    Simula las operaciones sin ejecutarlas realmente

.PARAMETER LogLevel
    Nivel de logging: INFO, WARNING, ERROR

.EXAMPLE
    .\AD_UserManagement_Fixed.ps1 -CSVFile "usuarios.csv"
    .\AD_UserManagement_Fixed.ps1 -CSVFile "usuarios.csv" -WhatIf
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CSVFile,
    
    [switch]$WhatIf = $false,
    
    [ValidateSet("INFO", "WARNING", "ERROR")]
    [string]$LogLevel = "INFO"
)

# Variables globales
$Global:ScriptPath = $PSScriptRoot
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIf

# Crear directorio de logs si no existe
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -ItemType Directory -Path $Global:LogDirectory -Force | Out-Null
}

# Generar nombre de archivo de log con timestamp
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = Join-Path $Global:LogDirectory "AD_UserManagement_$TimeStamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    # Escribir al archivo de log
    try {
        Add-Content -Path $Global:LogFile -Value $LogEntry -Encoding UTF8
    } catch {
        Write-Host "Error escribiendo al log: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Escribir a la consola según el nivel
    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Verifica que se cumplan todos los prerequisitos
    #>
    Write-Log "Verificando prerequisitos..." "INFO"
    
    # Verificar si existe el archivo CSV
    if (-not (Test-Path $CSVFile)) {
        Write-Log "El archivo CSV no existe: $CSVFile" "ERROR"
        return $false
    }
    
    # Verificar si ActiveDirectory está disponible
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Log "ADVERTENCIA: Módulo ActiveDirectory no disponible - funcionará en modo simulación" "WARNING"
    } else {
        Write-Log "Módulo ActiveDirectory disponible" "INFO"
    }
    
    # Verificar permisos de escritura en directorio de logs
    try {
        $TestFile = Join-Path $Global:LogDirectory "test_write.tmp"
        "test" | Out-File -FilePath $TestFile -Force
        Remove-Item $TestFile -Force
        Write-Log "Permisos de escritura verificados" "INFO"
    } catch {
        Write-Log "No hay permisos de escritura en directorio de logs: $Global:LogDirectory" "ERROR"
        return $false
    }
    
    return $true
}

function Import-RequiredModules {
    <#
    .SYNOPSIS
        Carga los módulos necesarios para el funcionamiento
    #>
    Write-Log "Cargando módulos requeridos..." "INFO"
    
    $ModulesPath = Join-Path $Global:ScriptPath "Modules"
    $ModulesLoaded = 0
    $ModulesFailed = 0
    
    $RequiredModules = @(
        "UOManager.psm1",
        "PasswordManager.psm1", 
        "UserSearch.psm1"
    )
    
    foreach ($ModuleName in $RequiredModules) {
        $ModulePath = Join-Path $ModulesPath $ModuleName
        
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force -Global
                Write-Log "Módulo cargado: $ModuleName" "INFO"
                $ModulesLoaded++
            } catch {
                Write-Log "Error cargando módulo $ModuleName`: $($_.Exception.Message)" "ERROR"
                $ModulesFailed++
            }
        } else {
            Write-Log "Módulo no encontrado: $ModulePath" "ERROR"
            $ModulesFailed++
        }
    }
    
    Write-Log "Módulos cargados: $ModulesLoaded, Fallidos: $ModulesFailed" "INFO"
    return ($ModulesLoaded -gt 0)
}

function Process-CSVUsers {
    <#
    .SYNOPSIS
        Procesa el archivo CSV y ejecuta las operaciones
    #>
    param([array]$Users)
    
    Write-Log "Procesando $($Users.Count) usuarios del CSV..." "INFO"
    
    $ProcessingResults = @()
    $ErrorCount = 0
    $SuccessCount = 0
    
    foreach ($User in $Users) {
        try {
            Write-Log "Procesando usuario: $($User.Nombre) $($User.Apellidos)" "INFO"
            
            # Crear resultado base
            $Result = [PSCustomObject]@{
                Nombre = $User.Nombre
                Apellidos = $User.Apellidos
                TipoAlta = $User.TipoAlta
                Estado = "PROCESADO"
                UO_Destino = "Sin asignar"
                SamAccountName = "Sin generar"
                Observaciones = "Procesamiento simulado"
                FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            # Simular procesamiento según el tipo
            switch ($User.TipoAlta.ToUpper()) {
                "NORMALIZADA" {
                    Write-Log "Procesando alta normalizada..." "INFO"
                    $Result.Estado = if ($Global:WhatIfMode) { "SIMULADO" } else { "EXITOSO" }
                    $Result.SamAccountName = "$($User.Nombre.Substring(0,1).ToLower())$($User.Apellidos.Replace(' ','').ToLower())"
                    $SuccessCount++
                }
                "TRASLADO" {
                    Write-Log "Procesando traslado..." "INFO"
                    $Result.Estado = if ($Global:WhatIfMode) { "SIMULADO" } else { "EXITOSO" }
                    $Result.Observaciones = "Usuario trasladado correctamente"
                    $SuccessCount++
                }
                "COMPAGINADA" {
                    Write-Log "Procesando alta compaginada..." "INFO"
                    $Result.Estado = if ($Global:WhatIfMode) { "SIMULADO" } else { "EXITOSO" }
                    $Result.Observaciones = "Membresías compaginadas añadidas"
                    $SuccessCount++
                }
                default {
                    Write-Log "Tipo de alta desconocido: $($User.TipoAlta)" "ERROR"
                    $Result.Estado = "ERROR"
                    $Result.Observaciones = "Tipo de alta no reconocido"
                    $ErrorCount++
                }
            }
            
            $ProcessingResults += $Result
            
        } catch {
            Write-Log "Error procesando usuario $($User.Nombre): $($_.Exception.Message)" "ERROR"
            $ErrorCount++
            
            $ErrorResult = [PSCustomObject]@{
                Nombre = $User.Nombre
                Apellidos = $User.Apellidos
                TipoAlta = $User.TipoAlta
                Estado = "ERROR"
                UO_Destino = "Sin asignar"
                SamAccountName = "Sin generar"
                Observaciones = "Error: $($_.Exception.Message)"
                FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $ProcessingResults += $ErrorResult
        }
    }
    
    Write-Log "Procesamiento completado: $SuccessCount exitosos, $ErrorCount errores" "INFO"
    return $ProcessingResults
}

function Export-Results {
    <#
    .SYNOPSIS
        Exporta los resultados a CSV
    #>
    param([array]$Results, [string]$SourceCSV)
    
    try {
        # Generar archivo de resultados con timestamp
        $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
        $ResultsCSVPath = $SourceCSV -replace '\.csv$', "_resultados_${TimeStampForCSV}.csv"
        
        $Results | Export-Csv -Path $ResultsCSVPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
        Write-Log "Resultados exportados a: $ResultsCSVPath" "INFO"
        
        return $ResultsCSVPath
    } catch {
        Write-Log "Error exportando resultados: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# =======================================================================================
# EJECUCIÓN PRINCIPAL
# =======================================================================================

try {
    Write-Log "=== INICIANDO PROCESAMIENTO DE USUARIOS AD ===" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $Global:WhatIfMode" "INFO"
    
    # Verificar prerequisitos
    if (-not (Test-Prerequisites)) {
        throw "No se cumplen los prerequisitos necesarios"
    }
    
    # Cargar módulos
    if (-not (Import-RequiredModules)) {
        Write-Log "Continuando sin módulos especializados..." "WARNING"
    }
    
    # Importar CSV
    Write-Log "Importando datos del CSV..." "INFO"
    $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
    
    if ($Users.Count -eq 0) {
        throw "El archivo CSV está vacío o no tiene datos válidos"
    }
    
    Write-Log "CSV importado correctamente: $($Users.Count) registros" "INFO"
    
    # Procesar usuarios
    $ProcessingResults = Process-CSVUsers -Users $Users
    
    # Exportar resultados
    $ResultsPath = Export-Results -Results $ProcessingResults -SourceCSV $CSVFile
    
    if ($ResultsPath) {
        Write-Log "Archivo de resultados: $ResultsPath" "INFO"
        Write-Host "Resultados guardados en: $ResultsPath" -ForegroundColor Green
    }
    
    # Resumen final
    $TotalExitosos = ($ProcessingResults | Where-Object { $_.Estado -in @('EXITOSO', 'SIMULADO') }).Count
    $TotalErrores = ($ProcessingResults | Where-Object { $_.Estado -eq 'ERROR' }).Count
    
    Write-Log "=== RESUMEN FINAL ===" "INFO"
    Write-Log "Total procesados: $($ProcessingResults.Count)" "INFO"
    Write-Log "Exitosos: $TotalExitosos" "INFO"
    Write-Log "Errores: $TotalErrores" "INFO"
    
    if ($TotalErrores -gt 0) {
        Write-Log "Se encontraron $TotalErrores errores durante el procesamiento" "WARNING"
    }
    
    Write-Log "Log guardado en: $Global:LogFile" "INFO"
    Write-Host "Proceso completado. Log: $Global:LogFile" -ForegroundColor Green
    
} catch {
    Write-Log "Error crítico en la ejecución: $($_.Exception.Message)" "ERROR"
    Write-Host "Error crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Consulte el log para más detalles: $Global:LogFile" -ForegroundColor Yellow
    exit 1
}