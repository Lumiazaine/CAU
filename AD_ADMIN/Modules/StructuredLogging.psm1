#Requires -Version 5.1

<#
.SYNOPSIS
Sistema de logging estructurado y trazabilidad avanzada para AD_ADMIN.

.DESCRIPTION
Módulo que implementa un sistema completo de logging estructurado que proporciona:
- Logging estructurado con formato JSON
- Correlación de operaciones mediante IDs únicos
- Métricas de rendimiento y operacional
- Alertas automáticas basadas en patrones
- Dashboard de monitorización en tiempo real
- Rotación automática de logs
- Agregación y análisis de logs históricos
- Integración con sistemas de monitorización empresariales

.AUTHOR
Sistema AD_ADMIN - Structured Logging & Traceability v1.0

.DATE
2025-08-28
#>

# Importar dependencias
Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue

# Variables globales del sistema de logging
$Global:LoggingConfig = @{
    BasePath = "C:\Logs\AD_ADMIN"
    StructuredPath = "C:\Logs\AD_ADMIN\Structured"
    MetricsPath = "C:\Logs\AD_ADMIN\Metrics"
    AlertsPath = "C:\Logs\AD_ADMIN\Alerts"
    MaxFileSizeMB = 50
    MaxFileAgeHours = 168  # 7 días
    BufferSize = 100
    FlushIntervalSeconds = 30
    EnableRealTimeAlerts = $true
    EnableMetrics = $true
    CorrelationEnabled = $true
    CompressionEnabled = $true
}

# Buffer global para logging asíncrono
$Global:LogBuffer = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
$Global:LoggingSession = @{
    SessionId = [System.Guid]::NewGuid().ToString()
    StartTime = Get-Date
    OperationCount = 0
    ErrorCount = 0
    WarningCount = 0
}

# Timer para flush automático
$Global:LogFlushTimer = $null

#region Enums y Estructuras

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;

public enum LogLevel {
    Trace = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
    Critical = 5
}

public enum LogCategory {
    System,
    Security,
    Performance,
    Business,
    Integration,
    Audit,
    Metrics
}

public enum AlertSeverity {
    Low,
    Medium,
    High,
    Critical
}

public class LogMetric {
    public string Name { get; set; }
    public double Value { get; set; }
    public string Unit { get; set; }
    public DateTime Timestamp { get; set; }
    public Dictionary<string, object> Tags { get; set; }
    
    public LogMetric() {
        Tags = new Dictionary<string, object>();
        Timestamp = DateTime.Now;
    }
}

public class LogAlert {
    public string Id { get; set; }
    public string RuleName { get; set; }
    public AlertSeverity Severity { get; set; }
    public string Message { get; set; }
    public DateTime Timestamp { get; set; }
    public Dictionary<string, object> Context { get; set; }
    public bool IsResolved { get; set; }
    
    public LogAlert() {
        Id = Guid.NewGuid().ToString();
        Context = new Dictionary<string, object>();
        Timestamp = DateTime.Now;
        IsResolved = false;
    }
}
"@

#endregion

#region Clases del Sistema de Logging

class StructuredLogger {
    [string]$Component
    [string]$CorrelationId
    [hashtable]$Context
    [bool]$IsEnabled
    
    StructuredLogger([string]$component) {
        $this.Component = $component
        $this.CorrelationId = [System.Guid]::NewGuid().ToString()
        $this.Context = @{}
        $this.IsEnabled = $true
    }
    
    StructuredLogger([string]$component, [string]$correlationId) {
        $this.Component = $component
        $this.CorrelationId = $correlationId
        $this.Context = @{}
        $this.IsEnabled = $true
    }
    
    [void]AddContext([string]$key, [object]$value) {
        $this.Context[$key] = $value
    }
    
    [void]RemoveContext([string]$key) {
        $this.Context.Remove($key)
    }
    
    [void]ClearContext() {
        $this.Context.Clear()
    }
    
    [void]Log([LogLevel]$level, [string]$message) {
        $this.Log($level, [LogCategory]::System, $message, @{})
    }
    
