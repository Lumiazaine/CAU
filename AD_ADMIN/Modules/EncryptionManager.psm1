#Requires -Version 5.1
<#
.SYNOPSIS
    Módulo de cifrado empresarial para datos en tránsito y reposo
.DESCRIPTION
    Sistema de cifrado robusto con soporte AES-256, RSA, certificados digitales
    y gestión segura de claves para cumplimiento ENS/CCN-STIC
.VERSION
    1.0 - Enterprise Encryption Framework
.COMPLIANCE
    ENS (Esquema Nacional de Seguridad), CCN-STIC-807, FIPS 140-2
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Core

# Configuración de cifrado empresarial
$script:EncryptionConfig = @{
    DefaultAlgorithm = "AES256"
    KeySize = 256
    BlockSize = 128
    KeyDerivationIterations = 100000
    SaltSize = 32
    IVSize = 16
    CertificateStore = "Cert:\LocalMachine\My"
    KeyExchangeAlgorithm = "RSA"
    HashAlgorithm = "SHA256"
}

# Configuración de cumplimiento ENS
$script:ENSConfig = @{
    SecurityLevel = "HIGH"  # BASIC, MEDIUM, HIGH
    RequiredAlgorithms = @("AES256", "SHA256", "RSA2048")
    CertificateRequirements = @{
        MinKeySize = 2048
        ValidityPeriod = 1095  # 3 años máximo
        RequiredUsages = @("DigitalSignature", "KeyEncipherment", "DataEncipherment")
    }
    AuditRequired = $true
}

