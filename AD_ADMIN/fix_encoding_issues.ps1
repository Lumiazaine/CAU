#Requires -Version 5.1

<#
.SYNOPSIS
    Script para corregir problemas de codificación en AD_UserManagement.ps1
#>

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceFile = Join-Path $ScriptPath "AD_UserManagement.ps1"
$BackupFile = Join-Path $ScriptPath "AD_UserManagement.ps1.backup"

Write-Host "Corrigiendo problemas de codificación en AD_UserManagement.ps1..." -ForegroundColor Yellow

# Crear backup
if (-not (Test-Path $BackupFile)) {
    Copy-Item $SourceFile $BackupFile
    Write-Host "Backup creado: $BackupFile" -ForegroundColor Green
}

# Leer el contenido línea por línea para preservar estructura
$Lines = Get-Content $SourceFile -Encoding UTF8

Write-Host "Procesando $($Lines.Count) líneas..." -ForegroundColor Cyan

# Aplicar correcciones línea por línea
for ($i = 0; $i -lt $Lines.Count; $i++) {
    $OriginalLine = $Lines[$i]
    $CorrectedLine = $OriginalLine
    
    # Reemplazar caracteres de comillas problemáticos
    $CorrectedLine = $CorrectedLine -replace '"', '"'
    $CorrectedLine = $CorrectedLine -replace '"', '"'
    $CorrectedLine = $CorrectedLine -replace ''', "'"
    $CorrectedLine = $CorrectedLine -replace ''', "'"
    
    # Correcciones específicas por número de línea
    switch ($i + 1) {
        2526 {
            if ($CorrectedLine -like '*elementos*') {
                $CorrectedLine = '        Write-Host "[$($i+1)] $($Desc.Name) ($($Desc.Count) elementos)" -ForegroundColor White'
            }
        }
        2529 {
            if ($CorrectedLine -like '*Continuar*') {
                $CorrectedLine = '    Write-Host "[0] Continuar sin plantilla" -ForegroundColor Gray'
            }
        }
        3209 {
            if ($CorrectedLine -like '*CSV*empty*') {
                $CorrectedLine = '    Write-Log "El archivo CSV esta vacio o no tiene datos validos" "ERROR"'
            }
        }
        3757 {
            if ($CorrectedLine -like '*CSV*execution*') {
                $CorrectedLine = '        Write-Log "Resultados CSV para esta ejecucion: $ResultsCSVPath" "INFO"'
            }
        }
        3779 {
            if ($CorrectedLine -like '*UTF8*') {
                $CorrectedLine = '            $HistoricalStats = Import-Csv -Path $CumulativeCSVPath -Delimiter ";" -Encoding UTF8'
            }
        }
        3806 {
            if ($CorrectedLine -like '*Proceso completado*') {
                $CorrectedLine = 'Write-Host "Proceso completado. Log: $Global:LogFile" -ForegroundColor Green'
            }
        }
    }
    
    if ($CorrectedLine -ne $OriginalLine) {
        Write-Host "Línea $($i+1): Corregida" -ForegroundColor Green
    }
    
    $Lines[$i] = $CorrectedLine
}

# Guardar el archivo corregido
$Lines | Out-File -FilePath $SourceFile -Encoding UTF8

Write-Host "Archivo corregido y guardado" -ForegroundColor Green
Write-Host "Probando sintaxis..." -ForegroundColor Yellow

# Test simple de sintaxis
try {
    $TestResult = powershell.exe -Command "Get-Content '$SourceFile' | Out-String | ForEach-Object { [System.Management.Automation.PSParser]::Tokenize(`$_, [ref]`$null) | Out-Null }; Write-Output 'OK'"
    if ($TestResult -like "*OK*") {
        Write-Host " Sintaxis válida" -ForegroundColor Green
    } else {
        throw "Sintaxis inválida"
    }
} catch {
    Write-Host " Aún hay errores de sintaxis" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    if (Test-Path $BackupFile) {
        Copy-Item $BackupFile $SourceFile -Force
        Write-Host "Backup restaurado" -ForegroundColor Yellow
    }
}