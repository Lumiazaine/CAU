#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Módulo de auditoría y seguridad empresarial con logging blockchain-like
.DESCRIPTION
    Sistema de auditoría GDPR-compliant con integridad criptográfica,
    gestión de credenciales segura y compliance dashboard
.VERSION
    1.0 - Enterprise Security Framework
.COMPLIANCE
    GDPR, LOPD, ISO 27001, ENS (Esquema Nacional de Seguridad)
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

# Variables globales del módulo de seguridad
$script:AuditChain = @()
$script:SecurityConfig = @{
    AuditPath = "C:\SecureLogs\AD_ADMIN_Audit\"
    EncryptionKey = $null
    HashAlgorithm = "SHA256"
    MaxLogSize = 100MB
    RetentionDays = 2555  # 7 años para cumplimiento legal
    ComplianceMode = $true
}

# Configuración GDPR/LOPD
$script:GDPRConfig = @{
    DataController = "Consejería de Justicia - Junta de Andalucía"
    LegalBasis = "Art. 6.1.e GDPR - Misión de interés público"
    DataCategories = @("Identificadores", "Datos profesionales", "Datos organizativos")
    RetentionPeriod = "7 años (normativa administrativa)"
    DataSubjects = @("Empleados públicos", "Funcionarios", "Personal laboral")
}

