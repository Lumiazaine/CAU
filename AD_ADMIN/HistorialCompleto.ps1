#Requires -Version 5.1

<#
.SYNOPSIS
    Herramienta para consultar y analizar el historial completo de altas AD_ADMIN
.DESCRIPTION
    Proporciona consultas y estadísticas del archivo acumulativo de todas las altas realizadas
.PARAMETER Action
    Tipo de consulta a realizar: Stats, Search, Export, Clean
.PARAMETER SearchTerm
    Término de búsqueda para buscar usuarios específicos
.PARAMETER DateFrom
    Fecha desde para filtrar (formato: yyyy-MM-dd)
.PARAMETER DateTo
    Fecha hasta para filtrar (formato: yyyy-MM-dd)
.PARAMETER CSVPath
    Ruta al archivo CSV para determinar la ubicación del historial
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Stats", "Search", "Export", "Clean", "Recent")]
    [string]$Action = "Stats",
    
    [Parameter(Mandatory=$false)]
    [string]$SearchTerm,
    
    [Parameter(Mandatory=$false)]
    [DateTime]$DateFrom,
    
    [Parameter(Mandatory=$false)]
    [DateTime]$DateTo,
    
    [Parameter(Mandatory=$false)]
    [string]$CSVPath = (Get-Location)
)

$Global:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Get-HistorialPath {
    param([string]$BasePath = (Get-Location))
    
    if (Test-Path $BasePath -PathType Leaf) {
        $BaseDir = Split-Path $BasePath -Parent
    } else {
        $BaseDir = $BasePath
    }
    
    return Join-Path $BaseDir "AD_ADMIN_Historial_Completo_Altas.csv"
}

