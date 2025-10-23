#Requires -Version 5.1

<#
.SYNOPSIS
Sistema de rollback automático con gestión transaccional para operaciones de Active Directory.

.DESCRIPTION
Módulo que implementa un sistema robusto de rollback automático que permite:
- Reversión automática de operaciones fallidas
- Gestión de transacciones atómicas
- Recuperación de estados previos
- Logging detallado de acciones de rollback
- Sistema de snapshots de usuarios

.AUTHOR
Sistema AD_ADMIN - Automatic Rollback v1.0

.DATE
2025-08-28
#>

# Importar dependencias requeridas
Import-Module ActiveDirectory -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Variables globales del sistema de rollback
$Global:RollbackStateFile = "$env:TEMP\AD_ADMIN_RollbackState.json"
$Global:RollbackLogPath = "C:\Logs\AD_ADMIN\Rollback"
$Global:SnapshotPath = "C:\Logs\AD_ADMIN\Snapshots"
$Global:MaxRollbackAttempts = 3

#region Enums para Rollback

Add-Type -TypeDefinition @"
public enum RollbackOperationType {
    CreateUser,
    ModifyUser,
    DeleteUser,
    AddToGroup,
    RemoveFromGroup,
    ChangePassword,
    MoveOU,
    SetAttribute,
    EnableDisableAccount
}

public enum RollbackStatus {
    Pending,
    InProgress,
    Completed,
    Failed,
    PartiallyCompleted
}

public enum SnapshotScope {
    UserOnly,
    UserWithGroups,
    UserWithGroupsAndPermissions,
    FullContext
}
"@

#endregion

#region Clases para Gestión de Rollback

class UserSnapshot {
    [string]$UserDN
    [string]$SamAccountName
    [string]$UserPrincipalName
    [hashtable]$Attributes
    [array]$GroupMemberships
    [string]$ParentOU
    [bool]$AccountEnabled
    [datetime]$SnapshotTime
    [string]$SnapshotId
    [SnapshotScope]$Scope
    
    UserSnapshot([string]$userIdentifier, [SnapshotScope]$snapshotScope) {
        $this.SnapshotId = [System.Guid]::NewGuid().ToString()
        $this.SnapshotTime = Get-Date
        $this.Scope = $snapshotScope
        $this.CaptureUserState($userIdentifier)
    }
    
