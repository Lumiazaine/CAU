#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Suite de tests exhaustivos para validación del sistema AD_ADMIN Enhanced
.DESCRIPTION
    Batería completa de pruebas para casos edge, normalización de texto,
    algoritmos de scoring y mapeo de UOs con reporting detallado
.VERSION
    3.0 - Enterprise testing framework
.AUTHOR
    AD_ADMIN Enhanced Team
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# Importar módulo enhanced
Import-Module "$PSScriptRoot\Modules\UOManagerEnhanced.psm1" -Force

# Variables globales del framework de testing
$script:TestResults = @()
$script:TestStats = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
    StartTime = Get-Date
    EndTime = $null
}

# Casos de test críticos para entorno judicial
$script:CriticalTestCases = @(
    # CASOS EDGE DE NORMALIZACIÓN
    @{
        Name = "Normalización caracteres especiales completos"
        Input = "Juzgado de Instrucción Nº 3 - Málaga (1ª Instancia)"
        Expected = "juzgado de instruccion no 3 malaga 1 instancia"
        Category = "Normalization"
        CriticalLevel = "High"
    },
    @{
        Name = "Manejo acentos múltiples y ñ"
        Input = "Peñón de Vélez - Señorío Andalúz"
        Expected = "penon de velez senorio andaluz"
        Category = "Normalization"
        CriticalLevel = "High"
    },
    @{
        Name = "Unicode y caracteres especiales"
        Input = "Córdoba – Administración Pública (Sección 2ª)"
        Expected = "cordoba administracion publica seccion 2"
        Category = "Normalization"
        CriticalLevel = "High"
    },
    
    # CASOS EDGE DE MAPEO UO
    @{
        Name = "Mapeo especial Instrucción -> Primera Instancia e Instrucción"
        Search = "Juzgado de Instrucción No 3"
        CandidateName = "Juzgado de Primera Instancia e Instrucción No 3"
        ExpectedMinScore = 90
        Category = "UOMapping"
        CriticalLevel = "Critical"
    },
    @{
        Name = "Diferencia numérica penalizada correctamente"
        Search = "Juzgado de Instrucción No 1"
        CandidateName = "Juzgado de Primera Instancia e Instrucción No 3"
        ExpectedMaxScore = 50  # Debe penalizar diferencia numérica
        Category = "UOMapping"
        CriticalLevel = "High"
    },
    @{
        Name = "Match exacto con puntuación perfecta"
        Search = "Juzgado de lo Penal No 2"
        CandidateName = "Juzgado de lo Penal No 2"
        ExpectedMinScore = 95
        Category = "UOMapping"
        CriticalLevel = "Critical"
    },
    @{
        Name = "Rechazo de matches irrelevantes"
        Search = "Juzgado de Instrucción No 1"
        CandidateName = "Audiencia Provincial Civil"
        ExpectedMaxScore = 30  # Debe rechazar completamente
        Category = "UOMapping"
        CriticalLevel = "High"
    },
    
    # CASOS EDGE DE NÚMEROS Y ABREVIACIONES
    @{
        Name = "Variaciones numéricas (Nº, No, Num)"
        TestSet = @(
            @{ Input = "Juzgado No 1"; Expected = "juzgado no 1" },
            @{ Input = "Juzgado Nº 1"; Expected = "juzgado no 1" },
            @{ Input = "Juzgado N.º 1"; Expected = "juzgado no 1" },
            @{ Input = "Juzgado Num. 1"; Expected = "juzgado no 1" }
        )
        Category = "Normalization"
        CriticalLevel = "High"
    },
    
    # CASOS EDGE DE PERFORMANCE Y LÍMITES
    @{
        Name = "String muy largo con múltiples caracteres especiales"
        Input = "Juzgado de Primera Instancia e Instrucción Número 15 de Sevilla - Sección Especializada en Violencia sobre la Mujer (Penal) - Señoría: Doña María José Rodríguez-Piñero y Fernández-Zappa"
        ExpectedPattern = "juzgado.*primera.*instancia.*instruccion.*15.*sevilla"
        Category = "Performance"
        CriticalLevel = "Medium"
    },
    @{
        Name = "String vacío y casos nulos"
        TestSet = @(
            @{ Input = ""; Expected = "" },
            @{ Input = "   "; Expected = "" },
            @{ Input = $null; Expected = "" }
        )
        Category = "EdgeCases"
        CriticalLevel = "High"
    }
)

