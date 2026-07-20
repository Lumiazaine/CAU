#Requires -Version 5.1

<#
.SYNOPSIS
    Módulo para validación de datos del CSV de usuarios
.DESCRIPTION
    Proporciona funciones para validar los campos requeridos y opcionales del CSV
#>

function Test-CSVUserData {
    <#
    .SYNOPSIS
        Valida los datos de un usuario del CSV
    .PARAMETER UserData
        Objeto con los datos del usuario del CSV
    .PARAMETER LineNumber
        Número de línea en el CSV (para reportes de error)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [int]$LineNumber = 0
    )
    
    $ValidationResults = [PSCustomObject]@{
        IsValid = $true
        Errors = @()
        Warnings = @()
        ProcessedData = $UserData
    }
    
    $LinePrefix = if ($LineNumber -gt 0) { "Línea $LineNumber`: " } else { "" }
    
    # Validar campo TipoAlta (obligatorio)
    if ([string]::IsNullOrWhiteSpace($UserData.TipoAlta)) {
        $ValidationResults.Errors += "$($LinePrefix)Establece el tipo de alta, es obligatorio para seguir con el proceso."
        $ValidationResults.IsValid = $false
    } else {
        $ValidTipoAlta = @("NORMALIZADA", "TRASLADO", "COMPAGINADA")
        if ($UserData.TipoAlta.ToUpper() -notin $ValidTipoAlta) {
            $ValidationResults.Errors += "$($LinePrefix)Tipo de alta inválido: '$($UserData.TipoAlta)'. Debe ser: NORMALIZADA, TRASLADO o COMPAGINADA."
            $ValidationResults.IsValid = $false
        } else {
            # Normalizar el tipo de alta
            $ValidationResults.ProcessedData.TipoAlta = $UserData.TipoAlta.ToUpper()
        }
    }
    
    # Validar campos obligatorios comunes
    $RequiredFields = @("Nombre", "Apellidos", "Oficina", "Descripcion")
    foreach ($Field in $RequiredFields) {
        if ([string]::IsNullOrWhiteSpace($UserData.$Field)) {
            $ValidationResults.Errors += "$($LinePrefix)El campo '$Field' es obligatorio."
            $ValidationResults.IsValid = $false
        }
    }
    
    # Validaciones específicas por tipo de alta
    switch ($UserData.TipoAlta.ToUpper()) {
        "TRASLADO" {
            # Para traslados, debe tener Email O campo AD
            if ([string]::IsNullOrWhiteSpace($UserData.Email) -and [string]::IsNullOrWhiteSpace($UserData.AD)) {
                $ValidationResults.Errors += "$($LinePrefix)Para traslados se requiere Email o campo AD para localizar al usuario existente."
                $ValidationResults.IsValid = $false
            }
        }
        "NORMALIZADA" {
            # Para altas normalizadas, validar que el campo AD esté vacío
            if (![string]::IsNullOrWhiteSpace($UserData.AD)) {
                $ValidationResults.Warnings += "$($LinePrefix)Para alta normalizada el campo AD debería estar vacío (se generará automáticamente)."
            }
        }
        "COMPAGINADA" {
            # Para compaginadas, debe tener Email O campo AD
            if ([string]::IsNullOrWhiteSpace($UserData.Email) -and [string]::IsNullOrWhiteSpace($UserData.AD)) {
                $ValidationResults.Errors += "$($LinePrefix)Para altas compaginadas se requiere Email o campo AD para localizar al usuario existente."
                $ValidationResults.IsValid = $false
            }
        }
    }
    
    # Validar formato de email si está presente
    if (![string]::IsNullOrWhiteSpace($UserData.Email)) {
        if (!($UserData.Email -match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")) {
            $ValidationResults.Warnings += "$($LinePrefix)El formato del email parece incorrecto: '$($UserData.Email)'"
        }
    }
    
    # Validar descripción
    if (![string]::IsNullOrWhiteSpace($UserData.Descripcion)) {
        $ValidDescriptions = @("LAJ", "Letrado", "Juez", "Magistrado", "Auxilio", "Gestor", "Tramitador", "Tramitadora")
        $IsValidDescription = $false
        
        foreach ($ValidDesc in $ValidDescriptions) {
            if ($UserData.Descripcion -like "*$ValidDesc*") {
                $IsValidDescription = $true
                break
            }
        }
        
        if (!$IsValidDescription) {
            $ValidationResults.Warnings += "$($LinePrefix)La descripción '$($UserData.Descripcion)' no coincide con los tipos estándar (LAJ, Letrado, Juez, Magistrado, Auxilio, Gestor, Tramitador)."
        }
    }
    
    # Validar teléfono/DNI
    if (![string]::IsNullOrWhiteSpace($UserData.Telefono)) {
        # Asumir que es un DNI si contiene letras, teléfono si es solo números
        if ($UserData.Telefono -match "^\d{8}[A-Z]$") {
            # Formato DNI español
            $ValidationResults.ProcessedData | Add-Member -NotePropertyName "IsDNI" -NotePropertyValue $true -Force
        } elseif ($UserData.Telefono -match "^[\d\s\-\+\(\)]+$") {
            # Formato teléfono
            $ValidationResults.ProcessedData | Add-Member -NotePropertyName "IsDNI" -NotePropertyValue $false -Force
        } else {
            $ValidationResults.Warnings += "$($LinePrefix)El formato del teléfono/DNI no es reconocido: '$($UserData.Telefono)'"
        }
    }
    
    return $ValidationResults
}