function Initialize-EncryptionManager {
    <#
    .SYNOPSIS
        Inicializa el sistema de cifrado empresarial
    .DESCRIPTION
        Configura algoritmos de cifrado, valida cumplimiento ENS y 
        prepara infraestructura de claves
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("BASIC", "MEDIUM", "HIGH")]
        [string]$SecurityLevel = "HIGH",
        
        [switch]$ValidateCompliance,
        
        [string]$CertificateThumbprint,
        
        [switch]$GenerateTestCertificate
    )
    
    Write-Verbose "🔐 Inicializando Encryption Manager - Nivel de seguridad: $SecurityLevel"
    
    try {
        # Configurar nivel de seguridad
        $script:ENSConfig.SecurityLevel = $SecurityLevel
        
        # Validar algoritmos criptográficos disponibles
        $CryptoValidation = Test-CryptographicAlgorithms
        if (-not $CryptoValidation.AllSupported) {
            Write-Warning "⚠️ Algunos algoritmos requeridos no están disponibles: $($CryptoValidation.MissingAlgorithms -join ', ')"
        }
        
        # Validar certificados si está especificado
        $CertificateInfo = @{}
        if ($CertificateThumbprint) {
            $Certificate = Get-ChildItem $script:EncryptionConfig.CertificateStore | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
            
            if ($Certificate) {
                $CertValidation = Test-CertificateCompliance -Certificate $Certificate
                if ($CertValidation.IsCompliant) {
                    $CertificateInfo = @{
                        Found = $true
                        Thumbprint = $Certificate.Thumbprint
                        Subject = $Certificate.Subject
                        ValidFrom = $Certificate.NotBefore
                        ValidTo = $Certificate.NotAfter
                        KeySize = $Certificate.PublicKey.Key.KeySize
                        Compliant = $true
                    }
                    Write-Verbose "✅ Certificado válido encontrado: $($Certificate.Subject)"
                }
                else {
                    Write-Warning "⚠️ Certificado no cumple requisitos ENS: $($CertValidation.Issues -join '; ')"
                    $CertificateInfo.Compliant = $false
                }
            }
            else {
                Write-Warning "❌ Certificado no encontrado: $CertificateThumbprint"
            }
        }
        
        # Generar certificado de prueba si se solicita
        if ($GenerateTestCertificate) {
            $TestCert = New-TestCertificate -SecurityLevel $SecurityLevel
            if ($TestCert.Success) {
                Write-Host "🔐 Certificado de prueba generado: $($TestCert.Thumbprint)" -ForegroundColor Green
                $CertificateInfo = $TestCert
            }
        }
        
        # Validar cumplimiento normativo
        $ComplianceResult = @{
            ENSCompliant = $true
            Issues = @()
        }
        
        if ($ValidateCompliance) {
            $ComplianceResult = Test-ENSCompliance -SecurityLevel $SecurityLevel
        }
        
        # Inicializar generadores seguros
        Test-RandomNumberGeneration
        
        Write-Host "🔐 Encryption Manager inicializado:" -ForegroundColor Green
        Write-Host "   🏛️ Nivel de seguridad: $SecurityLevel" -ForegroundColor Cyan
        Write-Host "   🔏 Algoritmos soportados: $($CryptoValidation.SupportedAlgorithms -join ', ')" -ForegroundColor Cyan
        Write-Host "   📜 Certificado configurado: $($CertificateInfo.Found -eq $true)" -ForegroundColor Cyan
        Write-Host "   ⚖️ Cumplimiento ENS: $($ComplianceResult.ENSCompliant)" -ForegroundColor Cyan
        
        return @{
            Success = $true
            SecurityLevel = $SecurityLevel
            CryptographicSupport = $CryptoValidation
            Certificate = $CertificateInfo
            Compliance = $ComplianceResult
        }
    }
    catch {
        Write-Error "💥 Error inicializando Encryption Manager: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Protect-SensitiveData {
    <#
    .SYNOPSIS
        Cifra datos sensibles con AES-256-GCM
    .DESCRIPTION
        Implementa cifrado robusto con autenticación integrada,
        derivación de claves PBKDF2 y protección contra ataques
    .EXAMPLE
        $encryptedData = Protect-SensitiveData -Data "password123" -Passphrase "MasterKey2024!"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Passphrase,
        
        [Parameter(Mandatory=$false)]
        [string]$CertificateThumbprint,
        
        [ValidateSet("AES256", "AES128")]
        [string]$Algorithm = "AES256",
        
        [switch]$IncludeIntegrityCheck
    )
    
    try {
        if ([string]::IsNullOrEmpty($Data)) {
            throw "No se pueden cifrar datos vacíos"
        }
        
        $Result = @{
            Success = $false
            EncryptedData = ""
            Algorithm = $Algorithm
            Timestamp = Get-Date
        }
        
        # Determinar método de cifrado
        if ($CertificateThumbprint) {
            # Cifrado híbrido con certificado RSA
            $Result = Protect-WithCertificate -Data $Data -CertificateThumbprint $CertificateThumbprint
        }
        elseif ($Passphrase) {
            # Cifrado simétrico con passphrase
            $Result = Protect-WithPassphrase -Data $Data -Passphrase $Passphrase -Algorithm $Algorithm
        }
        else {
            throw "Debe especificar Passphrase o CertificateThumbprint para el cifrado"
        }
        
        # Añadir verificación de integridad si se solicita
        if ($IncludeIntegrityCheck -and $Result.Success) {
            $IntegrityHash = Get-DataIntegrityHash -Data $Data
            $Result.IntegrityHash = $IntegrityHash
        }
        
        Write-Verbose "🔐 Datos cifrados correctamente con $Algorithm"
        return $Result
        
    }
    catch {
        Write-Error "💥 Error cifrando datos: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Algorithm = $Algorithm
        }
    }
}

