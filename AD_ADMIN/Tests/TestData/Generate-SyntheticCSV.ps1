#Requires -Version 5.1

<#
.SYNOPSIS
    Advanced synthetic CSV data generator for AD_ADMIN testing
.DESCRIPTION
    Generates comprehensive test CSV files with edge cases, problematic scenarios,
    and real-world data patterns for thorough system testing
.PARAMETER OutputDirectory
    Directory where CSV files will be generated
.PARAMETER GenerateAll
    Generate all predefined CSV test scenarios
.PARAMETER Scenario
    Generate specific test scenario
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "CSV"),
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateAll = $true,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Valid", "Invalid", "EdgeCases", "Provinces", "Performance", "UOMapping", "Malaga", "Sevilla")]
    [string]$Scenario
)

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Common data patterns for realistic test generation
$Global:TestDataPatterns = @{
    FirstNames = @(
        "Juan", "María", "José", "Carmen", "Antonio", "Ana", "Manuel", "Isabel", 
        "Francisco", "Pilar", "David", "Mercedes", "José María", "Dolores",
        "Jesús", "Josefa", "Javier", "Rosario", "Rafael", "Teresa"
    )
    
    LastNames = @(
        "García", "González", "López", "Martínez", "Sánchez", "Pérez", "Gómez",
        "Martín", "Jiménez", "Ruiz", "Hernández", "Díaz", "Moreno", "Muñoz",
        "Álvarez", "Romero", "Alonso", "Gutiérrez", "Navarro", "Torres"
    )
    
    CompoundLastNames = @(
        "García López", "González Martínez", "López Sánchez", "Martínez Pérez",
        "Sánchez Gómez", "Pérez Martín", "Gómez Jiménez", "Martín Ruiz",
        "Jiménez Hernández", "Ruiz Díaz"
    )
    
    Provinces = @(
        "Almería", "Cádiz", "Córdoba", "Granada", "Huelva", "Jaén", "Málaga", "Sevilla"
    )
    
    OfficeTypes = @(
        "Juzgado de Primera Instancia",
        "Juzgado de Instrucción", 
        "Juzgado de lo Penal",
        "Juzgado de lo Social",
        "Juzgado de Familia",
        "Juzgado de Violencia sobre la Mujer",
        "Juzgado de lo Mercantil",
        "Audiencia Provincial"
    )
    
    Descriptions = @(
        "LAJ", "Letrado", "Juez", "Magistrado", "Auxilio", "Gestor", 
        "Tramitador", "Tramitadora", "Secretario Judicial", "Médico Forense"
    )
    
    PhonePatterns = @(
        "95{0}######", "95{0}######", "600######", "6########", 
        "+34 95{0}######", "95{0} ## ## ##"
    )
    
    DNILetters = @("T","R","W","A","G","M","Y","F","P","D","X","B","N","J","Z","S","Q","V","H","L","C","K","E")
}