function Write-TestHeader {
    param([string]$Title)
    
    $Border = "=" * 80
    Write-Host ""
    Write-Host $Border -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor White
    Write-Host $Border -ForegroundColor Cyan
    Write-Host ""
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$CriticalLevel = "Medium"
    )
    
    $Icon = if ($Passed) { "✅" } else { "❌" }
    $Color = if ($Passed) { "Green" } else { "Red" }
    $CriticalIcon = switch ($CriticalLevel) {
        "Critical" { "🔴" }
        "High" { "🟡" }
        "Medium" { "🔵" }
        default { "⚪" }
    }
    
    Write-Host "$Icon $CriticalIcon $TestName" -ForegroundColor $Color
    if ($Details) {
        Write-Host "   └─ $Details" -ForegroundColor Gray
    }
    
    $script:TestResults += @{
        Name = $TestName
        Passed = $Passed
        Details = $Details
        CriticalLevel = $CriticalLevel
        Timestamp = Get-Date
    }
    
    $script:TestStats.Total++
    if ($Passed) { $script:TestStats.Passed++ } else { $script:TestStats.Failed++ }
}

function Test-NormalizationEnhanced {
    Write-TestHeader "PRUEBAS DE NORMALIZACIÓN DE TEXTO ENHANCED"
    
    foreach ($TestCase in $script:CriticalTestCases | Where-Object { $_.Category -eq "Normalization" }) {
        
        if ($TestCase.TestSet) {
            # Caso con múltiples variaciones
            Write-Host "🧪 Ejecutando: $($TestCase.Name)" -ForegroundColor Yellow
            
            $AllPassed = $true
            $FailureDetails = @()
            
            foreach ($SubTest in $TestCase.TestSet) {
                try {
                    $Result = Normalize-TextEnhanced -Text $SubTest.Input
                    $Passed = $Result -eq $SubTest.Expected
                    
                    if (-not $Passed) {
                        $AllPassed = $false
                        $FailureDetails += "Input: '$($SubTest.Input)' | Expected: '$($SubTest.Expected)' | Got: '$Result'"
                    }
                }
                catch {
                    $AllPassed = $false
                    $FailureDetails += "Input: '$($SubTest.Input)' | ERROR: $($_.Exception.Message)"
                }
            }
            
            $Details = if ($AllPassed) { "Todas las variaciones pasaron correctamente" } else { $FailureDetails -join "; " }
            Write-TestResult -TestName $TestCase.Name -Passed $AllPassed -Details $Details -CriticalLevel $TestCase.CriticalLevel
        }
        elseif ($TestCase.ExpectedPattern) {
            # Caso con patrón regex
            try {
                $Result = Normalize-TextEnhanced -Text $TestCase.Input
                $Passed = $Result -match $TestCase.ExpectedPattern
                $Details = if ($Passed) { "Patrón coincidente" } else { "Expected pattern: '$($TestCase.ExpectedPattern)' | Got: '$Result'" }
                
                Write-TestResult -TestName $TestCase.Name -Passed $Passed -Details $Details -CriticalLevel $TestCase.CriticalLevel
            }
            catch {
                Write-TestResult -TestName $TestCase.Name -Passed $false -Details "ERROR: $($_.Exception.Message)" -CriticalLevel $TestCase.CriticalLevel
            }
        }
        else {
            # Caso simple
            try {
                $Result = Normalize-TextEnhanced -Text $TestCase.Input
                $Passed = $Result -eq $TestCase.Expected
                $Details = if ($Passed) { "Normalización correcta" } else { "Expected: '$($TestCase.Expected)' | Got: '$Result'" }
                
                Write-TestResult -TestName $TestCase.Name -Passed $Passed -Details $Details -CriticalLevel $TestCase.CriticalLevel
            }
            catch {
                Write-TestResult -TestName $TestCase.Name -Passed $false -Details "ERROR: $($_.Exception.Message)" -CriticalLevel $TestCase.CriticalLevel
            }
        }
    }
}