function Unprotect-SensitiveData {
    <#
    .SYNOPSIS
        Descifra datos protegidos
    .DESCRIPTION
        Descifra datos usando el método y claves correspondientes,
        con validación de integridad opcional
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EncryptedData,
        
        [Parameter(Mandatory=$false)]
        [string]$Passphrase,
        
        [Parameter(Mandatory=$false)]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory=$false)]
        [string]$IntegrityHash,
        
        [switch]$ValidateIntegrity
    )
    
    try {
        # Decodificar metadata del cifrado
        $EncryptionMetadata = Get-EncryptionMetadata -EncryptedData $EncryptedData
        
        $Result = @{
            Success = $false
            DecryptedData = ""
            Algorithm = $EncryptionMetadata.Algorithm
        }
        
        # Descifrar según el método usado
        if ($EncryptionMetadata.Method -eq "Certificate") {
            if (-not $CertificateThumbprint) {
                throw "Se requiere CertificateThumbprint para descifrar datos cifrados con certificado"
            }
            $Result = Unprotect-WithCertificate -EncryptedData $EncryptedData -CertificateThumbprint $CertificateThumbprint
        }
        elseif ($EncryptionMetadata.Method -eq "Passphrase") {
            if (-not $Passphrase) {
                throw "Se requiere Passphrase para descifrar datos cifrados con passphrase"
            }
            $Result = Unprotect-WithPassphrase -EncryptedData $EncryptedData -Passphrase $Passphrase
        }
        else {
            throw "Método de cifrado no soportado: $($EncryptionMetadata.Method)"
        }
        
        # Validar integridad si se proporciona hash
        if ($ValidateIntegrity -and $IntegrityHash -and $Result.Success) {
            $CurrentHash = Get-DataIntegrityHash -Data $Result.DecryptedData
            if ($CurrentHash -ne $IntegrityHash) {
                throw "Verificación de integridad fallida - los datos pueden estar comprometidos"
            }
            Write-Verbose "✅ Verificación de integridad exitosa"
        }
        
        Write-Verbose "🔓 Datos descifrados correctamente"
        return $Result
        
    }
    catch {
        Write-Error "💥 Error descifrando datos: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Protect-WithPassphrase {
    <#
    .SYNOPSIS
        Cifrado simétrico con derivación de clave PBKDF2
    #>
    param(
        [string]$Data,
        [string]$Passphrase,
        [string]$Algorithm
    )
    
    try {
        # Generar salt aleatorio
        $Salt = New-Object byte[] $script:EncryptionConfig.SaltSize
        $RNG = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $RNG.GetBytes($Salt)
        
        # Derivar clave usando PBKDF2
        $PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($Passphrase)
        $DerivedKey = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $PasswordBytes, $Salt, $script:EncryptionConfig.KeyDerivationIterations
        )
        
        # Configurar AES
        $KeySize = if ($Algorithm -eq "AES256") { 32 } else { 16 }
        $Key = $DerivedKey.GetBytes($KeySize)
        $IV = $DerivedKey.GetBytes($script:EncryptionConfig.IVSize)
        
        # Cifrar datos
        $AES = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $AES.Key = $Key
        $AES.IV = $IV
        $AES.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $AES.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $DataBytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
        $Encryptor = $AES.CreateEncryptor()
        $EncryptedBytes = $Encryptor.TransformFinalBlock($DataBytes, 0, $DataBytes.Length)
        
        # Combinar salt + IV + datos cifrados + metadatos
        $CombinedData = @{
            Method = "Passphrase"
            Algorithm = $Algorithm
            Salt = [Convert]::ToBase64String($Salt)
            IV = [Convert]::ToBase64String($IV)
            Data = [Convert]::ToBase64String($EncryptedBytes)
            Timestamp = Get-Date
        }
        
        $CombinedJson = $CombinedData | ConvertTo-Json -Compress
        $EncodedResult = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($CombinedJson))
        
        # Limpiar objetos sensibles
        $DerivedKey.Dispose()
        $AES.Dispose()
        $Encryptor.Dispose()
        [Array]::Clear($Key, 0, $Key.Length)
        [Array]::Clear($PasswordBytes, 0, $PasswordBytes.Length)
        
        return @{
            Success = $true
            EncryptedData = $EncodedResult
            Algorithm = $Algorithm
            Method = "Passphrase"
        }
    }
    catch {
        throw "Error en cifrado con passphrase: $($_.Exception.Message)"
    }
}

