# Test para verificar el mapeo de Juzgado de Instruccion a Primera Instancia e Instruccion

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
    
    # Limpiar espacios multiples
    $NormalizedText = $NormalizedText -replace '\s+', ' '
    $NormalizedText = $NormalizedText -replace '[^\w\s\-]', ''
    $NormalizedText = $NormalizedText.Trim()
    
    return $NormalizedText
}

function Test-InstruccionMapping {
    Write-Host "=== Test: Mapeo de Juzgados de Instruccion ===" -ForegroundColor Cyan
    
    # Casos de prueba
    $TestCases = @(
        @{
            Office = "Juzgado de Instruccion No 1"
            Description = "Juzgado de Instruccion (solo instruccion)"
            ShouldMatch = $true
        },
        @{
            Office = "Juzgado de Instruccion No 5"
            Description = "Juzgado de Instruccion con numero"
            ShouldMatch = $true
        },
        @{
            Office = "Juzgado de Primera Instancia e Instruccion No 2"
            Description = "Ya tiene Primera Instancia e Instruccion"
            ShouldMatch = $false  # No deberia activar la logica especial
        },
        @{
            Office = "Juzgado de lo Penal No 3"
            Description = "Juzgado Penal (no instruccion)"
            ShouldMatch = $false
        }
    )
    
    # Simular UOs disponibles
    $MockOUs = @(
        [PSCustomObject]@{ Name = "Juzgado de Primera Instancia e Instruccion No 1" },
        [PSCustomObject]@{ Name = "Juzgado de Primera Instancia e Instruccion No 2" },
        [PSCustomObject]@{ Name = "Juzgado de Primera Instancia e Instruccion No 5" },
        [PSCustomObject]@{ Name = "Juzgado de lo Penal No 1" },
        [PSCustomObject]@{ Name = "Juzgado de lo Civil No 1" }
    )
    
    $PassedTests = 0
    $TotalTests = $TestCases.Count
    
    foreach ($TestCase in $TestCases) {
        $Office = $TestCase.Office
        $ShouldMatch = $TestCase.ShouldMatch
        
        Write-Host "`nProbando: '$Office'" -ForegroundColor Yellow
        Write-Host "Descripcion: $($TestCase.Description)" -ForegroundColor Gray
        
        # Normalizar oficina
        $CleanOffice = Normalize-Text -Text $Office
        $NormalizedOffice = $CleanOffice.ToLower()
        
        # Detectar si es Juzgado de Instruccion (solo instruccion)
        $IsInstruccionOnly = $NormalizedOffice -like "*instruccion*" -and 
                            $NormalizedOffice -notlike "*primera*" -and 
                            $NormalizedOffice -notlike "*instancia*" -and
                            $NormalizedOffice -like "*juzgado*"
        
        Write-Host "Es Juzgado de Instruccion (solo): $IsInstruccionOnly" -ForegroundColor Gray
        
        # Probar cada UO
        $FoundMatch = $false
        foreach ($OU in $MockOUs) {
            $CleanOUName = Normalize-Text -Text $OU.Name
            $OUName = $CleanOUName.ToLower()
            
            $IsFirstInstanceInstruction = $OUName -like "*primera*" -and 
                                         $OUName -like "*instancia*" -and 
                                         $OUName -like "*instruccion*"
            
            if ($IsInstruccionOnly -and $IsFirstInstanceInstruction) {
                Write-Host "  MAPEO ESPECIAL detectado con: '$($OU.Name)'" -ForegroundColor Green
                $FoundMatch = $true
            }
        }
        
        # Verificar resultado
        if ($ShouldMatch -eq $FoundMatch) {
            Write-Host "OK: Resultado esperado" -ForegroundColor Green
            $PassedTests++
        } else {
            Write-Host "ERROR: Resultado inesperado" -ForegroundColor Red
            Write-Host "  Esperado: $ShouldMatch, Obtenido: $FoundMatch" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Resumen ===" -ForegroundColor Cyan
    Write-Host "Pruebas pasadas: $PassedTests de $TotalTests" -ForegroundColor $(if ($PassedTests -eq $TotalTests) { "Green" } else { "Yellow" })
    
    if ($PassedTests -eq $TotalTests) {
        Write-Host "La logica de mapeo funciona correctamente!" -ForegroundColor Green
    } else {
        Write-Host "Revisar la logica de mapeo." -ForegroundColor Yellow
    }
}

# Ejecutar test
Test-InstruccionMapping