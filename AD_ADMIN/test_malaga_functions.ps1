# Test simplificado para las funciones específicas de Málaga

# Extraer solo las funciones necesarias del script principal
function Normalize-Text {
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }
    
    # Aplicar normalizaciones específicas paso a paso
    $Normalized = $Text
    
    # Correcciones específicas para ciudades problemáticas
    $Normalized = $Normalized -replace 'mamámámálaga', 'málaga'
    $Normalized = $Normalized -replace 'MAMÁMÁMÁLAGA', 'MÁLAGA'
    $Normalized = $Normalized -replace 'Mamámámálaga', 'Málaga'
    
    # Caracteres � (diamond question mark)
    $Normalized = $Normalized -replace 'L�PEZ', 'LÓPEZ'
    $Normalized = $Normalized -replace 'ALMER�A', 'ALMERÍA'
    $Normalized = $Normalized -replace 'C�DIZ', 'CÁDIZ'
    $Normalized = $Normalized -replace 'C�RDOBA', 'CÓRDOBA'
    $Normalized = $Normalized -replace 'JA�N', 'JAÉN'
    $Normalized = $Normalized -replace 'M�LAGA', 'MÁLAGA'
    
    # Caracteres ? (question mark - otra corrupción común)
    $Normalized = $Normalized -replace 'L?PEZ', 'LÓPEZ'
    $Normalized = $Normalized -replace 'ALMER?A', 'ALMERÍA'
    $Normalized = $Normalized -replace 'C?DIZ', 'CÁDIZ'
    $Normalized = $Normalized -replace 'C?RDOBA', 'CÓRDOBA'
    $Normalized = $Normalized -replace 'JA?N', 'JAÉN'
    $Normalized = $Normalized -replace 'M?LAGA', 'MÁLAGA'
    
    # Versiones con primera letra mayúscula - �
    $Normalized = $Normalized -replace 'L�pez', 'López'
    $Normalized = $Normalized -replace 'Almer�a', 'Almería'
    $Normalized = $Normalized -replace 'C�diz', 'Cádiz'
    $Normalized = $Normalized -replace 'C�rdoba', 'Córdoba'
    $Normalized = $Normalized -replace 'Ja�n', 'Jaén'
    $Normalized = $Normalized -replace 'M�laga', 'Málaga'
    
    # Versiones con primera letra mayúscula - ?
    $Normalized = $Normalized -replace 'L?pez', 'López'
    $Normalized = $Normalized -replace 'Almer?a', 'Almería'
    $Normalized = $Normalized -replace 'C?diz', 'Cádiz'
    $Normalized = $Normalized -replace 'C?rdoba', 'Córdoba'
    $Normalized = $Normalized -replace 'Ja?n', 'Jaén'
    $Normalized = $Normalized -replace 'M?laga', 'Málaga'
    
    # Versiones en minúsculas - �
    $Normalized = $Normalized -replace 'l�pez', 'lópez'
    $Normalized = $Normalized -replace 'almer�a', 'almería'
    $Normalized = $Normalized -replace 'c�diz', 'cádiz'
    $Normalized = $Normalized -replace 'c�rdoba', 'córdoba'
    $Normalized = $Normalized -replace 'ja�n', 'jaén'
    $Normalized = $Normalized -replace 'm�laga', 'málaga'
    
    # Versiones en minúsculas - ?
    $Normalized = $Normalized -replace 'l?pez', 'lópez'
    $Normalized = $Normalized -replace 'almer?a', 'almería'
    $Normalized = $Normalized -replace 'c?diz', 'cádiz'
    $Normalized = $Normalized -replace 'c?rdoba', 'córdoba'
    $Normalized = $Normalized -replace 'ja?n', 'jaén'
    $Normalized = $Normalized -replace 'm?laga', 'málaga'
    
    return $Normalized
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
        'granada' = 'granada'
        'cadiz' = 'cadiz'
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
        'malaga-macj' = 'malaga'
        'ciudad de la justicia' = 'malaga'
        'sevilla-se' = 'sevilla'
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
    
    # Confianza alta: coincidencia exacta de localidad + keywords decentes
    if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 2) {
        return "HIGH"
    }
    
    # Confianza alta también para scores muy altos
    if ($Score -ge 100 -and $KeywordMatches -ge 3) {
        return "HIGH"
    }
    
    # Confianza media: score decente + alguna coincidencia de localidad o keywords altos
    if (($Score -ge 50 -and $KeywordMatches -ge 2) -or ($KeywordMatches -ge 4)) {
        return "MEDIUM"
    }
    
    # Confianza baja: coincidencias mínimas pero válidas
    if ($Score -ge 10 -and $KeywordMatches -ge 1) {
        return "LOW"
    }
    
    return "VERY_LOW"
}

