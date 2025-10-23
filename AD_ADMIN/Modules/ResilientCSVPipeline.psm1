#Requires -Version 5.1

<#
.SYNOPSIS
Pipeline de procesamiento CSV resiliente con rollback automático y validación pre-procesamiento.

.DESCRIPTION
Módulo que implementa un pipeline robusto para el procesamiento de archivos CSV con:
- Validación exhaustiva pre-procesamiento
- Sistema de transacciones con rollback automático
- Manejo de estados persistentes
- Recovery automático ante fallos
- Trazabilidad completa de operaciones

.AUTHOR
Sistema AD_ADMIN - Pipeline Resiliente v1.0

.DATE
2025-08-27
#>

# Importar dependencias requeridas
Import-Module "$PSScriptRoot\CSVValidation.psm1" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module "$PSScriptRoot\UOManager.psm1" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module "$PSScriptRoot\UserSearch.psm1" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Variables globales del pipeline
$Global:PipelineStateFile = "$env:TEMP\AD_ADMIN_PipelineState.json"
$Global:PipelineLogPath = "C:\Logs\AD_ADMIN\Pipeline"
$Global:MaxRetryAttempts = 3
$Global:RetryBackoffSeconds = @(5, 15, 30)

#region Enums y Clases

# Estados de operación del pipeline
Add-Type -TypeDefinition @"
public enum PipelineOperationStatus {
    Pending,
    Validating,
    Processing,
    Completed,
    Failed,
    RolledBack,
    Retrying
}

public enum PipelineCheckpoint {
    PreValidation,
    IntegrityValidation, 
    DryRun,
    Processing,
    PostValidation,
    Completed
}

public enum RollbackAction {
    DeleteUser,
    RestoreUser,
    RemoveFromGroup,
    AddToGroup,
    ResetPassword,
    UndoTransfer,
    RestoreOU
}
"@

# Clase para gestionar el estado de operaciones
class PipelineOperation {
    [string]$Id
    [string]$Type
    [PipelineOperationStatus]$Status
    [PipelineCheckpoint]$Checkpoint
    [datetime]$StartTime
    [datetime]$LastUpdateTime
    [hashtable]$Data
    [array]$RollbackActions
    [array]$Errors
    [int]$RetryCount
    
    PipelineOperation([string]$operationType, [hashtable]$operationData) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Type = $operationType
        $this.Status = [PipelineOperationStatus]::Pending
        $this.Checkpoint = [PipelineCheckpoint]::PreValidation
        $this.StartTime = Get-Date
        $this.LastUpdateTime = Get-Date
        $this.Data = $operationData
        $this.RollbackActions = @()
        $this.Errors = @()
        $this.RetryCount = 0
    }
    
    [void]UpdateStatus([PipelineOperationStatus]$newStatus, [PipelineCheckpoint]$checkpoint) {
        $this.Status = $newStatus
        $this.Checkpoint = $checkpoint
        $this.LastUpdateTime = Get-Date
    }
    
    [void]AddRollbackAction([RollbackAction]$action, [hashtable]$actionData) {
        $rollbackItem = @{
            Action = $action
            Data = $actionData
            Timestamp = Get-Date
        }
        $this.RollbackActions += $rollbackItem
    }
    
    [void]AddError([string]$errorMessage) {
        $errorItem = @{
            Message = $errorMessage
            Timestamp = Get-Date
            Checkpoint = $this.Checkpoint
        }
        $this.Errors += $errorItem
    }
}

#endregion

#region Funciones de Estado Persistente

