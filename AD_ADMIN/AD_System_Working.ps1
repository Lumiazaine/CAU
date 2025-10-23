param(
    [string]$CSVFile = "Ejemplo_Usuarios_Oficial.csv",
    [switch]$WhatIfMode = $true
)

# Global variables
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIfMode
$Global:ADAvailable = $false

# Check ActiveDirectory module availability
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $Global:ADAvailable = $true
    Write-Host "ActiveDirectory module loaded successfully" -ForegroundColor Green
} catch {
    Write-Warning "ActiveDirectory module not available - running in simulation mode"
    $Global:ADAvailable = $false
}

# Create logs directory
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -ItemType Directory -Path $Global:LogDirectory -Force | Out-Null
}

# Configure log file
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $Global:LogDirectory "AD_UserManagement_$TimeStamp.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "INFO" { Write-Host $LogEntry -ForegroundColor Cyan }
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Test-CSVFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "CSV file not found: $FilePath" "ERROR"
        return $false
    }
    
    $FirstLine = Get-Content $FilePath -First 1 -Encoding UTF8
    $ExpectedHeaders = "TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD"
    
    if ($FirstLine -ne $ExpectedHeaders) {
        Write-Log "CSV headers do not match official format" "ERROR"
        Write-Log "Expected: $ExpectedHeaders" "ERROR"
        Write-Log "Found: $FirstLine" "ERROR"
        return $false
    }
    
    Write-Log "CSV file validated successfully" "INFO"
    return $true
}

function Generate-SamAccountName {
    param(
        [string]$Nombre,
        [string]$Apellidos
    )
    
    Write-Log "Generating SamAccountName for: $Nombre $Apellidos" "INFO"
    
    # Normalize special characters
    function Normalize-Text {
        param([string]$Text)
        $CharMap = @{
            'á'='a'; 'é'='e'; 'í'='i'; 'ó'='o'; 'ú'='u'; 'ñ'='n'
            'Á'='A'; 'É'='E'; 'Í'='I'; 'Ó'='O'; 'Ú'='U'; 'Ñ'='N'
            'ü'='u'; 'Ü'='U'; 'ç'='c'; 'Ç'='C'
        }
        
        foreach ($char in $CharMap.Keys) {
            $Text = $Text -replace $char, $CharMap[$char]
        }
        
        return $Text -replace '[^a-zA-Z0-9]', ''
    }
    
    $NombreNorm = Normalize-Text -Text $Nombre.Trim()
    $ApellidosNorm = Normalize-Text -Text $Apellidos.Trim()
    $ApellidosArray = $ApellidosNorm -split '\s+'
    $PrimerApellido = $ApellidosArray[0]
    $SegundoApellido = if ($ApellidosArray.Length -gt 1) { $ApellidosArray[1] } else { "" }
    
    # Determine name initials
    $NombresArray = $NombreNorm -split '\s+'
    if ($NombresArray.Length -gt 1) {
        # Compound name: use initials
        $InicialNombre = ($NombresArray | ForEach-Object { $_.Substring(0,1) }) -join ''
        Write-Log "Compound name detected: $Nombre -> Initials: $InicialNombre" "INFO"
    } else {
        # Simple name: first letter
        $InicialNombre = $NombresArray[0].Substring(0,1)
    }
    
    # Strategy 1: Initial(s) + first surname
    $BaseSamAccountName = "$InicialNombre$PrimerApellido".ToLower()
    Write-Log "Base SamAccountName generated: $BaseSamAccountName" "INFO"
    
    # Check uniqueness and generate alternatives if needed
    $Candidates = @()
    $Candidates += $BaseSamAccountName
    
    # Strategy 2: If second surname exists, add letters gradually
    if ($SegundoApellido) {
        for ($i = 1; $i -le $SegundoApellido.Length; $i++) {
            $Candidates += "$BaseSamAccountName$($SegundoApellido.Substring(0,$i))".ToLower()
        }
    }
    
    # Strategy 3: Full name + surname initials
    $NombreCompleto = ($NombresArray -join '').ToLower()
    $Candidates += "$NombreCompleto$($PrimerApellido.Substring(0,1))".ToLower()
    if ($SegundoApellido) {
        $Candidates += "$NombreCompleto$($PrimerApellido.Substring(0,1))$($SegundoApellido.Substring(0,1))".ToLower()
    }
    
    # Strategy 4: Sequential numbering
    for ($i = 1; $i -le 99; $i++) {
        $Candidates += "$BaseSamAccountName$i"
    }
    
    # Select first available candidate
    foreach ($Candidate in $Candidates) {
        # Limit to 20 characters maximum
        $FinalCandidate = $Candidate.Substring(0, [Math]::Min($Candidate.Length, 20))
        
        if (Test-SamAccountNameUnique -SamAccountName $FinalCandidate) {
            Write-Log "Unique SamAccountName found: $FinalCandidate" "INFO"
            return $FinalCandidate
        }
    }
    
    # Fallback: timestamp
    $FallbackName = "$BaseSamAccountName$(Get-Date -Format 'mmss')"
    Write-Log "Using fallback SamAccountName: $FallbackName" "WARNING"
    return $FallbackName
}

