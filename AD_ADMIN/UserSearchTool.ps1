#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Herramienta de búsqueda interactiva de usuarios en Active Directory
.DESCRIPTION
    Permite buscar usuarios de forma interactiva y realizar acciones de gestión
.AUTHOR
    CAU - Centro de Atención a Usuarios
.VERSION
    1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_UserSearch"
)

$ErrorActionPreference = "Stop"

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Import-Module "$ScriptPath\Modules\UOManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force
    Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force
    
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    
    $LogFile = Join-Path $LogPath "UserSearchTool_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$TimeStamp] [$Level] $Message"
        Add-Content -Path $LogFile -Value $LogEntry
    }
    
    Write-Host "=== HERRAMIENTA DE BÚSQUEDA DE USUARIOS AD ===" -ForegroundColor Cyan
    Write-Host "Iniciando herramienta de búsqueda interactiva..." -ForegroundColor Green
    Write-Host "Log: $LogFile" -ForegroundColor Gray
    Write-Host ""
    
    Write-Log "Iniciando herramienta de búsqueda interactiva"
    
    Initialize-UOManager
    Write-Log "Módulos inicializados correctamente"
    
    do {
        try {
            Start-InteractiveUserSearch
            
            Write-Host "`n¿Desea realizar otra búsqueda? (S/N)" -ForegroundColor Yellow
            $Continue = Read-Host
            
            if ($Continue -notmatch '^[SsYy]') {
                break
            }
            
        } catch {
            Write-Host "Error durante la búsqueda: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Error durante la búsqueda: $($_.Exception.Message)" "ERROR"
            
            Write-Host "`n¿Desea continuar? (S/N)" -ForegroundColor Yellow
            $Continue = Read-Host
            
            if ($Continue -notmatch '^[SsYy]') {
                break
            }
        }
        
        Clear-Host
        Write-Host "=== HERRAMIENTA DE BÚSQUEDA DE USUARIOS AD ===" -ForegroundColor Cyan
        
    } while ($true)
    
    Write-Host "`nGracias por usar la herramienta de búsqueda de usuarios." -ForegroundColor Green
    Write-Log "Herramienta finalizada correctamente"
    
} catch {
    Write-Host "Error crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Error crítico: $($_.Exception.Message)" "ERROR"
    throw
}