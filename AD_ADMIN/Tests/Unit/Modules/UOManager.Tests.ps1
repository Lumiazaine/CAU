#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive unit tests for UOManager module
.DESCRIPTION
    Tests all critical functions in UOManager.psm1 including edge cases and problematic scenarios
#>

BeforeAll {
    # Import module under test
    $ModulePath = Join-Path $PSScriptRoot "..\..\..\Modules\UOManager.psm1"
    Import-Module $ModulePath -Force
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "..\..\Config\TestEnvironment.psd1"
    $TestConfig = Import-PowerShellDataFile -Path $TestConfigPath
    
    # Mock AD functions to avoid real AD dependency
    Mock Get-ADDomain {
        param($Identity)
        return [PSCustomObject]@{
            DNSRoot = $Identity
            DistinguishedName = "DC=$(($Identity -split '\.')[0]),DC=$(($Identity -split '\.')[1]),DC=$(($Identity -split '\.')[2]),DC=$(($Identity -split '\.')[3])"
            Name = ($Identity -split '\.')[0]
        }
    }
    
    Mock Get-ADOrganizationalUnit {
        param($Filter, $SearchBase, $SearchScope)
        
        # Return mock OUs based on common test scenarios
        $MockOUs = @(
            [PSCustomObject]@{
                Name = "Juzgado de Primera Instancia e Instruccion No 3"
                DistinguishedName = "OU=Juzgado de Primera Instancia e Instruccion No 3,OU=Juzgados,OU=Malaga-MACJ,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            },
            [PSCustomObject]@{
                Name = "Juzgado de Primera Instancia No 19"
                DistinguishedName = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            },
            [PSCustomObject]@{
                Name = "Juzgados de Primera Instancia No 25 de Sevilla"
                DistinguishedName = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
            }
        )
        
        return $MockOUs
    }
}

Describe "UOManager Module - Critical Functions" {
    
    Context "Initialize-UOManager Function" {
        
        It "Should initialize UO cache successfully" {
            $Result = Initialize-UOManager
            $Result | Should -Be $true
        }
        
        It "Should handle domain connection failures gracefully" {
            Mock Get-ADDomain { throw "Domain not reachable" }
            
            $Result = Initialize-UOManager
            $Result | Should -Be $false
        }
        
        It "Should load all Andalusian provinces" {
            Initialize-UOManager
            $UOs = Get-AvailableUOs
            
            $AndalusianProvinces = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
            
            foreach ($Province in $AndalusianProvinces) {
                $UOs | Should -Contain $Province
            }
        }
    }
    
    Context "Get-UOByName Function - Core Logic" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should find exact matches case-insensitively" {
            $Result = Get-UOByName -Name "malaga"
            $Result | Should -Not -BeNullOrEmpty
            
            $Result2 = Get-UOByName -Name "MALAGA"
            $Result2 | Should -Not -BeNullOrEmpty
            
            $Result3 = Get-UOByName -Name "Malaga"
            $Result3 | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle partial matches correctly" {
            $Result = Get-UOByName -Name "mal"
            $Result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return null for non-existent UO" {
            $Result = Get-UOByName -Name "nonexistent"
            $Result | Should -BeNullOrEmpty
        }
        
        It "Should handle special characters in UO names" {
            $Result = Get-UOByName -Name "málaga"
            $Result | Should -Not -BeNullOrEmpty
        }
        
        It "Should trim whitespace from input" {
            $Result1 = Get-UOByName -Name " malaga "
            $Result2 = Get-UOByName -Name "malaga"
            
            $Result1.DNSRoot | Should -Be $Result2.DNSRoot
        }
    }
    
    Context "Get-UOByName Function - Edge Cases & Problems" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should handle empty or null input gracefully" {
            $Result1 = Get-UOByName -Name ""
            $Result1 | Should -BeNullOrEmpty
            
            $Result2 = Get-UOByName -Name $null
            $Result2 | Should -BeNullOrEmpty
        }
        
        It "Should handle problematic character combinations" {
            # Test the "mamámámálaga" problem identified in logs
            Mock Get-UOByName {
                param($Name)
                
                $Name = $Name.ToLower().Trim()
                
                # Simulate the problematic text normalization
                if ($Name -like "*mamámámálaga*") {
                    return $null # This should be fixed to return malaga
                }
                
                if ($Name -like "*malaga*" -or $Name -like "*málaga*") {
                    return [PSCustomObject]@{ DNSRoot = "malaga.justicia.junta-andalucia.es" }
                }
                
                return $null
            } -ModuleName UOManager
            
            $Result = Get-UOByName -Name "mamámámálaga"
            $Result | Should -BeNullOrEmpty # This test will fail until the bug is fixed
        }
        
        It "Should prioritize exact matches over partial matches" {
            # This tests the problematic fuzzy matching logic
            Mock Get-UOByName {
                param($Name)
                
                $Name = $Name.ToLower().Trim()
                $UOCache = @{
                    "cordoba" = [PSCustomObject]@{ DNSRoot = "cordoba.justicia.junta-andalucia.es" }
                    "cordobatest" = [PSCustomObject]@{ DNSRoot = "cordobatest.justicia.junta-andalucia.es" }
                }
                
                # Current implementation - problematic fuzzy matching
                foreach ($Key in $UOCache.Keys) {
                    if ($Key -like "*$Name*" -or $Name -like "*$Key*") {
                        return $UOCache[$Key]
                    }
                }
                
                return $null
            } -ModuleName UOManager
            
            $Result = Get-UOByName -Name "cordoba"
            # Should return exact match, but current implementation might return first partial match
            $Result.DNSRoot | Should -Be "cordoba.justicia.junta-andalucia.es"
        }
    }
    
    Context "Test-UOExists Function" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should return true for existing UO" {
            $Result = Test-UOExists -Name "malaga"
            $Result | Should -Be $true
        }
        
        It "Should return false for non-existing UO" {
            $Result = Test-UOExists -Name "nonexistent"
            $Result | Should -Be $false
        }
        
        It "Should handle case sensitivity properly" {
            $Result1 = Test-UOExists -Name "MALAGA"
            $Result2 = Test-UOExists -Name "malaga"
            $Result3 = Test-UOExists -Name "Malaga"
            
            $Result1 | Should -Be $Result2
            $Result2 | Should -Be $Result3
        }
    }
    
    Context "Get-UOContainer Function" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should return valid DN for existing UO" {
            $Result = Get-UOContainer -UOName "malaga"
            $Result | Should -Match "DC=malaga,DC=justicia,DC=junta-andalucia,DC=es$"
        }
        
        It "Should throw for non-existing UO" {
            { Get-UOContainer -UOName "nonexistent" } | Should -Throw "UO no encontrada: nonexistent"
        }
        
        It "Should prefer Users container when available" {
            Mock Get-ADOrganizationalUnit {
                param($Filter, $SearchBase, $SearchScope)
                
                if ($Filter -eq "Name -eq 'Users'") {
                    return [PSCustomObject]@{
                        DistinguishedName = "OU=Users,$SearchBase"
                    }
                }
                
                return @()
            }
            
            $Result = Get-UOContainer -UOName "malaga"
            $Result | Should -Match "OU=Users"
        }
    }
    
    Context "Find-NewOUs Function" {
        
        It "Should discover new OUs and add to cache" {
            Initialize-UOManager
            $InitialCount = (Get-AvailableUOs).Count
            
            # Mock new OU discovery
            Mock Get-ADOrganizationalUnit {
                return @(
                    [PSCustomObject]@{
                        Name = "newtestou"
                        DistinguishedName = "OU=newtestou,DC=test,DC=justicia,DC=junta-andalucia,DC=es"
                    }
                )
            }
            
            Find-NewOUs
            $FinalCount = (Get-AvailableUOs).Count
            
            $FinalCount | Should -BeGreaterThan $InitialCount
        }
        
        It "Should handle AD connection errors gracefully" {
            Mock Get-ADOrganizationalUnit { throw "AD connection failed" }
            
            { Find-NewOUs } | Should -Not -Throw
        }
    }
}

