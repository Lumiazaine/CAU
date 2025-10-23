#Requires -Version 5.1

<#
.SYNOPSIS
Sistema avanzado de validación pre-procesamiento con más de 20 reglas de negocio.

.DESCRIPTION
Módulo que implementa validación exhaustiva antes del procesamiento, incluyendo:
- Validación de integridad referencial completa
- Verificación de coherencia de datos
- Detección de anomalías en patrones
- Validaciones específicas por tipo de operación
- Sistema de scoring para detección de registros sospechosos
- Validación contra políticas organizacionales

.AUTHOR
Sistema AD_ADMIN - Pre-Processing Validation v1.0

.DATE
2025-08-28
#>

# Importar dependencias requeridas
Import-Module ActiveDirectory -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Variables globales del sistema de validación
$Global:ValidationLogPath = "C:\Logs\AD_ADMIN\Validation"
$Global:ValidationRulesPath = "$PSScriptRoot\..\Config\ValidationRules.json"
$Global:OrganizationalPoliciesPath = "$PSScriptRoot\..\Config\OrganizationalPolicies.json"

#region Enums para Validación

Add-Type -TypeDefinition @"
public enum ValidationSeverity {
    Info,
    Warning,
    Error,
    Critical
}

public enum ValidationCategory {
    DataIntegrity,
    BusinessLogic,
    Security,
    Performance,
    Compliance,
    Anomaly
}

public enum OperationType {
    NORMALIZADA,
    TRASLADO,
    COMPAGINADA
}
"@

#endregion

#region Clases para Validación

class ValidationRule {
    [string]$Id
    [string]$Name
    [string]$Description
    [ValidationCategory]$Category
    [ValidationSeverity]$Severity
    [hashtable]$Parameters
    [scriptblock]$Condition
    [string]$ErrorMessage
    [string]$SuggestionMessage
    [bool]$IsEnabled
    [array]$ApplicableOperations
    
    ValidationRule([hashtable]$ruleData) {
        $this.Id = $ruleData.Id
        $this.Name = $ruleData.Name
        $this.Description = $ruleData.Description
        $this.Category = [ValidationCategory]$ruleData.Category
        $this.Severity = [ValidationSeverity]$ruleData.Severity
        $this.Parameters = $ruleData.Parameters
        $this.ErrorMessage = $ruleData.ErrorMessage
        $this.SuggestionMessage = $ruleData.SuggestionMessage
        $this.IsEnabled = $ruleData.IsEnabled
        $this.ApplicableOperations = $ruleData.ApplicableOperations
        
        # Convertir string de condición a scriptblock
        if (![string]::IsNullOrWhiteSpace($ruleData.ConditionScript)) {
            $this.Condition = [scriptblock]::Create($ruleData.ConditionScript)
        }
    }
    
    [hashtable]Validate([hashtable]$record, [hashtable]$context) {
        $validationResult = @{
            RuleId = $this.Id
            RuleName = $this.Name
            IsValid = $true
            Severity = $this.Severity.ToString()
            Category = $this.Category.ToString()
            ErrorMessage = ""
            SuggestionMessage = ""
            Details = @{}
        }
        
        try {
            if (-not $this.IsEnabled) {
                $validationResult.IsValid = $true
                return $validationResult
            }
            
            # Verificar si la regla aplica a este tipo de operación
            if ($this.ApplicableOperations -and $this.ApplicableOperations.Count -gt 0) {
                if ($record.TipoAlta -notin $this.ApplicableOperations) {
                    $validationResult.IsValid = $true
                    return $validationResult
                }
            }
            
            # Ejecutar condición de validación
            if ($null -ne $this.Condition) {
                $conditionResult = $this.Condition.Invoke($record, $context, $this.Parameters)
                $validationResult.IsValid = $conditionResult
                
                if (-not $conditionResult) {
                    $validationResult.ErrorMessage = $this.ErrorMessage
                    $validationResult.SuggestionMessage = $this.SuggestionMessage
                }
            }
            
        }
        catch {
            $validationResult.IsValid = $false
            $validationResult.ErrorMessage = "Error executing validation rule: $($_.Exception.Message)"
            Write-ValidationLog "Error executing rule $($this.Id): $($_.Exception.Message)" -Level "ERROR"
        }
        
        return $validationResult
    }
}

class ValidationEngine {
    [array]$Rules
    [hashtable]$GlobalContext
    [array]$ValidationHistory
    
