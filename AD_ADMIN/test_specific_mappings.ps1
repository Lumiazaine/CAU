# Test script para verificar los mapeos específicos de OU añadidos
# Este script no requiere Active Directory

function Normalize-Text {
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    
    # Reemplazar caracteres especiales con equivalentes normales
    $Replacements = @{
        [char]0x00F1 = 'n'; [char]0x00D1 = 'N'  # ñ, Ñ
        [char]0x00E1 = 'a'; [char]0x00C1 = 'A'  # á, Á
        [char]0x00E9 = 'e'; [char]0x00C9 = 'E'  # é, É
        [char]0x00ED = 'i'; [char]0x00CD = 'I'  # í, Í
        [char]0x00F3 = 'o'; [char]0x00D3 = 'O'  # ó, Ó
        [char]0x00FA = 'u'; [char]0x00DA = 'U'  # ú, Ú
        [char]0x00FC = 'u'; [char]0x00DC = 'U'  # ü, Ü
        [char]0x00E7 = 'c'; [char]0x00C7 = 'C'  # ç, Ç
    }
    
    $NormalizedText = $Text
    foreach ($pair in $Replacements.GetEnumerator()) {
        $NormalizedText = $NormalizedText -replace $pair.Key, $pair.Value
    }
    
    # Limpiar espacios múltiples y caracteres especiales
    $NormalizedText = $NormalizedText -replace '\s+', ' '
    $NormalizedText = $NormalizedText -replace '[^\w\s\-]', ''
    $NormalizedText = $NormalizedText.Trim()
    
    return $NormalizedText
}

function Test-SpecificOUMappings {
    Write-Host "=== Probando mapeos específicos de OU ===" -ForegroundColor Cyan
    
    # Test cases - las oficinas problemáticas
    $TestCases = @(
        @{
            Office = "IMLCF Central de Jaen - Patologia Forense"
            Expected = "OU=IML - Sede Central,OU=Jaen-JA4C-San Antonio,DC=jaen,DC=justicia,DC=junta-andalucia,DC=es"
        },
        @{
            Office = "IMLCF de Algeciras"
            Expected = "OU=UVIG,OU=IML,OU=Algeciras-CAAL3-Virgen del Carmen,DC=cadiz,DC=justicia,DC=junta-andalucia,DC=es"
        },
        @{
            Office = "Registro Civil Exclusivo de Malaga"
            Expected = "OU=Registro Civil de Malaga,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
        }
    )
    
    # Mapeos específicos (copiados del código principal)
    $SpecificOUMappings = @{
        'imlcf central de jaen - patologia forense' = 'OU=IML - Sede Central,OU=Jaen-JA4C-San Antonio,DC=jaen,DC=justicia,DC=junta-andalucia,DC=es'
        'imlcf central de jaén - patología forense' = 'OU=IML - Sede Central,OU=Jaen-JA4C-San Antonio,DC=jaen,DC=justicia,DC=junta-andalucia,DC=es'
        'imlcf de algeciras' = 'OU=UVIG,OU=IML,OU=Algeciras-CAAL3-Virgen del Carmen,DC=cadiz,DC=justicia,DC=junta-andalucia,DC=es'
        'registro civil exclusivo de malaga' = 'OU=Registro Civil de Malaga,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es'
        'registro civil exclusivo de málaga' = 'OU=Registro Civil de Malaga,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es'
    }
    
    $PassedTests = 0
    $TotalTests = $TestCases.Count
    
    foreach ($TestCase in $TestCases) {
        $Office = $TestCase.Office
        $Expected = $TestCase.Expected
        
        # Normalizar nombre de oficina
        $CleanOffice = Normalize-Text -Text $Office
        $NormalizedOffice = $CleanOffice.ToLower()
        
        Write-Host "`nProbando: '$Office'" -ForegroundColor Yellow
        Write-Host "Normalizado como: '$NormalizedOffice'" -ForegroundColor Gray
        
        # Verificar si existe un mapeo específico
        if ($SpecificOUMappings.ContainsKey($NormalizedOffice)) {
            $Result = $SpecificOUMappings[$NormalizedOffice]
            
            if ($Result -eq $Expected) {
                Write-Host "✓ PASÓ: Mapeo correcto encontrado" -ForegroundColor Green
                Write-Host "  Resultado: $Result" -ForegroundColor Gray
                $PassedTests++
            } else {
                Write-Host "✗ FALLÓ: Mapeo incorrecto" -ForegroundColor Red
                Write-Host "  Esperado: $Expected" -ForegroundColor Gray
                Write-Host "  Obtenido: $Result" -ForegroundColor Gray
            }
        } else {
            Write-Host "✗ FALLÓ: No se encontró mapeo específico" -ForegroundColor Red
            Write-Host "  Esperado: $Expected" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n=== Resumen de pruebas ===" -ForegroundColor Cyan
    Write-Host "Pruebas pasadas: $PassedTests de $TotalTests" -ForegroundColor $(if ($PassedTests -eq $TotalTests) { "Green" } else { "Yellow" })
    
    if ($PassedTests -eq $TotalTests) {
        Write-Host "¡Todos los mapeos específicos funcionan correctamente!" -ForegroundColor Green
    } else {
        Write-Host "Algunos mapeos necesitan revision." -ForegroundColor Yellow
    }
}

# Ejecutar las pruebas
Test-SpecificOUMappings