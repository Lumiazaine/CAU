# Test script para validar el escenario específico de Sevilla
# Simula el caso: "Juzgado de Primera Instancia Nº 25 de Sevilla"
# Debe encontrar: UO con número 25 en Sevilla

# Extraer solo las funciones necesarias del script principal
function Normalize-Text {
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }
    
    $Normalized = $Text
    
    # Correcciones específicas para ciudades problemáticas
    $Normalized = $Normalized -replace 'mamámámálaga', 'málaga'
    $Normalized = $Normalized -replace 'MAMÁMÁMÁLAGA', 'MÁLAGA'
    $Normalized = $Normalized -replace 'Mamámámálaga', 'Málaga'
    
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
    
    # Extraer localidad de la oficina y de la UO
    $OfficeLocation = Extract-LocationFromOffice -Office $Office
    $OULocation = Extract-LocationFromOU -OUDN $OUDN
    
    # Extraer números para verificar coincidencias exactas
    $OfficeNumber = $null
    $OUNumber = $null
    
    if ($Office -match 'n[ºo°]\s*(\d+)') {
        $OfficeNumber = $matches[1]
    }
    
    if ($OUDN -match 'n[ºo°]\s*(\d+)') {
        $OUNumber = $matches[1]
    }
    
    # CONFIANZA ALTA: Coincidencia exacta de número + localidad + keywords decentes
    if ($OfficeNumber -and $OUNumber -and $OfficeNumber -eq $OUNumber -and 
        $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and 
        $KeywordMatches -ge 2) {
        return "HIGH"
    }
    
    # CONFIANZA ALTA: Coincidencia exacta de localidad + keywords decentes (sin número o número coincide)
    if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 3) {
        return "HIGH"
    }
    
    # CONFIANZA ALTA: Score muy alto + keywords decentes
    if ($Score -ge 100 -and $KeywordMatches -ge 3) {
        return "HIGH"
    }
    
    # CONFIANZA ALTA: Score alto + coincidencia de localidad
    if ($Score -ge 80 -and $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN") {
        return "HIGH"
    }
    
    # CONFIANZA MEDIA: Score decente + alguna coincidencia de localidad o keywords altos
    if (($Score -ge 50 -and $KeywordMatches -ge 2) -or ($KeywordMatches -ge 4)) {
        return "MEDIUM"
    }
    
    # CONFIANZA MEDIA: Coincidencia de localidad + keywords mínimos
    if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 2) {
        return "MEDIUM"
    }
    
    # CONFIANZA BAJA: Coincidencias mínimas pero válidas
    if ($Score -ge 10 -and $KeywordMatches -ge 1) {
        return "LOW"
    }
    
    return "VERY_LOW"
}

# TESTS
Write-Host "=== TEST SEVILLA SCENARIO ===" -ForegroundColor Yellow

# Simular el escenario exacto del log
$OriginalOffice = "Juzgado de Primera Instancia Nº 25 de Sevilla"
$SimulatedOU = "OU=Juzgados de Primera Instancia Nº 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es"
$Score = 30  # Score reportado en el log
$KeywordMatches = 3  # Keywords reportadas en el log

Write-Host "Escenario del log:"
Write-Host "   Oficina: '$OriginalOffice'"
Write-Host "   UO simulada: '$SimulatedOU'"
Write-Host "   Score: $Score"
Write-Host "   Keywords: $KeywordMatches"

# Test 1: Extracción de números
Write-Host "`n1. Extracción de números:"
$OfficeNumber = $null
$OUNumber = $null

if ($OriginalOffice -match 'n[ºo°]\s*(\d+)') {
    $OfficeNumber = $matches[1]
}

if ($SimulatedOU -match 'n[ºo°]\s*(\d+)') {
    $OUNumber = $matches[1]
}

Write-Host "   Número oficina: '$OfficeNumber'"
Write-Host "   Número UO: '$OUNumber'"
Write-Host "   Coincidencia numérica: $(if ($OfficeNumber -eq $OUNumber) { 'SÍ' } else { 'NO' })"