    [void]CaptureUserState([string]$userIdentifier) {
        try {
            $user = Get-ADUser -Identity $userIdentifier -Properties * -ErrorAction Stop
            
            $this.UserDN = $user.DistinguishedName
            $this.SamAccountName = $user.SamAccountName
            $this.UserPrincipalName = $user.UserPrincipalName
            $this.ParentOU = ($user.DistinguishedName -split ',', 2)[1]
            $this.AccountEnabled = $user.Enabled
            
            # Capturar atributos principales
            $this.Attributes = @{
                GivenName = $user.GivenName
                Surname = $user.Surname
                DisplayName = $user.DisplayName
                Description = $user.Description
                Department = $user.Department
                Title = $user.Title
                Manager = $user.Manager
                Office = $user.Office
                EmployeeID = $user.EmployeeID
                EmailAddress = $user.EmailAddress
                TelephoneNumber = $user.TelephoneNumber
                Company = $user.Company
                PasswordNeverExpires = $user.PasswordNeverExpires
                PasswordNotRequired = $user.PasswordNotRequired
                CannotChangePassword = $user.CannotChangePassword
                AccountExpirationDate = $user.AccountExpirationDate
            }
            
            # Capturar membresías de grupo si está en el scope
            if ($this.Scope -ge [SnapshotScope]::UserWithGroups) {
                $this.GroupMemberships = @()
                $groups = Get-ADUser -Identity $userIdentifier -Properties MemberOf | Select-Object -ExpandProperty MemberOf
                foreach ($groupDN in $groups) {
                    try {
                        $group = Get-ADGroup -Identity $groupDN -Properties Name, GroupScope, GroupCategory
                        $this.GroupMemberships += @{
                            DN = $group.DistinguishedName
                            Name = $group.Name
                            Scope = $group.GroupScope.ToString()
                            Category = $group.GroupCategory.ToString()
                        }
                    }
                    catch {
                        Write-RollbackLog "Warning: Could not capture group details for $groupDN" -Level "WARNING"
                    }
                }
            }
            
            Write-RollbackLog "User snapshot captured successfully for $($this.SamAccountName) (ID: $($this.SnapshotId))" -Level "INFO"
        }
        catch {
            Write-RollbackLog "Error capturing user snapshot for $userIdentifier`: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
    
    [hashtable]RestoreUser() {
        $restoreResult = @{
            Success = $false
            ActionsPerformed = @()
            Errors = @()
        }
        
        try {
            Write-RollbackLog "Starting user restore from snapshot ID: $($this.SnapshotId)" -Level "INFO"
            
            # Verificar que el usuario existe
            $currentUser = Get-ADUser -Identity $this.SamAccountName -Properties * -ErrorAction SilentlyContinue
            
            if (-not $currentUser) {
                # El usuario no existe, necesitamos recrearlo (caso complejo)
                $restoreResult.Errors += "User does not exist - recreation required (not implemented in basic restore)"
                return $restoreResult
            }
            
            # Restaurar atributos básicos
            $attributesToSet = @{}
            foreach ($attr in $this.Attributes.Keys) {
                if ($null -ne $this.Attributes[$attr] -and $this.Attributes[$attr] -ne $currentUser.$attr) {
                    $attributesToSet[$attr] = $this.Attributes[$attr]
                }
            }
            
            if ($attributesToSet.Count -gt 0) {
                Set-ADUser -Identity $this.SamAccountName @attributesToSet -ErrorAction Stop
                $restoreResult.ActionsPerformed += "Updated $($attributesToSet.Count) user attributes"
                Write-RollbackLog "Restored $($attributesToSet.Count) attributes for user $($this.SamAccountName)" -Level "INFO"
            }
            
            # Restaurar estado de cuenta
            if ($this.AccountEnabled -ne $currentUser.Enabled) {
                if ($this.AccountEnabled) {
                    Enable-ADAccount -Identity $this.SamAccountName -ErrorAction Stop
                    $restoreResult.ActionsPerformed += "Account enabled"
                } else {
                    Disable-ADAccount -Identity $this.SamAccountName -ErrorAction Stop
                    $restoreResult.ActionsPerformed += "Account disabled"
                }
                Write-RollbackLog "Restored account enabled state to: $($this.AccountEnabled)" -Level "INFO"
            }
            
            # Restaurar membresías de grupo (si están en el snapshot)
            if ($this.Scope -ge [SnapshotScope]::UserWithGroups -and $null -ne $this.GroupMemberships) {
                $currentGroups = Get-ADUser -Identity $this.SamAccountName -Properties MemberOf | 
                    Select-Object -ExpandProperty MemberOf
                
                $snapshotGroupDNs = $this.GroupMemberships | ForEach-Object { $_.DN }
                
                # Eliminar de grupos que no estaban en el snapshot
                foreach ($currentGroupDN in $currentGroups) {
                    if ($currentGroupDN -notin $snapshotGroupDNs) {
                        try {
                            Remove-ADGroupMember -Identity $currentGroupDN -Members $this.SamAccountName -Confirm:$false -ErrorAction Stop
                            $restoreResult.ActionsPerformed += "Removed from group: $(Split-Path $currentGroupDN -Leaf)"
                            Write-RollbackLog "Removed user from group: $currentGroupDN" -Level "INFO"
                        }
                        catch {
                            $restoreResult.Errors += "Failed to remove from group $currentGroupDN`: $($_.Exception.Message)"
                        }
                    }
                }
                
                # Agregar a grupos que estaban en el snapshot
                foreach ($snapshotGroup in $this.GroupMemberships) {
                    if ($snapshotGroup.DN -notin $currentGroups) {
                        try {
                            Add-ADGroupMember -Identity $snapshotGroup.DN -Members $this.SamAccountName -ErrorAction Stop
                            $restoreResult.ActionsPerformed += "Added to group: $($snapshotGroup.Name)"
                            Write-RollbackLog "Added user to group: $($snapshotGroup.DN)" -Level "INFO"
                        }
                        catch {
                            $restoreResult.Errors += "Failed to add to group $($snapshotGroup.DN)`: $($_.Exception.Message)"
                        }
                    }
                }
            }
            
            # Verificar si necesita mover OU
            if ($currentUser.DistinguishedName -ne $this.UserDN) {
                try {
                    Move-ADObject -Identity $currentUser.DistinguishedName -TargetPath $this.ParentOU -ErrorAction Stop
                    $restoreResult.ActionsPerformed += "Moved to original OU: $($this.ParentOU)"
                    Write-RollbackLog "Moved user to original OU: $($this.ParentOU)" -Level "INFO"
                }
                catch {
                    $restoreResult.Errors += "Failed to move to original OU: $($_.Exception.Message)"
                }
            }
            
            if ($restoreResult.Errors.Count -eq 0) {
                $restoreResult.Success = $true
                Write-RollbackLog "User restore completed successfully for $($this.SamAccountName)" -Level "INFO"
            } else {
                Write-RollbackLog "User restore completed with errors for $($this.SamAccountName)" -Level "WARNING"
            }
            
        }
        catch {
            $restoreResult.Errors += "Critical error during restore: $($_.Exception.Message)"
            Write-RollbackLog "Critical error during user restore: $($_.Exception.Message)" -Level "ERROR"
        }
        
        return $restoreResult
    }
    
    [void]SaveSnapshot() {
        try {
            if (!(Test-Path $Global:SnapshotPath)) {
                New-Item -ItemType Directory -Path $Global:SnapshotPath -Force | Out-Null
            }
            
            $snapshotFile = Join-Path $Global:SnapshotPath "UserSnapshot_$($this.SnapshotId).json"
            $this | ConvertTo-Json -Depth 10 | Out-File -FilePath $snapshotFile -Encoding UTF8
            
            Write-RollbackLog "Snapshot saved to file: $snapshotFile" -Level "DEBUG"
        }
        catch {
            Write-RollbackLog "Error saving snapshot: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

class RollbackTransaction {
    [string]$TransactionId
    [string]$OperationType
    [datetime]$StartTime
    [RollbackStatus]$Status
    [array]$RollbackActions
    [array]$CompletedActions
    [array]$FailedActions
    [UserSnapshot]$PreOperationSnapshot
    [hashtable]$OperationContext
    [int]$RetryCount
    
    RollbackTransaction([string]$operationType, [hashtable]$context) {
        $this.TransactionId = [System.Guid]::NewGuid().ToString()
        $this.OperationType = $operationType
        $this.StartTime = Get-Date
        $this.Status = [RollbackStatus]::Pending
        $this.RollbackActions = @()
        $this.CompletedActions = @()
        $this.FailedActions = @()
        $this.OperationContext = $context
        $this.RetryCount = 0
    }
    
    [void]CreateSnapshot([string]$userIdentifier, [SnapshotScope]$scope) {
        try {
            $this.PreOperationSnapshot = [UserSnapshot]::new($userIdentifier, $scope)
            $this.PreOperationSnapshot.SaveSnapshot()
            Write-RollbackLog "Pre-operation snapshot created for transaction $($this.TransactionId)" -Level "INFO"
        }
        catch {
            Write-RollbackLog "Error creating snapshot for transaction $($this.TransactionId)`: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
    
    [void]AddRollbackAction([RollbackOperationType]$actionType, [hashtable]$actionData) {
        $rollbackAction = @{
            Id = [System.Guid]::NewGuid().ToString()
            Type = $actionType
            Data = $actionData
            Timestamp = Get-Date
            Status = "Pending"
        }
        
        $this.RollbackActions += $rollbackAction
        Write-RollbackLog "Added rollback action: $actionType for transaction $($this.TransactionId)" -Level "DEBUG"
    }
    
    [hashtable]ExecuteRollback() {
        $rollbackResult = @{
            Success = $false
            TotalActions = $this.RollbackActions.Count
            CompletedActions = 0
            FailedActions = 0
            Errors = @()
            Details = @()
        }
        
        try {
            Write-RollbackLog "Starting rollback execution for transaction $($this.TransactionId)" -Level "INFO"
            $this.Status = [RollbackStatus]::InProgress
            
            # Ejecutar acciones en orden inverso (LIFO)
            $reversedActions = [array]::Reverse($this.RollbackActions.Clone())
            
            foreach ($action in $reversedActions) {
                try {
                    Write-RollbackLog "Executing rollback action: $($action.Type) (ID: $($action.Id))" -Level "INFO"
                    
                    $actionResult = $this.ExecuteSingleRollbackAction($action)
                    
                    if ($actionResult.Success) {
                        $action.Status = "Completed"
                        $this.CompletedActions += $action
                        $rollbackResult.CompletedActions++
                        $rollbackResult.Details += "✓ $($action.Type): $($actionResult.Message)"
                    } else {
                        $action.Status = "Failed"
                        $action.Error = $actionResult.Error
                        $this.FailedActions += $action
                        $rollbackResult.FailedActions++
                        $rollbackResult.Errors += $actionResult.Error
                        $rollbackResult.Details += "✗ $($action.Type): $($actionResult.Error)"
                    }
                }
                catch {
                    $action.Status = "Failed"
                    $action.Error = $_.Exception.Message
                    $this.FailedActions += $action
                    $rollbackResult.FailedActions++
                    $rollbackResult.Errors += $_.Exception.Message
                    $rollbackResult.Details += "✗ $($action.Type): $($_.Exception.Message)"
                    Write-RollbackLog "Error executing rollback action $($action.Id)`: $($_.Exception.Message)" -Level "ERROR"
                }
            }
            
            # Determinar éxito del rollback
            if ($rollbackResult.FailedActions -eq 0) {
                $this.Status = [RollbackStatus]::Completed
                $rollbackResult.Success = $true
                Write-RollbackLog "Rollback completed successfully for transaction $($this.TransactionId)" -Level "INFO"
            } elseif ($rollbackResult.CompletedActions -gt 0) {
                $this.Status = [RollbackStatus]::PartiallyCompleted
                Write-RollbackLog "Rollback partially completed for transaction $($this.TransactionId)" -Level "WARNING"
            } else {
                $this.Status = [RollbackStatus]::Failed
                Write-RollbackLog "Rollback failed completely for transaction $($this.TransactionId)" -Level "ERROR"
            }
            
        }
        catch {
            $this.Status = [RollbackStatus]::Failed
            $rollbackResult.Errors += "Critical error during rollback: $($_.Exception.Message)"
            Write-RollbackLog "Critical error during rollback execution: $($_.Exception.Message)" -Level "ERROR"
        }
        
        return $rollbackResult
    }
    
    [hashtable]ExecuteSingleRollbackAction([hashtable]$action) {
        $actionResult = @{
            Success = $false
            Message = ""
            Error = ""
        }
        
        try {
            switch ([RollbackOperationType]$action.Type) {
                "CreateUser" {
                    # Para rollback de creación de usuario, eliminamos el usuario
                    $userIdentity = $action.Data.UserIdentity
                    Remove-ADUser -Identity $userIdentity -Confirm:$false -ErrorAction Stop
                    $actionResult.Success = $true
                    $actionResult.Message = "User $userIdentity deleted successfully"
                }
                
                "DeleteUser" {
                    # Para rollback de eliminación, restauramos desde snapshot
                    if ($null -ne $this.PreOperationSnapshot) {
                        $restoreResult = $this.PreOperationSnapshot.RestoreUser()
                        $actionResult.Success = $restoreResult.Success
                        $actionResult.Message = "User restored from snapshot"
                        if (-not $restoreResult.Success) {
                            $actionResult.Error = $restoreResult.Errors -join "; "
                        }
                    } else {
                        $actionResult.Error = "No snapshot available for user restoration"
                    }
                }
                
                "ModifyUser" {
                    # Restaurar atributos desde snapshot
                    if ($null -ne $this.PreOperationSnapshot) {
                        $restoreResult = $this.PreOperationSnapshot.RestoreUser()
                        $actionResult.Success = $restoreResult.Success
                        $actionResult.Message = "User attributes restored from snapshot"
                        if (-not $restoreResult.Success) {
                            $actionResult.Error = $restoreResult.Errors -join "; "
                        }
                    } else {
                        $actionResult.Error = "No snapshot available for attribute restoration"
                    }
                }
                
                "AddToGroup" {
                    # Para rollback de adición a grupo, remover del grupo
                    $groupIdentity = $action.Data.GroupIdentity
                    $userIdentity = $action.Data.UserIdentity
                    Remove-ADGroupMember -Identity $groupIdentity -Members $userIdentity -Confirm:$false -ErrorAction Stop
                    $actionResult.Success = $true
                    $actionResult.Message = "User removed from group $groupIdentity"
                }
                
                "RemoveFromGroup" {
                    # Para rollback de remoción de grupo, agregar al grupo
                    $groupIdentity = $action.Data.GroupIdentity
                    $userIdentity = $action.Data.UserIdentity
                    Add-ADGroupMember -Identity $groupIdentity -Members $userIdentity -ErrorAction Stop
                    $actionResult.Success = $true
                    $actionResult.Message = "User added back to group $groupIdentity"
                }
                
                "ChangePassword" {
                    # Restaurar contraseña anterior (si está disponible)
                    if ($action.Data.ContainsKey("PreviousPassword")) {
                        $userIdentity = $action.Data.UserIdentity
                        $securePassword = ConvertTo-SecureString $action.Data.PreviousPassword -AsPlainText -Force
                        Set-ADAccountPassword -Identity $userIdentity -NewPassword $securePassword -Reset -ErrorAction Stop
                        $actionResult.Success = $true
                        $actionResult.Message = "Password restored for user $userIdentity"
                    } else {
                        $actionResult.Error = "Previous password not available for restoration"
                    }
                }
                
                "MoveOU" {
                    # Mover de vuelta a la OU original
                    $userIdentity = $action.Data.UserIdentity
                    $originalOU = $action.Data.OriginalOU
                    Move-ADObject -Identity $userIdentity -TargetPath $originalOU -ErrorAction Stop
                    $actionResult.Success = $true
                    $actionResult.Message = "User moved back to original OU: $originalOU"
                }
                
                "SetAttribute" {
                    # Restaurar atributo a valor anterior
                    $userIdentity = $action.Data.UserIdentity
                    $attributeName = $action.Data.AttributeName
                    $originalValue = $action.Data.OriginalValue
                    
                    if ($null -eq $originalValue -or $originalValue -eq "") {
                        Set-ADUser -Identity $userIdentity -Clear $attributeName -ErrorAction Stop
                    } else {
                        Set-ADUser -Identity $userIdentity -Replace @{$attributeName = $originalValue} -ErrorAction Stop
                    }
                    
                    $actionResult.Success = $true
                    $actionResult.Message = "Attribute $attributeName restored for user $userIdentity"
                }
                
                "EnableDisableAccount" {
                    # Cambiar estado de cuenta al valor original
                    $userIdentity = $action.Data.UserIdentity
                    $originalState = $action.Data.OriginalEnabled
                    
                    if ($originalState) {
                        Enable-ADAccount -Identity $userIdentity -ErrorAction Stop
                        $actionResult.Message = "Account enabled for user $userIdentity"
                    } else {
                        Disable-ADAccount -Identity $userIdentity -ErrorAction Stop
                        $actionResult.Message = "Account disabled for user $userIdentity"
                    }
                    
                    $actionResult.Success = $true
                }
                
                default {
                    $actionResult.Error = "Unknown rollback action type: $($action.Type)"
                }
            }
        }
        catch {
            $actionResult.Error = $_.Exception.Message
        }
        
        return $actionResult
    }
    
    [void]SaveTransaction() {
        try {
            if (!(Test-Path $Global:RollbackLogPath)) {
                New-Item -ItemType Directory -Path $Global:RollbackLogPath -Force | Out-Null
            }
            
            $transactionFile = Join-Path $Global:RollbackLogPath "Transaction_$($this.TransactionId).json"
            
            # Convertir a hashtable para serialización JSON
            $transactionData = @{
                TransactionId = $this.TransactionId
                OperationType = $this.OperationType
                StartTime = $this.StartTime
                Status = $this.Status.ToString()
                RollbackActions = $this.RollbackActions
                CompletedActions = $this.CompletedActions
                FailedActions = $this.FailedActions
                OperationContext = $this.OperationContext
                RetryCount = $this.RetryCount
                SnapshotId = if ($null -ne $this.PreOperationSnapshot) { $this.PreOperationSnapshot.SnapshotId } else { $null }
            }
            
            $transactionData | ConvertTo-Json -Depth 10 | Out-File -FilePath $transactionFile -Encoding UTF8
            Write-RollbackLog "Transaction saved to file: $transactionFile" -Level "DEBUG"
        }
        catch {
            Write-RollbackLog "Error saving transaction: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

#endregion

#region Funciones Principales de Rollback

function New-RollbackTransaction {
    <#
    .SYNOPSIS
    Crea una nueva transacción de rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationType,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$OperationContext,
        
        [Parameter(Mandatory = $false)]
        [string]$UserIdentifier,
        
        [Parameter(Mandatory = $false)]
        [SnapshotScope]$SnapshotScope = [SnapshotScope]::UserWithGroups
    )
    
    try {
        Write-RollbackLog "Creating new rollback transaction for operation: $OperationType" -Level "INFO"
        
        $transaction = [RollbackTransaction]::new($OperationType, $OperationContext)
        
        # Crear snapshot si se proporciona identificador de usuario
        if (![string]::IsNullOrWhiteSpace($UserIdentifier)) {
            $transaction.CreateSnapshot($UserIdentifier, $SnapshotScope)
        }
        
        $transaction.SaveTransaction()
        
        Write-RollbackLog "Rollback transaction created successfully: $($transaction.TransactionId)" -Level "INFO"
        return $transaction
    }
    catch {
        Write-RollbackLog "Error creating rollback transaction: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Invoke-OperationRollback {
    <#
    .SYNOPSIS
    Ejecuta el rollback automático de una operación fallida
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation
    )
    
    $rollbackResult = @{
        Success = $false
        TransactionId = $null
        ActionsExecuted = 0
        Errors = @()
        Details = @()
    }
    
    try {
        Write-RollbackLog "Starting automatic rollback for operation: $($Operation.Id)" -Level "INFO"
        
        # Verificar que la operación tiene acciones de rollback
        if ($null -eq $Operation.RollbackActions -or $Operation.RollbackActions.Count -eq 0) {
            $rollbackResult.Errors += "No rollback actions available for operation"
            Write-RollbackLog "No rollback actions available for operation: $($Operation.Id)" -Level "WARNING"
            return $rollbackResult
        }
        
        # Crear transacción de rollback desde los datos de la operación
        $transaction = [RollbackTransaction]::new("AutomaticRollback", $Operation.Data)
        $rollbackResult.TransactionId = $transaction.TransactionId
        
        # Copiar acciones de rollback de la operación
        foreach ($rollbackAction in $Operation.RollbackActions) {
            $actionData = $rollbackAction.Data
            $actionType = [RollbackOperationType]$rollbackAction.Action
            $transaction.AddRollbackAction($actionType, $actionData)
        }
        
        # Ejecutar rollback
        $executionResult = $transaction.ExecuteRollback()
        
        $rollbackResult.Success = $executionResult.Success
        $rollbackResult.ActionsExecuted = $executionResult.CompletedActions
        $rollbackResult.Errors = $executionResult.Errors
        $rollbackResult.Details = $executionResult.Details
        
        # Guardar transacción actualizada
        $transaction.SaveTransaction()
        
        if ($rollbackResult.Success) {
            Write-RollbackLog "Automatic rollback completed successfully for operation: $($Operation.Id)" -Level "INFO"
        } else {
            Write-RollbackLog "Automatic rollback completed with errors for operation: $($Operation.Id)" -Level "ERROR"
        }
        
    }
    catch {
        $rollbackResult.Errors += "Critical error during rollback: $($_.Exception.Message)"
        Write-RollbackLog "Critical error during automatic rollback: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $rollbackResult
}

function Get-RollbackHistory {
    <#
    .SYNOPSIS
    Obtiene el historial de transacciones de rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Last = 50,
        
        [Parameter(Mandatory = $false)]
        [string]$TransactionId,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationType
    )
    
    try {
        Write-RollbackLog "Retrieving rollback history (Last: $Last)" -Level "INFO"
        
        if (!(Test-Path $Global:RollbackLogPath)) {
            Write-RollbackLog "No rollback history found - directory does not exist" -Level "WARNING"
            return @()
        }
        
        $transactionFiles = Get-ChildItem -Path $Global:RollbackLogPath -Filter "Transaction_*.json" | 
            Sort-Object LastWriteTime -Descending
        
        if ($PSBoundParameters.ContainsKey('TransactionId')) {
            $transactionFiles = $transactionFiles | Where-Object { $_.Name -like "*$TransactionId*" }
        }
        
        $transactions = @()
        
        foreach ($file in ($transactionFiles | Select-Object -First $Last)) {
            try {
                $transactionData = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                
                if ($PSBoundParameters.ContainsKey('OperationType') -and 
                    $transactionData.OperationType -ne $OperationType) {
                    continue
                }
                
                $transactions += [PSCustomObject]@{
                    TransactionId = $transactionData.TransactionId
                    OperationType = $transactionData.OperationType
                    StartTime = [datetime]$transactionData.StartTime
                    Status = $transactionData.Status
                    RollbackActionsCount = $transactionData.RollbackActions.Count
                    CompletedActionsCount = $transactionData.CompletedActions.Count
                    FailedActionsCount = $transactionData.FailedActions.Count
                    RetryCount = $transactionData.RetryCount
                    SnapshotId = $transactionData.SnapshotId
                }
            }
            catch {
                Write-RollbackLog "Error reading transaction file $($file.Name)`: $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        Write-RollbackLog "Retrieved $($transactions.Count) rollback transactions" -Level "INFO"
        return $transactions
    }
    catch {
        Write-RollbackLog "Error retrieving rollback history: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-RollbackSystem {
    <#
    .SYNOPSIS
    Prueba la funcionalidad del sistema de rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    $testResults = @{
        OverallSuccess = $true
        Tests = @()
        Summary = @{
            Total = 0
            Passed = 0
            Failed = 0
        }
    }
    
    Write-RollbackLog "Starting rollback system tests" -Level "INFO"
    
    # Test 1: Verificar directorios necesarios
    $test1 = @{
        Name = "Directory Structure"
        Success = $true
        Details = @()
        Errors = @()
    }
    
    try {
        $requiredPaths = @($Global:RollbackLogPath, $Global:SnapshotPath)
        foreach ($path in $requiredPaths) {
            if (!(Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                $test1.Details += "Created directory: $path"
            } else {
                $test1.Details += "Directory exists: $path"
            }
        }
    }
    catch {
        $test1.Success = $false
        $test1.Errors += "Error checking/creating directories: $($_.Exception.Message)"
    }
    
    $testResults.Tests += $test1
    
    # Test 2: Crear y guardar snapshot de prueba
    $test2 = @{
        Name = "Snapshot Creation"
        Success = $true
        Details = @()
        Errors = @()
    }
    
    try {
        # Buscar un usuario existente para hacer snapshot
        $testUser = Get-ADUser -Filter "Enabled -eq 'True'" -ResultSetSize 1 -ErrorAction Stop
        
        if ($testUser) {
            $snapshot = [UserSnapshot]::new($testUser.SamAccountName, [SnapshotScope]::UserWithGroups)
            $snapshot.SaveSnapshot()
            $test2.Details += "Created snapshot for user: $($testUser.SamAccountName)"
            $test2.Details += "Snapshot ID: $($snapshot.SnapshotId)"
        } else {
            $test2.Success = $false
            $test2.Errors += "No enabled users found for snapshot test"
        }
    }
    catch {
        $test2.Success = $false
        $test2.Errors += "Error creating snapshot: $($_.Exception.Message)"
    }
    
    $testResults.Tests += $test2
    
    # Test 3: Crear transacción de prueba
    $test3 = @{
        Name = "Transaction Creation"
        Success = $true
        Details = @()
        Errors = @()
    }
    
    try {
        $testContext = @{
            TestOperation = "RollbackSystemTest"
            Timestamp = Get-Date
        }
        
        $transaction = [RollbackTransaction]::new("TestOperation", $testContext)
        $transaction.AddRollbackAction([RollbackOperationType]::SetAttribute, @{
            UserIdentity = "TestUser"
            AttributeName = "Description"
            OriginalValue = "Original Description"
        })
        
        $transaction.SaveTransaction()
        $test3.Details += "Created test transaction: $($transaction.TransactionId)"
        $test3.Details += "Added test rollback action"
    }
    catch {
        $test3.Success = $false
        $test3.Errors += "Error creating transaction: $($_.Exception.Message)"
    }
    
    $testResults.Tests += $test3
    
    # Calcular estadísticas
    $testResults.Summary.Total = $testResults.Tests.Count
    $testResults.Summary.Passed = ($testResults.Tests | Where-Object { $_.Success }).Count
    $testResults.Summary.Failed = ($testResults.Tests | Where-Object { -not $_.Success }).Count
    $testResults.OverallSuccess = ($testResults.Summary.Failed -eq 0)
    
    Write-RollbackLog "Rollback system tests completed. Passed: $($testResults.Summary.Passed)/$($testResults.Summary.Total)" -Level "INFO"
    
    return $testResults
}

function Invoke-PipelineOperation {
    <#
    .SYNOPSIS
    Ejecuta una operación individual dentro del pipeline con rollback automático
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )
    
    $operationResult = @{
        Success = $false
        Operation = $Operation
        Error = $null
        RollbackExecuted = $false
    }
    
    try {
        Write-RollbackLog "Starting pipeline operation: $($Operation.Type) for $($Operation.Data.DNI)" -Level "INFO"
        
        # Crear transacción de rollback si es necesario
        if ($Operation.Data.ContainsKey('DNI')) {
            try {
                $userIdentifier = $Operation.Data.DNI
                $existingUser = Get-ADUser -Filter "EmployeeID -eq '$userIdentifier'" -ErrorAction SilentlyContinue
                
                if ($existingUser) {
                    $transaction = New-RollbackTransaction -OperationType $Operation.Type -OperationContext $Operation.Data -UserIdentifier $existingUser.SamAccountName
                } else {
                    $transaction = New-RollbackTransaction -OperationType $Operation.Type -OperationContext $Operation.Data
                }
            }
            catch {
                Write-RollbackLog "Warning: Could not create rollback transaction for $($Operation.Data.DNI): $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        # Simular la ejecución de operación (aquí se integraría con el sistema real)
        $operationSuccess = Invoke-MockOperation -Operation $Operation
        
        if ($operationSuccess) {
            $Operation.UpdateStatus([PipelineOperationStatus]::Completed, [PipelineCheckpoint]::Completed)
            $operationResult.Success = $true
            Write-RollbackLog "Pipeline operation completed successfully: $($Operation.Data.DNI)" -Level "INFO"
        } else {
            $Operation.UpdateStatus([PipelineOperationStatus]::Failed, $Operation.Checkpoint)
            $Operation.AddError("Mock operation failed")
            $operationResult.Error = "Mock operation failed"
            throw "Operation execution failed"
        }
        
    }
    catch {
        $operationResult.Error = $_.Exception.Message
        Write-RollbackLog "Pipeline operation failed: $($_.Exception.Message)" -Level "ERROR"
        
        # La función que llama se encargará del rollback usando Invoke-OperationRollback
    }
    
    return $operationResult
}

function Invoke-MockOperation {
    <#
    .SYNOPSIS
    Función de prueba que simula operaciones reales (para testing)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation
    )
    
    # Simular operación - en producción esto se reemplazaría por lógica real
    $random = Get-Random -Minimum 1 -Maximum 10
    
    # 90% de éxito para simular operaciones reales
    return ($random -le 9)
}

#endregion

#region Funciones de Logging

function Write-RollbackLog {
    <#
    .SYNOPSIS
    Función de logging específica para el sistema de rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Escribir a consola con colores
    $color = switch ($Level) {
        "DEBUG" { "DarkGray" }
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    
    Write-Host "[$timestamp] [ROLLBACK] [$Level] $Message" -ForegroundColor $color
    
    # Escribir a archivo de log
    try {
        if (!(Test-Path $Global:RollbackLogPath)) {
            New-Item -ItemType Directory -Path $Global:RollbackLogPath -Force | Out-Null
        }
        
        $logFile = Join-Path $Global:RollbackLogPath "Rollback_$(Get-Date -Format 'yyyyMMdd').log"
        $logLine = "[$timestamp] [ROLLBACK] [$Level] $Message"
        
        Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Could not write to rollback log file: $($_.Exception.Message)"
    }
}

#endregion

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'New-RollbackTransaction',
    'Invoke-OperationRollback', 
    'Get-RollbackHistory',
    'Test-RollbackSystem',
    'Invoke-PipelineOperation',
    'Write-RollbackLog'
)

# Mensaje de inicialización
Write-Host "Automatic Rollback System v1.0 loaded successfully" -ForegroundColor Green
Write-Host "Available functions: New-RollbackTransaction, Invoke-OperationRollback, Get-RollbackHistory, Test-RollbackSystem" -ForegroundColor Cyan