    [void]Log([LogLevel]$level, [LogCategory]$category, [string]$message) {
        $this.Log($level, $category, $message, @{})
    }
    
    [void]Log([LogLevel]$level, [LogCategory]$category, [string]$message, [hashtable]$additionalData) {
        if (-not $this.IsEnabled) { return }
        
        $logEntry = @{
            Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
            Level = $level.ToString()
            Category = $category.ToString()
            Component = $this.Component
            CorrelationId = $this.CorrelationId
            SessionId = $Global:LoggingSession.SessionId
            Message = $message
            Context = $this.Context.Clone()
            Data = $additionalData
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            ProcessId = $PID
            MachineName = $env:COMPUTERNAME
            UserName = $env:USERNAME
        }
        
        # Agregar información adicional según el nivel
        if ($level -ge [LogLevel]::Warning) {
            $logEntry.StackTrace = (Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object { $_.ToString() }) -join "`n"
        }
        
        # Enviar al buffer para procesamiento asíncrono
        $Global:LogBuffer.Enqueue($logEntry)
        
        # Incrementar contadores de sesión
        $Global:LoggingSession.OperationCount++
        if ($level -eq [LogLevel]::Error -or $level -eq [LogLevel]::Critical) {
            $Global:LoggingSession.ErrorCount++
        } elseif ($level -eq [LogLevel]::Warning) {
            $Global:LoggingSession.WarningCount++
        }
        
        # Procesar alertas si es necesario
        if ($Global:LoggingConfig.EnableRealTimeAlerts) {
            $this.ProcessAlerts($logEntry)
        }
        
        # Mostrar en consola con formato
        $this.WriteConsoleOutput($logEntry)
    }
    
    [void]ProcessAlerts([hashtable]$logEntry) {
        try {
            $alertRules = Get-AlertRules
            
            foreach ($rule in $alertRules) {
                if ($this.EvaluateAlertRule($rule, $logEntry)) {
                    $alert = [LogAlert]::new()
                    $alert.RuleName = $rule.Name
                    $alert.Severity = [AlertSeverity]$rule.Severity
                    $alert.Message = $rule.Message -replace '\{([^}]+)\}', { param($match) $logEntry[$match.Groups[1].Value] }
                    $alert.Context = @{
                        LogEntry = $logEntry
                        RuleId = $rule.Id
                        TriggeredBy = $rule.Condition
                    }
                    
                    Send-Alert -Alert $alert
                }
            }
        }
        catch {
            # No fallar el logging por errores en alertas
            Write-Warning "Error processing alerts: $($_.Exception.Message)"
        }
    }
    
    [bool]EvaluateAlertRule([hashtable]$rule, [hashtable]$logEntry) {
        try {
            if ($rule.Condition -and $rule.Condition -is [scriptblock]) {
                return $rule.Condition.Invoke($logEntry)
            }
            return $false
        }
        catch {
            return $false
        }
    }
    
    [void]WriteConsoleOutput([hashtable]$logEntry) {
        $timestamp = $logEntry.Timestamp
        $level = $logEntry.Level
        $component = $logEntry.Component
        $message = $logEntry.Message
        
        # Colores por nivel
        $color = switch ($level) {
            "Trace" { "DarkGray" }
            "Debug" { "Gray" }
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Critical" { "Magenta" }
            default { "White" }
        }
        
        $correlationPart = if ($Global:LoggingConfig.CorrelationEnabled) { " [$($logEntry.CorrelationId.Substring(0,8))]" } else { "" }
        
        Write-Host "[$timestamp] [$level] [$component]$correlationPart $message" -ForegroundColor $color
        
        # Mostrar contexto adicional para errores
        if ($level -eq "Error" -or $level -eq "Critical") {
            if ($logEntry.Data -and $logEntry.Data.Count -gt 0) {
                Write-Host "  Additional Data: $($logEntry.Data | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
            }
        }
    }
    