function Initialize-AuditSecurityManager {
    <#
    .SYNOPSIS
        Inicializa el sistema de seguridad y auditoría empresarial
    .DESCRIPTION
        Configura logging seguro, directorio de auditoría, claves de cifrado
        y validaciones de cumplimiento normativo
    #>
    [CmdletBinding()]
    param(
        [string]$CustomAuditPath,
        [switch]$EnableEncryption,
        [switch]$EnableGDPRMode,
        [ValidateSet("Development", "Production", "Testing")]
        [string]$Environment = "Production"
    )
    
    $StartTime = Get-Date
    Write-Verbose "🔐 Inicializando Audit Security Manager v1.0..."
    
    try {
        # Configurar rutas de auditoría
        if ($CustomAuditPath) {
            $script:SecurityConfig.AuditPath = $CustomAuditPath
        }
        
        # Crear directorio seguro
        if (-not (Test-Path $script:SecurityConfig.AuditPath)) {
            $AuditDir = New-Item -Path $script:SecurityConfig.AuditPath -ItemType Directory -Force
            
            # Configurar permisos restrictivos (solo System y Administrators)
            $Acl = Get-Acl $AuditDir.FullName
            $Acl.SetAccessRuleProtection($true, $false)  # Remover herencia
            
            # Añadir permisos específicos
            $AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            
            $Acl.ResetAccessRule($AdminRule)
            $Acl.ResetAccessRule($SystemRule)
            Set-Acl -Path $AuditDir.FullName -AclObject $Acl
            
            Write-Verbose "📁 Directorio de auditoría seguro creado: $($script:SecurityConfig.AuditPath)"
        }
        
        # Inicializar cadena de auditoría con bloque génesis
        $GenesisBlock = @{
            BlockId = 0
            Timestamp = $StartTime
            PreviousHash = "0000000000000000000000000000000000000000000000000000000000000000"
            Data = @{
                Action = "AUDIT_GENESIS"
                Details = "Inicialización del sistema de auditoría"
                Environment = $Environment
                User = $env:USERNAME
                Computer = $env:COMPUTERNAME
                GDPRCompliant = $EnableGDPRMode.IsPresent
            }
            Hash = ""
            Nonce = 0
        }
        
        $GenesisBlock.Hash = Calculate-BlockHash -Block $GenesisBlock
        $script:AuditChain += $GenesisBlock
        
        # Configurar cifrado si está habilitado
        if ($EnableEncryption) {
            $script:SecurityConfig.EncryptionKey = Generate-EncryptionKey
            Write-Verbose "🔐 Cifrado habilitado para logs de auditoría"
        }
        
        # Configurar modo GDPR
        if ($EnableGDPRMode) {
            Write-Verbose "⚖️ Modo GDPR/LOPD activado - Cumplimiento normativo habilitado"
            Initialize-GDPRCompliance
        }
        
        # Validar integridad del sistema
        $IntegrityCheck = Test-SystemIntegrity
        if (-not $IntegrityCheck.IsValid) {
            throw "Fallo en verificación de integridad: $($IntegrityCheck.Issues -join '; ')"
        }
        
        # Crear entrada de auditoría de inicialización
        Add-AuditEntry -Action "SECURITY_MANAGER_INIT" -Details @"
Sistema de seguridad inicializado correctamente
Environment: $Environment
Encryption: $($EnableEncryption.IsPresent)
GDPR Mode: $($EnableGDPRMode.IsPresent)
Audit Path: $($script:SecurityConfig.AuditPath)
"@ -DataCategory "SystemEvent" -Severity "Info"
        
        $InitDuration = ((Get-Date) - $StartTime).TotalMilliseconds
        
        Write-Host "🔐 Audit Security Manager inicializado:" -ForegroundColor Green
        Write-Host "   📊 Ambiente: $Environment" -ForegroundColor Cyan
        Write-Host "   🔐 Cifrado: $($EnableEncryption.IsPresent)" -ForegroundColor Cyan
        Write-Host "   ⚖️ GDPR: $($EnableGDPRMode.IsPresent)" -ForegroundColor Cyan
        Write-Host "   ⏱️ Tiempo: $([math]::Round($InitDuration))ms" -ForegroundColor Cyan
        Write-Host "   🏗️ Bloques en cadena: $($script:AuditChain.Count)" -ForegroundColor Cyan
        
        return @{
            Success = $true
            Environment = $Environment
            EncryptionEnabled = $EnableEncryption.IsPresent
            GDPREnabled = $EnableGDPRMode.IsPresent
            AuditPath = $script:SecurityConfig.AuditPath
            InitDurationMs = $InitDuration
            ChainLength = $script:AuditChain.Count
        }
        
    }
    catch {
        Write-Error "💥 Error crítico inicializando Security Manager: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Add-AuditEntry {
    <#
    .SYNOPSIS
        Añade entrada de auditoría a la cadena blockchain-like
    .DESCRIPTION
        Crea bloque de auditoría con hash criptográfico, timestamp preciso
        y validación de integridad de la cadena
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,
        
        [Parameter(Mandatory=$true)]
        [string]$Details,
        
        [ValidateSet("UserData", "SystemEvent", "SecurityEvent", "ComplianceEvent")]
        [string]$DataCategory = "SystemEvent",
        
        [ValidateSet("Critical", "High", "Medium", "Low", "Info")]
        [string]$Severity = "Info",
        
        [hashtable]$AdditionalData = @{},
        
        [string]$AffectedUser = "",
        
        [switch]$RequireIntegrityValidation
    )
    
    try {
        $Timestamp = Get-Date
        $BlockId = $script:AuditChain.Count
        
        # Obtener hash del bloque anterior
        $PreviousHash = if ($BlockId -gt 0) { 
            $script:AuditChain[-1].Hash 
        } else { 
            "0000000000000000000000000000000000000000000000000000000000000000" 
        }
        
        # Validar integridad de la cadena antes de añadir
        if ($RequireIntegrityValidation -and -not (Test-ChainIntegrity)) {
            throw "Integridad de cadena comprometida - no se puede añadir entrada"
        }
        
        # Crear datos del bloque con información completa
        $BlockData = @{
            Action = $Action
            Details = $Details
            DataCategory = $DataCategory
            Severity = $Severity
            User = $env:USERNAME
            Computer = $env:COMPUTERNAME
            ProcessId = $PID
            SessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
            AffectedUser = $AffectedUser
            IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Dhcp"} | Select-Object -First 1).IPAddress
            AdditionalData = $AdditionalData
        }
        
        # Añadir metadatos GDPR si está en modo compliance
        if ($script:SecurityConfig.ComplianceMode) {
            $BlockData.GDPR = @{
                DataController = $script:GDPRConfig.DataController
                LegalBasis = $script:GDPRConfig.LegalBasis
                DataCategory = $DataCategory
                RetentionUntil = $Timestamp.AddDays($script:SecurityConfig.RetentionDays)
                ProcessingPurpose = "Gestión administrativa de usuarios AD"
            }
        }
        
        # Crear bloque de auditoría
        $AuditBlock = @{
            BlockId = $BlockId
            Timestamp = $Timestamp
            PreviousHash = $PreviousHash
            Data = $BlockData
            Hash = ""
            Nonce = 0
        }
        
        # Calcular hash del bloque (simulando proof-of-work ligero)
        $AuditBlock.Hash = Calculate-BlockHash -Block $AuditBlock
        
        # Añadir a la cadena
        $script:AuditChain += $AuditBlock
        
        # Persistir en disco si es necesario
        if ($script:AuditChain.Count % 10 -eq 0) {  # Cada 10 bloques
            Save-AuditChain
        }
        
        # Log de seguridad crítica para eventos de alta severidad
        if ($Severity -in @("Critical", "High")) {
            Write-EventLog -LogName "Application" -Source "AD_ADMIN_Security" -EventId 1001 -EntryType Warning -Message @"
AD_ADMIN Security Event
Action: $Action
Severity: $Severity
User: $($BlockData.User)
Details: $Details
Block ID: $BlockId
"@
        }
        
        Write-Verbose "🔗 Bloque de auditoría añadido: ID=$BlockId, Hash=$($AuditBlock.Hash.Substring(0,8))..."
        
        return @{
            Success = $true
            BlockId = $BlockId
            Hash = $AuditBlock.Hash
            Timestamp = $Timestamp
        }
        
    }
    catch {
        Write-Error "💥 Error añadiendo entrada de auditoría: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Calculate-BlockHash {
    <#
    .SYNOPSIS
        Calcula hash criptográfico SHA256 del bloque
    #>
    param($Block)
    
    # Crear string canónico del bloque (excluyendo Hash y Nonce para el cálculo)
    $BlockString = @(
        $Block.BlockId
        $Block.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $Block.PreviousHash
        ($Block.Data | ConvertTo-Json -Compress -Depth 5)
        $Block.Nonce
    ) -join "|"
    
    # Calcular SHA256
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($BlockString))
    $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    
    $hasher.Dispose()
    return $hashString.ToLower()
}