function New-SyntheticUser {
    <#
    .SYNOPSIS
        Generates a single synthetic user with realistic data patterns
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("NORMALIZADA", "TRASLADO", "COMPAGINADA")]
        [string]$TipoAlta,
        
        [Parameter(Mandatory=$false)]
        [string]$Province = $null,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Overrides = @{},
        
        [Parameter(Mandatory=$false)]
        [switch]$IntroduceIssues
    )
    
    $FirstName = Get-Random -InputObject $Global:TestDataPatterns.FirstNames
    $LastName = Get-Random -InputObject $Global:TestDataPatterns.CompoundLastNames
    
    if (-not $Province) {
        $Province = Get-Random -InputObject $Global:TestDataPatterns.Provinces
    }
    
    $OfficeType = Get-Random -InputObject $Global:TestDataPatterns.OfficeTypes
    $OfficeNumber = Get-Random -Minimum 1 -Maximum 30
    
    # Generate base office name with potential issues
    $Office = "$OfficeType Nº $OfficeNumber de $Province"
    
    if ($IntroduceIssues) {
        # Introduce various problematic patterns
        $IssueType = Get-Random -Minimum 1 -Maximum 6
        switch ($IssueType) {
            1 { # Text encoding issues
                $Office = $Office -replace "Málaga", "mamámámálaga"
                $Office = $Office -replace "Córdoba", "córdoba" 
            }
            2 { # Number format variations
                $Office = $Office -replace "Nº", "N°" 
                $Office = $Office -replace "Nº", "No." 
            }
            3 { # Extra whitespace
                $Office = $Office -replace " ", "  " 
                $Office = "  $Office  "
            }
            4 { # Mixed case issues
                $Office = $Office.ToUpper()
            }
            5 { # Special character issues
                $Office = $Office -replace "de", "DE"
                $Office = $Office -replace "Instancia", "INSTANCIA"
            }
        }
    }
    
    # Generate email
    $EmailUser = ($FirstName.Substring(0,1) + $LastName.Split()[0]).ToLower()
    $EmailUser = $EmailUser -replace "[áéíóúñ]", { 
        switch ($_.Value) {
            "á" { "a" } "é" { "e" } "í" { "i" } "ó" { "o" } "ú" { "u" } "ñ" { "n" }
        }
    }
    $Email = "$EmailUser@justicia.junta-andalucia.es"
    
    # Generate phone or DNI
    $UsePhone = (Get-Random -Minimum 0 -Maximum 2) -eq 0
    if ($UsePhone) {
        $ProvinceCode = switch ($Province) {
            "Málaga" { "5" } "Sevilla" { "4" } "Granada" { "8" } 
            "Córdoba" { "7" } "Almería" { "0" } "Cádiz" { "6" }
            "Huelva" { "9" } "Jaén" { "3" } default { "5" }
        }
        $PhonePattern = Get-Random -InputObject $Global:TestDataPatterns.PhonePatterns
        $Phone = $PhonePattern -replace "{0}", $ProvinceCode
        $Phone = $Phone -replace "#", { Get-Random -Minimum 0 -Maximum 10 }
    } else {
        # Generate DNI
        $DNINumber = "{0:D8}" -f (Get-Random -Minimum 10000000 -Maximum 99999999)
        $DNILetter = Get-Random -InputObject $Global:TestDataPatterns.DNILetters
        $Phone = "$DNINumber$DNILetter"
    }
    
    $Description = Get-Random -InputObject $Global:TestDataPatterns.Descriptions
    
    # Create user object
    $User = [PSCustomObject]@{
        TipoAlta = $TipoAlta
        Nombre = $FirstName
        Apellidos = $LastName  
        Email = $Email
        Telefono = $Phone
        Oficina = $Office
        Descripcion = $Description
        AD = ""
    }
    
    # Handle specific alta types
    switch ($TipoAlta) {
        "TRASLADO" {
            $User.AD = "existing_user_$(Get-Random -Minimum 100 -Maximum 999)"
            if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) {
                $User.Email = "" # Sometimes use AD instead of email
            }
        }
        "COMPAGINADA" {
            $User.AD = "compag_user_$(Get-Random -Minimum 100 -Maximum 999)"
        }
    }
    
    # Apply any overrides
    foreach ($Override in $Overrides.GetEnumerator()) {
        if ($User.PSObject.Properties.Name -contains $Override.Key) {
            $User.($Override.Key) = $Override.Value
        }
    }
    
    return $User
}