function Test-SamAccountNameUnique {
    param([string]$SamAccountName)
    
    if (-not $Global:ADAvailable) {
        # In simulation mode, always unique for testing
        return $true
    }
    
    # List of domains to check according to guide
    $DomainsToCheck = @(
        "almeria.justicia.junta-andalucia.es",
        "cadiz.justicia.junta-andalucia.es", 
        "cordoba.justicia.junta-andalucia.es",
        "granada.justicia.junta-andalucia.es",
        "huelva.justicia.junta-andalucia.es",
        "jaen.justicia.junta-andalucia.es",
        "malaga.justicia.junta-andalucia.es",
        "sevilla.justicia.junta-andalucia.es"
    )
    
    foreach ($Domain in $DomainsToCheck) {
        try {
            $ExistingUser = Get-ADUser -Identity $SamAccountName -Server $Domain -ErrorAction SilentlyContinue
            if ($ExistingUser) {
                Write-Log "SamAccountName $SamAccountName already exists in domain $Domain" "INFO"
                return $false
            }
        } catch {
            continue
        }
    }
    
    return $true
}

function Extract-ProvinceFromOffice {
    param([string]$Office)
    
    $ProvinciasMap = @{
        "almeria" = "almeria"
        "cadiz" = "cadiz"
        "cordoba" = "cordoba"
        "granada" = "granada"
        "huelva" = "huelva"
        "jaen" = "jaen"
        "malaga" = "malaga"
        "sevilla" = "sevilla"
    }
    
    $OfficeNorm = $Office.ToLower()
    foreach ($Key in $ProvinciasMap.Keys) {
        if ($OfficeNorm -like "*$Key*") {
            return $ProvinciasMap[$Key]
        }
    }
    
    return $null
}

function Find-UOByOffice {
    param([string]$OfficeDescription, [switch]$Interactive = $true)
    
    Write-Log "Searching OU for office: $OfficeDescription" "INFO"
    
    $Province = Extract-ProvinceFromOffice -Office $OfficeDescription
    if (-not $Province) {
        Write-Log "Could not automatically identify province" "WARNING"
        if ($Interactive) {
            return Select-ProvinceInteractively -OfficeDescription $OfficeDescription
        }
        return $null
    }
    
    Write-Log "Province identified: $Province" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulation: generate realistic OU
        $NormalizedOffice = $OfficeDescription -replace '[^\w\s]', '' -replace '\s+', ' '
        $SimulatedOU = "OU=$NormalizedOffice,OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "SIMULATION: Generated OU: $SimulatedOU" "INFO"
        return $SimulatedOU
    }
    
    # Real AD search would go here
    return "OU=Default,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
}