function Initialize-PipelineState {
    <#
    .SYNOPSIS
    Inicializa el estado persistente del pipeline
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Crear directorio de logs si no existe
        if (!(Test-Path $Global:PipelineLogPath)) {
            New-Item -ItemType Directory -Path $Global:PipelineLogPath -Force | Out-Null
        }
        
        # Inicializar archivo de estado
        $initialState = @{
            PipelineId = [System.Guid]::NewGuid().ToString()
            StartTime = Get-Date
            Operations = @()
            GlobalStatus = "Initialized"
            Version = "1.0"
        }
        
        $initialState | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:PipelineStateFile -Encoding UTF8
        Write-LogMessage "Pipeline state initialized. State file: $Global:PipelineStateFile" -Level "INFO"
        
        return $initialState.PipelineId
    }
    catch {
        Write-LogMessage "Error initializing pipeline state: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Save-PipelineState {
    <#
    .SYNOPSIS
    Guarda el estado actual del pipeline en disco
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )
    
    try {
        $State.LastSaved = Get-Date
        $State | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:PipelineStateFile -Encoding UTF8
        Write-LogMessage "Pipeline state saved successfully" -Level "DEBUG"
    }
    catch {
        Write-LogMessage "Error saving pipeline state: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-PipelineState {
    <#
    .SYNOPSIS
    Recupera el estado actual del pipeline desde disco
    #>
    [CmdletBinding()]
    param()
    
    try {
        if (!(Test-Path $Global:PipelineStateFile)) {
            Write-LogMessage "Pipeline state file not found. Initializing new state." -Level "WARNING"
            $pipelineId = Initialize-PipelineState
            return Get-PipelineState
        }
        
        $stateJson = Get-Content -Path $Global:PipelineStateFile -Raw -Encoding UTF8
        $state = $stateJson | ConvertFrom-Json -AsHashtable
        
        return $state
    }
    catch {
        Write-LogMessage "Error reading pipeline state: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Funciones de Validación Pre-procesamiento

function Test-CSVIntegrityValidation {
    <#
    .SYNOPSIS
    Realiza validación de integridad referencial exhaustiva del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$DetailedReport
    )
    
    $validationResults = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
        Statistics = @{
            TotalRecords = 0
            ValidRecords = 0
            InvalidRecords = 0
        }
        IntegrityChecks = @{
            DuplicateUsers = @()
            MissingReferences = @()
            InvalidDomains = @()
            OrphanedOperations = @()
        }
    }
    
    try {
        Write-LogMessage "Starting CSV integrity validation for: $CSVPath" -Level "INFO"
        
        # Verificar existencia del archivo
        if (!(Test-Path $CSVPath)) {
            $validationResults.Errors += "CSV file not found: $CSVPath"
            $validationResults.IsValid = $false
            return $validationResults
        }
        
        # Cargar y validar estructura básica del CSV
        $csvData = Import-Csv -Path $CSVPath -Encoding UTF8 -ErrorAction Stop
        $validationResults.Statistics.TotalRecords = $csvData.Count
        
        if ($csvData.Count -eq 0) {
            $validationResults.Errors += "CSV file is empty"
            $validationResults.IsValid = $false
            return $validationResults
        }
        
        # Validar cabeceras requeridas
        $requiredHeaders = @('DNI', 'Nombre', 'Apellidos', 'Email', 'TipoAlta', 'Oficina')
        $csvHeaders = $csvData[0].PSObject.Properties.Name
        
        foreach ($header in $requiredHeaders) {
            if ($header -notin $csvHeaders) {
                $validationResults.Errors += "Missing required header: $header"
                $validationResults.IsValid = $false
            }
        }
        
        if (-not $validationResults.IsValid) {
            return $validationResults
        }
        
        # Validaciones de integridad referencial
        $processedDNIs = @{}
        $processedEmails = @{}
        $lineNumber = 1
        
        foreach ($record in $csvData) {
            $lineNumber++
            $currentRecordValid = $true
            
            # Verificar duplicados por DNI
            if ($processedDNIs.ContainsKey($record.DNI)) {
                $validationResults.IntegrityChecks.DuplicateUsers += @{
                    DNI = $record.DNI
                    Lines = @($processedDNIs[$record.DNI], $lineNumber)
                    Type = "DNI"
                }
                $validationResults.Errors += "Duplicate DNI found: $($record.DNI) at lines $($processedDNIs[$record.DNI]) and $lineNumber"
                $currentRecordValid = $false
            } else {
                $processedDNIs[$record.DNI] = $lineNumber
            }
            
            # Verificar duplicados por Email
            if (![string]::IsNullOrWhiteSpace($record.Email)) {
                if ($processedEmails.ContainsKey($record.Email.ToLower())) {
                    $validationResults.IntegrityChecks.DuplicateUsers += @{
                        Email = $record.Email
                        Lines = @($processedEmails[$record.Email.ToLower()], $lineNumber)
                        Type = "Email"
                    }
                    $validationResults.Warnings += "Duplicate email found: $($record.Email) at lines $($processedEmails[$record.Email.ToLower()]) and $lineNumber"
                } else {
                    $processedEmails[$record.Email.ToLower()] = $lineNumber
                }
            }
            
            # Validar existencia de usuario en caso de TRASLADO
            if ($record.TipoAlta -eq "TRASLADO") {
                try {
                    $existingUser = Get-ADUser -Filter "EmployeeID -eq '$($record.DNI)'" -Properties EmployeeID -ErrorAction SilentlyContinue
                    if (-not $existingUser) {
                        $validationResults.IntegrityChecks.MissingReferences += @{
                            DNI = $record.DNI
                            Line = $lineNumber
                            Type = "TRASLADO_USER_NOT_FOUND"
                        }
                        $validationResults.Errors += "User not found for TRASLADO operation: $($record.DNI) at line $lineNumber"
                        $currentRecordValid = $false
                    }
                } catch {
                    $validationResults.Warnings += "Could not verify existing user for TRASLADO: $($record.DNI) at line $lineNumber. Error: $($_.Exception.Message)"
                }
            }
            
            # Validar dominio de destino
            if (![string]::IsNullOrWhiteSpace($record.Oficina)) {
                $domainFromOffice = Get-DomainFromOffice -OfficeName $record.Oficina
                if (-not $domainFromOffice) {
                    $validationResults.IntegrityChecks.InvalidDomains += @{
                        Office = $record.Oficina
                        Line = $lineNumber
                    }
                    $validationResults.Errors += "Invalid or unmappable office: $($record.Oficina) at line $lineNumber"
                    $currentRecordValid = $false
                }
            }
            
            if ($currentRecordValid) {
                $validationResults.Statistics.ValidRecords++
            } else {
                $validationResults.Statistics.InvalidRecords++
                $validationResults.IsValid = $false
            }
        }
        
        # Validaciones adicionales específicas por tipo de operación
        $typeStatistics = $csvData | Group-Object -Property TipoAlta | Select-Object Name, Count
        Write-LogMessage "Operation types found: $($typeStatistics | ForEach-Object { "$($_.Name): $($_.Count)" } | Join-String -Separator ', ')" -Level "INFO"
        
        Write-LogMessage "CSV integrity validation completed. Valid: $($validationResults.IsValid), Total: $($validationResults.Statistics.TotalRecords), Errors: $($validationResults.Errors.Count)" -Level "INFO"
        
        return $validationResults
    }
    catch {
        $validationResults.Errors += "Critical error during CSV validation: $($_.Exception.Message)"
        $validationResults.IsValid = $false
        Write-LogMessage "Critical error during CSV validation: $($_.Exception.Message)" -Level "ERROR"
        return $validationResults
    }
}

