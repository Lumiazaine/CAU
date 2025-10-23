#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Sets up the complete testing environment for AD_ADMIN project
.DESCRIPTION
    Installs Pester 5.0, creates test structure, and prepares sandbox environment
.PARAMETER InstallPester
    Forces installation of Pester 5.0
.PARAMETER CreateSandbox
    Creates AD sandbox environment structure
#>

param(
    [switch]$InstallPester = $true,
    [switch]$CreateSandbox = $true
)

$ErrorActionPreference = "Stop"

# Test environment configuration
$Global:TestConfig = @{
    TestDirectory = Join-Path $PSScriptRoot ".."
    PesterVersion = "5.6.1"
    SandboxDomain = "sandbox.justicia.test"
    TestDataDirectory = Join-Path $PSScriptRoot "TestData"
    ReportsDirectory = Join-Path $PSScriptRoot "Reports"
    CoverageDirectory = Join-Path $PSScriptRoot "Coverage"
}

function Write-TestLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Color = switch ($Level) {
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
    }
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

function Install-PesterModule {
    Write-TestLog "Setting up Pester 5.0 testing framework..." "INFO"
    
    try {
        # Check if Pester 5.x is already installed
        $PesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.0.0" }
        
        if (-not $PesterModule) {
            Write-TestLog "Installing Pester $($Global:TestConfig.PesterVersion)..." "INFO"
            
            # Remove old Pester versions
            $OldPester = Get-Module -ListAvailable -Name Pester
            if ($OldPester) {
                Write-TestLog "Removing old Pester versions..." "WARNING"
                $OldPester | Uninstall-Module -Force -ErrorAction SilentlyContinue
            }
            
            # Install Pester 5.x
            Install-Module -Name Pester -RequiredVersion $Global:TestConfig.PesterVersion -Force -SkipPublisherCheck -Scope AllUsers
            
            Write-TestLog "Pester $($Global:TestConfig.PesterVersion) installed successfully" "SUCCESS"
        } else {
            Write-TestLog "Pester 5.x already installed (Version: $($PesterModule.Version))" "SUCCESS"
        }
        
        # Import Pester
        Import-Module Pester -Force
        
        # Verify installation
        $ImportedPester = Get-Module -Name Pester
        if ($ImportedPester.Version -ge [version]"5.0.0") {
            Write-TestLog "Pester verification successful - Version: $($ImportedPester.Version)" "SUCCESS"
            return $true
        } else {
            throw "Pester version verification failed"
        }
        
    } catch {
        Write-TestLog "Failed to install Pester: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function New-TestStructure {
    Write-TestLog "Creating comprehensive test directory structure..." "INFO"
    
    $TestStructure = @(
        "Tests",
        "Tests\Unit",
        "Tests\Unit\Modules", 
        "Tests\Integration",
        "Tests\E2E",
        "Tests\Performance",
        "Tests\Security",
        "Tests\Regression",
        "Tests\TestData",
        "Tests\TestData\CSV",
        "Tests\TestData\MockAD", 
        "Tests\TestData\Scenarios",
        "Tests\Reports",
        "Tests\Coverage",
        "Tests\Artifacts",
        "Tests\Config"
    )
    
    foreach ($Dir in $TestStructure) {
        $FullPath = Join-Path $Global:TestConfig.TestDirectory $Dir
        if (-not (Test-Path $FullPath)) {
            New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
            Write-TestLog "Created directory: $Dir" "INFO"
        }
    }
    
    Write-TestLog "Test directory structure created successfully" "SUCCESS"
}

function New-TestConfiguration {
    Write-TestLog "Creating Pester configuration files..." "INFO"
    
    # Main Pester configuration
    $PesterConfigPath = Join-Path $Global:TestConfig.TestDirectory "Tests\pester.config.ps1"
    
    $PesterConfig = @'
# Pester 5.0 Configuration for AD_ADMIN Testing Framework
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Run.Path = @(
    ".\Unit",
    ".\Integration", 
    ".\E2E"
)

$PesterPreference.TestResult.Enabled = $true
$PesterPreference.TestResult.OutputPath = ".\Reports\TestResults.xml"
$PesterPreference.TestResult.OutputFormat = "NUnitXml"

$PesterPreference.CodeCoverage.Enabled = $true
$PesterPreference.CodeCoverage.Path = @(
    "..\Modules\*.psm1",
    "..\*.ps1"
)
$PesterPreference.CodeCoverage.OutputPath = ".\Coverage\CodeCoverage.xml"
$PesterPreference.CodeCoverage.OutputFormat = "JaCoCo"

$PesterPreference.Output.Verbosity = "Detailed"
$PesterPreference.Run.Exit = $false
$PesterPreference.Run.PassThru = $true

return $PesterPreference
'@
    
    Set-Content -Path $PesterConfigPath -Value $PesterConfig -Encoding UTF8
    
    # Test environment config
    $TestEnvConfigPath = Join-Path $Global:TestConfig.TestDirectory "Tests\Config\TestEnvironment.psd1"
    
    $TestEnvConfig = @"
@{
    # AD_ADMIN Test Environment Configuration
    TestEnvironment = @{
        SandboxDomain = '$($Global:TestConfig.SandboxDomain)'
        TestOUs = @(
            'OU=TestUsers,DC=sandbox,DC=justicia,DC=test',
            'OU=Malaga-Test,DC=sandbox,DC=justicia,DC=test',
            'OU=Sevilla-Test,DC=sandbox,DC=justicia,DC=test'
        )
        TestGroups = @(
            'CN=TestGroup1,OU=TestGroups,DC=sandbox,DC=justicia,DC=test',
            'CN=TestGroup2,OU=TestGroups,DC=sandbox,DC=justicia,DC=test'
        )
        MockAD = $true
        UseRealAD = $false
    }
    
    TestData = @{
        CSVSamples = @{
            ValidCSV = 'TestData\CSV\valid_users.csv'
            InvalidCSV = 'TestData\CSV\invalid_users.csv'
            EdgeCasesCSV = 'TestData\CSV\edge_cases.csv'
            ProvinceTestsCSV = 'TestData\CSV\province_tests.csv'
        }
        
        UOMappings = @{
            MalagaScenarios = 'TestData\Scenarios\malaga_mappings.json'
            SevillaScenarios = 'TestData\Scenarios\sevilla_mappings.json'
            EdgeCases = 'TestData\Scenarios\edge_cases.json'
        }
    }
    
    Performance = @{
        MaxExecutionTimeSeconds = 300
        MaxMemoryUsageMB = 512
        ParallelTestCount = 4
    }
    
    QualityGates = @{
        MinCodeCoverage = 95
        MaxFailedTests = 0
        MaxWarnings = 10
        CriticalBugTolerance = 0
    }
}
"@
    
    Set-Content -Path $TestEnvConfigPath -Value $TestEnvConfig -Encoding UTF8
    
    Write-TestLog "Test configuration files created successfully" "SUCCESS"
}

function Initialize-MockADStructure {
    Write-TestLog "Initializing Mock AD structure for testing..." "INFO"
    
    $MockADPath = Join-Path $Global:TestConfig.TestDirectory "Tests\TestData\MockAD"
    
    # Mock AD Users structure
    $MockUsers = @{
        "existinguser1" = @{
            SamAccountName = "existinguser1"
            DisplayName = "Usuario Existente Uno"
            Email = "existinguser1@justicia.junta-andalucia.es"
            DistinguishedName = "CN=Usuario Existente Uno,OU=Users,OU=Malaga-Test,DC=sandbox,DC=justicia,DC=test"
            Enabled = $true
            Office = "Juzgado de Primera Instancia No 1 de Málaga"
        }
        "existinguser2" = @{
            SamAccountName = "existinguser2" 
            DisplayName = "Usuario Existente Dos"
            Email = "existinguser2@justicia.junta-andalucia.es"
            DistinguishedName = "CN=Usuario Existente Dos,OU=Users,OU=Sevilla-Test,DC=sandbox,DC=justicia,DC=test"
            Enabled = $false
            Office = "Juzgado de Primera Instancia No 25 de Sevilla"
        }
    }
    
    $MockUsersPath = Join-Path $MockADPath "MockUsers.json"
    $MockUsers | ConvertTo-Json -Depth 3 | Set-Content -Path $MockUsersPath -Encoding UTF8
    
    # Mock AD OUs structure with problematic scenarios
    $MockOUs = @{
        "MalagaOUs" = @(
            @{
                Name = "Juzgado de Primera Instancia e Instruccion No 3"
                DistinguishedName = "OU=Juzgado de Primera Instancia e Instruccion No 3,OU=Juzgados,OU=Malaga-MACJ,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                Description = "Juzgado mixto de Málaga No 3"
            },
            @{
                Name = "Juzgado de Primera Instancia No 19"
                DistinguishedName = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                Description = "Juzgado de Primera Instancia No 19 de Málaga"
            }
        )
        "SevillaOUs" = @(
            @{
                Name = "Juzgados de Primera Instancia No 25 de Sevilla"
                DistinguishedName = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
                Description = "Juzgado de Primera Instancia No 25 de Sevilla"
            }
        )
    }
    
    $MockOUsPath = Join-Path $MockADPath "MockOUs.json"
    $MockOUs | ConvertTo-Json -Depth 4 | Set-Content -Path $MockOUsPath -Encoding UTF8
    
    Write-TestLog "Mock AD structure initialized successfully" "SUCCESS"
}

# Main execution
Write-TestLog "Starting AD_ADMIN Test Environment Setup" "INFO"
Write-TestLog "=========================================" "INFO"

if ($InstallPester) {
    if (-not (Install-PesterModule)) {
        Write-TestLog "Failed to setup Pester - aborting setup" "ERROR"
        exit 1
    }
}

New-TestStructure
New-TestConfiguration

if ($CreateSandbox) {
    Initialize-MockADStructure
}

Write-TestLog "=========================================" "SUCCESS"
Write-TestLog "AD_ADMIN Test Environment Setup Complete" "SUCCESS"
Write-TestLog "Next steps:" "INFO"
Write-TestLog "1. Run .\Tests\Run-AllTests.ps1 to execute test suite" "INFO" 
Write-TestLog "2. Check .\Tests\Reports\ for test results" "INFO"
Write-TestLog "3. Review coverage report in .\Tests\Coverage\" "INFO"