function New-ValidUsersCSV {
    param([string]$OutputPath)
    
    Write-Host "Generating valid users CSV with 100 entries..." -ForegroundColor Green
    
    $Users = @()
    
    # Generate balanced mix of alta types
    1..60 | ForEach-Object { 
        $Province = Get-Random -InputObject $Global:TestDataPatterns.Provinces
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Province $Province
    }
    
    1..25 | ForEach-Object { 
        $Province = Get-Random -InputObject $Global:TestDataPatterns.Provinces
        $Users += New-SyntheticUser -TipoAlta "TRASLADO" -Province $Province
    }
    
    1..15 | ForEach-Object { 
        $Province = Get-Random -InputObject $Global:TestDataPatterns.Provinces
        $Users += New-SyntheticUser -TipoAlta "COMPAGINADA" -Province $Province
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: $OutputPath ($(($Users).Count) users)" -ForegroundColor Green
}

function New-InvalidUsersCSV {
    param([string]$OutputPath)
    
    Write-Host "Generating invalid users CSV for error testing..." -ForegroundColor Yellow
    
    $Users = @()
    
    # Missing required fields
    $Users += [PSCustomObject]@{
        TipoAlta = ""; Nombre = "Juan"; Apellidos = "García"; Email = "juan@test.com"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    $Users += [PSCustomObject]@{
        TipoAlta = "NORMALIZADA"; Nombre = ""; Apellidos = "López"; Email = "test@test.com"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    $Users += [PSCustomObject]@{
        TipoAlta = "NORMALIZADA"; Nombre = "María"; Apellidos = ""; Email = "maria@test.com"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    # Invalid TipoAlta values
    $Users += [PSCustomObject]@{
        TipoAlta = "INVALID"; Nombre = "José"; Apellidos = "Martín"; Email = "jose@test.com"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    $Users += [PSCustomObject]@{
        TipoAlta = "normalizada"; Nombre = "Carmen"; Apellidos = "Ruiz"; Email = "carmen@test.com" 
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    # TRASLADO without identification
    $Users += [PSCustomObject]@{
        TipoAlta = "TRASLADO"; Nombre = "Francisco"; Apellidos = "González"; Email = ""
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    # Invalid email formats
    $Users += [PSCustomObject]@{
        TipoAlta = "NORMALIZADA"; Nombre = "Ana"; Apellidos = "Pérez"; Email = "invalid-email"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    $Users += [PSCustomObject]@{
        TipoAlta = "NORMALIZADA"; Nombre = "Luis"; Apellidos = "Díaz"; Email = "@invalid.com"
        Telefono = "123456789"; Oficina = "Test Office"; Descripcion = "Test"; AD = ""
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: $OutputPath ($(($Users).Count) invalid users)" -ForegroundColor Yellow
}

function New-EdgeCasesCSV {
    param([string]$OutputPath)
    
    Write-Host "Generating edge cases CSV for stress testing..." -ForegroundColor Magenta
    
    $Users = @()
    
    # Text encoding nightmares - the "mamámámálaga" problem and variants
    $TextEncodingCases = @(
        @{ Oficina = "Juzgado de Primera Instancia Nº 19 de mamámámálaga" }
        @{ Oficina = "Juzgado de Instrucción Nº 3 de MAMÁMÁMÁLAGA" }
        @{ Oficina = "Juzgado de lo Penal Nº 1 de Mamámámálaga" }
        @{ Oficina = "Juzgado de Primera Instancia Nº 5 de córdóbácórdoba" }
        @{ Oficina = "Juzgado de Familia Nº 2 de sevíllasevílla" }
    )
    
    foreach ($Case in $TextEncodingCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case -IntroduceIssues
    }
    
    # Number format variations
    $NumberFormatCases = @(
        @{ Oficina = "Juzgado de Primera Instancia N° 19 de Málaga" }
        @{ Oficina = "Juzgado de Primera Instancia No. 25 de Sevilla" }
        @{ Oficina = "Juzgado de Primera Instancia Núm. 3 de Granada" }
        @{ Oficina = "Juzgado de Primera Instancia # 7 de Córdoba" }
        @{ Oficina = "Juzgado de Primera Instancia 15 de Almería" }
    )
    
    foreach ($Case in $NumberFormatCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    # Whitespace chaos
    $WhitespaceCases = @(
        @{ Oficina = "  Juzgado    de   Primera   Instancia  Nº   19    de   Málaga  " }
        @{ Oficina = "`tJuzgado de Primera Instancia Nº 25 de Sevilla`t" }
        @{ Oficina = "Juzgado`nde Primera Instancia`nNº 3 de Granada" }
    )
    
    foreach ($Case in $WhitespaceCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    # Very long office names
    $LongNameCases = @(
        @{ Oficina = "Juzgado de Primera Instancia e Instrucción Número 19 de Málaga - Ciudad de la Justicia - Área Civil y Penal - Turno de Oficio - Especialidad en Familia y Violencia de Género" }
        @{ Oficina = "Audiencia Provincial de Sevilla - Sección Segunda - Sala de lo Civil - Ponencia de Recursos de Apelación en materia de Derecho de Familia" }
    )
    
    foreach ($Case in $LongNameCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    # Mixed case nightmares
    $MixedCaseCases = @(
        @{ Oficina = "jUZGADO dE pRIMERA iNSTANCIA nº 19 DE mÁLAGA" }
        @{ Oficina = "JUZGADO DE PRIMERA INSTANCIA Nº 25 DE SEVILLA" }
        @{ Oficina = "Juzgado De Primera Instancia Nº 3 De Granada" }
    )
    
    foreach ($Case in $MixedCaseCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    # Special character combinations
    $SpecialCharCases = @(
        @{ Nombre = "José-María"; Apellidos = "García-López" }
        @{ Nombre = "Mª Carmen"; Apellidos = "Ruiz y Pérez" }
        @{ Nombre = "Juan Carlos"; Apellidos = "de la Cruz Martínez" }
        @{ Telefono = "+34-954-123-456" }
        @{ Telefono = "954 12 34 56" }
        @{ Telefono = "(954) 123456" }
    )
    
    foreach ($Case in $SpecialCharCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    # Email edge cases  
    $EmailEdgeCases = @(
        @{ Email = "usuario.con.puntos@justicia.junta-andalucia.es" }
        @{ Email = "usuario+etiqueta@justicia.junta-andalucia.es" }
        @{ Email = "usuario_con_guion@justicia.junta-andalucia.es" }
        @{ Email = "USUARIO.MAYUSCULAS@JUSTICIA.JUNTA-ANDALUCIA.ES" }
    )
    
    foreach ($Case in $EmailEdgeCases) {
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides $Case
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: $OutputPath ($(($Users).Count) edge case users)" -ForegroundColor Magenta
}

function New-ProvinceSpecificCSV {
    param([string]$OutputPath)
    
    Write-Host "Generating province-specific test scenarios..." -ForegroundColor Cyan
    
    $Users = @()
    
    # Specific problematic scenarios for each province
    $ProvinceScenarios = @{
        "Málaga" = @(
            "Juzgado de Primera Instancia Nº 19 de Málaga",
            "Juzgado de Primera Instancia e Instrucción Nº 3", 
            "Juzgado de lo Penal Nº 1 - Ciudad de la Justicia",
            "mamámámálaga test case"
        )
        "Sevilla" = @(
            "Juzgado de Primera Instancia Nº 25 de Sevilla",
            "Juzgado de Instrucción Nº 15 de Sevilla",
            "Audiencia Provincial de Sevilla - Sección 2ª"
        )
        "Granada" = @(
            "Juzgado de Primera Instancia Nº 12 de Granada",
            "Juzgado de Familia Nº 2 de Granada"
        )
        "Córdoba" = @(
            "Juzgado de Primera Instancia Nº 8 de Córdoba", 
            "Juzgado de lo Mercantil Nº 1 de Córdoba"
        )
        "Almería" = @(
            "Juzgado de Primera Instancia Nº 6 de Almería",
            "Juzgado de Violencia sobre la Mujer Nº 1"
        )
        "Cádiz" = @(
            "Juzgado de Primera Instancia Nº 4 de Cádiz",
            "Juzgado de lo Social Nº 2 de Jerez"
        )
        "Huelva" = @(
            "Juzgado de Primera Instancia Nº 3 de Huelva"
        )
        "Jaén" = @(
            "Juzgado de Primera Instancia Nº 2 de Jaén"
        )
    }
    
    foreach ($Province in $ProvinceScenarios.Keys) {
        foreach ($Office in $ProvinceScenarios[$Province]) {
            $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Province $Province -Overrides @{ Oficina = $Office }
        }
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: $OutputPath ($(($Users).Count) province-specific scenarios)" -ForegroundColor Cyan
}

function New-PerformanceCSV {
    param([string]$OutputPath, [int]$UserCount = 5000)
    
    Write-Host "Generating large performance test CSV with $UserCount users..." -ForegroundColor Blue
    
    $Users = @()
    
    1..$UserCount | ForEach-Object {
        if ($_ % 500 -eq 0) {
            Write-Host "Generated $_/$UserCount users..." -ForegroundColor Gray
        }
        
        $TipoAlta = switch (($_ % 10)) {
            { $_ -in 0..6 } { "NORMALIZADA" }
            { $_ -in 7..8 } { "TRASLADO" }
            default { "COMPAGINADA" }
        }
        
        $Province = Get-Random -InputObject $Global:TestDataPatterns.Provinces
        $IntroduceIssues = ($_ % 20 -eq 0) # 5% with issues
        
        $Users += New-SyntheticUser -TipoAlta $TipoAlta -Province $Province -IntroduceIssues:$IntroduceIssues
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: $OutputPath ($UserCount users for performance testing)" -ForegroundColor Blue
}

function New-UOMappingCSV {
    param([string]$OutputPath)
    
    Write-Host "Generating UO mapping specific test scenarios..." -ForegroundColor Green
    
    $Users = @()
    
    # Specific mapping challenges from real scenarios
    $MappingChallenges = @(
        # Perfect matches - should score HIGH
        @{ Oficina = "Juzgado de Primera Instancia Nº 19 de Málaga" }
        @{ Oficina = "Juzgado de Primera Instancia Nº 25 de Sevilla" }
        
        # Partial matches - test scoring system
        @{ Oficina = "Juzgado de Instrucción Nº 3" } # Missing province
        @{ Oficina = "Primera Instancia Nº 19 de Málaga" } # Missing "Juzgado de"
        
        # Number mismatches - should penalize
        @{ Oficina = "Juzgado de Primera Instancia Nº 20 de Málaga" } # Wrong number
        
        # Mixed instruction types - special mapping scenarios  
        @{ Oficina = "Juzgado de Primera Instancia e Instrucción Nº 3" }
        @{ Oficina = "Juzgado de Instrucción Nº 3" } # Should map to mixed type above
        
        # Ciudad de la Justicia scenarios
        @{ Oficina = "Juzgado de Primera Instancia Nº 19 - Ciudad de la Justicia" }
        @{ Oficina = "Juzgado de lo Penal Nº 5 - Ciudad de la Justicia de Málaga" }
        
        # Encoding problems that affect matching
        @{ Oficina = "Juzgado de Primera Instancia Nº 19 de mamámámálaga" }
        @{ Oficina = "Juzgado de Primera Instancia Nº 25 de SEVILLA" }
        
        # Cross-province confusion tests
        @{ Oficina = "Juzgado de Primera Instancia Nº 1 de Sevilla" } # Common number
        @{ Oficina = "Juzgado de Primera Instancia Nº 1 de Málaga" }  # Same number different province
        @{ Oficina = "Juzgado de Primera Instancia Nº 1 de Granada" }
    )
    
    foreach ($Challenge in $MappingChallenges) {
        $Province = "Unknown"
        if ($Challenge.Oficina -match "málaga|malaga|mamámámálaga") { $Province = "Málaga" }
        elseif ($Challenge.Oficina -match "sevilla") { $Province = "Sevilla" }
        elseif ($Challenge.Oficina -match "granada") { $Province = "Granada" }
        elseif ($Challenge.Oficina -match "córdoba|cordoba") { $Province = "Córdoba" }
        
        $Users += New-SyntheticUser -TipoAlta "NORMALIZADA" -Province $Province -Overrides $Challenge
    }
    
    $Users | Export-Csv -Path $OutputPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation  
    Write-Host "Created: $OutputPath ($(($Users).Count) UO mapping test scenarios)" -ForegroundColor Green
}

# Main execution logic
Write-Host "AD_ADMIN Synthetic CSV Data Generator" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

if ($GenerateAll -or $Scenario -eq "Valid") {
    New-ValidUsersCSV -OutputPath (Join-Path $OutputDirectory "valid_users.csv")
}

if ($GenerateAll -or $Scenario -eq "Invalid") {
    New-InvalidUsersCSV -OutputPath (Join-Path $OutputDirectory "invalid_users.csv")
}

if ($GenerateAll -or $Scenario -eq "EdgeCases") {
    New-EdgeCasesCSV -OutputPath (Join-Path $OutputDirectory "edge_cases.csv")
}

if ($GenerateAll -or $Scenario -eq "Provinces") {
    New-ProvinceSpecificCSV -OutputPath (Join-Path $OutputDirectory "province_tests.csv")
}

if ($GenerateAll -or $Scenario -eq "Performance") {
    New-PerformanceCSV -OutputPath (Join-Path $OutputDirectory "performance_5000.csv") -UserCount 5000
}

if ($GenerateAll -or $Scenario -eq "UOMapping") {
    New-UOMappingCSV -OutputPath (Join-Path $OutputDirectory "uo_mapping_tests.csv")
}

# Generate specific problematic scenario files
if ($GenerateAll -or $Scenario -eq "Malaga") {
    $MalagaUsers = @()
    $MalagaUsers += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides @{ Oficina = "Juzgado de Primera Instancia Nº 19 de Málaga" }
    $MalagaUsers += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides @{ Oficina = "Juzgado de Primera Instancia Nº 19 de mamámámálaga" }
    $MalagaUsers += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides @{ Oficina = "Juzgado de Primera Instancia e Instrucción Nº 3" }
    $MalagaUsers | Export-Csv -Path (Join-Path $OutputDirectory "malaga_scenario.csv") -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: malaga_scenario.csv (specific Málaga test cases)" -ForegroundColor Green
}

if ($GenerateAll -or $Scenario -eq "Sevilla") {
    $SevillaUsers = @()
    $SevillaUsers += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides @{ Oficina = "Juzgado de Primera Instancia Nº 25 de Sevilla" }
    $SevillaUsers += New-SyntheticUser -TipoAlta "NORMALIZADA" -Overrides @{ Oficina = "JUZGADO DE PRIMERA INSTANCIA Nº 25 DE SEVILLA" }
    $SevillaUsers | Export-Csv -Path (Join-Path $OutputDirectory "sevilla_scenario.csv") -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Host "Created: sevilla_scenario.csv (specific Sevilla test cases)" -ForegroundColor Green
}

Write-Host "`nSynthetic CSV generation completed!" -ForegroundColor Yellow
Write-Host "Files generated in: $OutputDirectory" -ForegroundColor Green

# Generate summary report
$Files = Get-ChildItem -Path $OutputDirectory -Filter "*.csv"
Write-Host "`nGenerated Files Summary:" -ForegroundColor Cyan
foreach ($File in $Files) {
    $LineCount = (Get-Content $File.FullName | Measure-Object).Count - 1 # Subtract header
    Write-Host "  $($File.Name): $LineCount users" -ForegroundColor White
}