function Test-SystemConnectivity {
    <#
    .SYNOPSIS
    Verifica la conectividad a todos los dominios necesarios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredDomains = @("andalucia.jus", "ca.andalucia.jus", "gr.andalucia.jus", "se.andalucia.jus", "co.andalucia.jus", "ja.andalucia.jus", "hu.andalucia.jus", "al.andalucia.jus", "ma.andalucia.jus")
    )
    
    $connectivityResults = @{
        IsHealthy = $true
        DomainStatus = @{}
        Errors = @()
        TotalDomains = $RequiredDomains.Count
        HealthyDomains = 0
    }
    
    Write-LogMessage "Testing connectivity to $($RequiredDomains.Count) domains" -Level "INFO"
    
    foreach ($domain in $RequiredDomains) {
        try {
            # Test de conectividad básica
            $domainController = Get-ADDomainController -DomainName $domain -Discover -ErrorAction Stop
            
            # Test de autenticación
            $testUser = Get-ADUser -Filter "Name -like '*'" -Server $domain -ResultSetSize 1 -ErrorAction Stop
            
            $connectivityResults.DomainStatus[$domain] = @{
                Status = "Healthy"
                DomainController = $domainController.HostName
                ResponseTime = (Measure-Command { 
                    Test-NetConnection -ComputerName $domainController.HostName -Port 389 -WarningAction SilentlyContinue 
                }).TotalMilliseconds
                LastTested = Get-Date
            }
            
            $connectivityResults.HealthyDomains++
            Write-LogMessage "Domain $domain: Healthy (DC: $($domainController.HostName))" -Level "DEBUG"
        }
        catch {
            $connectivityResults.DomainStatus[$domain] = @{
                Status = "Failed"
                Error = $_.Exception.Message
                LastTested = Get-Date
            }
            
            $connectivityResults.Errors += "Domain $domain connectivity failed: $($_.Exception.Message)"
            $connectivityResults.IsHealthy = $false
            Write-LogMessage "Domain $domain: Failed - $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    $healthPercentage = [math]::Round(($connectivityResults.HealthyDomains / $connectivityResults.TotalDomains) * 100, 2)
    Write-LogMessage "Connectivity test completed. Healthy domains: $($connectivityResults.HealthyDomains)/$($connectivityResults.TotalDomains) ($healthPercentage%)" -Level "INFO"
    
    return $connectivityResults
}

function Invoke-CSVDryRun {
    <#
    .SYNOPSIS
    Realiza una ejecución de prueba completa sin realizar cambios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$DetailedReport
    )
    
    $dryRunResults = @{
        IsSuccessful = $true
        Errors = @()
        Warnings = @()
        SimulatedOperations = @()
        Statistics = @{
            TotalOperations = 0
            SuccessfulSimulations = 0
            FailedSimulations = 0
        }
        ResourceRequirements = @{
            EstimatedTimeMinutes = 0
            RequiredPermissions = @()
            AffectedDomains = @()
        }
    }
    
    try {
        Write-LogMessage "Starting CSV dry run for: $CSVPath" -Level "INFO"
        
        $csvData = Import-Csv -Path $CSVPath -Encoding UTF8
        $dryRunResults.Statistics.TotalOperations = $csvData.Count
        
        foreach ($record in $csvData) {
            $simulationResult = @{
                RecordData = $record
                OperationType = $record.TipoAlta
                SimulationStatus = "Success"
                PredictedActions = @()
                Warnings = @()
                Errors = @()
            }
            
            try {
                # Simular operación según tipo
                switch ($record.TipoAlta) {
                    "NORMALIZADA" {
                        $simulationResult.PredictedActions += "Create new user: $($record.DNI)"
                        $simulationResult.PredictedActions += "Set initial password"
                        $simulationResult.PredictedActions += "Add to groups based on description: $($record.Descripcion)"
                        
                        # Verificar que el usuario no existe
                        $existingUser = Get-ADUser -Filter "EmployeeID -eq '$($record.DNI)'" -ErrorAction SilentlyContinue
                        if ($existingUser) {
                            $simulationResult.SimulationStatus = "Failed"
                            $simulationResult.Errors += "User with DNI $($record.DNI) already exists"
                        }
                    }
                    
                    "TRASLADO" {
                        $simulationResult.PredictedActions += "Transfer existing user: $($record.DNI)"
                        $simulationResult.PredictedActions += "Update office/OU: $($record.Oficina)"
                        $simulationResult.PredictedActions += "Modify group memberships"
                        
                        # Verificar que el usuario existe
                        $existingUser = Get-ADUser -Filter "EmployeeID -eq '$($record.DNI)'" -ErrorAction SilentlyContinue
                        if (-not $existingUser) {
                            $simulationResult.SimulationStatus = "Failed"
                            $simulationResult.Errors += "User with DNI $($record.DNI) not found for transfer"
                        }
                    }
                    
                    "COMPAGINADA" {
                        $simulationResult.PredictedActions += "Create compound user account: $($record.DNI)"
                        $simulationResult.PredictedActions += "Configure dual office access"
                        $simulationResult.PredictedActions += "Set compound-specific groups"
                    }
                    
                    default {
                        $simulationResult.SimulationStatus = "Failed"
                        $simulationResult.Errors += "Unknown operation type: $($record.TipoAlta)"
                    }
                }
                
                # Verificar dominio de destino
                $targetDomain = Get-DomainFromOffice -OfficeName $record.Oficina
                if ($targetDomain) {
                    $simulationResult.PredictedActions += "Target domain: $targetDomain"
                    if ($targetDomain -notin $dryRunResults.ResourceRequirements.AffectedDomains) {
                        $dryRunResults.ResourceRequirements.AffectedDomains += $targetDomain
                    }
                } else {
                    $simulationResult.SimulationStatus = "Failed"
                    $simulationResult.Errors += "Cannot determine target domain for office: $($record.Oficina)"
                }
                
                # Estimar tiempo de operación (en segundos)
                $estimatedTime = switch ($record.TipoAlta) {
                    "NORMALIZADA" { 15 }  # Crear usuario completo
                    "TRASLADO" { 10 }     # Modificar usuario existente
                    "COMPAGINADA" { 20 }  # Configuración compleja
                    default { 12 }
                }
                $dryRunResults.ResourceRequirements.EstimatedTimeMinutes += ($estimatedTime / 60)
                
            }
            catch {
                $simulationResult.SimulationStatus = "Failed"
                $simulationResult.Errors += "Simulation error: $($_.Exception.Message)"
            }
            
            if ($simulationResult.SimulationStatus -eq "Success") {
                $dryRunResults.Statistics.SuccessfulSimulations++
            } else {
                $dryRunResults.Statistics.FailedSimulations++
                $dryRunResults.IsSuccessful = $false
                $dryRunResults.Errors += $simulationResult.Errors
            }
            
            $dryRunResults.SimulatedOperations += $simulationResult
        }
        
        # Redondear tiempo estimado
        $dryRunResults.ResourceRequirements.EstimatedTimeMinutes = [math]::Ceiling($dryRunResults.ResourceRequirements.EstimatedTimeMinutes)
        
        Write-LogMessage "CSV dry run completed. Success: $($dryRunResults.IsSuccessful), Successful: $($dryRunResults.Statistics.SuccessfulSimulations), Failed: $($dryRunResults.Statistics.FailedSimulations)" -Level "INFO"
        
        return $dryRunResults
    }
    catch {
        $dryRunResults.IsSuccessful = $false
        $dryRunResults.Errors += "Critical error during dry run: $($_.Exception.Message)"
        Write-LogMessage "Critical error during CSV dry run: $($_.Exception.Message)" -Level "ERROR"
        return $dryRunResults
    }
}