function Test-ChainIntegrity {
    <#
    .SYNOPSIS
        Valida la integridad completa de la cadena de auditoría
    #>
    [CmdletBinding()]
    param()
    
    if ($script:AuditChain.Count -eq 0) {
        return $true  # Cadena vacía es válida
    }
    
    Write-Verbose "🔍 Validando integridad de cadena de auditoría ($($script:AuditChain.Count) bloques)..."
    
    for ($i = 0; $i -lt $script:AuditChain.Count; $i++) {
        $Block = $script:AuditChain[$i]
        
        # Validar hash del bloque
        $CalculatedHash = Calculate-BlockHash -Block $Block
        if ($Block.Hash -ne $CalculatedHash) {
            Write-Warning "🚨 Hash inválido en bloque $i`: Expected=$($Block.Hash), Calculated=$CalculatedHash"
            return $false
        }
        
        # Validar enlace con bloque anterior
        if ($i -gt 0) {
            $PreviousBlock = $script:AuditChain[$i-1]
            if ($Block.PreviousHash -ne $PreviousBlock.Hash) {
                Write-Warning "🚨 Enlace roto entre bloques $($i-1) y $i"
                return $false
            }
        }
        
        # Validar timestamp secuencial
        if ($i -gt 0) {
            $PreviousBlock = $script:AuditChain[$i-1]
            if ($Block.Timestamp -lt $PreviousBlock.Timestamp) {
                Write-Warning "🚨 Timestamp no secuencial en bloque $i"
                return $false
            }
        }
    }
    
    Write-Verbose "✅ Integridad de cadena validada correctamente"
    return $true
}

function Save-AuditChain {
    <#
    .SYNOPSIS
        Persiste la cadena de auditoría en disco con cifrado opcional
    #>
    [CmdletBinding()]
    param([switch]$Force)
    
    try {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $FileName = "AuditChain_$Timestamp.json"
        $FilePath = Join-Path $script:SecurityConfig.AuditPath $FileName
        
        # Preparar datos para serialización
        $AuditData = @{
            Metadata = @{
                CreatedAt = Get-Date
                Version = "1.0"
                ChainLength = $script:AuditChain.Count
                Environment = $env:COMPUTERNAME
                ComplianceMode = $script:SecurityConfig.ComplianceMode
                GDPRInfo = if ($script:SecurityConfig.ComplianceMode) { $script:GDPRConfig } else { $null }
            }
            Chain = $script:AuditChain
            IntegrityHash = (Calculate-ChainIntegrityHash)
        }
        
        $JsonData = $AuditData | ConvertTo-Json -Depth 10
        
        # Cifrar si está configurado
        if ($script:SecurityConfig.EncryptionKey) {
            $JsonData = Protect-AuditData -Data $JsonData -Key $script:SecurityConfig.EncryptionKey
        }
        
        # Guardar en disco
        $JsonData | Out-File -FilePath $FilePath -Encoding UTF8 -Force
        
        # Validar que se guardó correctamente
        if (Test-Path $FilePath) {
            $FileSize = (Get-Item $FilePath).Length
            Write-Verbose "💾 Cadena de auditoría guardada: $FileName ($([math]::Round($FileSize/1KB, 2)) KB)"
            
            # Rotar logs si excede el tamaño máximo
            if ($FileSize -gt $script:SecurityConfig.MaxLogSize) {
                Compress-AuditLogs
            }
            
            return @{
                Success = $true
                FilePath = $FilePath
                FileSize = $FileSize
                ChainLength = $script:AuditChain.Count
            }
        }
        else {
            throw "Archivo no fue creado correctamente"
        }
    }
    catch {
        Write-Error "💥 Error guardando cadena de auditoría: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Generate-EncryptionKey {
    <#
    .SYNOPSIS
        Genera clave de cifrado segura para logs de auditoría
    #>
    $KeyBytes = New-Object byte[] 32  # 256-bit key
    $RNG = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $RNG.GetBytes($KeyBytes)
    $RNG.Dispose()
    
    return [Convert]::ToBase64String($KeyBytes)
}

function Protect-AuditData {
    <#
    .SYNOPSIS
        Cifra datos de auditoría usando AES-256
    #>
    param(
        [string]$Data,
        [string]$Key
    )
    
    try {
        $KeyBytes = [Convert]::FromBase64String($Key)
        $DataBytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
        
        $AES = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $AES.Key = $KeyBytes
        $AES.GenerateIV()
        
        $Encryptor = $AES.CreateEncryptor()
        $EncryptedBytes = $Encryptor.TransformFinalBlock($DataBytes, 0, $DataBytes.Length)
        
        # Combinar IV + datos cifrados
        $Result = $AES.IV + $EncryptedBytes
        
        $AES.Dispose()
        $Encryptor.Dispose()
        
        return [Convert]::ToBase64String($Result)
    }
    catch {
        Write-Error "Error cifrando datos: $($_.Exception.Message)"
        return $Data  # Fallback a datos sin cifrar
    }
}

function Calculate-ChainIntegrityHash {
    <#
    .SYNOPSIS
        Calcula hash de integridad de toda la cadena
    #>
    if ($script:AuditChain.Count -eq 0) { return "empty_chain" }
    
    $ChainData = ($script:AuditChain | ForEach-Object { $_.Hash }) -join ""
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ChainData))
    $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    
    $hasher.Dispose()
    return $hashString.ToLower()
}