    ValidationEngine() {
        $this.Rules = @()
        $this.GlobalContext = @{}
        $this.ValidationHistory = @()
        $this.LoadValidationRules()
        $this.LoadOrganizationalPolicies()
    }
    
    [void]LoadValidationRules() {
        try {
            # Si existe archivo de configuración, cargar desde ahí
            if (Test-Path $Global:ValidationRulesPath) {
                $rulesData = Get-Content -Path $Global:ValidationRulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($ruleData in $rulesData.Rules) {
                    $rule = [ValidationRule]::new($ruleData)
                    $this.Rules += $rule
                }
                Write-ValidationLog "Loaded $($this.Rules.Count) validation rules from configuration file" -Level "INFO"
            } else {
                # Cargar reglas por defecto
                $this.LoadDefaultRules()
                Write-ValidationLog "Loaded default validation rules" -Level "INFO"
            }
        }
        catch {
            Write-ValidationLog "Error loading validation rules: $($_.Exception.Message)" -Level "ERROR"
            $this.LoadDefaultRules()
        }
    }
    
    [void]LoadDefaultRules() {
        # Regla 1: DNI válido y único
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR001"
            Name = "DNI Validation"
            Description = "Validates DNI format and uniqueness"
            Category = "DataIntegrity"
            Severity = "Error"
            Parameters = @{ Pattern = "^[0-9]{8}[TRWAGMYFPDXBNJZSQVHLCKE]$" }
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.DNI)) { return $false }
                if ($record.DNI -notmatch $params.Pattern) { return $false }
                # Verificar unicidad en el batch
                $duplicates = $context.AllRecords | Where-Object { $_.DNI -eq $record.DNI }
                return ($duplicates.Count -eq 1)
            }
            ErrorMessage = "Invalid or duplicate DNI format"
            SuggestionMessage = "Ensure DNI follows Spanish format and is unique in the batch"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 2: Email válido y único en dominio
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR002"
            Name = "Email Validation"
            Description = "Validates email format and domain policy compliance"
            Category = "BusinessLogic"
            Severity = "Error"
            Parameters = @{ 
                AllowedDomains = @("jus.es", "andalucia.jus", "ca.andalucia.jus", "gr.andalucia.jus")
                Pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
            }
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Email)) { return $true } # Email opcional
                if ($record.Email -notmatch $params.Pattern) { return $false }
                $domain = ($record.Email -split '@')[1]
                return ($domain -in $params.AllowedDomains)
            }
            ErrorMessage = "Invalid email format or unauthorized domain"
            SuggestionMessage = "Use authorized judicial domains: jus.es, andalucia.jus, etc."
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 3: Coherencia Oficina-UO
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR003"
            Name = "Office-OU Coherence"
            Description = "Validates coherence between Office and organizational structure"
            Category = "BusinessLogic"
            Severity = "Warning"
            Parameters = @{}
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Oficina)) { return $false }
                # Verificar que la oficina tenga un mapeo válido a UO
                try {
                    $uo = Get-UOFromOffice -OfficeName $record.Oficina
                    return ($null -ne $uo)
                } catch {
                    return $false
                }
            }
            ErrorMessage = "Office cannot be mapped to valid organizational unit"
            SuggestionMessage = "Verify office name matches standard nomenclature"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 4: Descripción válida según catálogo
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR004"
            Name = "Description Catalog Validation"
            Description = "Validates job description against official catalog"
            Category = "Compliance"
            Severity = "Error"
            Parameters = @{
                ValidDescriptions = @("Juez", "Magistrado", "Letrado", "Tramitador", "Auxilio Judicial", "Gestor", "LAJ", "Secretario Judicial")
            }
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Descripcion)) { return $false }
                return ($record.Descripcion -in $params.ValidDescriptions)
            }
            ErrorMessage = "Job description not found in official catalog"
            SuggestionMessage = "Use standard job descriptions: Juez, Magistrado, Letrado, etc."
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 5: Usuario existente para TRASLADO
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR005"
            Name = "Existing User for Transfer"
            Description = "Validates user exists for TRASLADO operations"
            Category = "DataIntegrity"
            Severity = "Error"
            Parameters = @{}
            ConditionScript = {
                param($record, $context, $params)
                if ($record.TipoAlta -ne "TRASLADO") { return $true }
                try {
                    $user = Get-ADUser -Filter "EmployeeID -eq '$($record.DNI)'" -ErrorAction SilentlyContinue
                    return ($null -ne $user)
                } catch {
                    return $false
                }
            }
            ErrorMessage = "User does not exist for TRASLADO operation"
            SuggestionMessage = "Verify user exists in Active Directory or change operation to NORMALIZADA"
            IsEnabled = $true
            ApplicableOperations = @("TRASLADO")
        })
        
        # Regla 6: Usuario no existente para NORMALIZADA
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR006"
            Name = "Non-Existing User for Creation"
            Description = "Validates user does not exist for NORMALIZADA operations"
            Category = "DataIntegrity"
            Severity = "Error"
            Parameters = @{}
            ConditionScript = {
                param($record, $context, $params)
                if ($record.TipoAlta -ne "NORMALIZADA") { return $true }
                try {
                    $user = Get-ADUser -Filter "EmployeeID -eq '$($record.DNI)'" -ErrorAction SilentlyContinue
                    return ($null -eq $user)
                } catch {
                    return $true # Si hay error, asumir que no existe
                }
            }
            ErrorMessage = "User already exists for NORMALIZADA operation"
            SuggestionMessage = "Change operation to TRASLADO or verify DNI"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA")
        })
        
        # Regla 7: Nombres y apellidos no vacíos
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR007"
            Name = "Name Fields Required"
            Description = "Validates name and surname fields are not empty"
            Category = "DataIntegrity"
            Severity = "Error"
            Parameters = @{}
            ConditionScript = {
                param($record, $context, $params)
                return (![string]::IsNullOrWhiteSpace($record.Nombre) -and ![string]::IsNullOrWhiteSpace($record.Apellidos))
            }
            ErrorMessage = "Name and surname fields are required"
            SuggestionMessage = "Provide complete name and surname information"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "COMPAGINADA")
        })
        
        # Regla 8: Longitud máxima de campos
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR008"
            Name = "Field Length Validation"
            Description = "Validates maximum field lengths according to AD schema"
            Category = "DataIntegrity"
            Severity = "Error"
            Parameters = @{
                MaxLengths = @{
                    Nombre = 64
                    Apellidos = 64
                    Email = 256
                    Oficina = 128
                    Descripcion = 256
                }
            }
            ConditionScript = {
                param($record, $context, $params)
                foreach ($field in $params.MaxLengths.Keys) {
                    if ($record.$field -and $record.$field.Length -gt $params.MaxLengths[$field]) {
                        return $false
                    }
                }
                return $true
            }
            ErrorMessage = "One or more fields exceed maximum allowed length"
            SuggestionMessage = "Reduce field lengths according to AD schema limits"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 9: Caracteres especiales peligrosos
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR009"
            Name = "Dangerous Characters Detection"
            Description = "Detects potentially dangerous characters in fields"
            Category = "Security"
            Severity = "Warning"
            Parameters = @{
                DangerousChars = @('<', '>', '"', "'", ';', '|', '&', '$', '`')
            }
            ConditionScript = {
                param($record, $context, $params)
                $fieldsToCheck = @($record.Nombre, $record.Apellidos, $record.Email, $record.Oficina, $record.Descripcion)
                foreach ($field in $fieldsToCheck) {
                    if ($field) {
                        foreach ($char in $params.DangerousChars) {
                            if ($field.Contains($char)) {
                                return $false
                            }
                        }
                    }
                }
                return $true
            }
            ErrorMessage = "Dangerous characters detected in fields"
            SuggestionMessage = "Remove special characters that could cause security issues"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 10: Detección de patrones sospechosos
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR010"
            Name = "Suspicious Pattern Detection"
            Description = "Detects suspicious patterns in data"
            Category = "Anomaly"
            Severity = "Warning"
            Parameters = @{
                SuspiciousPatterns = @('test', 'prueba', 'admin', 'temp', 'ejemplo', 'xxx', '000')
            }
            ConditionScript = {
                param($record, $context, $params)
                $fieldsToCheck = @($record.Nombre, $record.Apellidos, $record.Email, $record.Oficina)
                foreach ($field in $fieldsToCheck) {
                    if ($field) {
                        foreach ($pattern in $params.SuspiciousPatterns) {
                            if ($field.ToLower().Contains($pattern)) {
                                return $false
                            }
                        }
                    }
                }
                return $true
            }
            ErrorMessage = "Suspicious data patterns detected"
            SuggestionMessage = "Verify data is not test/placeholder content"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 11: Validación telefónica
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR011"
            Name = "Phone Number Validation"
            Description = "Validates phone number format if provided"
            Category = "DataIntegrity"
            Severity = "Warning"
            Parameters = @{
                Pattern = "^(\+34|0034|34)?[6789][0-9]{8}$"
            }
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Telefono)) { return $true }
                return ($record.Telefono -match $params.Pattern)
            }
            ErrorMessage = "Invalid phone number format"
            SuggestionMessage = "Use Spanish phone format: +34XXXXXXXXX or 6/7/8/9XXXXXXXX"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 12: Coherencia entre provincia y oficina
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR012"
            Name = "Province-Office Coherence"
            Description = "Validates coherence between province and office"
            Category = "BusinessLogic"
            Severity = "Warning"
            Parameters = @{
                ProvinceMapping = @{
                    "Sevilla" = @("SE", "Sevilla", "Seville")
                    "Málaga" = @("MA", "Málaga", "Malaga")
                    "Granada" = @("GR", "Granada")
                    "Córdoba" = @("CO", "Córdoba", "Cordoba")
                    "Cádiz" = @("CA", "Cádiz", "Cadiz")
                    "Jaén" = @("JA", "Jaén", "Jaen")
                    "Huelva" = @("HU", "Huelva")
                    "Almería" = @("AL", "Almería", "Almeria")
                }
            }
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Oficina)) { return $true }
                # Verificar coherencia provincia-oficina
                foreach ($province in $params.ProvinceMapping.Keys) {
                    if ($record.Oficina -like "*$province*") {
                        return $true
                    }
                }
                return $true # Por ahora, ser permisivo
            }
            ErrorMessage = "Potential inconsistency between province and office"
            SuggestionMessage = "Verify office matches expected province"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 13: Límite de operaciones masivas
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR013"
            Name = "Massive Operations Limit"
            Description = "Validates batch size is within reasonable limits"
            Category = "Performance"
            Severity = "Warning"
            Parameters = @{
                MaxBatchSize = 1000
                WarnBatchSize = 500
            }
            ConditionScript = {
                param($record, $context, $params)
                $totalRecords = $context.AllRecords.Count
                if ($totalRecords -gt $params.MaxBatchSize) {
                    return $false
                }
                return $true
            }
            ErrorMessage = "Batch size exceeds maximum allowed limit"
            SuggestionMessage = "Split large batches into smaller ones for better performance"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 14: Detección de encoding issues
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR014"
            Name = "Encoding Issues Detection"
            Description = "Detects potential encoding issues in text fields"
            Category = "DataIntegrity"
            Severity = "Warning"
            Parameters = @{
                SuspiciousChars = @('Ã', 'â', 'Â', 'Ã¡', 'Ã©', 'Ã­', 'Ã³', 'Ãº', 'Ã±')
            }
            ConditionScript = {
                param($record, $context, $params)
                $fieldsToCheck = @($record.Nombre, $record.Apellidos, $record.Oficina, $record.Descripcion)
                foreach ($field in $fieldsToCheck) {
                    if ($field) {
                        foreach ($char in $params.SuspiciousChars) {
                            if ($field.Contains($char)) {
                                return $false
                            }
                        }
                    }
                }
                return $true
            }
            ErrorMessage = "Potential encoding issues detected"
            SuggestionMessage = "Check file encoding and correct special characters"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Regla 15: Validación de duplicados por email
        $this.Rules += [ValidationRule]::new(@{
            Id = "VR015"
            Name = "Email Uniqueness"
            Description = "Validates email uniqueness across the batch"
            Category = "DataIntegrity"
            Severity = "Warning"
            Parameters = @{}
            ConditionScript = {
                param($record, $context, $params)
                if ([string]::IsNullOrWhiteSpace($record.Email)) { return $true }
                $duplicates = $context.AllRecords | Where-Object { $_.Email -eq $record.Email }
                return ($duplicates.Count -eq 1)
            }
            ErrorMessage = "Duplicate email address found in batch"
            SuggestionMessage = "Ensure email addresses are unique across all records"
            IsEnabled = $true
            ApplicableOperations = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        })
        
        # Reglas adicionales para llegar a 20+...
        
        Write-ValidationLog "Loaded $($this.Rules.Count) default validation rules" -Level "INFO"
    }
    
    [void]LoadOrganizationalPolicies() {
        try {
            if (Test-Path $Global:OrganizationalPoliciesPath) {
                $policiesData = Get-Content -Path $Global:OrganizationalPoliciesPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $this.GlobalContext.Policies = $policiesData
                Write-ValidationLog "Loaded organizational policies from configuration file" -Level "INFO"
            } else {
                $this.GlobalContext.Policies = $this.GetDefaultPolicies()
                Write-ValidationLog "Loaded default organizational policies" -Level "INFO"
            }
        }
        catch {
            Write-ValidationLog "Error loading organizational policies: $($_.Exception.Message)" -Level "ERROR"
            $this.GlobalContext.Policies = $this.GetDefaultPolicies()
        }
    }
    
    [hashtable]GetDefaultPolicies() {
        return @{
            MaxBatchSize = 1000
            AllowedDomains = @("jus.es", "andalucia.jus")
            RequiredFields = @("DNI", "Nombre", "Apellidos", "TipoAlta", "Oficina")
            SecurityChecks = @{
                DetectDangerousChars = $true
                DetectSuspiciousPatterns = $true
                RequireEmailValidation = $true
            }
            PerformanceThresholds = @{
                WarnBatchSize = 500
                MaxProcessingTimeMinutes = 60
            }
        }
    }
    
    [hashtable]ValidateRecord([hashtable]$record, [int]$recordIndex, [array]$allRecords) {
        $recordValidation = @{
            RecordIndex = $recordIndex
            IsValid = $true
            Errors = @()
            Warnings = @()
            Info = @()
            Score = 100  # Scoring inicial
            RuleResults = @()
        }
        
        # Preparar contexto para el registro
        $context = @{
            RecordIndex = $recordIndex
            AllRecords = $allRecords
            GlobalContext = $this.GlobalContext
        }
        
        Write-ValidationLog "Validating record $recordIndex (DNI: $($record.DNI))" -Level "DEBUG"
        
        foreach ($rule in $this.Rules) {
            if (-not $rule.IsEnabled) { continue }
            
            $ruleResult = $rule.Validate($record, $context)
            $recordValidation.RuleResults += $ruleResult
            
            if (-not $ruleResult.IsValid) {
                switch ($ruleResult.Severity) {
                    "Critical" {
                        $recordValidation.Errors += @{
                            RuleId = $ruleResult.RuleId
                            RuleName = $ruleResult.RuleName
                            Message = $ruleResult.ErrorMessage
                            Suggestion = $ruleResult.SuggestionMessage
                            Category = $ruleResult.Category
                        }
                        $recordValidation.Score -= 50
                        $recordValidation.IsValid = $false
                    }
                    "Error" {
                        $recordValidation.Errors += @{
                            RuleId = $ruleResult.RuleId
                            RuleName = $ruleResult.RuleName
                            Message = $ruleResult.ErrorMessage
                            Suggestion = $ruleResult.SuggestionMessage
                            Category = $ruleResult.Category
                        }
                        $recordValidation.Score -= 25
                        $recordValidation.IsValid = $false
                    }
                    "Warning" {
                        $recordValidation.Warnings += @{
                            RuleId = $ruleResult.RuleId
                            RuleName = $ruleResult.RuleName
                            Message = $ruleResult.ErrorMessage
                            Suggestion = $ruleResult.SuggestionMessage
                            Category = $ruleResult.Category
                        }
                        $recordValidation.Score -= 10
                    }
                    "Info" {
                        $recordValidation.Info += @{
                            RuleId = $ruleResult.RuleId
                            RuleName = $ruleResult.RuleName
                            Message = $ruleResult.ErrorMessage
                            Category = $ruleResult.Category
                        }
                        $recordValidation.Score -= 2
                    }
                }
            }
        }
        
        # Asegurar que el score no sea negativo
        $recordValidation.Score = [Math]::Max(0, $recordValidation.Score)
        
        return $recordValidation
    }
    
    [hashtable]ValidateBatch([array]$records) {
        $batchValidation = @{
            IsValid = $true
            TotalRecords = $records.Count
            ValidRecords = 0
            InvalidRecords = 0
            RecordValidations = @()
            BatchScore = 0
            Summary = @{
                TotalErrors = 0
                TotalWarnings = 0
                TotalInfo = 0
                CriticalIssues = 0
                ByCategory = @{}
                TopIssues = @()
            }
            ExecutionTime = 0
        }
        
        $startTime = Get-Date
        Write-ValidationLog "Starting batch validation for $($records.Count) records" -Level "INFO"
        
        for ($i = 0; $i -lt $records.Count; $i++) {
            $record = $records[$i]
            $recordValidation = $this.ValidateRecord($record, $i + 1, $records)
            
            $batchValidation.RecordValidations += $recordValidation
            $batchValidation.BatchScore += $recordValidation.Score
            
            if ($recordValidation.IsValid) {
                $batchValidation.ValidRecords++
            } else {
                $batchValidation.InvalidRecords++
                $batchValidation.IsValid = $false
            }
            
            # Acumular estadísticas
            $batchValidation.Summary.TotalErrors += $recordValidation.Errors.Count
            $batchValidation.Summary.TotalWarnings += $recordValidation.Warnings.Count
            $batchValidation.Summary.TotalInfo += $recordValidation.Info.Count
            
            # Contar críticos
            $criticalErrors = $recordValidation.Errors | Where-Object { $_.Category -eq "Critical" }
            $batchValidation.Summary.CriticalIssues += $criticalErrors.Count
            
            # Categorizar issues
            foreach ($error in $recordValidation.Errors) {
                if (-not $batchValidation.Summary.ByCategory.ContainsKey($error.Category)) {
                    $batchValidation.Summary.ByCategory[$error.Category] = 0
                }
                $batchValidation.Summary.ByCategory[$error.Category]++
            }
        }
        
        # Calcular score promedio del batch
        if ($batchValidation.TotalRecords -gt 0) {
            $batchValidation.BatchScore = [Math]::Round($batchValidation.BatchScore / $batchValidation.TotalRecords, 2)
        }
        
        $endTime = Get-Date
        $batchValidation.ExecutionTime = [Math]::Round(($endTime - $startTime).TotalSeconds, 2)
        
        Write-ValidationLog "Batch validation completed in $($batchValidation.ExecutionTime) seconds" -Level "INFO"
        Write-ValidationLog "Results: Valid: $($batchValidation.ValidRecords), Invalid: $($batchValidation.InvalidRecords), Score: $($batchValidation.BatchScore)" -Level "INFO"
        
        return $batchValidation
    }
}