# Test 2: Extracción de localidades
Write-Host "`n2. Extracción de localidades:"
$OfficeLocation = Extract-LocationFromOffice -Office $OriginalOffice
$OULocation = Extract-LocationFromOU -OUDN $SimulatedOU

Write-Host "   Localidad oficina: '$OfficeLocation'"
Write-Host "   Localidad UO: '$OULocation'"
Write-Host "   Coincidencia localidad: $(if ($OfficeLocation -eq $OULocation) { 'SÍ' } else { 'NO' })"

# Test 3: Evaluación de confianza
Write-Host "`n3. Evaluación de confianza:"
$Confidence = Get-UOMatchConfidence -Score $Score -KeywordMatches $KeywordMatches -Office $OriginalOffice -OUDN $SimulatedOU

Write-Host "   Confianza evaluada: '$Confidence'"

# Test 4: Qué confianza DEBERÍA tener
Write-Host "`n4. Análisis de por qué DEBERÍA ser HIGH:"

$ShouldBeHigh = $false
$Reason = ""

# Verificar criterio 1: número + localidad + keywords
if ($OfficeNumber -and $OUNumber -and $OfficeNumber -eq $OUNumber -and 
    $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and 
    $KeywordMatches -ge 2) {
    $ShouldBeHigh = $true
    $Reason = "Coincidencia EXACTA: número ($OfficeNumber), localidad ($OfficeLocation), keywords ($KeywordMatches ≥ 2)"
}

# Verificar criterio 2: localidad + keywords altos
elseif ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 3) {
    $ShouldBeHigh = $true
    $Reason = "Localidad coincide ($OfficeLocation) y keywords suficientes ($KeywordMatches ≥ 3)"
}

if ($ShouldBeHigh) {
    Write-Host "   ✅ DEBERÍA SER HIGH: $Reason" -ForegroundColor Green
} else {
    Write-Host "   ❌ No cumple criterios para HIGH" -ForegroundColor Red
    Write-Host "     - Número: oficina='$OfficeNumber', UO='$OUNumber', coincide=$(if ($OfficeNumber -eq $OUNumber) { 'SÍ' } else { 'NO' })"
    Write-Host "     - Localidad: oficina='$OfficeLocation', UO='$OULocation', coincide=$(if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne 'UNKNOWN') { 'SÍ' } else { 'NO' })"
    Write-Host "     - Keywords: $KeywordMatches (necesita ≥2 con número+localidad o ≥3 solo con localidad)"
}

# Test 5: Diagnóstico del problema
Write-Host "`n5. Diagnóstico:"

if ($Confidence -ne "HIGH" -and $ShouldBeHigh) {
    Write-Host "   🐛 BUG DETECTADO: Debería ser HIGH pero es $Confidence" -ForegroundColor Red
} elseif ($Confidence -eq "HIGH") {
    Write-Host "   ✅ CORRECTO: Evaluación HIGH apropiada" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Evaluación correcta pero Score muy bajo ($Score) para coincidencia exacta" -ForegroundColor Yellow
}

Write-Host "`n=== CONCLUSIÓN ===" -ForegroundColor Yellow

if ($OfficeNumber -eq $OUNumber -and $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN") {
    Write-Host "Este es una coincidencia PERFECTA que debería ser HIGH confidence:" -ForegroundColor Green
    Write-Host "- Mismo número: $OfficeNumber = $OUNumber ✅" -ForegroundColor Green
    Write-Host "- Misma localidad: $OfficeLocation = $OULocation ✅" -ForegroundColor Green
    Write-Host "- Keywords suficientes: $KeywordMatches ≥ 2 ✅" -ForegroundColor Green
    
    if ($Confidence -ne "HIGH") {
        Write-Host "❌ ERROR: Sistema evalúa como $Confidence en lugar de HIGH" -ForegroundColor Red
    } else {
        Write-Host "✅ Sistema funciona correctamente" -ForegroundColor Green
    }
} else {
    Write-Host "Revisión manual necesaria" -ForegroundColor Yellow
}

Write-Host "`n=== FIN ===" -ForegroundColor Yellow