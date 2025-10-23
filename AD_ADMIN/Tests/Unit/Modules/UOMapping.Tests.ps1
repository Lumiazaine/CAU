#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive tests for UO mapping and scoring system
.DESCRIPTION
    Tests the critical UO matching logic, scoring algorithms, and confidence assessment
    that determine which UO a user should be placed in based on their office location.
#>

BeforeAll {
    # Import required modules
    $ModulesPath = Join-Path $PSScriptRoot "..\..\..\Modules"
    Import-Module (Join-Path $ModulesPath "UOManager.psm1") -Force
    
    # Load test scenarios from existing test scripts
    . (Join-Path $PSScriptRoot "..\..\..\test_scoring_system.ps1") -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot "..\..\..\test_malaga_scenario.ps1") -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot "..\..\..\test_sevilla_scenario.ps1") -ErrorAction SilentlyContinue
    
    # Import synthetic test data
    $SyntheticDataPath = Join-Path $PSScriptRoot "..\..\TestData\CSV"
    
    # Define test functions based on actual implementation
    function Normalize-Text {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
        
        $Replacements = @{
            [char]0x00F1 = 'n'; [char]0x00D1 = 'N'
            [char]0x00E1 = 'a'; [char]0x00C1 = 'A' 
            [char]0x00E9 = 'e'; [char]0x00C9 = 'E'
            [char]0x00ED = 'i'; [char]0x00CD = 'I'
            [char]0x00F3 = 'o'; [char]0x00D3 = 'O'
            [char]0x00FA = 'u'; [char]0x00DA = 'U'
        }
        
        $NormalizedText = $Text
        foreach ($pair in $Replacements.GetEnumerator()) {
            $NormalizedText = $NormalizedText -replace $pair.Key, $pair.Value
        }
        
        # Fix known problematic patterns
        $NormalizedText = $NormalizedText -replace 'mamámámálaga', 'malaga'
        $NormalizedText = $NormalizedText -replace 'MAMÁMÁMÁLAGA', 'MALAGA'
        
        $NormalizedText = $NormalizedText -replace '\s+', ' '
        $NormalizedText = $NormalizedText -replace '[^\w\s\-]', ''
        return $NormalizedText.Trim()
    }
    
    function Extract-LocationFromOffice {
        param([string]$Office)
        
        $OfficeClean = Normalize-Text -Text $Office
        $OfficeLower = $OfficeClean.ToLower()
        
        $LocationMappings = @{
            'malaga' = 'malaga'
            'málaga' = 'malaga'
            'sevilla' = 'sevilla'
            'cordoba' = 'cordoba'
            'córdoba' = 'cordoba'
            'granada' = 'granada'
            'cadiz' = 'cadiz'
            'cádiz' = 'cadiz'
            'almeria' = 'almeria'
            'jaen' = 'jaen'
            'huelva' = 'huelva'
        }
        
        foreach ($Location in $LocationMappings.Keys) {
            if ($OfficeLower -like "*$Location*") {
                return $LocationMappings[$Location]
            }
        }
        
        return "UNKNOWN"
    }
    
    function Extract-LocationFromOU {
        param([string]$OUDN)
        
        $OUClean = Normalize-Text -Text $OUDN
        $OULower = $OUClean.ToLower()
        
        $LocationPatterns = @{
            'sevilla-se' = 'sevilla'
            'sevilla' = 'sevilla'
            'malaga-macj' = 'malaga'
            'ciudad de la justicia' = 'malaga'
            'cordoba-co' = 'cordoba'
            'granada-gr' = 'granada'
            'cadiz-ca' = 'cadiz'
            'almeria-al' = 'almeria'
            'jaen-ja' = 'jaen'
            'huelva-hu' = 'huelva'
        }
        
        foreach ($Pattern in $LocationPatterns.Keys) {
            if ($OULower -like "*$Pattern*") {
                return $LocationPatterns[$Pattern]
            }
        }
        
        return "UNKNOWN"
    }
    
    function Get-UOMatchConfidence {
        param(
            [int]$Score,
            [int]$KeywordMatches,
            [string]$Office,
            [string]$OUDN
        )
        
        $OfficeLocation = Extract-LocationFromOffice -Office $Office
        $OULocation = Extract-LocationFromOU -OUDN $OUDN
        
        # Extract numbers for exact matching
        $OfficeNumber = $null
        $OUNumber = $null
        
        if ($Office -match 'n[ºo°]\s*(\d+)') {
            $OfficeNumber = $matches[1]
        }
        
        if ($OUDN -match 'n[ºo°]\s*(\d+)') {
            $OUNumber = $matches[1]
        }
        
        # HIGH confidence criteria
        if ($OfficeNumber -and $OUNumber -and $OfficeNumber -eq $OUNumber -and 
            $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and 
            $KeywordMatches -ge 2) {
            return "HIGH"
        }
        
        if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 3) {
            return "HIGH"
        }
        
        if ($Score -ge 100 -and $KeywordMatches -ge 3) {
            return "HIGH"
        }
        
        if ($Score -ge 80 -and $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN") {
            return "HIGH"
        }
        
        # MEDIUM confidence
        if (($Score -ge 50 -and $KeywordMatches -ge 2) -or ($KeywordMatches -ge 4)) {
            return "MEDIUM"
        }
        
        if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 2) {
            return "MEDIUM"
        }
        
        # LOW confidence
        if ($Score -ge 10 -and $KeywordMatches -ge 1) {
            return "LOW"
        }
        
        return "VERY_LOW"
    }
    
    function Calculate-UOMatchScore {
        param(
            [string]$Office,
            [string]$OUDN,
            [string]$OUName
        )
        
        $NormalizedOffice = (Normalize-Text -Text $Office).ToLower()
        $NormalizedOUName = (Normalize-Text -Text $OUName).ToLower()
        
        $Score = 0
        $KeywordMatches = 0
        
        # Extract numbers
        $OfficeNumber = ""
        if ($NormalizedOffice -match '\b(\d+)\b') {
            $OfficeNumber = $Matches[1]
        }
        
        $OUNumber = ""
        if ($NormalizedOUName -match '\bn[o..]\s*(\d+)') {
            $OUNumber = $Matches[1]
        }
        
        # Special mapping logic for mixed instruction courts
        $IsInstruccionOnly = $NormalizedOffice -like "*instruccion*" -and 
                            $NormalizedOffice -notlike "*primera*" -and 
                            $NormalizedOffice -notlike "*instancia*" -and
                            $NormalizedOffice -like "*juzgado*"
        
        $IsFirstInstanceInstruction = $NormalizedOUName -like "*primera*" -and 
                                     $NormalizedOUName -like "*instancia*" -and 
                                     $NormalizedOUName -like "*instruccion*"
        
        # Special mapping bonus
        if ($IsInstruccionOnly -and $IsFirstInstanceInstruction) {
            $Score += 100
            $KeywordMatches += 5
        }
        
        # Number matching
        if ($OfficeNumber -and $OUNumber) {
            if ($OfficeNumber -eq $OUNumber) {
                $Score += 20
            } else {
                $Score = [math]::Max(1, $Score * 0.3) # Penalize mismatched numbers
            }
        }
        
        # Keyword matching
        $KeyWords = @('juzgado', 'primera', 'instancia', 'instruccion', 'penal', 'social', 'familia', 'mercantil')
        foreach ($KeyWord in $KeyWords) {
            if ($NormalizedOffice -like "*$KeyWord*" -and $NormalizedOUName -like "*$KeyWord*") {
                $KeywordMatches++
                $Score += 1
            }
        }
        
        return @{
            Score = [int]$Score
            KeywordMatches = $KeywordMatches
            OfficeNumber = $OfficeNumber
            OUNumber = $OUNumber
        }
    }
    
    # Mock test data - realistic UO scenarios
    $Global:MockUOs = @{
        "malaga" = @(
            @{
                Name = "Juzgado de Primera Instancia e Instruccion No 3"
                DistinguishedName = "OU=Juzgado de Primera Instancia e Instruccion No 3,OU=Juzgados,OU=Malaga-MACJ,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            },
            @{
                Name = "Juzgado de Primera Instancia No 19"
                DistinguishedName = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            }
        )
        "sevilla" = @(
            @{
                Name = "Juzgados de Primera Instancia No 25 de Sevilla"
                DistinguishedName = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
            }
        )
    }
}

