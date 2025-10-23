# Diagnóstico de sintaxis para AD_UserManagement.ps1
Write-Host "=== DIAGNÓSTICO DE SINTAXIS ===" -ForegroundColor Yellow

try {
    Write-Host "1. Verificando existencia del archivo..." -ForegroundColor Cyan
    $FilePath = "C:\Users\CAU.LAP\CAU\AD_ADMIN\AD_UserManagement.ps1"
    if (Test-Path $FilePath) {
        Write-Host "✅ Archivo existe" -ForegroundColor Green
        
        Write-Host "`n2. Verificando codificación..." -ForegroundColor Cyan
        $Content = Get-Content $FilePath -Raw -Encoding UTF8
        Write-Host "✅ Contenido leído: $($Content.Length) caracteres" -ForegroundColor Green
        
        Write-Host "`n3. Verificando parseo de sintaxis..." -ForegroundColor Cyan
        $Errors = $null
        $Tokens = $null
        $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$Errors)
        
        if ($Errors.Count -eq 0) {
            Write-Host "✅ Sin errores de sintaxis" -ForegroundColor Green
        } else {
            Write-Host "❌ Errores encontrados:" -ForegroundColor Red
            foreach ($Error in $Errors) {
                Write-Host "  Línea $($Error.Extent.StartLineNumber): $($Error.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "`n4. Verificando carga de funciones específicas..." -ForegroundColor Cyan
        
        # Intentar encontrar y evaluar funciones específicas
        $NormalizeTextFunction = $Content -match "function Normalize-Text"
        $ExtractLocationFunction = $Content -match "function Extract-LocationFromOffice"
        $GetUOMatchFunction = $Content -match "function Get-UOMatchConfidence"
        
        Write-Host "  Normalize-Text function: $(if($NormalizeTextFunction){'✅ Encontrada'}else{'❌ No encontrada'})"
        Write-Host "  Extract-LocationFromOffice function: $(if($ExtractLocationFunction){'✅ Encontrada'}else{'❌ No encontrada'})"
        Write-Host "  Get-UOMatchConfidence function: $(if($GetUOMatchFunction){'✅ Encontrada'}else{'❌ No encontrada'})"
        
    } else {
        Write-Host "❌ Archivo no encontrado" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error durante diagnóstico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== FIN DIAGNÓSTICO ===" -ForegroundColor Yellow