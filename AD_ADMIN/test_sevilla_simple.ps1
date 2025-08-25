# Test simplificado para Sevilla scenario
function Get-UOMatchConfidence {
    param([int]$Score, [int]$KeywordMatches, [string]$Office, [string]$OUDN)
    
    # Extraer numeros
    $OfficeNumber = $null
    $OUNumber = $null
    
    if ($Office -match 'n[ºo°]\s*(\d+)') { $OfficeNumber = $matches[1] }
    if ($OUDN -match 'n[ºo°]\s*(\d+)') { $OUNumber = $matches[1] }
    
    # Extraer localidades (simplificado)
    $OfficeLocation = if ($Office -like "*sevilla*") { "sevilla" } else { "UNKNOWN" }
    $OULocation = if ($OUDN -like "*sevilla*") { "sevilla" } else { "UNKNOWN" }
    
    # Criterio principal: numero + localidad + keywords
    if ($OfficeNumber -and $OUNumber -and $OfficeNumber -eq $OUNumber -and 
        $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and 
        $KeywordMatches -ge 2) {
        return "HIGH"
    }
    
    # Otros criterios...
    if ($OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and $KeywordMatches -ge 3) {
        return "HIGH"
    }
    
    if (($Score -ge 50 -and $KeywordMatches -ge 2) -or ($KeywordMatches -ge 4)) {
        return "MEDIUM"
    }
    
    if ($Score -ge 10 -and $KeywordMatches -ge 1) {
        return "LOW"
    }
    
    return "VERY_LOW"
}

# Test del escenario real
$Office = "Juzgado de Primera Instancia No 25 de Sevilla"
$OUDN = "OU=Juzgados de Primera Instancia No 25 de Sevilla,OU=Juzgados,OU=Sevilla-SE,DC=sevilla"
$Score = 30
$KeywordMatches = 3

Write-Host "=== TEST SEVILLA ==="
Write-Host "Oficina: $Office"
Write-Host "UO: $OUDN"
Write-Host "Score: $Score, Keywords: $KeywordMatches"

# Extraer numeros
$OfficeNumber = $null
$OUNumber = $null

if ($Office -match 'n[ºo°]\s*(\d+)') { $OfficeNumber = $matches[1] }
if ($OUDN -match 'n[ºo°]\s*(\d+)') { $OUNumber = $matches[1] }

Write-Host "Numero oficina: '$OfficeNumber'"
Write-Host "Numero UO: '$OUNumber'"
Write-Host "Numeros coinciden: $(if ($OfficeNumber -eq $OUNumber) { 'SI' } else { 'NO' })"

$OfficeLocation = if ($Office -like "*sevilla*") { "sevilla" } else { "UNKNOWN" }
$OULocation = if ($OUDN -like "*sevilla*") { "sevilla" } else { "UNKNOWN" }

Write-Host "Localidad oficina: '$OfficeLocation'"
Write-Host "Localidad UO: '$OULocation'"
Write-Host "Localidades coinciden: $(if ($OfficeLocation -eq $OULocation) { 'SI' } else { 'NO' })"

$Confidence = Get-UOMatchConfidence -Score $Score -KeywordMatches $KeywordMatches -Office $Office -OUDN $OUDN

Write-Host "Confianza evaluada: '$Confidence'"

# Verificar si DEBERIA ser HIGH
$ShouldBeHigh = ($OfficeNumber -and $OUNumber -and $OfficeNumber -eq $OUNumber -and 
                 $OfficeLocation -eq $OULocation -and $OfficeLocation -ne "UNKNOWN" -and 
                 $KeywordMatches -ge 2)

Write-Host "DEBERIA ser HIGH: $(if ($ShouldBeHigh) { 'SI' } else { 'NO' })"

if ($ShouldBeHigh -and $Confidence -ne "HIGH") {
    Write-Host "ERROR: Deberia ser HIGH pero es $Confidence" -ForegroundColor Red
} elseif ($Confidence -eq "HIGH") {
    Write-Host "CORRECTO: Es HIGH como deberia" -ForegroundColor Green
} else {
    Write-Host "Evaluacion correcta segun criterios actuales" -ForegroundColor Yellow
}

Write-Host "=== FIN ==="