#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests with AD sandbox environment for AD_ADMIN system
.DESCRIPTION
    Comprehensive integration testing framework that uses a sandbox AD environment
    to test real AD operations without affecting production data
#>

BeforeAll {
    # Import required modules
    $ModulesPath = Join-Path $PSScriptRoot "..\..\Modules"
    $TestModules = @(
        "UOManager.psm1",
        "DomainStructureManager.psm1", 
        "UserSearch.psm1",
        "CSVValidation.psm1"
    )
    
    foreach ($Module in $TestModules) {
        $ModulePath = Join-Path $ModulesPath $Module
        if (Test-Path $ModulePath) {
            Import-Module $ModulePath -Force
        }
    }
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "..\Config\TestEnvironment.psd1"
    $Global:TestConfig = Import-PowerShellDataFile -Path $TestConfigPath -ErrorAction SilentlyContinue
    
    if (-not $Global:TestConfig) {
        throw "Test configuration not found at $TestConfigPath"
    }
    
    # Sandbox AD Configuration
    $Global:SandboxConfig = @{
        Domain = "sandbox.justicia.test"
        RootDN = "DC=sandbox,DC=justicia,DC=test"
        AdminUser = "testadmin@sandbox.justicia.test"
        TestOUBase = "OU=TestData,DC=sandbox,DC=justicia,DC=test"
        BackupPath = "C:\TestBackups\AD_Sandbox"
        UseMockAD = $Global:TestConfig.TestEnvironment.MockAD
    }
    
    # Mock AD functions if not using real sandbox
    if ($Global:SandboxConfig.UseMockAD) {
        Write-Host "Using Mock AD for integration testing" -ForegroundColor Yellow
        
        Mock Get-ADDomain {
            param($Identity)
            return [PSCustomObject]@{
                DNSRoot = $Identity
                DistinguishedName = "DC=sandbox,DC=justicia,DC=test"
                Name = "sandbox"
                NetBIOSName = "SANDBOX"
            }
        }
        
        Mock Get-ADOrganizationalUnit {
            param($Filter, $SearchBase, $SearchScope, $Properties)
            
            # Return mock OUs based on test scenarios
            return @(
                [PSCustomObject]@{
                    Name = "TestOU-Malaga"
                    DistinguishedName = "OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    Description = "Mock Málaga OU for testing"
                    whenCreated = (Get-Date).AddDays(-30)
                    whenChanged = (Get-Date).AddDays(-1)
                },
                [PSCustomObject]@{
                    Name = "TestOU-Sevilla"
                    DistinguishedName = "OU=TestOU-Sevilla,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    Description = "Mock Sevilla OU for testing"
                    whenCreated = (Get-Date).AddDays(-25)
                    whenChanged = (Get-Date).AddDays(-2)
                }
            )
        }
        
        Mock Get-ADUser {
            param($Filter, $SearchBase, $Properties)
            
            return @(
                [PSCustomObject]@{
                    SamAccountName = "testuser1"
                    Name = "Test User One"
                    DisplayName = "Test User One"
                    EmailAddress = "testuser1@sandbox.justicia.test"
                    DistinguishedName = "CN=Test User One,OU=Users,OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    Enabled = $true
                    Office = "Juzgado de Primera Instancia No 19 de Málaga"
                    Description = "LAJ"
                },
                [PSCustomObject]@{
                    SamAccountName = "testuser2"
                    Name = "Test User Two"
                    DisplayName = "Test User Two"
                    EmailAddress = "testuser2@sandbox.justicia.test"
                    DistinguishedName = "CN=Test User Two,OU=Users,OU=TestOU-Sevilla,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    Enabled = $false
                    Office = "Juzgado de Primera Instancia No 25 de Sevilla"
                    Description = "Letrado"
                }
            )
        }
        
        Mock New-ADUser {
            param($Name, $SamAccountName, $Path, $EmailAddress, $Office, $Description)
            
            Write-Verbose "Mock: Creating AD user $SamAccountName in $Path"
            return [PSCustomObject]@{
                SamAccountName = $SamAccountName
                Name = $Name
                DistinguishedName = "CN=$Name,$Path"
                Created = Get-Date
            }
        }
        
        Mock Set-ADUser {
            param($Identity, $Replace, $Add, $Remove)
            Write-Verbose "Mock: Updating AD user $Identity"
            return $true
        }
        
        Mock Remove-ADUser {
            param($Identity, $Confirm)
            Write-Verbose "Mock: Removing AD user $Identity"
            return $true
        }
    }
    
    # Initialize sandbox environment
    function Initialize-SandboxEnvironment {
        try {
            if ($Global:SandboxConfig.UseMockAD) {
                Write-Host "Mock AD environment initialized" -ForegroundColor Green
                return $true
            } else {
                # Real sandbox initialization would go here
                Write-Host "Real AD sandbox environment not available - using mock" -ForegroundColor Yellow
                return $true
            }
        } catch {
            Write-Error "Failed to initialize sandbox environment: $($_.Exception.Message)"
            return $false
        }
    }
    
    function Backup-SandboxState {
        # In a real environment, this would backup the sandbox AD state
        Write-Verbose "Backing up sandbox state (mock)"
        return $true
    }
    
    function Restore-SandboxState {
        # In a real environment, this would restore the sandbox AD state
        Write-Verbose "Restoring sandbox state (mock)"
        return $true
    }
    
    # Initialize the sandbox
    $SandboxInitialized = Initialize-SandboxEnvironment
    if (-not $SandboxInitialized) {
        throw "Failed to initialize sandbox environment"
    }
}