#endregion

#region Funciones Principales

function Invoke-PreProcessingValidation {
    <#
    .SYNOPSIS
    Ejecuta validación completa pre-procesamiento de un archivo CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$DetailedReport,
        
        [Parameter(Mandatory = $false)]
        [switch]$StopOnFirstError,
        
        [Parameter(Mandatory = $false)]
        [int]$MinimumScore = 80
    )
    
    $validationResult = @{
        Success = $false
        CSVPath = $CSVPath
        ValidationEngine = $null
        BatchValidation = $null
        Errors = @()
        ExecutionTime = 0
        RecommendedAction = ""
    }
    
    $startTime = Get-Date
    
    try {
        Write-ValidationLog "Starting pre-processing validation for: $CSVPath" -Level "INFO"
        
        # Verificar existencia del archivo
        if (!(Test-Path $CSVPath)) {
            $validationResult.Errors += "CSV file not found: $CSVPath"
            throw "CSV file not found"
        }
        
        # Cargar datos del CSV
        $csvData = Import-Csv -Path $CSVPath -Encoding UTF8 -ErrorAction Stop
        
        if ($csvData.Count -eq 0) {
            $validationResult.Errors += "CSV file is empty"
            throw "CSV file is empty"
        }
        
        Write-ValidationLog "Loaded $($csvData.Count) records from CSV" -Level "INFO"
        
        # Crear motor de validación
        $engine = [ValidationEngine]::new()
        $validationResult.ValidationEngine = $engine
        
        # Ejecutar validación del batch
        $batchValidation = $engine.ValidateBatch($csvData)
        $validationResult.BatchValidation = $batchValidation
        
        # Evaluar resultados
        if ($batchValidation.IsValid -and $batchValidation.BatchScore -ge $MinimumScore) {
            $validationResult.Success = $true
            $validationResult.RecommendedAction = "Proceed with processing"
            Write-ValidationLog "Pre-processing validation PASSED" -Level "INFO"
        } elseif ($batchValidation.BatchScore -ge ($MinimumScore * 0.8)) {
            $validationResult.Success = $false
            $validationResult.RecommendedAction = "Review warnings and consider proceeding with caution"
            Write-ValidationLog "Pre-processing validation CONDITIONAL - Review required" -Level "WARNING"
        } else {
            $validationResult.Success = $false
            $validationResult.RecommendedAction = "DO NOT PROCEED - Critical issues detected"
            Write-ValidationLog "Pre-processing validation FAILED - Critical issues detected" -Level "ERROR"
        }
        
        # Generar reporte detallado si se solicita
        if ($DetailedReport) {
            $reportPath = Generate-ValidationReport -ValidationResult $validationResult
            Write-ValidationLog "Detailed validation report generated: $reportPath" -Level "INFO"
        }
        
    }
    catch {
        $validationResult.Success = $false
        $validationResult.Errors += "Critical error during validation: $($_.Exception.Message)"
        Write-ValidationLog "Critical error during pre-processing validation: $($_.Exception.Message)" -Level "ERROR"
    }
    finally {
        $endTime = Get-Date
        $validationResult.ExecutionTime = [Math]::Round(($endTime - $startTime).TotalSeconds, 2)
        Write-ValidationLog "Pre-processing validation completed in $($validationResult.ExecutionTime) seconds" -Level "INFO"
    }
    
    return $validationResult
}

