#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Herramienta avanzada de búsqueda de usuarios en múltiples dominios
.DESCRIPTION
    Permite buscar usuarios en dominios específicos o en todos los dominios del bosque
.PARAMETER Domain
    Dominio específico donde buscar (opcional)
.PARAMETER SearchAllDomains
    Buscar en todos los dominios del bosque
.PARAMETER LogPath
    Ruta para los archivos de log
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [switch]$SearchAllDomains,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_MultiDomainSearch"
)

# Importar el módulo de búsqueda multi-dominio
$ModulePath = Join-Path $PSScriptRoot "Modules\MultiDomainSearch.psm1"
if (-not (Test-Path $ModulePath)) {
    Write-Host "Error: No se encontró el módulo MultiDomainSearch.psm1" -ForegroundColor Red
    Write-Host "Ruta esperada: $ModulePath" -ForegroundColor Red
    exit 1
}

try {
    Import-Module $ModulePath -Force -ErrorAction Stop
    Write-Verbose "Módulo MultiDomainSearch cargado correctamente"
} catch {
    Write-Host "Error cargando el módulo MultiDomainSearch: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Script principal
try {
    Start-MultiDomainUserSearch -Domain $Domain -SearchAllDomains:$SearchAllDomains
} catch {
    Write-Host "Error crítico: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}