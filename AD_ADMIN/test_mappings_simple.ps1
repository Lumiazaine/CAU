# Test simple para verificar los mapeos especificos de OU
Write-Host "=== Probando mapeos especificos de OU ===" -ForegroundColor Cyan

# Mapeos especificos (copiados del codigo principal)
$SpecificOUMappings = @{
    'imlcf central de jaen - patologia forense' = 'OU=IML - Sede Central,OU=Jaen-JA4C-San Antonio,DC=jaen,DC=justicia,DC=junta-andalucia,DC=es'
    'imlcf de algeciras' = 'OU=UVIG,OU=IML,OU=Algeciras-CAAL3-Virgen del Carmen,DC=cadiz,DC=justicia,DC=junta-andalucia,DC=es'
    'registro civil exclusivo de malaga' = 'OU=Registro Civil de Malaga,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es'
}

# Test cases
$TestCases = @(
    "IMLCF Central de Jaen - Patologia Forense",
    "IMLCF de Algeciras", 
    "Registro Civil Exclusivo de Malaga"
)

$PassedTests = 0

foreach ($Office in $TestCases) {
    $NormalizedOffice = $Office.ToLower()
    
    Write-Host "`nProbando: '$Office'" -ForegroundColor Yellow
    Write-Host "Normalizado como: '$NormalizedOffice'" -ForegroundColor Gray
    
    if ($SpecificOUMappings.ContainsKey($NormalizedOffice)) {
        $Result = $SpecificOUMappings[$NormalizedOffice]
        Write-Host "OK: Mapeo encontrado" -ForegroundColor Green
        Write-Host "  Resultado: $Result" -ForegroundColor Gray
        $PassedTests++
    } else {
        Write-Host "ERROR: No se encontro mapeo especifico" -ForegroundColor Red
    }
}

Write-Host "`n=== Resumen ===" -ForegroundColor Cyan
Write-Host "Pruebas pasadas: $PassedTests de $($TestCases.Count)" -ForegroundColor $(if ($PassedTests -eq $TestCases.Count) { "Green" } else { "Yellow" })