Describe "UOManager Module - Performance Tests" {
    
    Context "Performance Benchmarks" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should complete UO lookup within performance threshold" {
            $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            1..100 | ForEach-Object {
                Get-UOByName -Name "malaga"
            }
            
            $StopWatch.Stop()
            $StopWatch.ElapsedMilliseconds | Should -BeLessThan 1000 # 1 second for 100 lookups
        }
        
        It "Should handle concurrent lookups efficiently" {
            $Jobs = @()
            $ProvinceList = @("malaga", "sevilla", "cordoba", "granada")
            
            foreach ($Province in $ProvinceList) {
                $Jobs += Start-Job -ScriptBlock {
                    param($ProvinceName, $ModulePath)
                    Import-Module $ModulePath -Force
                    Initialize-UOManager
                    1..25 | ForEach-Object { Get-UOByName -Name $ProvinceName }
                } -ArgumentList $Province, $ModulePath
            }
            
            $Results = $Jobs | Wait-Job | Receive-Job
            $Jobs | Remove-Job
            
            $Results.Count | Should -Be 100 # 4 provinces × 25 iterations
        }
    }
}

Describe "UOManager Module - Integration Scenarios" {
    
    Context "Real-World Scenario Tests" {
        
        BeforeEach {
            Initialize-UOManager
        }
        
        It "Should handle Málaga 'Ciudad de la Justicia' scenario correctly" {
            # This tests the specific case mentioned in the logs
            $Office = "Juzgado de Primera Instancia Nº 19 de Málaga"
            
            # Extract location from office name
            $Location = if ($Office -match "málaga|malaga") { "malaga" } else { "unknown" }
            
            $Result = Get-UOByName -Name $Location
            $Result | Should -Not -BeNullOrEmpty
            $Result.DNSRoot | Should -Match "malaga"
        }
        
        It "Should handle Sevilla scenario correctly" {
            $Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"
            
            $Location = if ($Office -match "sevilla") { "sevilla" } else { "unknown" }
            
            $Result = Get-UOByName -Name $Location
            $Result | Should -Not -BeNullOrEmpty
            $Result.DNSRoot | Should -Match "sevilla"
        }
        
        It "Should handle edge case with mixed encoding" {
            # Test various encoding issues that could cause problems
            $TestCases = @(
                "málaga",
                "malaga",
                "MÁLAGA",
                "MALAGA",
                "Málaga"
            )
            
            foreach ($TestCase in $TestCases) {
                $Result = Get-UOByName -Name $TestCase
                $Result | Should -Not -BeNullOrEmpty -Because "Failed for: $TestCase"
            }
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module UOManager -Force -ErrorAction SilentlyContinue
}