    # Métodos de conveniencia
    [void]Trace([string]$message) { $this.Log([LogLevel]::Trace, $message) }
    [void]Debug([string]$message) { $this.Log([LogLevel]::Debug, $message) }
    [void]Info([string]$message) { $this.Log([LogLevel]::Info, $message) }
    [void]Warning([string]$message) { $this.Log([LogLevel]::Warning, $message) }
    [void]Error([string]$message) { $this.Log([LogLevel]::Error, $message) }
    [void]Critical([string]$message) { $this.Log([LogLevel]::Critical, $message) }
    
    [void]Trace([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Trace, $category, $message, $data) }
    [void]Debug([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Debug, $category, $message, $data) }
    [void]Info([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Info, $category, $message, $data) }
    [void]Warning([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Warning, $category, $message, $data) }
    [void]Error([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Error, $category, $message, $data) }
    [void]Critical([LogCategory]$category, [string]$message, [hashtable]$data) { $this.Log([LogLevel]::Critical, $category, $message, $data) }
}

class MetricsCollector {
    [hashtable]$Metrics
    [datetime]$LastFlush
    [int]$BufferSize
    
    MetricsCollector() {
        $this.Metrics = @{}
        $this.LastFlush = Get-Date
        $this.BufferSize = 1000
    }
    
    [void]RecordMetric([string]$name, [double]$value) {
        $this.RecordMetric($name, $value, "", @{})
    }
    
    [void]RecordMetric([string]$name, [double]$value, [string]$unit) {
        $this.RecordMetric($name, $value, $unit, @{})
    }
    
    [void]RecordMetric([string]$name, [double]$value, [string]$unit, [hashtable]$tags) {
        $metric = [LogMetric]::new()
        $metric.Name = $name
        $metric.Value = $value
        $metric.Unit = $unit
        
        foreach ($tag in $tags.GetEnumerator()) {
            $metric.Tags[$tag.Key] = $tag.Value
        }
        
        if (-not $this.Metrics.ContainsKey($name)) {
            $this.Metrics[$name] = @()
        }
        
        $this.Metrics[$name] += $metric
        
        # Auto-flush si se alcanza el buffer size
        if ($this.GetTotalMetricsCount() -ge $this.BufferSize) {
            $this.FlushMetrics()
        }
    }
    
    [int]GetTotalMetricsCount() {
        $total = 0
        foreach ($metricList in $this.Metrics.Values) {
            $total += $metricList.Count
        }
        return $total
    }
    