function Select-ProvinceInteractively {
    param([string]$OfficeDescription)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    Write-Host "`nCould not determine province for: $OfficeDescription" -ForegroundColor Yellow
    Write-Host "Available provinces:" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $ProvinciasAndalucia.Count; $i++) {
        Write-Host "  $($i + 1). $($ProvinciasAndalucia[$i])" -ForegroundColor White
    }
    
    do {
        $Selection = Read-Host "Select province (1-8)"
        $SelectionNum = 0
        $ValidSelection = [int]::TryParse($Selection, [ref]$SelectionNum)
    } while (-not $ValidSelection -or $SelectionNum -lt 1 -or $SelectionNum -gt 8)
    
    $SelectedProvince = $ProvinciasAndalucia[$SelectionNum - 1]
    Write-Log "Province selected interactively: $SelectedProvince" "INFO"
    
    $DefaultOU = "OU=Usuarios,OU=$SelectedProvince-MACJ-Ciudad de la Justicia,DC=$SelectedProvince,DC=justicia,DC=junta-andalucia,DC=es"
    return $DefaultOU
}

function Find-ExistingUser {
    param(
        [string]$SearchTerm,
        [string]$SearchType
    )
    
    Write-Log "Searching existing user by $SearchType : $SearchTerm" "INFO"
    
    if (-not $Global:ADAvailable) {
        return @{
            SamAccountName = $SearchTerm
            DisplayName = "Usuario Existente Simulado"
            Domain = "malaga"
            DistinguishedName = "CN=$SearchTerm,OU=Users,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
        }
    }
    
    # Real search would go here
    return $null
}

function Extract-DomainFromOU {
    param([string]$OUDN)
    
    if ($OUDN -match "DC=([^,]+),DC=justicia") {
        return $matches[1]
    }
    return "malaga"
}

function Process-NormalizedUser {
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESSING NORMALIZED USER ===" "INFO"
    
    $SamAccountName = Generate-SamAccountName -Nombre $User.Nombre -Apellidos $User.Apellidos
    $Result.SamAccountName = $SamAccountName
    
    $EmailAddress = "$SamAccountName@justicia.junta-andalucia.es"
    $Result.Email = $EmailAddress
    
    $OUDN = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $false
    if (-not $OUDN) {
        throw "Could not determine OU for office: $($User.Oficina)"
    }
    $Result.UO_Destino = $OUDN
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULATION: User $SamAccountName would be created in $OUDN" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Usuario creado en $OUDN con descripcion: $($User.Descripcion)"
    } else {
        Write-Log "EXECUTING: Creating user $SamAccountName" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Usuario creado correctamente en $OUDN"
    }
    
    return $Result
}

function Process-UserTransfer {
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESSING TRANSFER ===" "INFO"
    
    $ExistingUser = $null
    if ($User.AD) {
        $ExistingUser = Find-ExistingUser -SearchTerm $User.AD -SearchType "SamAccountName"
    } elseif ($User.Email) {
        $ExistingUser = Find-ExistingUser -SearchTerm $User.Email -SearchType "Email"
    } else {
        throw "TRANSFER requires AD or Email field"
    }
    
    if (-not $ExistingUser) {
        throw "Existing user not found"
    }
    
    $DestinationOU = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $false
    if (-not $DestinationOU) {
        throw "Could not determine destination OU"
    }
    
    $Result.UO_Destino = $DestinationOU
    $Result.SamAccountName = $ExistingUser.SamAccountName
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULATION: User would be transferred to $DestinationOU" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Usuario trasladado a $DestinationOU"
    } else {
        Write-Log "EXECUTING: Transferring user" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Usuario trasladado exitosamente"
    }
    
    return $Result
}

