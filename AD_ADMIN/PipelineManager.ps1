#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
Gestor principal del pipeline resiliente de AD_ADMIN con capacidades enterprise-grade.

.DESCRIPTION
Script principal que orquesta el pipeline completo de procesamiento CSV con:
- Pipeline de procesamiento CSV resiliente
- Sistema de rollback automático
- Validación pre-procesamiento exhaustiva  
- Logging estructurado y trazabilidad
- Dashboard de monitorización en tiempo real
- Métricas de rendimiento y operacional
- Integración con sistemas existentes

.PARAMETER CSVPath
Ruta del archivo CSV a procesar

.PARAMETER Force
Fuerza la ejecución ignorando advertencias de validación

.PARAMETER WhatIf
Ejecuta simulación completa sin realizar cambios

.PARAMETER MaxParallelOperations
Número máximo de operaciones en paralelo (default: 5)

.PARAMETER EnableLogging
Habilita logging estructurado (default: true)

.PARAMETER EnableMetrics
Habilita recolección de métricas (default: true)

.PARAMETER EnableAlerts
Habilita sistema de alertas (default: true)

.EXAMPLE
.\PipelineManager.ps1 -CSVPath "C:\Data\usuarios.csv" -WhatIf
Ejecuta simulación completa del procesamiento

.EXAMPLE
.\PipelineManager.ps1 -CSVPath "C:\Data\usuarios.csv" -Force -MaxParallelOperations 10
Procesa archivo forzando ejecución con 10 operaciones paralelas

.AUTHOR
Sistema AD_ADMIN - Pipeline Manager v1.0

.DATE
2025-08-28
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if (!(Test-Path $_)) {
            throw "CSV file not found: $_"
        }
        if ($_ -notlike "*.csv") {
            throw "File must be a CSV: $_"
        }
        return $true
    })]
    [string]$CSVPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$MaxParallelOperations = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableLogging = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableMetrics = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableAlerts = $true,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 100)]
    [int]$MinimumValidationScore = 80,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateDetailedReport = $false
)

# Variables globales del script
$Global:ScriptStartTime = Get-Date
$Global:PipelineManagerVersion = "1.0"
$Global:ExecutionId = [System.Guid]::NewGuid().ToString()

# Configuración de logging
$LogPath = "C:\Logs\AD_ADMIN\PipelineManager"
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

#region Importación de Módulos

try {
    Write-Host "🔧 Cargando módulos del pipeline..." -ForegroundColor Cyan
    
    $ModulesPath = Join-Path $PSScriptRoot "Modules"
    
    # Cargar módulos en orden de dependencia
    $ModuleLoadOrder = @(
        "StructuredLogging.psm1",
        "PreProcessingValidation.psm1", 
        "AutomaticRollback.psm1",
        "ResilientCSVPipeline.psm1"
    )
    
    $LoadedModules = @()
    
    foreach ($ModuleName in $ModuleLoadOrder) {
        $ModulePath = Join-Path $ModulesPath $ModuleName
        
        if (Test-Path $ModulePath) {
            Import-Module $ModulePath -Force -ErrorAction Stop
            $LoadedModules += $ModuleName
            Write-Host "   ✓ $ModuleName" -ForegroundColor Green
        } else {
            Write-Warning "Módulo no encontrado: $ModulePath"
        }
    }
    
    Write-Host "📦 Módulos cargados: $($LoadedModules.Count)/$($ModuleLoadOrder.Count)" -ForegroundColor Green
    
} catch {
    Write-Error "Error crítico cargando módulos: $($_.Exception.Message)"
    exit 1
}

#endregion

#region Inicialización del Sistema