function Test-UOMappingEnhanced {
    Write-TestHeader "PRUEBAS DE MAPEO UO CON SCORING ENHANCED"
    
    foreach ($TestCase in $script:CriticalTestCases | Where-Object { $_.Category -eq "UOMapping" }) {
        Write-Host "🧪 Ejecutando: $($TestCase.Name)" -ForegroundColor Yellow
        
        try {
            $SearchNormalized = Normalize-TextEnhanced -Text $TestCase.Search
            
            # Extraer número si existe
            $SearchNumber = ""
            if ($SearchNormalized -match '\b(\d+)\b') {
                $SearchNumber = $Matches[1]
            }
            
            # Calcular score usando la función enhanced
            $Score = Calculate-UOMatchScore -SearchTerm $SearchNormalized -CandidateName $TestCase.CandidateName -SearchNumber $SearchNumber -EnableLogging
            
            $Passed = $false
            $Details = ""
            
            if ($TestCase.ExpectedMinScore) {
                $Passed = $Score.TotalScore -ge $TestCase.ExpectedMinScore
                $Details = "Score: $($Score.TotalScore) (esperado ≥ $($TestCase.ExpectedMinScore))"
            }
            elseif ($TestCase.ExpectedMaxScore) {
                $Passed = $Score.TotalScore -le $TestCase.ExpectedMaxScore
                $Details = "Score: $($Score.TotalScore) (esperado ≤ $($TestCase.ExpectedMaxScore))"
            }
            
            # Añadir detalles del scoring
            if ($Score.MatchedKeywords.Count -gt 0) {
                $Details += " | Keywords: $($Score.MatchedKeywords -join ', ')"
            }
            
            Write-TestResult -TestName $TestCase.Name -Passed $Passed -Details $Details -CriticalLevel $TestCase.CriticalLevel
        }
        catch {
            Write-TestResult -TestName $TestCase.Name -Passed $false -Details "ERROR: $($_.Exception.Message)" -CriticalLevel $TestCase.CriticalLevel
        }
    }
}

function Test-EdgeCasesEnhanced {
    Write-TestHeader "PRUEBAS DE CASOS EDGE Y LÍMITES"
    
    # Test de strings vacíos y nulos
    $EdgeCaseTests = $script:CriticalTestCases | Where-Object { $_.Category -eq "EdgeCases" }
    
    foreach ($TestCase in $EdgeCaseTests) {
        Write-Host "🧪 Ejecutando: $($TestCase.Name)" -ForegroundColor Yellow
        
        if ($TestCase.TestSet) {
            $AllPassed = $true
            $FailureDetails = @()
            
            foreach ($SubTest in $TestCase.TestSet) {
                try {
                    $Result = Normalize-TextEnhanced -Text $SubTest.Input
                    $Passed = $Result -eq $SubTest.Expected
                    
                    if (-not $Passed) {
                        $AllPassed = $false
                        $FailureDetails += "Input: '$($SubTest.Input)' | Expected: '$($SubTest.Expected)' | Got: '$Result'"
                    }
                }
                catch {
                    $AllPassed = $false
                    $FailureDetails += "Input: '$($SubTest.Input)' | ERROR: $($_.Exception.Message)"
                }
            }
            
            $Details = if ($AllPassed) { "Todos los casos edge manejados correctamente" } else { $FailureDetails -join "; " }
            Write-TestResult -TestName $TestCase.Name -Passed $AllPassed -Details $Details -CriticalLevel $TestCase.CriticalLevel
        }
    }
    
    # Test de performance con strings largos
    $PerformanceTests = $script:CriticalTestCases | Where-Object { $_.Category -eq "Performance" }
    
    foreach ($TestCase in $PerformanceTests) {
        Write-Host "🧪 Ejecutando: $($TestCase.Name)" -ForegroundColor Yellow
        
        try {
            $StartTime = Get-Date
            $Result = Normalize-TextEnhanced -Text $TestCase.Input
            $EndTime = Get-Date
            $Duration = ($EndTime - $StartTime).TotalMilliseconds
            
            # Verificar que el resultado contiene los elementos esperados
            $Passed = $Result -match $TestCase.ExpectedPattern
            $Details = if ($Passed) { "Patrón correcto en ${Duration}ms" } else { "Patrón incorrecto: '$Result'" }
            
            # Añadir warning si es muy lento
            if ($Duration -gt 100) {
                $Details += " | ⚠️ Lento: ${Duration}ms"
                $script:TestStats.Warnings++
            }
            
            Write-TestResult -TestName $TestCase.Name -Passed $Passed -Details $Details -CriticalLevel $TestCase.CriticalLevel
        }
        catch {
            Write-TestResult -TestName $TestCase.Name -Passed $false -Details "ERROR: $($_.Exception.Message)" -CriticalLevel $TestCase.CriticalLevel
        }
    }
}

