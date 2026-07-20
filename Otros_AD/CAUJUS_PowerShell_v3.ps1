#Requires -Version 5.1
#Requires -RunAsAdministrator

# Configurar codificación para mostrar caracteres especiales correctamente
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    Utilidad de Soporte IT CAU - Versión PowerShell v3.0 (Optimizada para Win 10/11)
.DESCRIPTION
    Herramienta integral de soporte migrada de Batch a PowerShell.
    Optimizada para Windows 10/11 con logging avanzado y ejecución elevada.
.NOTES
    Versión: JUS-010226-PS
    Autor: CAU IT Team
#>

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

$Global:CAUConfig = @{
    RemoteLogDir     = "\iusnas05\SIJ\CAU-2012\logs"
    SoftwareBase     = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
    DriverBase       = "\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"
    
    # Instaladores
    IslMsi           = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi"
    IslExe           = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.exe"
    FnmtConfig       = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_5.1.1_64bits.exe"
    AutoFirmaExe     = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Autofirma_64_v1_9_installer.exe"
    AutoFirmaMsi     = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi"
    ChromeMsi        = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi"
    LibreOfficeMsi   = "\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi"
    
    # URLs
    UrlMiCuenta      = "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
    UrlFnmtSolicitar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
    UrlFnmtRenovar   = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
    UrlFnmtDescargar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
    
    ScriptVersion    = "JUS-010226-PS"
    BlockedHost      = "IUSSWRDPCAU02"
}

$Global:CAUSession = @{
    StartTime = Get-Date
    LogFile   = $null
    ADUser    = $null
    Hostname  = $env:COMPUTERNAME
}

# =============================================================================
# VARIABLES DE TEXTO (Caracteres especiales)
# =============================================================================
$VersionText   = "Versi$([char]243)n"
$BateriaText   = "1. Bater$([char]237)a de pruebas (Optimizaci$([char]243)n)"
$ImpresionText = "3. Reiniciar cola de impres$([char]237)n"
$GestionText   = "5. Gesti$([char]243)n de Certificados Digitales"
$OpcionText    = "Seleccione una opci$([char]243)n"

# =============================================================================
# FUNCIONES DE SISTEMA (LOGGING Y ENTORNO)
# =============================================================================