function Initialize-PipelineManager {
    <#
    .SYNOPSIS
    Inicializa todos los sistemas del pipeline manager
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "`n🚀 INICIANDO PIPELINE MANAGER v$Global:PipelineManagerVersion" -ForegroundColor Yellow
        Write-Host "Execution ID: $Global:ExecutionId" -ForegroundColor Cyan
        Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
        Write-Host "CSV Path: $CSVPath" -ForegroundColor Cyan
        Write-Host "Mode: $(if($WhatIf) { 'SIMULATION' } else { 'PRODUCTION' })" -ForegroundColor $(if($WhatIf) { 'Yellow' } else { 'Green' })
        
        # Inicializar logging estructurado
        if ($EnableLogging) {
            Write-Host "`n📝 Inicializando sistema de logging..." -ForegroundColor Cyan
            $loggingConfig = @{
                BasePath = "C:\Logs\AD_ADMIN"
                EnableRealTimeAlerts = $EnableAlerts
                EnableMetrics = $EnableMetrics
                CorrelationEnabled = $true
            }
            
            $loggingInit = Initialize-StructuredLogging -Configuration $loggingConfig
            if ($loggingInit) {
                Write-Host "   ✓ Logging estructurado iniciado" -ForegroundColor Green
                
                # Crear logger para el pipeline manager
                $Global:Logger = New-StructuredLogger -Component "PipelineManager" -CorrelationId $Global:ExecutionId
                $Global:Logger.AddContext("CSVPath", $CSVPath)
                $Global:Logger.AddContext("ExecutionMode", $(if($WhatIf) { "SIMULATION" } else { "PRODUCTION" }))
                $Global:Logger.AddContext("Version", $Global:PipelineManagerVersion)
                
                $Global:Logger.Info([LogCategory]::System, "Pipeline Manager initialized", @{
                    Version = $Global:PipelineManagerVersion
                    ExecutionId = $Global:ExecutionId
                    Parameters = $PSBoundParameters
                })
            } else {
                Write-Warning "No se pudo inicializar logging estructurado"
            }
        }
        
        # Inicializar colector de métricas
        if ($EnableMetrics) {
            Write-Host "`n📊 Inicializando colector de métricas..." -ForegroundColor Cyan
            $Global:MetricsCollector = New-MetricsCollector
            $Global:MetricsCollector.RecordCounter("pipeline.manager.started", @{
                version = $Global:PipelineManagerVersion
                execution_id = $Global:ExecutionId
            })
            Write-Host "   ✓ Métricas iniciadas" -ForegroundColor Green
        }
        
        # Verificar dependencias del sistema
        Test-SystemDependencies
        
        # Mostrar banner del sistema
        Show-SystemBanner
        
        return $true
        
    } catch {
        Write-Error "Error crítico inicializando Pipeline Manager: $($_.Exception.Message)"
        if ($Global:Logger) {
            $Global:Logger.Critical([LogCategory]::System, "Pipeline Manager initialization failed", @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            })
        }
        return $false
    }
}