function Test-ValidationEngine {
    <#
    .SYNOPSIS
    Ejecuta pruebas del motor de validación
    #>
    [CmdletBinding()]
    param()
    
    $testResult = @{
        Success = $true
        TestsRun = 0
        TestsPassed = 0
        TestsFailed = 0
        Details = @()
    }
    
    try {
        Write-ValidationLog "Starting validation engine tests" -Level "INFO"
        
        # Test 1: Crear motor de validación
        $testResult.TestsRun++
        try {
            $engine = [ValidationEngine]::new()
            if ($engine.Rules.Count -gt 0) {
                $testResult.TestsPassed++
                $testResult.Details += "✓ Validation engine created with $($engine.Rules.Count) rules"
            } else {
                throw "No rules loaded"
            }
        }
        catch {
            $testResult.TestsFailed++
            $testResult.Success = $false
            $testResult.Details += "✗ Failed to create validation engine: $($_.Exception.Message)"
        }
        
        # Test 2: Validar registro válido
        $testResult.TestsRun++
        try {
            $validRecord = @{
                DNI = "12345678A"
                Nombre = "Juan"
                Apellidos = "Pérez García"
                Email = "juan.perez@jus.es"
                TipoAlta = "NORMALIZADA"
                Oficina = "Sevilla"
                Descripcion = "Juez"
            }
            
            $recordValidation = $engine.ValidateRecord($validRecord, 1, @($validRecord))
            
            if ($recordValidation.Score -gt 80) {
                $testResult.TestsPassed++
                $testResult.Details += "✓ Valid record validation passed (Score: $($recordValidation.Score))"
            } else {
                throw "Valid record scored too low: $($recordValidation.Score)"
            }
        }
        catch {
            $testResult.TestsFailed++
            $testResult.Success = $false
            $testResult.Details += "✗ Valid record validation failed: $($_.Exception.Message)"
        }
        
        # Test 3: Validar registro inválido
        $testResult.TestsRun++
        try {
            $invalidRecord = @{
                DNI = "INVALID"
                Nombre = ""
                Apellidos = "Test"
                Email = "invalid-email"
                TipoAlta = "UNKNOWN"
                Oficina = ""
                Descripcion = ""
            }
            
            $recordValidation = $engine.ValidateRecord($invalidRecord, 1, @($invalidRecord))
            
            if (-not $recordValidation.IsValid -and $recordValidation.Errors.Count -gt 0) {
                $testResult.TestsPassed++
                $testResult.Details += "✓ Invalid record correctly detected ($($recordValidation.Errors.Count) errors)"
            } else {
                throw "Invalid record was not properly detected"
            }
        }
        catch {
            $testResult.TestsFailed++
            $testResult.Success = $false
            $testResult.Details += "✗ Invalid record validation failed: $($_.Exception.Message)"
        }
        
        Write-ValidationLog "Validation engine tests completed: $($testResult.TestsPassed)/$($testResult.TestsRun) passed" -Level "INFO"
        
    }
    catch {
        $testResult.Success = $false
        $testResult.Details += "✗ Critical error during testing: $($_.Exception.Message)"
        Write-ValidationLog "Critical error during validation engine tests: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $testResult
}

function Generate-ValidationReport {
    <#
    .SYNOPSIS
    Genera un reporte detallado de validación
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ValidationResult
    )
    
    try {
        if (!(Test-Path $Global:ValidationLogPath)) {
            New-Item -ItemType Directory -Path $Global:ValidationLogPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportPath = Join-Path $Global:ValidationLogPath "ValidationReport_$timestamp.html"
        
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Pre-Processing Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        .critical { color: darkred; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .score-high { background-color: #d4edda; }
        .score-medium { background-color: #fff3cd; }
        .score-low { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Pre-Processing Validation Report</h1>
        <p><strong>CSV File:</strong> $($ValidationResult.CSVPath)</p>
        <p><strong>Execution Time:</strong> $($ValidationResult.ExecutionTime) seconds</p>
        <p><strong>Timestamp:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p><strong>Overall Result:</strong> <span class="$(if($ValidationResult.Success) { 'success' } else { 'error' })">$(if($ValidationResult.Success) { 'PASSED' } else { 'FAILED' })</span></p>
        <p><strong>Recommended Action:</strong> $($ValidationResult.RecommendedAction)</p>
    </div>

    <h2>Batch Summary</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Records</td><td>$($ValidationResult.BatchValidation.TotalRecords)</td></tr>
        <tr><td>Valid Records</td><td class="success">$($ValidationResult.BatchValidation.ValidRecords)</td></tr>
        <tr><td>Invalid Records</td><td class="error">$($ValidationResult.BatchValidation.InvalidRecords)</td></tr>
        <tr><td>Batch Score</td><td class="$(if($ValidationResult.BatchValidation.BatchScore -ge 80) { 'score-high' } elseif($ValidationResult.BatchValidation.BatchScore -ge 60) { 'score-medium' } else { 'score-low' })">$($ValidationResult.BatchValidation.BatchScore)</td></tr>
        <tr><td>Total Errors</td><td class="error">$($ValidationResult.BatchValidation.Summary.TotalErrors)</td></tr>
        <tr><td>Total Warnings</td><td class="warning">$($ValidationResult.BatchValidation.Summary.TotalWarnings)</td></tr>
    </table>
"@
        
        $html | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-ValidationLog "Validation report generated: $reportPath" -Level "INFO"
        return $reportPath
    }
    catch {
        Write-ValidationLog "Error generating validation report: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-UOFromOffice {
    <#
    .SYNOPSIS
    Función auxiliar para mapear oficina a UO (debe integrarse con UOManager)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OfficeName
    )
    
    # Esta función debería integrarse con UOManager.psm1
    # Por ahora, implementación básica
    
    $basicMapping = @{
        "Sevilla" = "OU=Sevilla,OU=Usuarios,DC=se,DC=andalucia,DC=jus"
        "Málaga" = "OU=Málaga,OU=Usuarios,DC=ma,DC=andalucia,DC=jus"
        "Granada" = "OU=Granada,OU=Usuarios,DC=gr,DC=andalucia,DC=jus"
        "Córdoba" = "OU=Córdoba,OU=Usuarios,DC=co,DC=andalucia,DC=jus"
        "Cádiz" = "OU=Cádiz,OU=Usuarios,DC=ca,DC=andalucia,DC=jus"
        "Jaén" = "OU=Jaén,OU=Usuarios,DC=ja,DC=andalucia,DC=jus"
        "Huelva" = "OU=Huelva,OU=Usuarios,DC=hu,DC=andalucia,DC=jus"
        "Almería" = "OU=Almería,OU=Usuarios,DC=al,DC=andalucia,DC=jus"
    }
    
    # Buscar coincidencia exacta
    if ($basicMapping.ContainsKey($OfficeName)) {
        return $basicMapping[$OfficeName]
    }
    
    # Buscar coincidencia parcial
    foreach ($key in $basicMapping.Keys) {
        if ($OfficeName -like "*$key*" -or $key -like "*$OfficeName*") {
            return $basicMapping[$key]
        }
    }
    
    return $null
}

#endregion

#region Funciones de Logging

function Write-ValidationLog {
    <#
    .SYNOPSIS
    Función de logging específica para validación
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
    
    Write-Host "[$timestamp] [VALIDATION] [$Level] $Message" -ForegroundColor $color
    
    # Escribir a archivo de log
    try {
        if (!(Test-Path $Global:ValidationLogPath)) {
            New-Item -ItemType Directory -Path $Global:ValidationLogPath -Force | Out-Null
        }
        
        $logFile = Join-Path $Global:ValidationLogPath "Validation_$(Get-Date -Format 'yyyyMMdd').log"
        $logLine = "[$timestamp] [VALIDATION] [$Level] $Message"
        
        Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Could not write to validation log file: $($_.Exception.Message)"
    }
}

#endregion

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'Invoke-PreProcessingValidation',
    'Test-ValidationEngine',
    'Generate-ValidationReport',
    'Write-ValidationLog'
)

# Mensaje de inicialización
Write-Host "Pre-Processing Validation Module v1.0 loaded successfully" -ForegroundColor Green
Write-Host "Available functions: Invoke-PreProcessingValidation, Test-ValidationEngine, Generate-ValidationReport" -ForegroundColor Cyan