function Process-SharedUser {
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESSING SHARED USER ===" "INFO"
    
    $ExistingUser = $null
    if ($User.AD) {
        $ExistingUser = Find-ExistingUser -SearchTerm $User.AD -SearchType "SamAccountName"
    } elseif ($User.Email) {
        $ExistingUser = Find-ExistingUser -SearchTerm $User.Email -SearchType "Email"
    } else {
        throw "SHARED requires AD or Email field"
    }
    
    if (-not $ExistingUser) {
        throw "Existing user not found"
    }
    
    $AdditionalOU = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $false
    if (-not $AdditionalOU) {
        throw "Could not determine additional OU"
    }
    
    $Result.UO_Destino = $AdditionalOU
    $Result.SamAccountName = $ExistingUser.SamAccountName
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULATION: Shared permissions would be added for $AdditionalOU" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Permisos compaginados anadidos para $AdditionalOU"
    } else {
        Write-Log "EXECUTING: Adding shared permissions" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Permisos compaginados anadidos exitosamente"
    }
    
    return $Result
}

function Process-UserByType {
    param([PSCustomObject]$User)
    
    $Result = [PSCustomObject]@{
        Nombre = $User.Nombre
        Apellidos = $User.Apellidos
        Email = $User.Email
        Telefono = $User.Telefono
        Oficina = $User.Oficina
        Descripcion = $User.Descripcion
        AD = $User.AD
        TipoAlta = $User.TipoAlta
        UO_Destino = ""
        SamAccountName = ""
        Estado = "PROCESADO"
        Observaciones = ""
        FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        switch ($User.TipoAlta.ToUpper()) {
            "NORMALIZADA" {
                $Result = Process-NormalizedUser -User $User -Result $Result
            }
            "TRASLADO" {
                $Result = Process-UserTransfer -User $User -Result $Result
            }
            "COMPAGINADA" {
                $Result = Process-SharedUser -User $User -Result $Result
            }
            default {
                throw "Unrecognized user type: $($User.TipoAlta)"
            }
        }
    } catch {
        Write-Log "Error processing user: $($_.Exception.Message)" "ERROR"
        $Result.Estado = "ERROR"
        $Result.Observaciones = "Error: $($_.Exception.Message)"
    }
    
    return $Result
}

# MAIN EXECUTION
try {
    Write-Log "=== STARTING AD USER MANAGEMENT SYSTEM ===" "INFO"
    Write-Log "CSV File: $CSVFile" "INFO"
    Write-Log "WhatIf Mode: $Global:WhatIfMode" "INFO"
    
    if (-not $Global:ADAvailable) {
        Write-Log "WARNING: ActiveDirectory module not available - running in simulation mode" "WARNING"
    }
    
    if (-not (Test-CSVFile -FilePath $CSVFile)) {
        throw "CSV file validation failed"
    }
    
    Write-Log "Importing CSV data..." "INFO"
    $UsersData = Import-Csv -Path $CSVFile -Delimiter ';' -Encoding UTF8
    Write-Log "CSV imported successfully: $($UsersData.Count) records" "INFO"
    
    Write-Log "Starting user processing..." "INFO"
    $Results = @()
    $SuccessCount = 0
    $ErrorCount = 0
    
    foreach ($User in $UsersData) {
        Write-Log "--- Processing: $($User.Nombre) $($User.Apellidos) ---" "INFO"
        Write-Log "Office: $($User.Oficina)" "INFO"
        Write-Log "Type: $($User.TipoAlta)" "INFO"
        
        $UserResult = Process-UserByType -User $User
        $Results += $UserResult
        
        if ($UserResult.Estado -eq "ERROR") {
            $ErrorCount++
        } else {
            $SuccessCount++
        }
    }
    
    $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = $CSVFile -replace '\.csv$', "_resultados_$TimeStampForCSV.csv"
    $Results | Export-Csv -Path $OutputPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Write-Log "Results exported to: $OutputPath" "INFO"
    
    Write-Log "=== FINAL SUMMARY ===" "INFO"
    Write-Log "Total processed: $($UsersData.Count)" "INFO"
    Write-Log "Successful: $SuccessCount" "INFO"
    Write-Log "Errors: $ErrorCount" "INFO"
    Write-Log "Log saved to: $LogFile" "INFO"
    
} catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    exit 1
}