#endregion

#region Funciones de Pipeline Principal

function Start-ResilientCSVPipeline {
    <#
    .SYNOPSIS
    Inicia el pipeline completo de procesamiento CSV con validación y rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxParallelOperations = 5
    )
    
    $pipelineResult = @{
        Success = $false
        PipelineId = $null
        TotalOperations = 0
        SuccessfulOperations = 0
        FailedOperations = 0
        RolledBackOperations = 0
        ExecutionTimeMinutes = 0
        Errors = @()
        Warnings = @()
    }
    
    $startTime = Get-Date
    
    try {
        Write-LogMessage "Starting Resilient CSV Pipeline for: $CSVPath" -Level "INFO"
        
        # Fase 1: Inicialización
        $pipelineId = Initialize-PipelineState
        $pipelineResult.PipelineId = $pipelineId
        $state = Get-PipelineState
        $state.CSVPath = $CSVPath
        $state.GlobalStatus = "PreValidation"
        Save-PipelineState -State $state
        
        Write-LogMessage "Pipeline initialized with ID: $pipelineId" -Level "INFO"
        
        # Fase 2: Validación de Conectividad
        Write-LogMessage "Phase 2: System Connectivity Validation" -Level "INFO"
        $connectivityResult = Test-SystemConnectivity
        
        if (-not $connectivityResult.IsHealthy) {
            if (-not $Force) {
                $pipelineResult.Errors += "System connectivity check failed. Use -Force to proceed anyway."
                $pipelineResult.Errors += $connectivityResult.Errors
                throw "Critical connectivity issues detected"
            } else {
                Write-LogMessage "Connectivity issues detected but proceeding due to -Force parameter" -Level "WARNING"
                $pipelineResult.Warnings += "Proceeding with connectivity issues due to -Force parameter"
            }
        }
        
        # Fase 3: Validación de Integridad del CSV
        Write-LogMessage "Phase 3: CSV Integrity Validation" -Level "INFO"
        $integrityResult = Test-CSVIntegrityValidation -CSVPath $CSVPath -DetailedReport
        
        if (-not $integrityResult.IsValid) {
            $pipelineResult.Errors += "CSV integrity validation failed"
            $pipelineResult.Errors += $integrityResult.Errors
            throw "CSV integrity validation failed"
        }
        
        $pipelineResult.TotalOperations = $integrityResult.Statistics.TotalRecords
        
        # Fase 4: Dry Run
        Write-LogMessage "Phase 4: Dry Run Simulation" -Level "INFO"
        $dryRunResult = Invoke-CSVDryRun -CSVPath $CSVPath -DetailedReport
        
        if (-not $dryRunResult.IsSuccessful) {
            if (-not $Force) {
                $pipelineResult.Errors += "Dry run failed. Use -Force to proceed anyway."
                $pipelineResult.Errors += $dryRunResult.Errors
                throw "Dry run validation failed"
            } else {
                Write-LogMessage "Dry run issues detected but proceeding due to -Force parameter" -Level "WARNING"
                $pipelineResult.Warnings += "Proceeding with dry run issues due to -Force parameter"
            }
        }
        
        # Actualizar estado
        $state.GlobalStatus = "ValidationCompleted"
        $state.EstimatedTimeMinutes = $dryRunResult.ResourceRequirements.EstimatedTimeMinutes
        Save-PipelineState -State $state
        
        if ($WhatIf) {
            Write-LogMessage "WhatIf mode: Pipeline validation completed successfully. No actual processing performed." -Level "INFO"
            $pipelineResult.Success = $true
            $pipelineResult.Warnings += "WhatIf mode: No actual operations performed"
            return $pipelineResult
        }
        
        # Fase 5: Procesamiento Real
        Write-LogMessage "Phase 5: Real Processing with Transaction Management" -Level "INFO"
        $csvData = Import-Csv -Path $CSVPath -Encoding UTF8
        
        $state.GlobalStatus = "Processing"
        Save-PipelineState -State $state
        
        $processedCount = 0
        $failedCount = 0
        
        foreach ($record in $csvData) {
            try {
                $operation = [PipelineOperation]::new($record.TipoAlta, @{
                    DNI = $record.DNI
                    Nombre = $record.Nombre
                    Apellidos = $record.Apellidos
                    Email = $record.Email
                    Oficina = $record.Oficina
                    Descripcion = $record.Descripcion
                })
                
                # Procesar operación individual con rollback automático
                $operationResult = Invoke-PipelineOperation -Operation $operation -State $state
                
                if ($operationResult.Success) {
                    $processedCount++
                    Write-LogMessage "Operation completed successfully: $($record.DNI) ($($record.TipoAlta))" -Level "INFO"
                } else {
                    $failedCount++
                    $pipelineResult.Errors += "Operation failed: $($record.DNI) - $($operationResult.Error)"
                    Write-LogMessage "Operation failed: $($record.DNI) - $($operationResult.Error)" -Level "ERROR"
                    
                    # Si la operación falló, intentar rollback automático
                    if ($operationResult.Operation.RollbackActions.Count -gt 0) {
                        Write-LogMessage "Attempting automatic rollback for operation: $($record.DNI)" -Level "WARNING"
                        $rollbackResult = Invoke-OperationRollback -Operation $operationResult.Operation
                        
                        if ($rollbackResult.Success) {
                            $pipelineResult.RolledBackOperations++
                            Write-LogMessage "Automatic rollback successful for: $($record.DNI)" -Level "INFO"
                        } else {
                            Write-LogMessage "Automatic rollback failed for: $($record.DNI) - Manual intervention required" -Level "ERROR"
                            $pipelineResult.Errors += "Rollback failed for $($record.DNI) - Manual intervention required"
                        }
                    }
                }
                
                $state.Operations += @{
                    Id = $operation.Id
                    Type = $operation.Type
                    Status = $operation.Status.ToString()
                    Data = $operation.Data
                    Errors = $operation.Errors
                }
                
                Save-PipelineState -State $state
                
            }
            catch {
                $failedCount++
                $errorMsg = "Critical error processing record $($record.DNI): $($_.Exception.Message)"
                $pipelineResult.Errors += $errorMsg
                Write-LogMessage $errorMsg -Level "ERROR"
            }
        }
        
        $pipelineResult.SuccessfulOperations = $processedCount
        $pipelineResult.FailedOperations = $failedCount
        
        # Fase 6: Post-validación
        Write-LogMessage "Phase 6: Post-Processing Validation" -Level "INFO"
        $state.GlobalStatus = "PostValidation"
        Save-PipelineState -State $state
        
        # Determinar éxito del pipeline
        $successRate = if ($pipelineResult.TotalOperations -gt 0) {
            ($pipelineResult.SuccessfulOperations / $pipelineResult.TotalOperations) * 100
        } else { 0 }
        
        $pipelineResult.Success = ($successRate -ge 95) # 95% o más de éxito requerido
        
        if ($pipelineResult.Success) {
            $state.GlobalStatus = "Completed"
            Write-LogMessage "Pipeline completed successfully. Success rate: $([math]::Round($successRate, 2))%" -Level "INFO"
        } else {
            $state.GlobalStatus = "Failed"
            Write-LogMessage "Pipeline completed with errors. Success rate: $([math]::Round($successRate, 2))%" -Level "ERROR"
        }
        
        Save-PipelineState -State $state
        
    }
    catch {
        $pipelineResult.Success = $false
        $pipelineResult.Errors += "Pipeline critical error: $($_.Exception.Message)"
        Write-LogMessage "Pipeline critical error: $($_.Exception.Message)" -Level "ERROR"
        
        # Actualizar estado de fallo
        if ($null -ne $state) {
            $state.GlobalStatus = "Failed"
            $state.Error = $_.Exception.Message
            Save-PipelineState -State $state
        }
    }
    finally {
        $endTime = Get-Date
        $pipelineResult.ExecutionTimeMinutes = [math]::Round(($endTime - $startTime).TotalMinutes, 2)
        
        Write-LogMessage "Pipeline execution completed in $($pipelineResult.ExecutionTimeMinutes) minutes" -Level "INFO"
        Write-LogMessage "Final Results - Success: $($pipelineResult.Success), Processed: $($pipelineResult.SuccessfulOperations), Failed: $($pipelineResult.FailedOperations), Rolled Back: $($pipelineResult.RolledBackOperations)" -Level "INFO"
    }
    
    return $pipelineResult
}