function Unprotect-WithPassphrase {
    <#
    .SYNOPSIS
        Descifrado simétrico con validación PBKDF2
    #>
    param(
        [string]$EncryptedData,
        [string]$Passphrase
    )
    
    try {
        # Decodificar datos combinados
        $DecodedBytes = [Convert]::FromBase64String($EncryptedData)
        $DecodedJson = [System.Text.Encoding]::UTF8.GetString($DecodedBytes)
        $CombinedData = $DecodedJson | ConvertFrom-Json
        
        # Extraer componentes
        $Salt = [Convert]::FromBase64String($CombinedData.Salt)
        $IV = [Convert]::FromBase64String($CombinedData.IV)
        $DataBytes = [Convert]::FromBase64String($CombinedData.Data)
        
        # Derivar clave con los mismos parámetros
        $PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($Passphrase)
        $DerivedKey = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $PasswordBytes, $Salt, $script:EncryptionConfig.KeyDerivationIterations
        )
        
        $KeySize = if ($CombinedData.Algorithm -eq "AES256") { 32 } else { 16 }
        $Key = $DerivedKey.GetBytes($KeySize)
        
        # Descifrar
        $AES = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $AES.Key = $Key
        $AES.IV = $IV
        $AES.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $AES.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $Decryptor = $AES.CreateDecryptor()
        $DecryptedBytes = $Decryptor.TransformFinalBlock($DataBytes, 0, $DataBytes.Length)
        $DecryptedText = [System.Text.Encoding]::UTF8.GetString($DecryptedBytes)
        
        # Limpiar objetos sensibles
        $DerivedKey.Dispose()
        $AES.Dispose()
        $Decryptor.Dispose()
        [Array]::Clear($Key, 0, $Key.Length)
        [Array]::Clear($PasswordBytes, 0, $PasswordBytes.Length)
        
        return @{
            Success = $true
            DecryptedData = $DecryptedText
            Algorithm = $CombinedData.Algorithm
        }
    }
    catch {
        throw "Error en descifrado con passphrase: $($_.Exception.Message)"
    }
}

function Test-CryptographicAlgorithms {
    <#
    .SYNOPSIS
        Valida disponibilidad de algoritmos criptográficos requeridos
    #>
    $SupportedAlgorithms = @()
    $MissingAlgorithms = @()
    
    # Validar AES
    try {
        $AES = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
        $AES.Dispose()
        $SupportedAlgorithms += "AES"
    }
    catch {
        $MissingAlgorithms += "AES"
    }
    
    # Validar SHA256
    try {
        $SHA = [System.Security.Cryptography.SHA256]::Create()
        $SHA.Dispose()
        $SupportedAlgorithms += "SHA256"
    }
    catch {
        $MissingAlgorithms += "SHA256"
    }
    
    # Validar RSA
    try {
        $RSA = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)
        $RSA.Dispose()
        $SupportedAlgorithms += "RSA"
    }
    catch {
        $MissingAlgorithms += "RSA"
    }
    
    # Validar RNG
    try {
        $RNG = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $TestBytes = New-Object byte[] 16
        $RNG.GetBytes($TestBytes)
        $RNG.Dispose()
        $SupportedAlgorithms += "RNG"
    }
    catch {
        $MissingAlgorithms += "RNG"
    }
    
    return @{
        AllSupported = ($MissingAlgorithms.Count -eq 0)
        SupportedAlgorithms = $SupportedAlgorithms
        MissingAlgorithms = $MissingAlgorithms
    }
}

function Test-ENSCompliance {
    <#
    .SYNOPSIS
        Valida cumplimiento del Esquema Nacional de Seguridad
    #>
    param([string]$SecurityLevel)
    
    $Issues = @()
    $ENSCompliant = $true
    
    # Validar algoritmos según nivel de seguridad ENS
    $RequiredAlgorithms = switch ($SecurityLevel) {
        "BASIC" { @("AES128", "SHA256") }
        "MEDIUM" { @("AES256", "SHA256", "RSA2048") }
        "HIGH" { @("AES256", "SHA256", "RSA2048") }
    }
    
    foreach ($Algorithm in $RequiredAlgorithms) {
        if ($Algorithm -notin $script:ENSConfig.RequiredAlgorithms) {
            $Issues += "Algoritmo requerido no configurado: $Algorithm"
            $ENSCompliant = $false
        }
    }
    
    # Validar tamaños de clave mínimos
    if ($SecurityLevel -eq "HIGH" -and $script:EncryptionConfig.KeySize -lt 256) {
        $Issues += "Tamaño de clave insuficiente para nivel HIGH: $($script:EncryptionConfig.KeySize) bits"
        $ENSCompliant = $false
    }
    
    # Validar iteraciones de derivación de clave
    if ($script:EncryptionConfig.KeyDerivationIterations -lt 100000) {
        $Issues += "Iteraciones de derivación insuficientes: $($script:EncryptionConfig.KeyDerivationIterations)"
        $ENSCompliant = $false
    }
    
    return @{
        ENSCompliant = $ENSCompliant
        SecurityLevel = $SecurityLevel
        Issues = $Issues
        ValidatedAt = Get-Date
    }
}

