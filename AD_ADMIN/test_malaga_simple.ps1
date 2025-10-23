# Test simple para escenario de Malaga usando funciones basicas

# Cargar las funciones
. ".\test_simple_functions.ps1"

Write-Host "=== TEST MALAGA SCENARIO SIMPLE ===" -ForegroundColor Yellow
Write-Host "Probando: 'Juzgado de Primera Instancia N 19 de Malaga'" -ForegroundColor Cyan

# Test data
$OriginalOffice = "Juzgado de Primera Instancia N 19 de Malaga"
$CorrectOU = "OU=Juzgado de Primera Instancia N 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"

# Test 1: Normalizacion de texto
Write-Host "`n1. Probando normalizacion de texto..." -ForegroundColor Green
$NormalizedOffice = Normalize-Text -Text $OriginalOffice
Write-Host "   Original: '$OriginalOffice'"
Write-Host "   Normalizada: '$NormalizedOffice'"

# Test 2: Extraccion de localidad de oficina
Write-Host "`n2. Probando extraccion de localidad de oficina..." -ForegroundColor Green
$OfficeLocation = Extract-LocationFromOffice -Office $OriginalOffice
Write-Host "   Localidad detectada: '$OfficeLocation'"

# Test 3: Extraccion de localidad de UO
Write-Host "`n3. Probando extraccion de localidad de UO..." -ForegroundColor Green
$OULocation = Extract-LocationFromOU -OUDN $CorrectOU
Write-Host "   DN: '$CorrectOU'"
Write-Host "   Localidad detectada: '$OULocation'"

# Test 4: Evaluacion de confianza
Write-Host "`n4. Probando evaluacion de confianza..." -ForegroundColor Green
$Score = 120
$KeywordMatches = 4

$Confidence = Get-UOMatchConfidence -Score $Score -KeywordMatches $KeywordMatches -Office $OriginalOffice -OUDN $CorrectOU
Write-Host "   Score: $Score"
Write-Host "   Keyword matches: $KeywordMatches"
Write-Host "   Localidad oficina: '$OfficeLocation'"
Write-Host "   Localidad UO: '$OULocation'"
Write-Host "   Confianza evaluada: '$Confidence'"

Write-Host "`n=== RESULTADO DEL TEST ===" -ForegroundColor Yellow

# Verificaciones
$AllTestsPassed = $true

if ($NormalizedOffice -notlike "*malaga*") {
    Write-Host "ERROR: Normalizacion no mantiene 'malaga' correctamente" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "OK: Normalizacion funciona correctamente" -ForegroundColor Green
}

if ($OfficeLocation -ne "malaga") {
    Write-Host "ERROR: Extraccion de localidad de oficina incorrecta (esperado: 'malaga', obtenido: '$OfficeLocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "OK: Extraccion de localidad de oficina correcta" -ForegroundColor Green
}

if ($OULocation -ne "malaga") {
    Write-Host "ERROR: Extraccion de localidad de UO incorrecta (esperado: 'malaga', obtenido: '$OULocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "OK: Extraccion de localidad de UO correcta" -ForegroundColor Green
}

if ($Confidence -ne "HIGH") {
    Write-Host "ERROR: Confianza deberia ser HIGH (obtenido: '$Confidence')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "OK: Confianza evaluada correctamente como HIGH" -ForegroundColor Green
}

if ($AllTestsPassed) {
    Write-Host "`nTODOS LOS TESTS PASARON CORRECTAMENTE" -ForegroundColor Green
    Write-Host "Las funciones basicas funcionan correctamente" -ForegroundColor Green
} else {
    Write-Host "`nALGUNOS TESTS FALLARON" -ForegroundColor Red
    Write-Host "Es necesario revisar las correcciones" -ForegroundColor Red
}

Write-Host "`n=== FIN DEL TEST ===" -ForegroundColor Yellow