function Test-SystemDependencies {
    <#
    .SYNOPSIS
    Verifica dependencias críticas del sistema
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`n🔍 Verificando dependencias del sistema..." -ForegroundColor Cyan
    
    $Dependencies = @(
        @{ Name = "Active Directory Module"; Test = { Get-Module ActiveDirectory -ListAvailable } },
        @{ Name = "CSV File Access"; Test = { Test-Path $CSVPath } },
        @{ Name = "Log Directory Write"; Test = { Test-Path $LogPath -PathType Container } },
        @{ Name = "PowerShell Version"; Test = { $PSVersionTable.PSVersion.Major -ge 5 } }
    )
    
    $PassedDependencies = 0
    
    foreach ($Dependency in $Dependencies) {
        try {
            $Result = & $Dependency.Test
            if ($Result) {
                Write-Host "   ✓ $($Dependency.Name)" -ForegroundColor Green
                $PassedDependencies++
            } else {
                Write-Host "   ✗ $($Dependency.Name)" -ForegroundColor Red
            }
        } catch {
            Write-Host "   ✗ $($Dependency.Name) - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if ($PassedDependencies -eq $Dependencies.Count) {
        Write-Host "   🎯 Todas las dependencias satisfechas ($PassedDependencies/$($Dependencies.Count))" -ForegroundColor Green
        if ($Global:Logger) {
            $Global:Logger.Info([LogCategory]::System, "All system dependencies satisfied", @{
                TotalDependencies = $Dependencies.Count
                PassedDependencies = $PassedDependencies
            })
        }
    } else {
        $Message = "Dependencias faltantes: $($Dependencies.Count - $PassedDependencies)/$($Dependencies.Count)"
        Write-Warning $Message
        if ($Global:Logger) {
            $Global:Logger.Warning([LogCategory]::System, $Message, @{
                TotalDependencies = $Dependencies.Count
                PassedDependencies = $PassedDependencies
            })
        }
        
        if (-not $Force) {
            throw "Dependencias críticas no satisfechas. Use -Force para continuar."
        }
    }
}

function Show-SystemBanner {
    <#
    .SYNOPSIS
    Muestra banner informativo del sistema
    #>
    [CmdletBinding()]
    param()
    
    $Banner = @"

╔════════════════════════════════════════════════════════════╗
║                    AD_ADMIN PIPELINE v$Global:PipelineManagerVersion                     ║
║                    Resilient CSV Processing                ║
╠════════════════════════════════════════════════════════════╣
║  🔧 Sistema de Rollback Automático                        ║
║  📝 Logging Estructurado y Trazabilidad                   ║
║  ✅ Validación Pre-procesamiento (20+ reglas)             ║
║  📊 Métricas y Monitorización en Tiempo Real              ║
║  🚨 Sistema de Alertas Automáticas                        ║
║  ⚡ Procesamiento Paralelo Optimizado                     ║
╚════════════════════════════════════════════════════════════╝

"@

    Write-Host $Banner -ForegroundColor Cyan
}

#endregion

#region Función Principal de Ejecución

function Invoke-PipelineExecution {
    <#
    .SYNOPSIS
    Ejecuta el pipeline completo de procesamiento
    #>
    [CmdletBinding()]
    param()
    
    $ExecutionResult = @{
        Success = $false
        TotalTime = 0
        PipelineResult = $null
        ValidationResult = $null
        Errors = @()
        Warnings = @()
        Metrics = @{}
    }
    
    $ExecutionStartTime = Get-Date
    
    try {
        if ($Global:Logger) {
            $Global:Logger.Info([LogCategory]::Business, "Starting pipeline execution", @{
                CSVPath = $CSVPath
                WhatIf = $WhatIf.IsPresent
                Force = $Force.IsPresent
                MaxParallelOperations = $MaxParallelOperations
            })
        }
        
        # FASE 1: Validación Pre-procesamiento
        Write-Host "`n🔍 FASE 1: VALIDACIÓN PRE-PROCESAMIENTO" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════" -ForegroundColor Yellow
        
        if ($Global:MetricsCollector) {
            $validationTimer = [System.Diagnostics.Stopwatch]::StartNew()
        }
        
        $ValidationResult = Invoke-PreProcessingValidation -CSVPath $CSVPath -DetailedReport:$GenerateDetailedReport -MinimumScore $MinimumValidationScore
        $ExecutionResult.ValidationResult = $ValidationResult
        
        if ($Global:MetricsCollector) {
            $validationTimer.Stop()
            $Global:MetricsCollector.RecordTimer("validation.duration", $validationTimer.Elapsed, @{
                csv_path = $CSVPath
                result = $ValidationResult.Success
            })
        }
        
        if (-not $ValidationResult.Success) {
            $ErrorMsg = "Pre-processing validation failed"
            $ExecutionResult.Errors += $ErrorMsg
            
            if ($Global:Logger) {
                $Global:Logger.Error([LogCategory]::Business, $ErrorMsg, @{
                    ValidationErrors = $ValidationResult.Errors
                    BatchScore = $ValidationResult.BatchValidation.BatchScore
                    RecommendedAction = $ValidationResult.RecommendedAction
                })
            }
            
            if (-not $Force) {
                Write-Host "❌ VALIDACIÓN FALLIDA - Detener ejecución" -ForegroundColor Red
                Write-Host "   Recomendación: $($ValidationResult.RecommendedAction)" -ForegroundColor Yellow
                Write-Host "   Use -Force para continuar ignorando validaciones" -ForegroundColor Yellow
                return $ExecutionResult
            } else {
                Write-Host "⚠️  VALIDACIÓN FALLIDA - Continuando con -Force" -ForegroundColor Yellow
                $ExecutionResult.Warnings += "Validation failed but continuing due to -Force parameter"
            }
        } else {
            Write-Host "✅ VALIDACIÓN EXITOSA" -ForegroundColor Green
            Write-Host "   Score del batch: $($ValidationResult.BatchValidation.BatchScore)" -ForegroundColor Green
            Write-Host "   Registros válidos: $($ValidationResult.BatchValidation.ValidRecords)/$($ValidationResult.BatchValidation.TotalRecords)" -ForegroundColor Green
        }
        
        # FASE 2: Procesamiento del Pipeline
        Write-Host "`n⚙️  FASE 2: PROCESAMIENTO DEL PIPELINE" -ForegroundColor Yellow
        Write-Host "════════════════════════════════════════" -ForegroundColor Yellow
        
        if ($Global:MetricsCollector) {
            $pipelineTimer = [System.Diagnostics.Stopwatch]::StartNew()
        }
        
        $PipelineParams = @{
            CSVPath = $CSVPath
            Force = $Force
            WhatIf = $WhatIf
            MaxParallelOperations = $MaxParallelOperations
        }
        
        $PipelineResult = Start-ResilientCSVPipeline @PipelineParams
        $ExecutionResult.PipelineResult = $PipelineResult
        
        if ($Global:MetricsCollector) {
            $pipelineTimer.Stop()
            $Global:MetricsCollector.RecordTimer("pipeline.duration", $pipelineTimer.Elapsed, @{
                csv_path = $CSVPath
                result = $PipelineResult.Success
                total_operations = $PipelineResult.TotalOperations
            })
            
            # Métricas adicionales del pipeline
            $Global:MetricsCollector.RecordGauge("pipeline.operations.total", $PipelineResult.TotalOperations)
            $Global:MetricsCollector.RecordGauge("pipeline.operations.successful", $PipelineResult.SuccessfulOperations)
            $Global:MetricsCollector.RecordGauge("pipeline.operations.failed", $PipelineResult.FailedOperations)
            $Global:MetricsCollector.RecordGauge("pipeline.operations.rolled_back", $PipelineResult.RolledBackOperations)
        }
        
        if ($PipelineResult.Success) {
            Write-Host "✅ PIPELINE COMPLETADO EXITOSAMENTE" -ForegroundColor Green
            Write-Host "   Operaciones exitosas: $($PipelineResult.SuccessfulOperations)" -ForegroundColor Green
            Write-Host "   Operaciones fallidas: $($PipelineResult.FailedOperations)" -ForegroundColor $(if($PipelineResult.FailedOperations -eq 0) { 'Green' } else { 'Yellow' })"
            Write-Host "   Rollbacks ejecutados: $($PipelineResult.RolledBackOperations)" -ForegroundColor $(if($PipelineResult.RolledBackOperations -eq 0) { 'Green' } else { 'Yellow' })"
            Write-Host "   Tiempo de ejecución: $($PipelineResult.ExecutionTimeMinutes) minutos" -ForegroundColor Green
            
            if ($Global:Logger) {
                $Global:Logger.Info([LogCategory]::Business, "Pipeline completed successfully", @{
                    TotalOperations = $PipelineResult.TotalOperations
                    SuccessfulOperations = $PipelineResult.SuccessfulOperations
                    FailedOperations = $PipelineResult.FailedOperations
                    RolledBackOperations = $PipelineResult.RolledBackOperations
                    ExecutionTimeMinutes = $PipelineResult.ExecutionTimeMinutes
                })
            }
            
            $ExecutionResult.Success = $true
        } else {
            Write-Host "❌ PIPELINE FALLÓ" -ForegroundColor Red
            Write-Host "   Errores: $($PipelineResult.Errors.Count)" -ForegroundColor Red
            Write-Host "   Advertencias: $($PipelineResult.Warnings.Count)" -ForegroundColor Yellow
            
            $ExecutionResult.Errors += $PipelineResult.Errors
            $ExecutionResult.Warnings += $PipelineResult.Warnings
            
            if ($Global:Logger) {
                $Global:Logger.Error([LogCategory]::Business, "Pipeline execution failed", @{
                    Errors = $PipelineResult.Errors
                    Warnings = $PipelineResult.Warnings
                    TotalOperations = $PipelineResult.TotalOperations
                    SuccessfulOperations = $PipelineResult.SuccessfulOperations
                })
            }
        }
        
    } catch {
        $CriticalError = "Critical error during pipeline execution: $($_.Exception.Message)"
        $ExecutionResult.Errors += $CriticalError
        
        Write-Host "💥 ERROR CRÍTICO EN PIPELINE" -ForegroundColor Red
        Write-Host "   $CriticalError" -ForegroundColor Red
        
        if ($Global:Logger) {
            $Global:Logger.Critical([LogCategory]::System, $CriticalError, @{
                Exception = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
                CSVPath = $CSVPath
            })
        }
        
        if ($Global:MetricsCollector) {
            $Global:MetricsCollector.RecordCounter("pipeline.critical_errors", @{
                csv_path = $CSVPath
                error_message = $_.Exception.Message
            })
        }
    }
    finally {
        $ExecutionEndTime = Get-Date
        $ExecutionResult.TotalTime = ($ExecutionEndTime - $ExecutionStartTime).TotalMinutes
        
        # FASE 3: Finalización y Reporte
        Write-Host "`n📊 FASE 3: FINALIZACIÓN Y REPORTE" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════" -ForegroundColor Yellow
        
        Show-ExecutionSummary -ExecutionResult $ExecutionResult
        
        # Flush final de logs y métricas
        if ($Global:MetricsCollector) {
            $Global:MetricsCollector.RecordTimer("pipeline.total_execution", [TimeSpan]::FromMinutes($ExecutionResult.TotalTime))
            $Global:MetricsCollector.FlushMetrics()
        }
        
        if ($EnableLogging) {
            if ($Global:Logger) {
                $Global:Logger.Info([LogCategory]::System, "Pipeline execution completed", @{
                    Success = $ExecutionResult.Success
                    TotalTimeMinutes = $ExecutionResult.TotalTime
                    ErrorCount = $ExecutionResult.Errors.Count
                    WarningCount = $ExecutionResult.Warnings.Count
                })
            }
            
            # Flush final de logs
            Invoke-LogFlush -Force | Out-Null
        }
    }
    
    return $ExecutionResult
}

