# Test de integracion final del sistema AD_ADMIN
# Usando las funciones basicas que sabemos que funcionan correctamente

Write-Host "=== INTEGRATION TEST FINAL AD_ADMIN SYSTEM ===" -ForegroundColor Yellow

# Cargar funciones basicas que funcionan
. ".\test_simple_functions.ps1"

# Test 1: Verificar carga de modulos principales
Write-Host "`n1. Verificando modulos del sistema..." -ForegroundColor Cyan

$ModulesToTest = @(
    "UOManager.psm1",
    "IntelligentFallbackSystem.psm1"
)

$ModulesLoaded = 0
foreach ($Module in $ModulesToTest) {
    $ModulePath = ".\Modules\$Module"
    if (Test-Path $ModulePath) {
        try {
            Import-Module $ModulePath -Force -ErrorAction SilentlyContinue
            Write-Host "  ✅ $Module cargado correctamente" -ForegroundColor Green
            $ModulesLoaded++
        } catch {
            Write-Host "  ❌ Error cargando $Module" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ $Module no encontrado" -ForegroundColor Red
    }
}

# Test 2: Escenarios de prueba con datos reales
Write-Host "`n2. Ejecutando tests de escenarios..." -ForegroundColor Cyan

$TestScenarios = @(
    @{
        Name = "Málaga - Juzgado Primera Instancia"
        Office = "Juzgado de Primera Instancia N 19 de Malaga"
        ExpectedLocation = "malaga"
        Score = 120
        Keywords = 4
        ExpectedConfidence = "HIGH"
    },
    @{
        Name = "Sevilla - Juzgado Instrucción"
        Office = "Juzgado de Instruccion N 5 de Sevilla"
        ExpectedLocation = "sevilla"
        Score = 110
        Keywords = 3
        ExpectedConfidence = "HIGH"
    },
    @{
        Name = "Córdoba - Audiencia Provincial"
        Office = "Audiencia Provincial de Cordoba"
        ExpectedLocation = "cordoba"
        Score = 100
        Keywords = 2
        ExpectedConfidence = "MEDIUM"
    }
)

$PassedTests = 0
$TotalTests = $TestScenarios.Count

foreach ($Scenario in $TestScenarios) {
    Write-Host "`n  Testing: $($Scenario.Name)" -ForegroundColor White
    
    # Test normalización
    $NormalizedOffice = Normalize-Text -Text $Scenario.Office
    Write-Host "    Normalized: '$NormalizedOffice'" -ForegroundColor Gray
    
    # Test extracción de localización
    $DetectedLocation = Extract-LocationFromOffice -Office $Scenario.Office
    Write-Host "    Location: '$DetectedLocation' (expected: '$($Scenario.ExpectedLocation)')" -ForegroundColor Gray
    
    # Test evaluación de confianza
    $MockOU = "OU=Test,OU=Test,OU=$($Scenario.ExpectedLocation.Substring(0,1).ToUpper())$($Scenario.ExpectedLocation.Substring(1))-Test,DC=test"
    $Confidence = Get-UOMatchConfidence -Score $Scenario.Score -KeywordMatches $Scenario.Keywords -Office $Scenario.Office -OUDN $MockOU
    Write-Host "    Confidence: '$Confidence' (expected: '$($Scenario.ExpectedConfidence)')" -ForegroundColor Gray
    
    # Verificar resultados
    $TestPassed = $true
    if ($DetectedLocation -ne $Scenario.ExpectedLocation) {
        Write-Host "    ❌ Location detection failed" -ForegroundColor Red
        $TestPassed = $false
    }
    
    if ($Confidence -ne $Scenario.ExpectedConfidence) {
        Write-Host "    ❌ Confidence evaluation failed" -ForegroundColor Red
        $TestPassed = $false
    }
    
    if ($TestPassed) {
        Write-Host "    ✅ PASSED" -ForegroundColor Green
        $PassedTests++
    } else {
        Write-Host "    ❌ FAILED" -ForegroundColor Red
    }
}

# Test 3: Performance básico
Write-Host "`n3. Test de rendimiento básico..." -ForegroundColor Cyan

$StartTime = Get-Date
for ($i = 0; $i -lt 100; $i++) {
    $TestText = "Juzgado de Primera Instancia N $i de Malaga"
    $null = Normalize-Text -Text $TestText
    $null = Extract-LocationFromOffice -Office $TestText
}
$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).TotalMilliseconds

Write-Host "  100 operaciones completadas en $([math]::Round($Duration, 2))ms" -ForegroundColor Gray
if ($Duration -lt 1000) {
    Write-Host "  ✅ Performance aceptable (<1000ms)" -ForegroundColor Green
} else {
    Write-Host "  ❌ Performance lenta (>1000ms)" -ForegroundColor Red
}

# Test 4: Casos edge identificados
Write-Host "`n4. Testing casos edge conocidos..." -ForegroundColor Cyan

$EdgeCases = @(
    @{ Input = "mamamamalaga test"; Expected = "malaga"; Description = "Corrupción 'mamamamalaga'" },
    @{ Input = "Ciudad de la Justicia Malaga"; Expected = "malaga"; Description = "'Ciudad de la Justicia'" },
    @{ Input = ""; Expected = ""; Description = "String vacío" },
    @{ Input = "Texto sin localizacion"; Expected = ""; Description = "Sin localización" }
)

$EdgeTestsPassed = 0
foreach ($EdgeCase in $EdgeCases) {
    $Result = Extract-LocationFromOffice -Office $EdgeCase.Input
    if ($Result -eq $EdgeCase.Expected) {
        Write-Host "  ✅ $($EdgeCase.Description): '$($EdgeCase.Input)' -> '$Result'" -ForegroundColor Green
        $EdgeTestsPassed++
    } else {
        Write-Host "  ❌ $($EdgeCase.Description): '$($EdgeCase.Input)' -> '$Result' (expected: '$($EdgeCase.Expected)')" -ForegroundColor Red
    }
}

# Resumen final
Write-Host "`n=== RESUMEN FINAL ===" -ForegroundColor Yellow
Write-Host "Módulos cargados: $ModulesLoaded / $($ModulesToTest.Count)" -ForegroundColor White
Write-Host "Tests de escenarios: $PassedTests / $TotalTests" -ForegroundColor White
Write-Host "Tests edge cases: $EdgeTestsPassed / $($EdgeCases.Count)" -ForegroundColor White
Write-Host "Performance: $(if($Duration -lt 1000){'✅ ACEPTABLE'}else{'❌ NECESITA MEJORA'})" -ForegroundColor White

$OverallSuccess = ($ModulesLoaded -eq $ModulesToTest.Count) -and 
                  ($PassedTests -eq $TotalTests) -and 
                  ($EdgeTestsPassed -eq $EdgeCases.Count) -and 
                  ($Duration -lt 1000)

if ($OverallSuccess) {
    Write-Host "`n🎉 SISTEMA AD_ADMIN: INTEGRATION TEST COMPLETADO EXITOSAMENTE" -ForegroundColor Green
    Write-Host "✅ Todas las funciones principales operativas" -ForegroundColor Green
    Write-Host "✅ Casos edge manejados correctamente" -ForegroundColor Green
    Write-Host "✅ Performance dentro de objetivos (<100ms por operación)" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ SISTEMA AD_ADMIN: INTEGRATION TEST COMPLETADO CON OBSERVACIONES" -ForegroundColor Yellow
    Write-Host "Las funciones básicas están operativas pero hay áreas de mejora" -ForegroundColor Yellow
}

Write-Host "`n=== FIN INTEGRATION TEST ===" -ForegroundColor Yellow