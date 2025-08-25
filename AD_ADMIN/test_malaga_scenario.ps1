# Test script para validar el escenario específico de Málaga
# Simula el caso: "Juzgado de Primera Instancia Nº 19 de Málaga" 
# Debe encontrar: "OU=Juzgado de Primera Instancia Nº 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"

# Importar el script principal para tener acceso a las funciones
. ".\AD_UserManagement.ps1"

Write-Host "=== TEST MÁLAGA SCENARIO ===" -ForegroundColor Yellow
Write-Host "Probando: 'Juzgado de Primera Instancia Nº 19 de Málaga'" -ForegroundColor Cyan

# Test 1: Normalización de texto
Write-Host "`n1. Probando normalización de texto..." -ForegroundColor Green
$OriginalOffice = "Juzgado de Primera Instancia Nº 19 de Málaga"
$NormalizedOffice = Normalize-Text -Text $OriginalOffice
Write-Host "   Original: '$OriginalOffice'"
Write-Host "   Normalizada: '$NormalizedOffice'"

# Test 2: Extracción de localidad de oficina
Write-Host "`n2. Probando extracción de localidad de oficina..." -ForegroundColor Green
$OfficeLocation = Extract-LocationFromOffice -Office $OriginalOffice
Write-Host "   Localidad detectada: '$OfficeLocation'"

# Test 3: Extracción de localidad de UO (simular el DN correcto)
Write-Host "`n3. Probando extracción de localidad de UO..." -ForegroundColor Green
$CorrectOU = "OU=Juzgado de Primera Instancia Nº 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
$OULocation = Extract-LocationFromOU -OUDN $CorrectOU
Write-Host "   DN: '$CorrectOU'"
Write-Host "   Localidad detectada: '$OULocation'"

# Test 4: Evaluación de confianza
Write-Host "`n4. Probando evaluación de confianza..." -ForegroundColor Green
$Score = 120  # Score alto para coincidencia exacta
$KeywordMatches = 4  # "juzgado", "primera", "instancia", "19"

$Confidence = Get-UOMatchConfidence -Score $Score -KeywordMatches $KeywordMatches -Office $OriginalOffice -OUDN $CorrectOU
Write-Host "   Score: $Score"
Write-Host "   Keyword matches: $KeywordMatches"
Write-Host "   Localidad oficina: '$OfficeLocation'"
Write-Host "   Localidad UO: '$OULocation'"
Write-Host "   Confianza evaluada: '$Confidence'"

# Test 5: Verificar que no hay problemas de normalización
Write-Host "`n5. Verificando problemas conocidos de normalización..." -ForegroundColor Green
$ProblematicText = "mamámámálaga test"
$FixedText = Normalize-Text -Text $ProblematicText
Write-Host "   Texto problemático: '$ProblematicText'"
Write-Host "   Texto corregido: '$FixedText'"

# Test 6: Verificar patrones de Ciudad de la Justicia
Write-Host "`n6. Verificando detección de 'Ciudad de la Justicia'..." -ForegroundColor Green
$CiudadJusticiaOU = "OU=Something,OU=Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
$CiudadJusticiaLocation = Extract-LocationFromOU -OUDN $CiudadJusticiaOU
Write-Host "   DN con 'Ciudad de la Justicia': '$CiudadJusticiaOU'"
Write-Host "   Localidad detectada: '$CiudadJusticiaLocation'"

Write-Host "`n=== RESULTADO DEL TEST ===" -ForegroundColor Yellow

# Verificar que todo funcione como esperado
$AllTestsPassed = $true

if ($NormalizedOffice -notlike "*málaga*") {
    Write-Host "❌ FALLO: Normalización no mantiene 'málaga' correctamente" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Normalización funciona correctamente" -ForegroundColor Green
}

if ($OfficeLocation -ne "malaga") {
    Write-Host "❌ FALLO: Extracción de localidad de oficina incorrecta (esperado: 'malaga', obtenido: '$OfficeLocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Extracción de localidad de oficina correcta" -ForegroundColor Green
}

if ($OULocation -ne "malaga") {
    Write-Host "❌ FALLO: Extracción de localidad de UO incorrecta (esperado: 'malaga', obtenido: '$OULocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Extracción de localidad de UO correcta" -ForegroundColor Green
}

if ($Confidence -ne "HIGH") {
    Write-Host "❌ FALLO: Confianza debería ser HIGH (obtenido: '$Confidence')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Confianza evaluada correctamente como HIGH" -ForegroundColor Green
}

if ($FixedText -like "*mamámámálaga*") {
    Write-Host "❌ FALLO: Problema de normalización 'mamámámálaga' no corregido" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Problema 'mamámámálaga' corregido" -ForegroundColor Green
}

if ($CiudadJusticiaLocation -ne "malaga") {
    Write-Host "❌ FALLO: 'Ciudad de la Justicia' no detectada como Málaga (obtenido: '$CiudadJusticiaLocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: 'Ciudad de la Justicia' detectada correctamente como Málaga" -ForegroundColor Green
}

if ($AllTestsPassed) {
    Write-Host "`n🎉 TODOS LOS TESTS PASARON CORRECTAMENTE" -ForegroundColor Green
    Write-Host "El sistema debería funcionar correctamente con el escenario de Málaga" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ ALGUNOS TESTS FALLARON" -ForegroundColor Red
    Write-Host "Es necesario revisar las correcciones" -ForegroundColor Red
}

Write-Host "`n=== FIN DEL TEST ===" -ForegroundColor Yellow