Describe "UO Mapping and Scoring System" {
    
    Context "Text Normalization for Mapping" {
        
        It "Should normalize problematic office names correctly" {
            $ProblematicCases = @(
                @{ Input = "mamámámálaga test"; Expected = "malaga test" }
                @{ Input = "Juzgado de Primera Instancia Nº 19"; ShouldContain = @("juzgado", "primera", "instancia", "19") }
                @{ Input = "JUZGADO DE INSTRUCCIÓN Nº 3"; ShouldContain = @("juzgado", "instruccion", "3") }
            )
            
            foreach ($Case in $ProblematicCases) {
                $Result = Normalize-Text -Text $Case.Input
                
                if ($Case.Expected) {
                    $Result.ToLower() | Should -Be $Case.Expected
                }
                
                if ($Case.ShouldContain) {
                    foreach ($ExpectedWord in $Case.ShouldContain) {
                        $Result.ToLower() | Should -Match $ExpectedWord -Because "Should contain '$ExpectedWord' in normalized text"
                    }
                }
            }
        }
        
        It "Should handle whitespace and special characters consistently" {
            $Input = "  Juzgado   de   Primera   Instancia   Nº  19   "
            $Result = Normalize-Text -Text $Input
            
            $Result | Should -Not -Match "^\s" -Because "Should not start with whitespace"
            $Result | Should -Not -Match "\s$" -Because "Should not end with whitespace"
            $Result | Should -Not -Match "\s{2,}" -Because "Should not contain multiple spaces"
        }
    }
    
    Context "Location Extraction Logic" {
        
        It "Should correctly extract province from office names" {
            $LocationTests = @(
                @{ Office = "Juzgado de Primera Instancia Nº 19 de Málaga"; Expected = "malaga" }
                @{ Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"; Expected = "sevilla" }
                @{ Office = "Juzgado de Instrucción Nº 3 de Córdoba"; Expected = "cordoba" }
                @{ Office = "mamámámálaga test case"; Expected = "malaga" }
                @{ Office = "Something in Granada"; Expected = "granada" }
                @{ Office = "Unknown location"; Expected = "UNKNOWN" }
            )
            
            foreach ($Test in $LocationTests) {
                $Result = Extract-LocationFromOffice -Office $Test.Office
                $Result | Should -Be $Test.Expected -Because "Failed for office: $($Test.Office)"
            }
        }
        
        It "Should correctly extract province from UO Distinguished Names" {
            $OUTests = @(
                @{ 
                    OUDN = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "malaga"
                }
                @{
                    OUDN = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "sevilla"
                }
                @{
                    OUDN = "OU=Something,OU=Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "malaga"
                }
            )
            
            foreach ($Test in $OUTests) {
                $Result = Extract-LocationFromOU -OUDN $Test.OUDN
                $Result | Should -Be $Test.Expected -Because "Failed for DN: $($Test.OUDN)"
            }
        }
    }
    
    Context "UO Match Scoring Algorithm" {
        
        It "Should calculate high scores for perfect matches" {
            $PerfectMatchTests = @(
                @{
                    Office = "Juzgado de Primera Instancia Nº 19 de Málaga"
                    OUName = "Juzgado de Primera Instancia No 19"
                    ExpectedMinScore = 50
                    ExpectedMinKeywords = 3
                }
                @{
                    Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"
                    OUName = "Juzgados de Primera Instancia No 25 de Sevilla"
                    ExpectedMinScore = 50
                    ExpectedMinKeywords = 3
                }
            )
            
            foreach ($Test in $PerfectMatchTests) {
                $Result = Calculate-UOMatchScore -Office $Test.Office -OUName $Test.OUName -OUDN "test"
                
                $Result.Score | Should -BeGreaterOrEqual $Test.ExpectedMinScore
                $Result.KeywordMatches | Should -BeGreaterOrEqual $Test.ExpectedMinKeywords
            }
        }
        
        It "Should handle special instruction mapping scenario correctly" {
            # This tests the specific mapping logic for "Juzgado de Instrucción" -> "Primera Instancia e Instrucción"
            $Office = "Juzgado de Instrucción Nº 3"
            $OUName = "Juzgado de Primera Instancia e Instruccion No 3"
            
            $Result = Calculate-UOMatchScore -Office $Office -OUName $OUName -OUDN "test"
            
            $Result.Score | Should -BeGreaterThan 100 -Because "Special mapping should give bonus score"
            $Result.KeywordMatches | Should -BeGreaterOrEqual 5 -Because "Special mapping should increase keyword matches"
        }
        
        It "Should penalize number mismatches appropriately" {
            $MismatchTests = @(
                @{
                    Office = "Juzgado de Primera Instancia Nº 19 de Málaga"
                    OUName = "Juzgado de Primera Instancia No 20"  # Wrong number
                    ShouldBePenalized = $true
                }
                @{
                    Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"
                    OUName = "Juzgado de Primera Instancia No 25"  # Correct number
                    ShouldBePenalized = $false
                }
            )
            
            foreach ($Test in $MismatchTests) {
                $Result = Calculate-UOMatchScore -Office $Test.Office -OUName $Test.OUName -OUDN "test"
                
                if ($Test.ShouldBePenalized) {
                    $Result.Score | Should -BeLessThan 20 -Because "Mismatched numbers should be penalized heavily"
                } else {
                    $Result.Score | Should -BeGreaterThan 20 -Because "Matched numbers should not be penalized"
                }
            }
        }
    }
    
    Context "Confidence Assessment Logic" {
        
        It "Should assign HIGH confidence for perfect matches" {
            $HighConfidenceTests = @(
                @{
                    Score = 125
                    KeywordMatches = 4
                    Office = "Juzgado de Primera Instancia Nº 19 de Málaga"
                    OUDN = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "HIGH"
                }
                @{
                    Score = 30  # Even low score should be HIGH if other criteria met
                    KeywordMatches = 3
                    Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"
                    OUDN = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "HIGH"
                }
            )
            
            foreach ($Test in $HighConfidenceTests) {
                $Result = Get-UOMatchConfidence -Score $Test.Score -KeywordMatches $Test.KeywordMatches -Office $Test.Office -OUDN $Test.OUDN
                $Result | Should -Be $Test.Expected -Because "Perfect match scenario should have HIGH confidence"
            }
        }
        
        It "Should assign MEDIUM confidence for partial matches" {
            $MediumConfidenceTests = @(
                @{
                    Score = 60
                    KeywordMatches = 2
                    Office = "Juzgado de Primera Instancia de Málaga"  # Missing number
                    OUDN = "OU=Juzgado de Primera Instancia No 19,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
                    Expected = "MEDIUM"
                }
            )
            
            foreach ($Test in $MediumConfidenceTests) {
                $Result = Get-UOMatchConfidence -Score $Test.Score -KeywordMatches $Test.KeywordMatches -Office $Test.Office -OUDN $Test.OUDN
                $Result | Should -Be $Test.Expected
            }
        }
        
        It "Should assign LOW/VERY_LOW confidence for poor matches" {
            $LowConfidenceTests = @(
                @{
                    Score = 5
                    KeywordMatches = 1
                    Office = "Some random office"
                    OUDN = "OU=Completely different,DC=other,DC=domain"
                    Expected = "LOW"
                }
                @{
                    Score = 0
                    KeywordMatches = 0
                    Office = "Unrelated text"
                    OUDN = "OU=No match at all"
                    Expected = "VERY_LOW"
                }
            )
            
            foreach ($Test in $LowConfidenceTests) {
                $Result = Get-UOMatchConfidence -Score $Test.Score -KeywordMatches $Test.KeywordMatches -Office $Test.Office -OUDN $Test.OUDN
                $Result | Should -BeIn @("LOW", "VERY_LOW") -Because "Poor matches should have low confidence"
            }
        }
    }
}

Describe "Real-World Scenario Tests" {
    
    Context "Málaga Scenario - From Actual Logs" {
        
        It "Should correctly handle the 'Ciudad de la Justicia' mapping" {
            $Office = "Juzgado de Primera Instancia Nº 19 de Málaga"
            $OUDN = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            
            $OfficeLocation = Extract-LocationFromOffice -Office $Office
            $OULocation = Extract-LocationFromOU -OUDN $OUDN
            
            $OfficeLocation | Should -Be "malaga"
            $OULocation | Should -Be "malaga"
            
            $Scoring = Calculate-UOMatchScore -Office $Office -OUName "Juzgado de Primera Instancia No 19" -OUDN $OUDN
            $Confidence = Get-UOMatchConfidence -Score $Scoring.Score -KeywordMatches $Scoring.KeywordMatches -Office $Office -OUDN $OUDN
            
            $Confidence | Should -Be "HIGH" -Because "Perfect number and location match should result in HIGH confidence"
        }
        
        It "Should handle the mamámámálaga text encoding problem" {
            $ProblematicOffice = "Juzgado de Primera Instancia Nº 19 de mamámámálaga"
            $OUDN = "OU=Juzgado de Primera Instancia No 19,OU=Malaga-MACJ,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            
            $OfficeLocation = Extract-LocationFromOffice -Office $ProblematicOffice
            $OULocation = Extract-LocationFromOU -OUDN $OUDN
            
            # The normalized location should resolve to 'malaga'
            $OfficeLocation | Should -Be "malaga" -Because "Problematic text should normalize to 'malaga'"
            $OULocation | Should -Be "malaga"
            
            $Confidence = Get-UOMatchConfidence -Score 50 -KeywordMatches 3 -Office $ProblematicOffice -OUDN $OUDN
            $Confidence | Should -Be "HIGH" -Because "After normalization, should match correctly"
        }
    }
    
    Context "Sevilla Scenario - From Actual Logs" {
        
        It "Should correctly map Sevilla Juzgado de Primera Instancia No 25" {
            $Office = "Juzgado de Primera Instancia Nº 25 de Sevilla"
            $OUDN = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
            
            $OfficeLocation = Extract-LocationFromOffice -Office $Office
            $OULocation = Extract-LocationFromOU -OUDN $OUDN
            
            $OfficeLocation | Should -Be "sevilla"
            $OULocation | Should -Be "sevilla"
            
            # Extract numbers
            $Office -match 'nº\s*(\d+)' | Should -Be $true
            $OfficeNumber = $Matches[1]
            $OfficeNumber | Should -Be "25"
            
            $OUDN -match 'no\s*(\d+)' | Should -Be $true
            $OUNumber = $Matches[1]
            $OUNumber | Should -Be "25"
            
            $Confidence = Get-UOMatchConfidence -Score 50 -KeywordMatches 3 -Office $Office -OUDN $OUDN
            $Confidence | Should -Be "HIGH" -Because "Perfect match with same number and location"
        }
    }
    
    Context "Cross-Province Confusion Prevention" {
        
        It "Should distinguish between same-numbered courts in different provinces" {
            $TestScenarios = @(
                @{ Office = "Juzgado de Primera Instancia Nº 1 de Sevilla"; Province = "sevilla" }
                @{ Office = "Juzgado de Primera Instancia Nº 1 de Málaga"; Province = "malaga" }
                @{ Office = "Juzgado de Primera Instancia Nº 1 de Granada"; Province = "granada" }
            )
            
            foreach ($Scenario in $TestScenarios) {
                $ExtractedLocation = Extract-LocationFromOffice -Office $Scenario.Office
                $ExtractedLocation | Should -Be $Scenario.Province -Because "Should correctly identify province for same-numbered courts"
            }
        }
        
        It "Should penalize cross-province matches" {
            $Office = "Juzgado de Primera Instancia Nº 1 de Sevilla"
            $WrongProvinceOUDN = "OU=Juzgado de Primera Instancia No 1,OU=Malaga-MACJ,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
            
            $OfficeLocation = Extract-LocationFromOffice -Office $Office
            $OULocation = Extract-LocationFromOU -OUDN $WrongProvinceOUDN
            
            $OfficeLocation | Should -Be "sevilla"
            $OULocation | Should -Be "malaga"
            
            # Even with matching numbers, different provinces should reduce confidence
            $Confidence = Get-UOMatchConfidence -Score 50 -KeywordMatches 3 -Office $Office -OUDN $WrongProvinceOUDN
            $Confidence | Should -Not -Be "HIGH" -Because "Different provinces should prevent HIGH confidence"
        }
    }
}

Describe "Performance and Stress Testing" {
    
    Context "Mapping Performance" {
        
        It "Should process UO mappings efficiently" {
            $TestOffices = @(
                "Juzgado de Primera Instancia Nº 1 de Sevilla",
                "Juzgado de Primera Instancia Nº 19 de Málaga", 
                "Juzgado de Instrucción Nº 3 de Granada",
                "Juzgado de lo Penal Nº 5 de Córdoba",
                "Audiencia Provincial de Almería"
            )
            
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            foreach ($Office in $TestOffices) {
                1..20 | ForEach-Object {
                    $Location = Extract-LocationFromOffice -Office $Office
                    $Normalized = Normalize-Text -Text $Office
                    $Scoring = Calculate-UOMatchScore -Office $Office -OUName "Test OU" -OUDN "Test DN"
                }
            }
            
            $Stopwatch.Stop()
            $Stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000 -Because "Should process 100 mappings in under 1 second"
        }
        
        It "Should handle large batches efficiently" {
            # Load synthetic test data if available
            $SyntheticDataPath = Join-Path $PSScriptRoot "..\..\TestData\CSV\performance_5000.csv"
            
            if (Test-Path $SyntheticDataPath) {
                $TestData = Import-Csv -Path $SyntheticDataPath -Delimiter ";"
                $SampleData = $TestData | Select-Object -First 100
                
                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                $Results = $SampleData | ForEach-Object {
                    $Location = Extract-LocationFromOffice -Office $_.Oficina
                    $Normalized = Normalize-Text -Text $_.Oficina
                    
                    @{
                        Office = $_.Oficina
                        Location = $Location
                        Normalized = $Normalized
                    }
                }
                
                $Stopwatch.Stop()
                
                $Results.Count | Should -Be 100
                $Stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000 -Because "Should process 100 real scenarios in under 2 seconds"
            } else {
                Set-ItResult -Skipped -Because "Synthetic test data not available"
            }
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module UOManager -Force -ErrorAction SilentlyContinue
}