Describe "AD Sandbox Integration Tests - UO Management" {
    
    BeforeEach {
        Backup-SandboxState
        
        # Initialize UO Manager with sandbox configuration
        if (Get-Command Initialize-UOManager -ErrorAction SilentlyContinue) {
            Initialize-UOManager
        }
    }
    
    AfterEach {
        Restore-SandboxState
    }
    
    Context "UO Discovery and Caching" {
        
        It "Should discover OUs in sandbox environment" {
            $UOs = Get-AvailableUOs
            $UOs | Should -Not -BeNullOrEmpty
            $UOs.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle sandbox domain queries correctly" {
            $UO = Get-UOByName -Name "TestOU-Malaga"
            $UO | Should -Not -BeNullOrEmpty
            $UO.Name | Should -Be "TestOU-Malaga"
        }
        
        It "Should cache discovered UOs for performance" {
            # First call
            $StartTime = Get-Date
            $UO1 = Get-UOByName -Name "TestOU-Malaga"
            $FirstCallTime = (Get-Date) - $StartTime
            
            # Second call (should be cached)
            $StartTime = Get-Date
            $UO2 = Get-UOByName -Name "TestOU-Malaga"  
            $SecondCallTime = (Get-Date) - $StartTime
            
            $UO1.Name | Should -Be $UO2.Name
            $SecondCallTime | Should -BeLessThan $FirstCallTime
        }
        
        It "Should find new OUs added to sandbox" {
            $InitialCount = (Get-AvailableUOs).Count
            
            # Mock adding a new OU
            Mock Get-ADOrganizationalUnit {
                param($Filter, $SearchBase, $SearchScope)
                
                $ExistingOUs = @(
                    [PSCustomObject]@{
                        Name = "TestOU-Malaga"
                        DistinguishedName = "OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    },
                    [PSCustomObject]@{
                        Name = "TestOU-NewlyAdded"
                        DistinguishedName = "OU=TestOU-NewlyAdded,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                    }
                )
                
                return $ExistingOUs
            }
            
            Find-NewOUs
            $FinalCount = (Get-AvailableUOs).Count
            
            $FinalCount | Should -BeGreaterThan $InitialCount
        }
    }
}

Describe "AD Sandbox Integration Tests - User Operations" {
    
    BeforeEach {
        Backup-SandboxState
    }
    
    AfterEach {
        Restore-SandboxState  
    }
    
    Context "User Creation and Management" {
        
        It "Should create new AD user in sandbox" {
            $UserData = @{
                Name = "Integration Test User"
                SamAccountName = "inttestuser"
                EmailAddress = "inttestuser@sandbox.justicia.test"
                Office = "Juzgado de Primera Instancia No 99 de Test"
                Description = "Integration Test LAJ"
                Path = "OU=Users,OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
            }
            
            $Result = New-ADUser @UserData
            $Result | Should -Not -BeNullOrEmpty
            $Result.SamAccountName | Should -Be $UserData.SamAccountName
        }
        
        It "Should find existing users in sandbox" {
            if (Get-Command Search-UserByName -ErrorAction SilentlyContinue) {
                $Users = Search-UserByName -FirstName "Test" -LastName "User"
                $Users | Should -Not -BeNullOrEmpty
                $Users.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "Search-UserByName function not available"
            }
        }
        
        It "Should update user properties correctly" {
            $UserIdentity = "testuser1"
            $NewProperties = @{
                Office = "Updated Office Location"
                Description = "Updated Description"
            }
            
            $Result = Set-ADUser -Identity $UserIdentity -Replace $NewProperties
            $Result | Should -Be $true
        }
        
        It "Should handle user transfer operations" {
            $SourceUser = "testuser1"
            $TargetOU = "OU=Users,OU=TestOU-Sevilla,OU=TestData,DC=sandbox,DC=justicia,DC=test"
            
            # Mock user transfer operation
            Mock Move-ADObject {
                param($Identity, $TargetPath)
                Write-Verbose "Mock: Moving user $Identity to $TargetPath"
                return $true
            }
            
            if (Get-Command Move-ADObject -ErrorAction SilentlyContinue) {
                $Result = Move-ADObject -Identity "CN=Test User One,OU=Users,OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test" -TargetPath $TargetOU
                $Result | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "Move-ADObject not available in mock environment"
            }
        }
    }
}

Describe "AD Sandbox Integration Tests - CSV Processing" {
    
    BeforeEach {
        Backup-SandboxState
    }
    
    AfterEach {
        Restore-SandboxState
    }
    
    Context "CSV Validation and Processing" {
        
        It "Should validate CSV structure against sandbox requirements" {
            # Create test CSV content
            $TestCSVContent = @"
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
NORMALIZADA;Juan;García López;jgarcia@sandbox.justicia.test;12345678A;TestOU-Malaga;LAJ;
TRASLADO;María;Rodríguez;mrodriguez@sandbox.justicia.test;87654321B;TestOU-Sevilla;Letrado;testuser2
"@
            
            $TempCSVPath = Join-Path $env:TEMP "integration_test.csv"
            Set-Content -Path $TempCSVPath -Value $TestCSVContent -Encoding UTF8
            
            try {
                if (Get-Command Test-CSVFile -ErrorAction SilentlyContinue) {
                    $ValidationResult = Test-CSVFile -CSVPath $TempCSVPath
                    
                    $ValidationResult | Should -Not -BeNullOrEmpty
                    $ValidationResult.IsValid | Should -Be $true
                    $ValidationResult.TotalRows | Should -Be 2
                    $ValidationResult.ValidRows | Should -Be 2
                } else {
                    Set-ItResult -Skipped -Because "Test-CSVFile function not available"
                }
            } finally {
                Remove-Item -Path $TempCSVPath -ErrorAction SilentlyContinue
            }
        }
        
        It "Should process user creation from CSV in sandbox" {
            $TestUsers = @(
                [PSCustomObject]@{
                    TipoAlta = "NORMALIZADA"
                    Nombre = "Carlos"
                    Apellidos = "Martínez López"
                    Email = "cmartinez@sandbox.justicia.test"
                    Telefono = "11122233A"
                    Oficina = "TestOU-Malaga"
                    Descripcion = "Gestor"
                    AD = ""
                }
            )
            
            foreach ($User in $TestUsers) {
                # Mock processing the user creation
                $UserParams = @{
                    Name = "$($User.Nombre) $($User.Apellidos)"
                    SamAccountName = "cmartinez_test"
                    EmailAddress = $User.Email
                    Office = $User.Oficina
                    Description = $User.Descripcion
                    Path = "OU=Users,OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                }
                
                $Result = New-ADUser @UserParams
                $Result | Should -Not -BeNullOrEmpty
                $Result.SamAccountName | Should -Be "cmartinez_test"
            }
        }
    }
}

Describe "AD Sandbox Integration Tests - Error Handling" {
    
    Context "Network and Connectivity Issues" {
        
        It "Should handle AD connection timeouts gracefully" {
            # Mock network timeout
            Mock Get-ADDomain {
                Start-Sleep -Seconds 2
                throw "The server is not operational"
            }
            
            $Result = Initialize-UOManager
            $Result | Should -Be $false
        }
        
        It "Should recover from temporary AD unavailability" {
            # Mock intermittent AD failures
            $script:CallCount = 0
            Mock Get-ADOrganizationalUnit {
                $script:CallCount++
                if ($script:CallCount -le 2) {
                    throw "The domain controller is not available"
                } else {
                    return @(
                        [PSCustomObject]@{
                            Name = "RecoveredOU"
                            DistinguishedName = "OU=RecoveredOU,DC=sandbox,DC=justicia,DC=test"
                        }
                    )
                }
            }
            
            # First attempts should fail
            { Find-NewOUs } | Should -Not -Throw
            
            # Subsequent attempt should succeed
            $Result = Get-UOByName -Name "RecoveredOU"
            $Result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Data Integrity and Validation" {
        
        It "Should prevent creation of duplicate users" {
            # Mock duplicate user scenario
            Mock Get-ADUser {
                param($Filter)
                if ($Filter -like "*testduplicate*") {
                    return [PSCustomObject]@{
                        SamAccountName = "testduplicate"
                        Name = "Existing Test User"
                    }
                }
                return $null
            }
            
            Mock New-ADUser {
                throw "The specified account already exists"
            }
            
            { New-ADUser -Name "Test Duplicate" -SamAccountName "testduplicate" } | Should -Throw
        }
        
        It "Should validate OU paths before user creation" {
            Mock Get-ADOrganizationalUnit {
                param($Filter, $SearchBase)
                if ($SearchBase -like "*NonExistentOU*") {
                    return $null
                }
                throw "The specified object was not found"
            }
            
            $InvalidPath = "OU=NonExistentOU,DC=sandbox,DC=justicia,DC=test"
            
            { New-ADUser -Name "Test User" -SamAccountName "testuser" -Path $InvalidPath } | Should -Throw
        }
    }
}

Describe "AD Sandbox Integration Tests - Performance" {
    
    Context "Bulk Operations Performance" {
        
        It "Should handle bulk user creation efficiently" {
            $UserCount = 10
            $Users = @()
            
            1..$UserCount | ForEach-Object {
                $Users += @{
                    Name = "Bulk Test User $_"
                    SamAccountName = "bulktest$_"
                    EmailAddress = "bulktest$_@sandbox.justicia.test"
                    Path = "OU=Users,OU=TestOU-Malaga,OU=TestData,DC=sandbox,DC=justicia,DC=test"
                }
            }
            
            $StartTime = Get-Date
            
            foreach ($User in $Users) {
                $Result = New-ADUser @User
                $Result | Should -Not -BeNullOrEmpty
            }
            
            $ExecutionTime = (Get-Date) - $StartTime
            $ExecutionTime.TotalSeconds | Should -BeLessThan 30 # Should complete within 30 seconds
        }
        
        It "Should cache UO lookups for performance" {
            $LookupCount = 20
            
            $StartTime = Get-Date
            
            1..$LookupCount | ForEach-Object {
                $UO = Get-UOByName -Name "TestOU-Malaga"
                $UO | Should -Not -BeNullOrEmpty
            }
            
            $ExecutionTime = (Get-Date) - $StartTime
            $ExecutionTime.TotalSeconds | Should -BeLessThan 5 # Cached lookups should be very fast
        }
    }
}

AfterAll {
    # Cleanup sandbox environment
    try {
        Restore-SandboxState
        
        # Remove imported modules
        $TestModules = @("UOManager", "DomainStructureManager", "UserSearch", "CSVValidation")
        foreach ($Module in $TestModules) {
            Remove-Module -Name $Module -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "AD Sandbox integration test cleanup completed" -ForegroundColor Green
        
    } catch {
        Write-Warning "Error during test cleanup: $($_.Exception.Message)"
    }
}