function Test-IntegrationScenarios {
    Write-TestHeader "PRUEBAS DE INTEGRACIÓN Y ESCENARIOS REALES"
    
    # Escenarios reales del entorno judicial andaluz
    $IntegrationScenarios = @(
        @{
            Name = "Escenario Málaga - Instrucción"
            Office = "Juzgado de Instrucción No 3 - Málaga"
            ExpectedOUs = @("Primera Instancia e Instrucción No 3", "Instrucción No 3")
            MinCandidates = 1
        },
        @{
            Name = "Escenario Sevilla - Penal"
            Office = "Juzgado de lo Penal No 1 - Sevilla"
            ExpectedKeywords = @("juzgado", "penal")
            MinScore = 80
        },
        @{
            Name = "Escenario Córdoba - Primera Instancia"
            Office = "Juzgado de Primera Instancia No 5 - Córdoba"
            ExpectedKeywords = @("juzgado", "primera", "instancia")
            MinScore = 85
        }
    )
    
    foreach ($Scenario in $IntegrationScenarios) {
        Write-Host "🧪 Ejecutando: $($Scenario.Name)" -ForegroundColor Yellow
        
        try {
            # Simular búsqueda de UO usando el escenario
            $NormalizedOffice = Normalize-TextEnhanced -Text $Scenario.Office
            
            # Simular algunos candidatos típicos para testing
            $TestCandidates = @(
                "Juzgado de Primera Instancia e Instrucción No 3 - Málaga",
                "Juzgado de Instrucción No 3 - Málaga", 
                "Juzgado de lo Penal No 1 - Sevilla",
                "Juzgado de Primera Instancia No 5 - Córdoba",
                "Audiencia Provincial de Málaga"
            )
            
            $MatchingCandidates = @()
            
            foreach ($Candidate in $TestCandidates) {
                $Score = Calculate-UOMatchScore -SearchTerm $NormalizedOffice -CandidateName $Candidate -SearchNumber "" -EnableLogging:$false
                
                if ($Score.TotalScore -gt 50) {  # Umbral mínimo
                    $MatchingCandidates += @{
                        Name = $Candidate
                        Score = $Score.TotalScore
                        Keywords = $Score.MatchedKeywords
                    }
                }
            }
            
            $MatchingCandidates = $MatchingCandidates | Sort-Object Score -Descending
            
            $Passed = $false
            $Details = ""
            
            if ($Scenario.MinCandidates) {
                $Passed = $MatchingCandidates.Count -ge $Scenario.MinCandidates
                $Details = "Candidatos encontrados: $($MatchingCandidates.Count) (esperado ≥ $($Scenario.MinCandidates))"
            }
            elseif ($Scenario.MinScore -and $MatchingCandidates.Count -gt 0) {
                $BestScore = $MatchingCandidates[0].Score
                $Passed = $BestScore -ge $Scenario.MinScore
                $Details = "Mejor score: $BestScore (esperado ≥ $($Scenario.MinScore))"
            }
            
            if ($MatchingCandidates.Count -gt 0) {
                $TopCandidate = $MatchingCandidates[0]
                $Details += " | Top: '$($TopCandidate.Name)' ($($TopCandidate.Score) pts)"
            }
            
            Write-TestResult -TestName $Scenario.Name -Passed $Passed -Details $Details -CriticalLevel "High"
        }
        catch {
            Write-TestResult -TestName $Scenario.Name -Passed $false -Details "ERROR: $($_.Exception.Message)" -CriticalLevel "High"
        }
    }
}