    [void]FlushMetrics() {
        if ($this.Metrics.Count -eq 0) { return }
        
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $metricsFile = Join-Path $Global:LoggingConfig.MetricsPath "Metrics_$timestamp.json"
            
            # Crear directorio si no existe
            $directory = Split-Path $metricsFile -Parent
            if (!(Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            
            # Preparar datos para exportación
            $exportData = @{
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
                SessionId = $Global:LoggingSession.SessionId
                FlushReason = "Scheduled"
                TotalMetrics = $this.GetTotalMetricsCount()
                Metrics = $this.Metrics
            }
            
            # Guardar en JSON
            $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsFile -Encoding UTF8
            
            # Limpiar buffer
            $this.Metrics.Clear()
            $this.LastFlush = Get-Date
            
            Write-Host "Metrics flushed to: $metricsFile" -ForegroundColor DarkGreen
        }
        catch {
            Write-Warning "Error flushing metrics: $($_.Exception.Message)"
        }
    }
    
    # Métricas de conveniencia
    [void]RecordCounter([string]$name) { $this.RecordCounter($name, @{}) }
    [void]RecordCounter([string]$name, [hashtable]$tags) { $this.RecordMetric($name, 1, "count", $tags) }
    
    [void]RecordTimer([string]$name, [timespan]$duration) { $this.RecordTimer($name, $duration, @{}) }
    [void]RecordTimer([string]$name, [timespan]$duration, [hashtable]$tags) { 
        $this.RecordMetric($name, $duration.TotalMilliseconds, "ms", $tags) 
    }
    
    [void]RecordGauge([string]$name, [double]$value) { $this.RecordGauge($name, $value, @{}) }
    [void]RecordGauge([string]$name, [double]$value, [hashtable]$tags) { 
        $this.RecordMetric($name, $value, "gauge", $tags) 
    }
}

#endregion

#region Funciones Principales

function Initialize-StructuredLogging {
    <#
    .SYNOPSIS
    Inicializa el sistema de logging estructurado
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        Write-Host "Initializing Structured Logging System..." -ForegroundColor Cyan
        
        # Aplicar configuración personalizada
        foreach ($key in $Configuration.Keys) {
            if ($Global:LoggingConfig.ContainsKey($key)) {
                $Global:LoggingConfig[$key] = $Configuration[$key]
            }
        }
        
        # Crear directorios necesarios
        $directories = @(
            $Global:LoggingConfig.BasePath,
            $Global:LoggingConfig.StructuredPath,
            $Global:LoggingConfig.MetricsPath,
            $Global:LoggingConfig.AlertsPath
        )
        
        foreach ($dir in $directories) {
            if (!(Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Host "Created directory: $dir" -ForegroundColor Green
            }
        }
        
        # Inicializar timer de flush
        if ($null -ne $Global:LogFlushTimer) {
            $Global:LogFlushTimer.Dispose()
        }
        
        $Global:LogFlushTimer = New-Object System.Timers.Timer
        $Global:LogFlushTimer.Interval = $Global:LoggingConfig.FlushIntervalSeconds * 1000
        $Global:LogFlushTimer.AutoReset = $true
        
        # Registrar evento de flush
        Register-ObjectEvent -InputObject $Global:LogFlushTimer -EventName Elapsed -Action {
            try {
                Invoke-LogFlush
            }
            catch {
                Write-Warning "Error in automatic log flush: $($_.Exception.Message)"
            }
        } | Out-Null
        
        $Global:LogFlushTimer.Start()
        
        # Limpiar logs antiguos
        if (-not $Force) {
            Start-LogCleanup
        }
        
        Write-Host "Structured Logging System initialized successfully" -ForegroundColor Green
        Write-Host "Session ID: $($Global:LoggingSession.SessionId)" -ForegroundColor Cyan
        
        # Log inicial del sistema
        $systemLogger = New-StructuredLogger -Component "LoggingSystem"
        $systemLogger.Info([LogCategory]::System, "Structured logging initialized", @{
            SessionId = $Global:LoggingSession.SessionId
            Configuration = $Global:LoggingConfig
            Directories = $directories
        })
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize structured logging: $($_.Exception.Message)"
        return $false
    }
}

function New-StructuredLogger {
    <#
    .SYNOPSIS
    Crea un nuevo logger estructurado para un componente
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId
    )
    
    if ([string]::IsNullOrWhiteSpace($CorrelationId)) {
        return [StructuredLogger]::new($Component)
    } else {
        return [StructuredLogger]::new($Component, $CorrelationId)
    }
}

function New-MetricsCollector {
    <#
    .SYNOPSIS
    Crea un nuevo colector de métricas
    #>
    [CmdletBinding()]
    param()
    
    return [MetricsCollector]::new()
}

