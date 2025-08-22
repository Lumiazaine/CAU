# Test del sistema de puntuacion para mapeo de Juzgado de Instruccion

function Normalize-Text {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    
    $Replacements = @{
        [char]0x00F1 = 'n'; [char]0x00D1 = 'N'
        [char]0x00E1 = 'a'; [char]0x00C1 = 'A' 
        [char]0x00E9 = 'e'; [char]0x00C9 = 'E'
        [char]0x00ED = 'i'; [char]0x00CD = 'I'
        [char]0x00F3 = 'o'; [char]0x00D3 = 'O'
        [char]0x00FA = 'u'; [char]0x00DA = 'U'
    }
    
    $NormalizedText = $Text
    foreach ($pair in $Replacements.GetEnumerator()) {
        $NormalizedText = $NormalizedText -replace $pair.Key, $pair.Value
    }
    
    $NormalizedText = $NormalizedText -replace '\s+', ' '
    $NormalizedText = $NormalizedText -replace '[^\w\s\-]', ''
    return $NormalizedText.Trim()
}

function Test-ScoringSystem {
    Write-Host "=== Test: Sistema de Puntuacion para Mapeo Especial ===" -ForegroundColor Cyan
    
    $Office = "Juzgado de Instruccion No 3"
    $CleanOffice = Normalize-Text -Text $Office
    $NormalizedOffice = $CleanOffice.ToLower()
    
    # Extraer numero
    $OfficeNumber = ""
    if ($NormalizedOffice -match '\b(\d+)\b') {
        $OfficeNumber = $Matches[1]
    }
    
    Write-Host "Oficina de prueba: '$Office'" -ForegroundColor Yellow
    Write-Host "Normalizada: '$NormalizedOffice'" -ForegroundColor Gray
    Write-Host "Numero detectado: '$OfficeNumber'" -ForegroundColor Gray
    
    # UOs de prueba
    $TestOUs = @(
        [PSCustomObject]@{ Name = "Juzgado de Primera Instancia e Instruccion No 3"; Expected = "MATCH PERFECTO" },
        [PSCustomObject]@{ Name = "Juzgado de Primera Instancia e Instruccion No 1"; Expected = "MATCH con penalizacion" },
        [PSCustomObject]@{ Name = "Juzgado de Instruccion No 3"; Expected = "Match exacto" },
        [PSCustomObject]@{ Name = "Juzgado de lo Penal No 3"; Expected = "Sin match especial" }
    )
    
    Write-Host "`nEvaluando UOs disponibles:" -ForegroundColor Cyan
    
    foreach ($OU in $TestOUs) {
        Write-Host "`n--- Evaluando: '$($OU.Name)' ---" -ForegroundColor White
        
        $CleanOUName = Normalize-Text -Text $OU.Name
        $OUNameNormalized = $CleanOUName.ToLower()
        
        # Logica de deteccion
        $IsInstruccionOnly = $NormalizedOffice -like "*instruccion*" -and 
                            $NormalizedOffice -notlike "*primera*" -and 
                            $NormalizedOffice -notlike "*instancia*" -and
                            $NormalizedOffice -like "*juzgado*"
        
        $IsFirstInstanceInstruction = $OUNameNormalized -like "*primera*" -and 
                                     $OUNameNormalized -like "*instancia*" -and 
                                     $OUNameNormalized -like "*instruccion*"
        
        $Score = 0
        $MatchedKeyWords = 0
        
        # Mapeo especial
        if ($IsInstruccionOnly -and $IsFirstInstanceInstruction) {
            Write-Host "  MAPEO ESPECIAL ACTIVADO!" -ForegroundColor Green
            $Score += 100
            $MatchedKeyWords += 5
        }
        
        # Verificar numero
        if ($OfficeNumber -and $OUNameNormalized -match '\bn[o..]\s*(\d+)') {
            $OUNumber = $Matches[1]
            if ($OUNumber -eq $OfficeNumber) {
                Write-Host "  Numero coincidente: $OUNumber" -ForegroundColor Green
                $Score += 20
            } else {
                Write-Host "  Numero diferente: $OUNumber vs $OfficeNumber (penalizacion)" -ForegroundColor Yellow
                $Score = $Score * 0.3
            }
        }
        
        # Palabras clave basicas
        $KeyWords = @('juzgado', 'primera', 'instancia', 'instruccion')
        foreach ($KeyWord in $KeyWords) {
            if ($NormalizedOffice -like "*$KeyWord*" -and $OUNameNormalized -like "*$KeyWord*") {
                $MatchedKeyWords++
                $Score += 1
            }
        }
        
        Write-Host "  Score final: $Score" -ForegroundColor $(if ($Score -gt 50) { "Green" } elseif ($Score -gt 10) { "Yellow" } else { "Red" })
        Write-Host "  Keywords matched: $MatchedKeyWords" -ForegroundColor Gray
        Write-Host "  Esperado: $($OU.Expected)" -ForegroundColor Gray
    }
    
    Write-Host "`n=== Conclusion ===" -ForegroundColor Cyan
    Write-Host "El sistema deberia priorizar 'Primera Instancia e Instruccion No 3' con el score mas alto." -ForegroundColor White
}

Test-ScoringSystem