function Write-CAULog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'RUNAS')][string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch($Level) {
        'INFO'  { 'Cyan' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'RUNAS' { 'Green' }
    }
    $LogEntry = "$Timestamp [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    
    if ($Global:CAUSession.LogFile) {
        $LogEntry | Out-File -FilePath $Global:CAUSession.LogFile -Append -Encoding UTF8
    }
}

function Initialize-CAUEnvironment {
    # 1. Bloqueo de Máquina de Salto
    if ($env:COMPUTERNAME -eq $Global:CAUConfig.BlockedHost) {
        Write-Host "ERROR: Este script no puede ejecutarse en la máquina de salto ($($Global:CAUConfig.BlockedHost))." -ForegroundColor Red
        Pause
        exit
    }

    # 2. Credenciales
    $Global:CAUSession.ADUser = Read-Host "Introduce tu usuario AD"
    if ([string]::IsNullOrWhiteSpace($Global:CAUSession.ADUser)) { exit }
    
    # 3. Preparar Log Local
    $LogDir = Join-Path $env:TEMP "CAUJUS_Logs"
    if (!(Test-Path $LogDir)) { New-Item $LogDir -ItemType Directory | Out-Null }
    
    $TimestampFile = Get-Date -Format "yyyyMMdd_HHmmss"
    $Global:CAUSession.LogFile = Join-Path $LogDir "$($Global:CAUSession.ADUser)_$($env:COMPUTERNAME)_$TimestampFile.log"
    
    Write-CAULog "Script iniciado. Usuario: $($env:USERNAME), Máquina: $($env:COMPUTERNAME)"
    
    # 4. Instalación inicial de ISL (Silenciosa)
    if (Test-Path $Global:CAUConfig.IslExe) {
        Write-CAULog "Ejecutando ISL inicial..."
        Start-Process $Global:CAUConfig.IslExe -ArgumentList "/S" -Wait
    }
}

function Get-SystemSummary {
    $IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Virtual' }).IPAddress | Select-Object -First 1
    $SN = (Get-CimInstance Win32_Bios).SerialNumber
    $OS = (Get-CimInstance Win32_OperatingSystem).Caption
    $Build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

    return @{
        IP    = $IP
        SN    = if ($SN) { $SN } else { "Desconocido" }
        OS    = $OS
        Build = $Build
    }
}

# =============================================================================
# ACCIONES PRINCIPALES
# =============================================================================

function Invoke-BateryTest {
    Write-CAULog "Iniciando Batería de Pruebas..."
    
    # 1. Cerrar Navegadores
    Write-CAULog "Cerrando navegadores..."
    Get-Process chrome, iexplore, msedge -ErrorAction SilentlyContinue | Stop-Process -Force

    # 2. Limpieza de Caches
    Write-Progress -Activity "Batería de Pruebas" -Status "Limpiando Caches" -PercentComplete 25
    Clear-DnsClientCache
    # Limpieza IE/Internet (Nativo)
    Start-Process RunDll32.exe -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait
    
    # Limpieza Chrome Cache
    $ChromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    if (Test-Path $ChromeCache) { Remove-Item "$ChromeCache\*" -Recurse -Force -ErrorAction SilentlyContinue }

    # 3. Ajustes de Rendimiento (Registro)
    Write-CAULog "Aplicando tweaks de efectos visuales..."
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (!(Test-Path $RegPath)) { New-Item $RegPath -Force | Out-Null }
    Set-ItemProperty -Path $RegPath -Name "VisualFXSetting" -Value 2

    # 4. Mantenimiento de Sistema
    Write-Progress -Activity "Batería de Pruebas" -Status "Mantenimiento GPUpdate" -PercentComplete 75
    gpupdate /force
    
    # Limpieza SoftwareDistribution (Windows Update Cache)
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue

    Write-Progress -Activity "Batería de Pruebas" -Completed
    Write-CAULog "Batería de pruebas completada."
    
    $Res = Read-Host "¿Deseas reiniciar el equipo ahora? (S/N)"
    if ($Res -eq 'S') {
        Upload-Log
        Restart-Computer -Force
    }
}

function Invoke-ResetPrintSpooler {
    Write-CAULog "Reiniciando cola de impresión..."
    Stop-Service Spooler -Force
    Remove-Item "$env:windir\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    Write-CAULog "Cola de impresión reseteada."
    Pause
}

function Upload-Log {
    try {
        if (!(Test-Path $Global:CAUConfig.RemoteLogDir)) {
            New-Item $Global:CAUConfig.RemoteLogDir -ItemType Directory -Force | Out-Null
        }
        $Dest = Join-Path $Global:CAUConfig.RemoteLogDir (Split-Path $Global:CAUSession.LogFile -Leaf)
        Copy-Item $Global:CAUSession.LogFile -Destination $Dest -Force
        Write-CAULog "Log subido exitosamente a la red."
    } catch {
        Write-CAULog "No se pudo subir el log a la red." "WARN"
    }
}

# =============================================================================
# MENÚS
# =============================================================================

function Show-MainMenu {
    $Sys = Get-SystemSummary

    Clear-Host
    Write-Host "------------------------------------------" -ForegroundColor Yellow
    Write-Host "             $($Global:CAUConfig.ScriptVersion)             " -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "------------------------------------------" -ForegroundColor Yellow
    Write-Host " Usuario AD: $($Global:CAUSession.ADUser)"
    Write-Host " Equipo:     $($env:COMPUTERNAME) | IP: $($Sys.IP)"
    Write-Host " S/N:        $($Sys.SN)"
    Write-Host " OS:         $($Sys.OS) (Build $($Sys.Build))"
    Write-Host " ${VersionText}:    $($Global:CAUConfig.ScriptVersion)"
    Write-Host "------------------------------------------" -ForegroundColor Yellow
    Write-Host " $BateriaText"
    Write-Host " 2. Cambiar password correo"
    Write-Host " $ImpresionText"
    Write-Host " 4. Administrador de dispositivos"
    Write-Host " $GestionText"
    Write-Host " 6. Instalar ISL Always On"
    Write-Host " 7. Utilidades Varias"
    Write-Host " 8. Salir y Subir Log"
    Write-Host ""
}

# =============================================================================
# BUCLE PRINCIPAL
# =============================================================================

Initialize-CAUEnvironment

do {
    Show-MainMenu
    $Opt = Read-Host "$OpcionText"
    
    switch ($Opt) {
        "1" { Invoke-BateryTest }
        "2" { Start-Process chrome $Global:CAUConfig.UrlMiCuenta }
        "3" { Invoke-ResetPrintSpooler }
        "4" { Start-Process devmgmt.msc }
        "5" { 
            # Menú Certificados (Lógica simplificada para el ejemplo)
            Write-CAULog "Abriendo portal de certificados..."
            Start-Process chrome $Global:CAUConfig.UrlFnmtSolicitar 
        }
        "6" { 
            Write-CAULog "Instalando ISL Always On..."
            if (Test-Path $Global:CAUConfig.IslMsi) {
                Start-Process msiexec.exe -ArgumentList "/i `"$($Global:CAUConfig.IslMsi)`" /qn" -Wait
            }
        }
        "7" {
            Write-CAULog "Abriendo utilidades..."
            Start-Process winver
        }
        "8" { 
            Upload-Log
            Write-CAULog "Saliendo..."
            Start-Sleep -Seconds 2
            exit 
        }
    }
} while ($true)