function Show-TestSummary {
    Write-TestHeader "RESUMEN DE RESULTADOS"
    
    $script:TestStats.EndTime = Get-Date
    $Duration = ($script:TestStats.EndTime - $script:TestStats.StartTime).TotalSeconds
    
    # Estadísticas generales
    Write-Host "📊 ESTADÍSTICAS GENERALES:" -ForegroundColor White
    Write-Host "   ✅ Tests pasados: $($script:TestStats.Passed)" -ForegroundColor Green
    Write-Host "   ❌ Tests fallidos: $($script:TestStats.Failed)" -ForegroundColor Red
    Write-Host "   ⚠️ Warnings: $($script:TestStats.Warnings)" -ForegroundColor Yellow
    Write-Host "   📈 Total ejecutado: $($script:TestStats.Total)" -ForegroundColor Cyan
    Write-Host "   ⏱️ Duración total: $([math]::Round($Duration, 2)) segundos" -ForegroundColor Cyan
    Write-Host ""
    
    # Calcular tasa de éxito
    $SuccessRate = if ($script:TestStats.Total -gt 0) { [math]::Round(($script:TestStats.Passed / $script:TestStats.Total) * 100, 2) } else { 0 }
    
    $StatusColor = if ($SuccessRate -ge 95) { "Green" } elseif ($SuccessRate -ge 80) { "Yellow" } else { "Red" }
    $StatusIcon = if ($SuccessRate -ge 95) { "🎯" } elseif ($SuccessRate -ge 80) { "⚠️" } else { "🚨" }
    
    Write-Host "$StatusIcon TASA DE ÉXITO: $SuccessRate%" -ForegroundColor $StatusColor
    Write-Host ""
    
    # Desglose por nivel crítico
    $CriticalFailures = $script:TestResults | Where-Object { -not $_.Passed -and $_.CriticalLevel -eq "Critical" }
    $HighFailures = $script:TestResults | Where-Object { -not $_.Passed -and $_.CriticalLevel -eq "High" }
    
    if ($CriticalFailures.Count -gt 0) {
        Write-Host "🔴 FALLOS CRÍTICOS ($($CriticalFailures.Count)):" -ForegroundColor Red
        foreach ($Failure in $CriticalFailures) {
            Write-Host "   • $($Failure.Name): $($Failure.Details)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($HighFailures.Count -gt 0) {
        Write-Host "🟡 FALLOS DE ALTA PRIORIDAD ($($HighFailures.Count)):" -ForegroundColor Yellow
        foreach ($Failure in $HighFailures) {
            Write-Host "   • $($Failure.Name): $($Failure.Details)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Recomendaciones finales
    Write-Host "💡 RECOMENDACIONES:" -ForegroundColor White
    
    if ($SuccessRate -ge 95) {
        Write-Host "   🎉 Sistema listo para producción" -ForegroundColor Green
        Write-Host "   📈 Monitorear performance en entorno real" -ForegroundColor Green
    }
    elseif ($SuccessRate -ge 80) {
        Write-Host "   ⚠️ Revisar fallos de alta prioridad antes de producción" -ForegroundColor Yellow
        Write-Host "   🔧 Optimizar algoritmos de scoring" -ForegroundColor Yellow
    }
    else {
        Write-Host "   🚨 SISTEMA NO LISTO PARA PRODUCCIÓN" -ForegroundColor Red
        Write-Host "   🔧 Refactoring crítico requerido" -ForegroundColor Red
        Write-Host "   📋 Revisar casos de normalización fallidos" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "📁 Log completo guardado en: TestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').json" -ForegroundColor Cyan
    
    # Guardar resultados detallados
    $DetailedResults = @{
        TestStats = $script:TestStats
        TestResults = $script:TestResults
        Environment = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Timestamp = Get-Date
        }
    }
    
    try {
        $LogPath = "TestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $DetailedResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $LogPath -Encoding UTF8
        Write-Host "✅ Resultados guardados en: $LogPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "⚠️ No se pudo guardar el log detallado: $($_.Exception.Message)"
    }
}

# EJECUCIÓN PRINCIPAL DEL FRAMEWORK DE TESTING
function Start-TestSuiteEnhanced {
    <#
    .SYNOPSIS
        Ejecuta la suite completa de tests para AD_ADMIN Enhanced
    .PARAMETER SkipIntegration
        Omite las pruebas de integración (más rápido)
    .PARAMETER Verbose
        Muestra información detallada durante la ejecución
    #>
    param(
        [switch]$SkipIntegration,
        [switch]$Verbose
    )
    
    if ($Verbose) { $VerbosePreference = 'Continue' }
    
    Write-Host @"

██╗  ██╗██████╗      █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗
██║  ██║██╔══██╗    ██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║
███████║██║  ██║    ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║
██╔══██║██║  ██║    ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║
██║  ██║██████╔╝    ██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║
╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝

Enhanced Testing Framework v3.0
"@ -ForegroundColor Green
    
    Write-Host "🚀 Iniciando suite de tests exhaustivos..." -ForegroundColor Yellow
    Write-Host "📅 Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # Reinicializar contadores
    $script:TestResults = @()
    $script:TestStats = @{
        Total = 0
        Passed = 0
        Failed = 0
        Warnings = 0
        StartTime = Get-Date
        EndTime = $null
    }
    
    try {
        # Ejecutar baterías de tests
        Test-NormalizationEnhanced
        Test-UOMappingEnhanced 
        Test-EdgeCasesEnhanced
        
        if (-not $SkipIntegration) {
            Test-IntegrationScenarios
        }
        else {
            Write-Host "⏭️ Pruebas de integración omitidas por parámetro" -ForegroundColor Yellow
        }
        
        # Mostrar resumen final
        Show-TestSummary
        
        # Retornar código de salida basado en resultados
        $ExitCode = if ($script:TestStats.Failed -eq 0) { 0 } else { 1 }
        return $ExitCode
        
    }
    catch {
        Write-Error "💥 Error crítico en el framework de testing: $($_.Exception.Message)"
        return 2
    }
}

# Ejecutar automáticamente si se invoca directamente
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    $ExitCode = Start-TestSuiteEnhanced -Verbose
    exit $ExitCode
}

# Exportar función principal
Export-ModuleMember -Function Start-TestSuiteEnhanced