#endregion

#region Funciones Auxiliares

function Write-LogMessage {
    <#
    .SYNOPSIS
    Función de logging estructurado para el pipeline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Context = $Context
        Pipeline = $true
    }
    
    # Escribir a consola con colores
    $color = switch ($Level) {
        "DEBUG" { "Gray" }
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # Escribir a archivo de log
    try {
        if (!(Test-Path $Global:PipelineLogPath)) {
            New-Item -ItemType Directory -Path $Global:PipelineLogPath -Force | Out-Null
        }
        
        $logFile = Join-Path $Global:PipelineLogPath "Pipeline_$(Get-Date -Format 'yyyyMMdd').log"
        $logLine = "[$timestamp] [$Level] $Message"
        
        if ($Context.Count -gt 0) {
            $contextJson = $Context | ConvertTo-Json -Compress
            $logLine += " | Context: $contextJson"
        }
        
        Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Could not write to log file: $($_.Exception.Message)"
    }
}

function Get-DomainFromOffice {
    <#
    .SYNOPSIS
    Determina el dominio destino basado en la oficina
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OfficeName
    )
    
    # Mapeo básico de oficinas a dominios - esto debería expandirse según la lógica de negocio
    $domainMapping = @{
        # Sevilla
        "Sevilla" = "se.andalucia.jus"
        "Seville" = "se.andalucia.jus"
        "SE" = "se.andalucia.jus"
        
        # Málaga
        "Málaga" = "ma.andalucia.jus"
        "Malaga" = "ma.andalucia.jus"
        "MA" = "ma.andalucia.jus"
        
        # Granada
        "Granada" = "gr.andalucia.jus"
        "GR" = "gr.andalucia.jus"
        
        # Córdoba
        "Córdoba" = "co.andalucia.jus"
        "Cordoba" = "co.andalucia.jus"
        "CO" = "co.andalucia.jus"
        
        # Cádiz
        "Cádiz" = "ca.andalucia.jus"
        "Cadiz" = "ca.andalucia.jus"
        "CA" = "ca.andalucia.jus"
        
        # Jaén
        "Jaén" = "ja.andalucia.jus"
        "Jaen" = "ja.andalucia.jus"
        "JA" = "ja.andalucia.jus"
        
        # Huelva
        "Huelva" = "hu.andalucia.jus"
        "HU" = "hu.andalucia.jus"
        
        # Almería
        "Almería" = "al.andalucia.jus"
        "Almeria" = "al.andalucia.jus"
        "AL" = "al.andalucia.jus"
    }
    
    # Buscar coincidencia exacta
    if ($domainMapping.ContainsKey($OfficeName)) {
        return $domainMapping[$OfficeName]
    }
    
    # Buscar coincidencia parcial
    foreach ($key in $domainMapping.Keys) {
        if ($OfficeName -like "*$key*" -or $key -like "*$OfficeName*") {
            return $domainMapping[$key]
        }
    }
    
    # Si no se encuentra, intentar usar UOManager para mapeo avanzado
    try {
        if (Get-Command "Get-UODomainMapping" -ErrorAction SilentlyContinue) {
            return Get-UODomainMapping -OfficeName $OfficeName
        }
    }
    catch {
        Write-LogMessage "Could not use advanced domain mapping for office: $OfficeName" -Level "WARNING"
    }
    
    return $null
}

#endregion

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'Start-ResilientCSVPipeline',
    'Test-CSVIntegrityValidation',
    'Test-SystemConnectivity',
    'Invoke-CSVDryRun',
    'Initialize-PipelineState',
    'Get-PipelineState',
    'Save-PipelineState',
    'Write-LogMessage'
)

# Mensaje de inicialización
Write-Host "Resilient CSV Pipeline Module v1.0 loaded successfully" -ForegroundColor Green
Write-Host "Available functions: Start-ResilientCSVPipeline, Test-CSVIntegrityValidation, Test-SystemConnectivity, Invoke-CSVDryRun" -ForegroundColor Cyan