function Test-CSVFile {
    <#
    .SYNOPSIS
        Valida todo un archivo CSV antes de procesarlo
    .PARAMETER CSVPath
        Ruta al archivo CSV
    .PARAMETER Delimiter
        Delimitador usado en el CSV (por defecto ';')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory=$false)]
        [string]$Delimiter = ";"
    )
    
    $ValidationSummary = [PSCustomObject]@{
        IsValid = $true
        TotalRows = 0
        ValidRows = 0
        ErrorRows = 0
        WarningRows = 0
        Errors = @()
        Warnings = @()
        ValidatedData = @()
    }
    
    try {
        if (!(Test-Path $CSVPath)) {
            $ValidationSummary.Errors += "El archivo CSV no existe: $CSVPath"
            $ValidationSummary.IsValid = $false
            return $ValidationSummary
        }
        
        # Importar CSV
        $CSVData = Import-Csv -Path $CSVPath -Delimiter $Delimiter -Encoding UTF8
        $ValidationSummary.TotalRows = $CSVData.Count
        
        if ($ValidationSummary.TotalRows -eq 0) {
            $ValidationSummary.Errors += "El archivo CSV está vacío o no tiene datos válidos"
            $ValidationSummary.IsValid = $false
            return $ValidationSummary
        }
        
        # Verificar cabeceras requeridas
        $RequiredHeaders = @("TipoAlta", "Nombre", "Apellidos", "Email", "Telefono", "Oficina", "Descripcion", "AD")
        $CSVHeaders = $CSVData[0].PSObject.Properties.Name
        
        foreach ($RequiredHeader in $RequiredHeaders) {
            if ($RequiredHeader -notin $CSVHeaders) {
                $ValidationSummary.Errors += "Falta la cabecera requerida: '$RequiredHeader'"
                $ValidationSummary.IsValid = $false
            }
        }
        
        if (!$ValidationSummary.IsValid) {
            return $ValidationSummary
        }
        
        # Validar cada fila
        for ($i = 0; $i -lt $CSVData.Count; $i++) {
            $LineNumber = $i + 2  # +2 porque empezamos en línea 2 (después de cabeceras)
            $RowValidation = Test-CSVUserData -UserData $CSVData[$i] -LineNumber $LineNumber
            
            if ($RowValidation.IsValid) {
                $ValidationSummary.ValidRows++
                $ValidationSummary.ValidatedData += $RowValidation.ProcessedData
            } else {
                $ValidationSummary.ErrorRows++
                $ValidationSummary.IsValid = $false
            }
            
            if ($RowValidation.Warnings.Count -gt 0) {
                $ValidationSummary.WarningRows++
            }
            
            $ValidationSummary.Errors += $RowValidation.Errors
            $ValidationSummary.Warnings += $RowValidation.Warnings
        }
        
        return $ValidationSummary
        
    } catch {
        $ValidationSummary.Errors += "Error procesando archivo CSV: $($_.Exception.Message)"
        $ValidationSummary.IsValid = $false
        return $ValidationSummary
    }
}

function Show-ValidationSummary {
    <#
    .SYNOPSIS
        Muestra un resumen de la validación del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ValidationSummary
    )
    
    Write-Host "`n=== RESUMEN DE VALIDACIÓN DEL CSV ===" -ForegroundColor Cyan
    Write-Host "Total de filas: $($ValidationSummary.TotalRows)" -ForegroundColor White
    Write-Host "Filas válidas: $($ValidationSummary.ValidRows)" -ForegroundColor Green
    Write-Host "Filas con errores: $($ValidationSummary.ErrorRows)" -ForegroundColor Red
    Write-Host "Filas con advertencias: $($ValidationSummary.WarningRows)" -ForegroundColor Yellow
    Write-Host "Estado general: $(if ($ValidationSummary.IsValid) { 'VÁLIDO' } else { 'INVÁLIDO' })" -ForegroundColor $(if ($ValidationSummary.IsValid) { 'Green' } else { 'Red' })
    
    if ($ValidationSummary.Errors.Count -gt 0) {
        Write-Host "`nERRORES ENCONTRADOS:" -ForegroundColor Red
        foreach ($Error in $ValidationSummary.Errors) {
            Write-Host "  ERROR: $Error" -ForegroundColor Red
        }
    }
    
    if ($ValidationSummary.Warnings.Count -gt 0) {
        Write-Host "`nADVERTENCIAS:" -ForegroundColor Yellow
        foreach ($Warning in $ValidationSummary.Warnings) {
            Write-Host "  WARNING: $Warning" -ForegroundColor Yellow
        }
    }
    
    if ($ValidationSummary.IsValid) {
        Write-Host "`nEl archivo CSV esta listo para ser procesado." -ForegroundColor Green
    } else {
        Write-Host "`nCorrija los errores antes de procesar el archivo CSV." -ForegroundColor Red
    }
    
    Write-Host ""
}

Export-ModuleMember -Function @(
    'Test-CSVUserData',
    'Test-CSVFile',
    'Show-ValidationSummary'
)