function Show-ExecutionSummary {
    <#
    .SYNOPSIS
    Muestra resumen final de la ejecución
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ExecutionResult
    )
    
    $SummaryColor = if ($ExecutionResult.Success) { "Green" } else { "Red" }
    $StatusIcon = if ($ExecutionResult.Success) { "✅" } else { "❌" }
    $StatusText = if ($ExecutionResult.Success) { "ÉXITO" } else { "FALLO" }
    
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor $SummaryColor
    Write-Host "║                    RESUMEN DE EJECUCIÓN                   ║" -ForegroundColor $SummaryColor
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor $SummaryColor
    Write-Host "║ Estado Final: $StatusIcon $StatusText" -ForegroundColor $SummaryColor -NoNewline
    
    # Rellenar espacios para alineación
    $padding = 49 - "Estado Final: $StatusIcon $StatusText".Length
    Write-Host (" " * $padding) -NoNewline
    Write-Host "║" -ForegroundColor $SummaryColor
    
    Write-Host "║ Tiempo Total: $([math]::Round($ExecutionResult.TotalTime, 2)) minutos" -ForegroundColor $SummaryColor -NoNewline
    $padding = 56 - "Tiempo Total: $([math]::Round($ExecutionResult.TotalTime, 2)) minutos".Length
    Write-Host (" " * $padding) -NoNewline
    Write-Host "║" -ForegroundColor $SummaryColor
    
    Write-Host "║ CSV Procesado: $(Split-Path $CSVPath -Leaf)" -ForegroundColor $SummaryColor -NoNewline
    $padding = 55 - "CSV Procesado: $(Split-Path $CSVPath -Leaf)".Length
    Write-Host (" " * $padding) -NoNewline
    Write-Host "║" -ForegroundColor $SummaryColor
    
    if ($ExecutionResult.PipelineResult) {
        Write-Host "║ Operaciones Exitosas: $($ExecutionResult.PipelineResult.SuccessfulOperations)" -ForegroundColor $SummaryColor -NoNewline
        $padding = 57 - "Operaciones Exitosas: $($ExecutionResult.PipelineResult.SuccessfulOperations)".Length
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor $SummaryColor
        
        Write-Host "║ Operaciones Fallidas: $($ExecutionResult.PipelineResult.FailedOperations)" -ForegroundColor $SummaryColor -NoNewline
        $padding = 57 - "Operaciones Fallidas: $($ExecutionResult.PipelineResult.FailedOperations)".Length
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor $SummaryColor
        
        Write-Host "║ Rollbacks Ejecutados: $($ExecutionResult.PipelineResult.RolledBackOperations)" -ForegroundColor $SummaryColor -NoNewline
        $padding = 57 - "Rollbacks Ejecutados: $($ExecutionResult.PipelineResult.RolledBackOperations)".Length
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor $SummaryColor
    }
    
    if ($ExecutionResult.ValidationResult) {
        Write-Host "║ Score de Validación: $($ExecutionResult.ValidationResult.BatchValidation.BatchScore)" -ForegroundColor $SummaryColor -NoNewline
        $padding = 57 - "Score de Validación: $($ExecutionResult.ValidationResult.BatchValidation.BatchScore)".Length
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor $SummaryColor
    }
    
    Write-Host "║ Errores: $($ExecutionResult.Errors.Count)" -ForegroundColor $SummaryColor -NoNewline
    $padding = 57 - "Errores: $($ExecutionResult.Errors.Count)".Length
    Write-Host (" " * $padding) -NoNewline
    Write-Host "║" -ForegroundColor $SummaryColor
    
    Write-Host "║ Advertencias: $($ExecutionResult.Warnings.Count)" -ForegroundColor $SummaryColor -NoNewline
    $padding = 55 - "Advertencias: $($ExecutionResult.Warnings.Count)".Length
    Write-Host (" " * $padding) -NoNewline
    Write-Host "║" -ForegroundColor $SummaryColor
    
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $SummaryColor
    
    # Mostrar errores si existen
    if ($ExecutionResult.Errors.Count -gt 0) {
        Write-Host "`n🚨 ERRORES DETECTADOS:" -ForegroundColor Red
        foreach ($Error in $ExecutionResult.Errors) {
            Write-Host "   • $Error" -ForegroundColor Red
        }
    }
    
    # Mostrar advertencias si existen  
    if ($ExecutionResult.Warnings.Count -gt 0) {
        Write-Host "`n⚠️  ADVERTENCIAS:" -ForegroundColor Yellow
        foreach ($Warning in $ExecutionResult.Warnings) {
            Write-Host "   • $Warning" -ForegroundColor Yellow
        }
    }
    
    # Información de logs y reportes
    Write-Host "`n📁 ARCHIVOS GENERADOS:" -ForegroundColor Cyan
    Write-Host "   • Logs: $LogPath" -ForegroundColor Cyan
    
    if ($EnableMetrics) {
        Write-Host "   • Métricas: C:\Logs\AD_ADMIN\Metrics" -ForegroundColor Cyan
    }
    
    if ($EnableLogging) {
        Write-Host "   • Logs Estructurados: C:\Logs\AD_ADMIN\Structured" -ForegroundColor Cyan
    }
    
    if ($GenerateDetailedReport) {
        Write-Host "   • Reporte Detallado: C:\Logs\AD_ADMIN\Validation" -ForegroundColor Cyan
    }
}