# TESTS
Write-Host "=== TEST MÁLAGA FUNCTIONS ===" -ForegroundColor Yellow

# Test 1: Normalización básica
$OriginalOffice = "Juzgado de Primera Instancia No 19 de Málaga"
$NormalizedOffice = Normalize-Text -Text $OriginalOffice
Write-Host "1. Normalización básica:"
Write-Host "   Original: '$OriginalOffice'"
Write-Host "   Normalizada: '$NormalizedOffice'"

# Test 2: Corrección del problema "mamámámálaga"
$ProblematicText = "mamámámálaga test"
$FixedText = Normalize-Text -Text $ProblematicText
Write-Host "`n2. Corrección 'mamámámálaga':"
Write-Host "   Problemático: '$ProblematicText'"
Write-Host "   Corregido: '$FixedText'"

# Test 3: Extracción de localidad de oficina
$OfficeLocation = Extract-LocationFromOffice -Office $OriginalOffice
Write-Host "`n3. Localidad de oficina:"
Write-Host "   Oficina: '$OriginalOffice'"
Write-Host "   Localidad: '$OfficeLocation'"

# Test 4: Extracción de localidad de UO
$CorrectOU = "OU=Juzgado de Primera Instancia No 19,OU=Juzgados de Primera Instancia,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
$OULocation = Extract-LocationFromOU -OUDN $CorrectOU
Write-Host "`n4. Localidad de UO:"
Write-Host "   UO DN: '$CorrectOU'"
Write-Host "   Localidad: '$OULocation'"

# Test 5: Confianza para coincidencia exacta
$Score = 120
$KeywordMatches = 4
$Confidence = Get-UOMatchConfidence -Score $Score -KeywordMatches $KeywordMatches -Office $OriginalOffice -OUDN $CorrectOU
Write-Host "`n5. Evaluación de confianza:"
Write-Host "   Score: $Score"
Write-Host "   Keywords: $KeywordMatches"
Write-Host "   Localidad oficina: '$OfficeLocation'"
Write-Host "   Localidad UO: '$OULocation'"
Write-Host "   Confianza: '$Confidence'"

# Test 6: Patrón 'Ciudad de la Justicia'
$CiudadJusticiaOU = "OU=Something,OU=Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
$CiudadJusticiaLocation = Extract-LocationFromOU -OUDN $CiudadJusticiaOU
Write-Host "`n6. Patrón 'Ciudad de la Justicia':"
Write-Host "   UO: '$CiudadJusticiaOU'"
Write-Host "   Localidad: '$CiudadJusticiaLocation'"

# RESULTADOS
Write-Host "`n=== RESULTADOS ===" -ForegroundColor Yellow

$AllTestsPassed = $true

if ($NormalizedOffice -notlike "*málaga*") {
    Write-Host "❌ FALLO: Normalización no mantiene 'málaga'" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Normalización mantiene 'málaga'" -ForegroundColor Green
}

if ($FixedText -like "*mamámámálaga*") {
    Write-Host "❌ FALLO: Problema 'mamámámálaga' no corregido" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Problema 'mamámámálaga' corregido" -ForegroundColor Green
}

if ($OfficeLocation -ne "malaga") {
    Write-Host "❌ FALLO: Localidad oficina incorrecta (esperado: 'malaga', obtenido: '$OfficeLocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Localidad oficina correcta" -ForegroundColor Green
}

if ($OULocation -ne "malaga") {
    Write-Host "❌ FALLO: Localidad UO incorrecta (esperado: 'malaga', obtenido: '$OULocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Localidad UO correcta" -ForegroundColor Green
}

if ($Confidence -ne "HIGH") {
    Write-Host "❌ FALLO: Confianza debería ser HIGH (obtenido: '$Confidence')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: Confianza evaluada correctamente como HIGH" -ForegroundColor Green
}

if ($CiudadJusticiaLocation -ne "malaga") {
    Write-Host "❌ FALLO: 'Ciudad de la Justicia' no detectada como Málaga (obtenido: '$CiudadJusticiaLocation')" -ForegroundColor Red
    $AllTestsPassed = $false
} else {
    Write-Host "✅ OK: 'Ciudad de la Justicia' detectada correctamente" -ForegroundColor Green
}

if ($AllTestsPassed) {
    Write-Host "`n🎉 TODOS LOS TESTS PASARON" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ ALGUNOS TESTS FALLARON" -ForegroundColor Red
}

Write-Host "`n=== FIN ===" -ForegroundColor Yellow