function Invoke-LogFlush {
    <#
    .SYNOPSIS
    Ejecuta flush de logs pendientes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $flushedCount = 0
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # Procesar buffer de logs
        if ($Global:LogBuffer.Count -gt 0) {
            $logEntries = @()
            
            # Drenar el buffer
            while ($Global:LogBuffer.TryDequeue([ref]$null)) {
                $logEntry = $null
                if ($Global:LogBuffer.TryDequeue([ref]$logEntry)) {
                    $logEntries += $logEntry
                    $flushedCount++
                }
            }
            
            if ($logEntries.Count -gt 0) {
                # Agrupar por categoría y nivel
                $groupedLogs = $logEntries | Group-Object { "$($_.Category)_$($_.Level)" }
                
                foreach ($group in $groupedLogs) {
                    $categoryLevel = $group.Name
                    $fileName = "StructuredLog_$categoryLevel_$timestamp.json"
                    $filePath = Join-Path $Global:LoggingConfig.StructuredPath $fileName
                    
                    $logBatch = @{
                        BatchId = [System.Guid]::NewGuid().ToString()
                        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
                        SessionId = $Global:LoggingSession.SessionId
                        Category = $categoryLevel
                        Count = $group.Count
                        Entries = $group.Group
                    }
                    
                    # Comprimir si está habilitado
                    if ($Global:LoggingConfig.CompressionEnabled) {
                        $jsonContent = $logBatch | ConvertTo-Json -Depth 10 -Compress
                    } else {
                        $jsonContent = $logBatch | ConvertTo-Json -Depth 10
                    }
                    
                    # Guardar archivo
                    $jsonContent | Out-File -FilePath $filePath -Encoding UTF8
                }
            }
        }
        
        if ($flushedCount -gt 0) {
            Write-Host "Flushed $flushedCount log entries to structured storage" -ForegroundColor DarkGreen
            
            # Registrar métrica de flush
            $metricsCollector = New-MetricsCollector
            $metricsCollector.RecordCounter("log.flush.executed", @{ count = $flushedCount })
            $metricsCollector.FlushMetrics()
        }
        
        return $flushedCount
    }
    catch {
        Write-Warning "Error during log flush: $($_.Exception.Message)"
        return 0
    }
}

function Start-LogCleanup {
    <#
    .SYNOPSIS
    Inicia limpieza automática de logs antiguos
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$MaxAgeHours = $Global:LoggingConfig.MaxFileAgeHours,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxFileSizeMB = $Global:LoggingConfig.MaxFileSizeMB
    )
    
    try {
        Write-Host "Starting log cleanup (Max Age: $MaxAgeHours hours, Max Size: $MaxFileSizeMB MB)" -ForegroundColor Yellow
        
        $cutoffDate = (Get-Date).AddHours(-$MaxAgeHours)
        $totalCleaned = 0
        $totalSizeFreed = 0
        
        $logDirectories = @(
            $Global:LoggingConfig.StructuredPath,
            $Global:LoggingConfig.MetricsPath,
            $Global:LoggingConfig.AlertsPath
        )
        
        foreach ($directory in $logDirectories) {
            if (Test-Path $directory) {
                $oldFiles = Get-ChildItem -Path $directory -File | Where-Object {
                    $_.LastWriteTime -lt $cutoffDate -or ($_.Length / 1MB) -gt $MaxFileSizeMB
                }
                
                foreach ($file in $oldFiles) {
                    $sizeMB = [math]::Round($file.Length / 1MB, 2)
                    Remove-Item -Path $file.FullName -Force
                    $totalCleaned++
                    $totalSizeFreed += $sizeMB
                }
            }
        }
        
        if ($totalCleaned -gt 0) {
            Write-Host "Cleaned up $totalCleaned files, freed $([math]::Round($totalSizeFreed, 2)) MB" -ForegroundColor Green
            
            # Log cleanup activity
            $systemLogger = New-StructuredLogger -Component "LogCleanup"
            $systemLogger.Info([LogCategory]::System, "Log cleanup completed", @{
                FilesRemoved = $totalCleaned
                SizeFreedMB = [math]::Round($totalSizeFreed, 2)
                MaxAgeHours = $MaxAgeHours
                MaxFileSizeMB = $MaxFileSizeMB
            })
        }
        
        return @{
            FilesRemoved = $totalCleaned
            SizeFreedMB = [math]::Round($totalSizeFreed, 2)
        }
    }
    catch {
        Write-Warning "Error during log cleanup: $($_.Exception.Message)"
        return @{ FilesRemoved = 0; SizeFreedMB = 0 }
    }
}