#endregion

#region Cleanup y Finalización

function Cleanup-PipelineManager {
    <#
    .SYNOPSIS
    Limpia recursos y finaliza el pipeline manager
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "`n🧹 Limpiando recursos..." -ForegroundColor Yellow
        
        # Detener logging estructurado si está activo
        if ($EnableLogging -and (Get-Command Stop-StructuredLogging -ErrorAction SilentlyContinue)) {
            Stop-StructuredLogging | Out-Null
        }
        
        # Limpiar variables globales
        Remove-Variable -Name Logger -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name MetricsCollector -Scope Global -ErrorAction SilentlyContinue
        
        Write-Host "   ✓ Recursos limpiados" -ForegroundColor Green
        
    } catch {
        Write-Warning "Error durante cleanup: $($_.Exception.Message)"
    }
}

#endregion

#region Ejecución Principal

try {
    # Mostrar información inicial
    Write-Host "🎯 AD_ADMIN Pipeline Manager" -ForegroundColor Green
    Write-Host "Procesando: $CSVPath" -ForegroundColor White
    Write-Host "Modo: $(if($WhatIf) { 'SIMULACIÓN' } else { 'PRODUCCIÓN' })" -ForegroundColor $(if($WhatIf) { 'Yellow' } else { 'Green' })
    
    # Inicializar sistema
    $InitResult = Initialize-PipelineManager
    if (-not $InitResult) {
        Write-Host "❌ No se pudo inicializar Pipeline Manager" -ForegroundColor Red
        exit 1
    }
    
    # Ejecutar pipeline
    $ExecutionResult = Invoke-PipelineExecution
    
    # Determinar código de salida
    $ExitCode = if ($ExecutionResult.Success) { 0 } else { 1 }
    
    # Mostrar mensaje final
    if ($ExecutionResult.Success) {
        Write-Host "`n🎉 ¡PIPELINE COMPLETADO EXITOSAMENTE!" -ForegroundColor Green
        Write-Host "Tiempo total: $([math]::Round($ExecutionResult.TotalTime, 2)) minutos" -ForegroundColor Green
    } else {
        Write-Host "`n💥 PIPELINE FALLÓ" -ForegroundColor Red
        Write-Host "Verifique los logs para más detalles." -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n💥 ERROR CRÍTICO NO MANEJADO" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    $ExitCode = 2
    
} finally {
    # Cleanup final
    Cleanup-PipelineManager
    
    # Mostrar tiempo total de ejecución
    $TotalScriptTime = (Get-Date) - $Global:ScriptStartTime
    Write-Host "`n⏱️  Tiempo total del script: $([math]::Round($TotalScriptTime.TotalMinutes, 2)) minutos" -ForegroundColor Cyan
    Write-Host "Finalizando a las $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    
    # Salir con código apropiado
    exit $ExitCode
}

#endregion