function Test-SystemIntegrity {
    <#
    .SYNOPSIS
        Ejecuta validaciones de integridad del sistema
    #>
    $Issues = @()
    
    # Validar permisos del directorio de auditoría
    if (Test-Path $script:SecurityConfig.AuditPath) {
        $Acl = Get-Acl $script:SecurityConfig.AuditPath
        $HasPublicAccess = $Acl.Access | Where-Object { 
            $_.IdentityReference -match "Everyone|Users" -and $_.AccessControlType -eq "Allow" 
        }
        
        if ($HasPublicAccess) {
            $Issues += "Directorio de auditoría tiene permisos públicos"
        }
    }
    
    # Validar integridad de la cadena
    if (-not (Test-ChainIntegrity)) {
        $Issues += "Integridad de cadena de auditoría comprometida"
    }
    
    # Validar configuración de seguridad
    if (-not $script:SecurityConfig.ComplianceMode) {
        $Issues += "Modo de cumplimiento normativo deshabilitado"
    }
    
    return @{
        IsValid = ($Issues.Count -eq 0)
        Issues = $Issues
        CheckedAt = Get-Date
    }
}

function Initialize-GDPRCompliance {
    <#
    .SYNOPSIS
        Inicializa configuración GDPR/LOPD
    #>
    Write-Verbose "⚖️ Inicializando cumplimiento GDPR/LOPD..."
    
    # Validar configuración legal
    $RequiredFields = @("DataController", "LegalBasis", "DataCategories", "RetentionPeriod")
    foreach ($Field in $RequiredFields) {
        if (-not $script:GDPRConfig[$Field]) {
            Write-Warning "⚠️ Campo GDPR faltante: $Field"
        }
    }
    
    # Crear log de cumplimiento inicial
    Add-AuditEntry -Action "GDPR_COMPLIANCE_INIT" -Details @"
Inicialización de cumplimiento GDPR/LOPD
Responsable del tratamiento: $($script:GDPRConfig.DataController)
Base legal: $($script:GDPRConfig.LegalBasis)
Categorías de datos: $($script:GDPRConfig.DataCategories -join ', ')
Período de conservación: $($script:GDPRConfig.RetentionPeriod)
"@ -DataCategory "ComplianceEvent" -Severity "Info"
}

function Compress-AuditLogs {
    <#
    .SYNOPSIS
        Comprime logs antiguos para gestión de espacio
    #>
    Write-Verbose "🗜️ Iniciando compresión de logs de auditoría..."
    
    # Implementar rotación y compresión de logs
    # Por seguridad, los logs se mantienen sin comprimir en esta versión
    Write-Verbose "📋 Rotación de logs programada para implementación futura"
}

# Exportar funciones públicas del módulo
Export-ModuleMember -Function @(
    'Initialize-AuditSecurityManager',
    'Add-AuditEntry',
    'Test-ChainIntegrity',
    'Save-AuditChain',
    'Test-SystemIntegrity'
)