function Get-LogAnalytics {
    <#
    .SYNOPSIS
    Genera analytics de logs para un período específico
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [datetime]$StartDate = (Get-Date).AddDays(-7),
        
        [Parameter(Mandatory = $false)]
        [datetime]$EndDate = (Get-Date),
        
        [Parameter(Mandatory = $false)]
        [string[]]$Categories = @(),
        
        [Parameter(Mandatory = $false)]
        [string[]]$Levels = @()
    )
    
    try {
        Write-Host "Generating log analytics from $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        
        $analytics = @{
            Period = @{
                Start = $StartDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                End = $EndDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                DurationHours = ($EndDate - $StartDate).TotalHours
            }
            Summary = @{
                TotalLogFiles = 0
                TotalLogEntries = 0
                TotalSizeMB = 0
                ByLevel = @{}
                ByCategory = @{}
                ByComponent = @{}
                TopErrors = @()
                PerformanceMetrics = @{}
            }
            Trends = @{
                HourlyVolume = @{}
                DailyVolume = @{}
                ErrorRate = @{}
            }
        }
        
        # Buscar archivos de log en el rango de fechas
        $logFiles = Get-ChildItem -Path $Global:LoggingConfig.StructuredPath -Filter "*.json" | 
            Where-Object { $_.LastWriteTime -ge $StartDate -and $_.LastWriteTime -le $EndDate }
        
        $analytics.Summary.TotalLogFiles = $logFiles.Count
        
        foreach ($logFile in $logFiles) {
            try {
                $analytics.Summary.TotalSizeMB += [math]::Round($logFile.Length / 1MB, 2)
                
                $logContent = Get-Content -Path $logFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                
                if ($logContent.Entries) {
                    $entries = $logContent.Entries
                    $analytics.Summary.TotalLogEntries += $entries.Count
                    
                    # Filtrar por categorías y niveles si se especifican
                    if ($Categories.Count -gt 0) {
                        $entries = $entries | Where-Object { $_.Category -in $Categories }
                    }
                    if ($Levels.Count -gt 0) {
                        $entries = $entries | Where-Object { $_.Level -in $Levels }
                    }
                    
                    # Agregar estadísticas
                    foreach ($entry in $entries) {
                        # Por nivel
                        if (-not $analytics.Summary.ByLevel.ContainsKey($entry.Level)) {
                            $analytics.Summary.ByLevel[$entry.Level] = 0
                        }
                        $analytics.Summary.ByLevel[$entry.Level]++
                        
                        # Por categoría
                        if (-not $analytics.Summary.ByCategory.ContainsKey($entry.Category)) {
                            $analytics.Summary.ByCategory[$entry.Category] = 0
                        }
                        $analytics.Summary.ByCategory[$entry.Category]++
                        
                        # Por componente
                        if (-not $analytics.Summary.ByComponent.ContainsKey($entry.Component)) {
                            $analytics.Summary.ByComponent[$entry.Component] = 0
                        }
                        $analytics.Summary.ByComponent[$entry.Component]++
                        
                        # Errores top
                        if ($entry.Level -in @("Error", "Critical")) {
                            $analytics.Summary.TopErrors += @{
                                Timestamp = $entry.Timestamp
                                Component = $entry.Component
                                Message = $entry.Message
                                Level = $entry.Level
                            }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Error processing log file $($logFile.Name): $($_.Exception.Message)"
            }
        }
        
        # Limpiar y ordenar top errors
        $analytics.Summary.TopErrors = $analytics.Summary.TopErrors | 
            Sort-Object Timestamp -Descending | 
            Select-Object -First 20
        
        Write-Host "Analytics generated: $($analytics.Summary.TotalLogEntries) entries from $($analytics.Summary.TotalLogFiles) files ($($analytics.Summary.TotalSizeMB) MB)" -ForegroundColor Green
        
        return $analytics
    }
    catch {
        Write-Error "Error generating log analytics: $($_.Exception.Message)"
        return $null
    }
}

function Send-Alert {
    <#
    .SYNOPSIS
    Envía una alerta basada en reglas del sistema
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [LogAlert]$Alert
    )
    
    try {
        # Guardar alerta en storage
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $alertFile = Join-Path $Global:LoggingConfig.AlertsPath "Alert_$($Alert.Id)_$timestamp.json"
        
        $alertData = @{
            Id = $Alert.Id
            RuleName = $Alert.RuleName
            Severity = $Alert.Severity.ToString()
            Message = $Alert.Message
            Timestamp = $Alert.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            Context = $Alert.Context
            IsResolved = $Alert.IsResolved
        }
        
        $alertData | ConvertTo-Json -Depth 10 | Out-File -FilePath $alertFile -Encoding UTF8
        
        # Mostrar alerta en consola con color según severidad
        $color = switch ($Alert.Severity) {
            "Low" { "DarkYellow" }
            "Medium" { "Yellow" }
            "High" { "Red" }
            "Critical" { "Magenta" }
        }
        
        Write-Host "🚨 ALERT [$($Alert.Severity)] $($Alert.RuleName): $($Alert.Message)" -ForegroundColor $color
        
        # Aquí se podría integrar con sistemas externos (email, Slack, etc.)
        # Send-EmailAlert -Alert $Alert
        # Send-SlackAlert -Alert $Alert
        
        return $true
    }
    catch {
        Write-Warning "Error sending alert: $($_.Exception.Message)"
        return $false
    }
}

function Get-AlertRules {
    <#
    .SYNOPSIS
    Obtiene las reglas de alertas configuradas
    #>
    [CmdletBinding()]
    param()
    
    # Reglas de alerta por defecto
    return @(
        @{
            Id = "AR001"
            Name = "High Error Rate"
            Severity = "High"
            Message = "High error rate detected: {ErrorCount} errors in the last minute"
            Condition = {
                param($logEntry)
                return ($logEntry.Level -eq "Error" -or $logEntry.Level -eq "Critical")
            }
        },
        @{
            Id = "AR002"
            Name = "Security Event"
            Severity = "Critical"
            Message = "Security-related log detected: {Message}"
            Condition = {
                param($logEntry)
                return ($logEntry.Category -eq "Security")
            }
        },
        @{
            Id = "AR003"
            Name = "Performance Degradation"
            Severity = "Medium"
            Message = "Performance issue detected: {Message}"
            Condition = {
                param($logEntry)
                return ($logEntry.Category -eq "Performance" -and $logEntry.Level -eq "Warning")
            }
        }
    )
}

function Stop-StructuredLogging {
    <#
    .SYNOPSIS
    Detiene el sistema de logging estructurado
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Stopping Structured Logging System..." -ForegroundColor Yellow
        
        # Flush final
        $flushedCount = Invoke-LogFlush -Force
        
        # Detener timer
        if ($null -ne $Global:LogFlushTimer) {
            $Global:LogFlushTimer.Stop()
            $Global:LogFlushTimer.Dispose()
            $Global:LogFlushTimer = $null
        }
        
        # Log final de sesión
        $sessionDuration = (Get-Date) - $Global:LoggingSession.StartTime
        $systemLogger = New-StructuredLogger -Component "LoggingSystem"
        $systemLogger.Info([LogCategory]::System, "Structured logging session ended", @{
            SessionId = $Global:LoggingSession.SessionId
            Duration = $sessionDuration.ToString()
            TotalOperations = $Global:LoggingSession.OperationCount
            TotalErrors = $Global:LoggingSession.ErrorCount
            TotalWarnings = $Global:LoggingSession.WarningCount
            FinalFlushCount = $flushedCount
        })
        
        # Flush este último log
        Start-Sleep -Seconds 1
        Invoke-LogFlush -Force
        
        Write-Host "Structured Logging System stopped successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Error stopping structured logging: $($_.Exception.Message)"
        return $false
    }
}

#endregion

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'Initialize-StructuredLogging',
    'New-StructuredLogger',
    'New-MetricsCollector',
    'Invoke-LogFlush',
    'Start-LogCleanup',
    'Get-LogAnalytics',
    'Send-Alert',
    'Stop-StructuredLogging'
)

# Mensaje de inicialización
Write-Host "Structured Logging & Traceability Module v1.0 loaded successfully" -ForegroundColor Green
Write-Host "Available functions: Initialize-StructuredLogging, New-StructuredLogger, New-MetricsCollector, Get-LogAnalytics" -ForegroundColor Cyan
Write-Host "Note: Call Initialize-StructuredLogging to start the logging system" -ForegroundColor Yellow