function Show-HistorialStats {
    param([string]$HistorialPath)
    
    if (-not (Test-Path $HistorialPath)) {
        Write-Host "No se encontró archivo de historial: $HistorialPath" -ForegroundColor Red
        Write-Host "Ejecute primero AD_UserManagement.ps1 para generar datos históricos" -ForegroundColor Yellow
        return
    }
    
    $Records = Import-Csv -Path $HistorialPath -Delimiter ";" -Encoding UTF8
    
    Write-Host "=== ESTADÍSTICAS DEL HISTORIAL COMPLETO ===" -ForegroundColor Green
    Write-Host "Archivo: $HistorialPath" -ForegroundColor Gray
    Write-Host "Total de registros: $($Records.Count)" -ForegroundColor White
    Write-Host ""
    
    # Estadísticas por estado
    $ByStatus = $Records | Group-Object Estado | Sort-Object Name
    Write-Host "=== POR ESTADO ===" -ForegroundColor Cyan
    foreach ($Group in $ByStatus) {
        $Color = switch ($Group.Name) {
            "EXITOSO" { "Green" }
            "ERROR" { "Red" }
            "SIMULADO" { "Yellow" }
            default { "Gray" }
        }
        Write-Host "  $($Group.Name): $($Group.Count) registros" -ForegroundColor $Color
    }
    Write-Host ""
    
    # Estadísticas por tipo de alta
    $ByType = $Records | Group-Object TipoAlta | Sort-Object Count -Descending
    Write-Host "=== POR TIPO DE ALTA ===" -ForegroundColor Cyan
    foreach ($Group in $ByType) {
        Write-Host "  $($Group.Name): $($Group.Count) registros" -ForegroundColor White
    }
    Write-Host ""
    
    # Estadísticas por dominio
    $ByDomain = $Records | Where-Object { $_.UO_Destino -like "*DC=*" } | 
                         ForEach-Object { 
                             if ($_.UO_Destino -match "DC=([^,]+)") { 
                                 $matches[1] 
                             } else { 
                                 "Desconocido" 
                             }
                         } | 
                         Group-Object | Sort-Object Count -Descending
    
    if ($ByDomain.Count -gt 0) {
        Write-Host "=== POR DOMINIO DE DESTINO ===" -ForegroundColor Cyan
        foreach ($Group in $ByDomain) {
            Write-Host "  $($Group.Name): $($Group.Count) registros" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Estadísticas por usuario de ejecución
    $ByUser = $Records | Group-Object UsuarioEjecucion | Sort-Object Count -Descending
    Write-Host "=== POR USUARIO DE EJECUCIÓN ===" -ForegroundColor Cyan
    foreach ($Group in $ByUser) {
        Write-Host "  $($Group.Name): $($Group.Count) registros" -ForegroundColor White
    }
    Write-Host ""
    
    # Estadísticas temporales
    $DateRecords = $Records | Where-Object { $_.FechaProceso }
    if ($DateRecords.Count -gt 0) {
        $FirstDate = ($DateRecords | Sort-Object FechaProceso | Select-Object -First 1).FechaProceso
        $LastDate = ($DateRecords | Sort-Object FechaProceso | Select-Object -Last 1).FechaProceso
        
        Write-Host "=== RANGO TEMPORAL ===" -ForegroundColor Cyan
        Write-Host "  Primera alta: $FirstDate" -ForegroundColor White
        Write-Host "  Última alta: $LastDate" -ForegroundColor White
        
        # Estadísticas por días recientes
        $RecentDays = 7
        $RecentDate = (Get-Date).AddDays(-$RecentDays)
        $RecentRecords = $DateRecords | Where-Object { [DateTime]::Parse($_.FechaProceso) -ge $RecentDate }
        Write-Host "  Últimos $RecentDays días: $($RecentRecords.Count) registros" -ForegroundColor Yellow
    }
}

function Search-HistorialRecords {
    param([string]$HistorialPath, [string]$SearchTerm, [DateTime]$DateFrom, [DateTime]$DateTo)
    
    if (-not (Test-Path $HistorialPath)) {
        Write-Host "No se encontró archivo de historial: $HistorialPath" -ForegroundColor Red
        return
    }
    
    $Records = Import-Csv -Path $HistorialPath -Delimiter ";" -Encoding UTF8
    $FilteredRecords = $Records
    
    # Filtrar por término de búsqueda
    if ($SearchTerm) {
        $FilteredRecords = $FilteredRecords | Where-Object {
            $_.Nombre -like "*$SearchTerm*" -or
            $_.Apellidos -like "*$SearchTerm*" -or
            $_.AD -like "*$SearchTerm*" -or
            $_.Email -like "*$SearchTerm*" -or
            $_.Oficina -like "*$SearchTerm*"
        }
    }
    
    # Filtrar por fechas
    if ($DateFrom) {
        $FilteredRecords = $FilteredRecords | Where-Object { 
            $_.FechaProceso -and [DateTime]::Parse($_.FechaProceso) -ge $DateFrom 
        }
    }
    
    if ($DateTo) {
        $FilteredRecords = $FilteredRecords | Where-Object { 
            $_.FechaProceso -and [DateTime]::Parse($_.FechaProceso) -le $DateTo 
        }
    }
    
    Write-Host "=== RESULTADOS DE BÚSQUEDA ===" -ForegroundColor Green
    Write-Host "Criterio: $SearchTerm" -ForegroundColor Gray
    Write-Host "Registros encontrados: $($FilteredRecords.Count)" -ForegroundColor White
    Write-Host ""
    
    foreach ($Record in $FilteredRecords | Sort-Object FechaProceso -Descending | Select-Object -First 20) {
        $StatusColor = switch ($Record.Estado) {
            "EXITOSO" { "Green" }
            "ERROR" { "Red" }
            "SIMULADO" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host "[$($Record.Estado)]" -ForegroundColor $StatusColor -NoNewline
        Write-Host " $($Record.Nombre) $($Record.Apellidos)" -ForegroundColor White
        Write-Host "     AD: $($Record.AD) | Tipo: $($Record.TipoAlta) | Fecha: $($Record.FechaProceso)" -ForegroundColor Gray
        Write-Host "     Oficina: $($Record.Oficina)" -ForegroundColor Gray
        if ($Record.Motivo) {
            Write-Host "     Motivo: $($Record.Motivo)" -ForegroundColor DarkYellow
        }
        Write-Host ""
    }
    
    if ($FilteredRecords.Count -gt 20) {
        Write-Host "... y $($FilteredRecords.Count - 20) registros más" -ForegroundColor Yellow
    }
}

function Show-RecentRecords {
    param([string]$HistorialPath, [int]$Days = 7)
    
    if (-not (Test-Path $HistorialPath)) {
        Write-Host "No se encontró archivo de historial: $HistorialPath" -ForegroundColor Red
        return
    }
    
    $Records = Import-Csv -Path $HistorialPath -Delimiter ";" -Encoding UTF8
    $RecentDate = (Get-Date).AddDays(-$Days)
    $RecentRecords = $Records | Where-Object { 
        $_.FechaProceso -and [DateTime]::Parse($_.FechaProceso) -ge $RecentDate 
    } | Sort-Object FechaProceso -Descending
    
    Write-Host "=== REGISTROS RECIENTES (Últimos $Days días) ===" -ForegroundColor Green
    Write-Host "Encontrados: $($RecentRecords.Count) registros" -ForegroundColor White
    Write-Host ""
    
    foreach ($Record in $RecentRecords | Select-Object -First 50) {
        $StatusColor = switch ($Record.Estado) {
            "EXITOSO" { "Green" }
            "ERROR" { "Red" }
            "SIMULADO" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host "[$($Record.Estado)]" -ForegroundColor $StatusColor -NoNewline
        Write-Host " $($Record.FechaProceso) - $($Record.Nombre) $($Record.Apellidos)" -ForegroundColor White
        Write-Host "     AD: $($Record.AD) | Archivo: $($Record.ArchivoOrigen)" -ForegroundColor Gray
        Write-Host ""
    }
}

function Export-FilteredHistorial {
    param([string]$HistorialPath, [string]$SearchTerm, [DateTime]$DateFrom, [DateTime]$DateTo)
    
    if (-not (Test-Path $HistorialPath)) {
        Write-Host "No se encontró archivo de historial: $HistorialPath" -ForegroundColor Red
        return
    }
    
    $Records = Import-Csv -Path $HistorialPath -Delimiter ";" -Encoding UTF8
    $FilteredRecords = $Records
    
    # Aplicar filtros (igual que Search-HistorialRecords)
    if ($SearchTerm) {
        $FilteredRecords = $FilteredRecords | Where-Object {
            $_.Nombre -like "*$SearchTerm*" -or
            $_.Apellidos -like "*$SearchTerm*" -or
            $_.AD -like "*$SearchTerm*" -or
            $_.Email -like "*$SearchTerm*" -or
            $_.Oficina -like "*$SearchTerm*"
        }
    }
    
    if ($DateFrom) {
        $FilteredRecords = $FilteredRecords | Where-Object { 
            $_.FechaProceso -and [DateTime]::Parse($_.FechaProceso) -ge $DateFrom 
        }
    }
    
    if ($DateTo) {
        $FilteredRecords = $FilteredRecords | Where-Object { 
            $_.FechaProceso -and [DateTime]::Parse($_.FechaProceso) -le $DateTo 
        }
    }
    
    # Generar nombre de archivo
    $ExportPath = $HistorialPath -replace '\.csv$', "_Filtrado_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    $FilteredRecords | Export-Csv -Path $ExportPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    
    Write-Host "Exportado: $($FilteredRecords.Count) registros a $ExportPath" -ForegroundColor Green
}

# Script principal
$HistorialPath = Get-HistorialPath -BasePath $CSVPath

Write-Host "=== HERRAMIENTA DE CONSULTA HISTORIAL AD_ADMIN ===" -ForegroundColor Cyan
Write-Host "Acción: $Action" -ForegroundColor Yellow
Write-Host "Archivo de historial: $HistorialPath" -ForegroundColor Gray
Write-Host ""

switch ($Action) {
    "Stats" { 
        Show-HistorialStats -HistorialPath $HistorialPath
    }
    "Search" {
        if (-not $SearchTerm) {
            $SearchTerm = Read-Host "Ingrese término de búsqueda (nombre, apellidos, AD, email, oficina)"
        }
        Search-HistorialRecords -HistorialPath $HistorialPath -SearchTerm $SearchTerm -DateFrom $DateFrom -DateTo $DateTo
    }
    "Recent" {
        $Days = Read-Host "¿Cuántos días atrás desea consultar? (por defecto: 7)"
        if ([string]::IsNullOrWhiteSpace($Days)) { $Days = 7 }
        Show-RecentRecords -HistorialPath $HistorialPath -Days ([int]$Days)
    }
    "Export" {
        if (-not $SearchTerm) {
            $SearchTerm = Read-Host "Ingrese término de búsqueda (o Enter para exportar todo)"
        }
        Export-FilteredHistorial -HistorialPath $HistorialPath -SearchTerm $SearchTerm -DateFrom $DateFrom -DateTo $DateTo
    }
    "Clean" {
        Write-Host "ADVERTENCIA: Esta acción eliminará todo el historial acumulativo." -ForegroundColor Red
        $Confirm = Read-Host "¿Está seguro? Escriba 'CONFIRMAR' para proceder"
        if ($Confirm -eq "CONFIRMAR") {
            if (Test-Path $HistorialPath) {
                Remove-Item $HistorialPath
                Write-Host "Historial eliminado: $HistorialPath" -ForegroundColor Yellow
            } else {
                Write-Host "No existe historial para eliminar" -ForegroundColor Gray
            }
        } else {
            Write-Host "Operación cancelada" -ForegroundColor Yellow
        }
    }
}

Write-Host "`nOperación completada." -ForegroundColor Green