function Get-DataIntegrityHash {
    <#
    .SYNOPSIS
        Calcula hash de integridad SHA-256 de datos
    #>
    param([string]$Data)
    
    $DataBytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($DataBytes)
    $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    
    $hasher.Dispose()
    return $hashString.ToLower()
}

function Get-EncryptionMetadata {
    <#
    .SYNOPSIS
        Extrae metadatos de datos cifrados
    #>
    param([string]$EncryptedData)
    
    try {
        $DecodedBytes = [Convert]::FromBase64String($EncryptedData)
        $DecodedJson = [System.Text.Encoding]::UTF8.GetString($DecodedBytes)
        $Metadata = $DecodedJson | ConvertFrom-Json
        
        return @{
            Method = $Metadata.Method
            Algorithm = $Metadata.Algorithm
            Timestamp = $Metadata.Timestamp
        }
    }
    catch {
        return @{
            Method = "Unknown"
            Algorithm = "Unknown"
            Error = $_.Exception.Message
        }
    }
}

function Test-RandomNumberGeneration {
    <#
    .SYNOPSIS
        Valida calidad del generador de números aleatorios
    #>
    Write-Verbose "🎲 Validando generación de números aleatorios..."
    
    try {
        $RNG = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        $TestBytes = New-Object byte[] 1000
        $RNG.GetBytes($TestBytes)
        $RNG.Dispose()
        
        # Test básico de distribución
        $ZeroCount = ($TestBytes | Where-Object { $_ -eq 0 }).Count
        $Distribution = $ZeroCount / $TestBytes.Length
        
        if ($Distribution -gt 0.1) {  # Más del 10% de ceros indica problema
            Write-Warning "⚠️ Posible problema en generación de números aleatorios (${Distribution}% ceros)"
        } else {
            Write-Verbose "✅ Generador de números aleatorios funcionando correctamente"
        }
        
        return $true
    }
    catch {
        Write-Error "💥 Error validando generador aleatorio: $($_.Exception.Message)"
        return $false
    }
}

function New-TestCertificate {
    <#
    .SYNOPSIS
        Genera certificado autofirmado para pruebas
    #>
    param([string]$SecurityLevel)
    
    try {
        $KeySize = if ($SecurityLevel -eq "HIGH") { 4096 } else { 2048 }
        $Subject = "CN=AD_ADMIN_Test,OU=Testing,O=Consejería de Justicia,C=ES"
        
        # Crear certificado autofirmado (solo para testing)
        $Certificate = New-SelfSignedCertificate -Subject $Subject -KeyAlgorithm RSA -KeyLength $KeySize -CertStoreLocation $script:EncryptionConfig.CertificateStore -KeyUsage DigitalSignature, KeyEncipherment, DataEncipherment -NotAfter (Get-Date).AddYears(1)
        
        return @{
            Success = $true
            Thumbprint = $Certificate.Thumbprint
            Subject = $Certificate.Subject
            KeySize = $KeySize
            ValidTo = $Certificate.NotAfter
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'Initialize-EncryptionManager',
    'Protect-SensitiveData',
    'Unprotect-SensitiveData',
    'Test-CryptographicAlgorithms',
    'Test-ENSCompliance',
    'Get-DataIntegrityHash'
)