#Requires -Version 5.1
#Requires -RunAsAdministrator

# Configuración de codificación para evitar errores con caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
    Utilidad de Soporte IT CAU - Versión PowerShell v3.1 (Windows 10/11)
.DESCRIPTION
    Herramienta integral de soporte optimizada para aprovechar las ventajas de PowerShell 5.1.
    Manejo de servicios, registro, limpieza de archivos y logging avanzado.
.NOTES
    Versión: JUS-120226-PS-ADV
    Autor: CAU IT Team
#>

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

$Global:CAUConfig = @{
    RemoteLogDir     = "\\iusnas05\SIJ\CAU-2012\logs"
    SoftwareBase     = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
    DriverBase       = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"
    
    # Instaladores
    IslMsi           = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi"
    IslExe           = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.exe"
    FnmtConfig       = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_5.1.1_64bits.exe"
    AutoFirmaExe     = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Autofirma_64_v1_9_installer.exe"
    AutoFirmaMsi     = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi"
    ChromeMsi        = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi"
    LibreOfficeMsi   = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi"
    
    # Drivers
    DriverPct        = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"
    DriverSatellite  = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
    
    # URLs
    UrlMiCuenta      = "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
    UrlFnmtSolicitar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
    UrlFnmtRenovar   = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
    UrlFnmtDescargar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
    
    ScriptVersion    = "JUS-120226-PS-ADV"
    BlockedHost      = "IUSSWRDPCAU02"
}

$Global:CAUSession = @{
    StartTime = Get-Date
    LogFile   = $null
    ADUser    = $null
    Hostname  = $env:COMPUTERNAME
}

# =============================================================================
# FUNCIONES DE SOPORTE
# =============================================================================

function Write-CAULog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'RUNAS', 'SUCCESS')][string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'RUNAS'   { 'Green' }
        'SUCCESS' { 'Magenta' }
        Default   { 'White' }
    }
    
    $LogEntry = "$Timestamp [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    
    if ($Global:CAUSession.LogFile) {
        try {
            $LogEntry | Out-File -FilePath $Global:CAUSession.LogFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            # Si falla el log a archivo, al menos queda en pantalla
        }
    }
}

function Invoke-RunAsAD {
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [switch]$Wait = $true
    )
    Write-CAULog "RUNAS: Preparando ejecucion como $($Global:CAUSession.ADUser)..." "RUNAS"
    
    $ProcessParams = @{
        FilePath     = "runas.exe"
        ArgumentList = "/user:$($Global:CAUSession.ADUser)@JUSTICIA /savecred `"$Command`""
        Wait         = $Wait
        WindowStyle  = 'Minimized'
    }
    
    try {
        Start-Process @ProcessParams
    } catch {
        Write-CAULog "Fallo al iniciar el proceso RunAs: $($_.Exception.Message)" "ERROR"
    }
}

function Get-SystemSummary {
    $Summary = [PSCustomObject]@{
        IP    = "Desconocida"
        SN    = "Desconocido"
        OS    = "Desconocido"
        Build = "Desconocido"
    }

    try {
        $NetInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Virtual|Pseudo' } | Select-Object -First 1
        if ($NetInfo) { $Summary.IP = $NetInfo.IPAddress }

        $Bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
        if ($Bios) { $Summary.SN = $Bios.SerialNumber }

        $OSInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($OSInfo) { $Summary.OS = $OSInfo.Caption }

        $RegistryInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        if ($RegistryInfo) { $Summary.Build = $RegistryInfo.CurrentBuildNumber }
    } catch {
        Write-CAULog "Error al obtener resumen del sistema: $($_.Exception.Message)" "WARN"
    }

    return $Summary
}

function Upload-Log {
    if (-not $Global:CAUSession.LogFile -or -not (Test-Path $Global:CAUSession.LogFile)) {
        return
    }

    Write-CAULog "Sincronizando log con el repositorio central..." "INFO"
    try {
        $LogFileName = Split-Path $Global:CAUSession.LogFile -Leaf
        $RemoteDir = $Global:CAUConfig.RemoteLogDir
        $RemotePath = Join-Path $RemoteDir $LogFileName
        
        # Asegurar directorio remoto
        Invoke-RunAsAD "cmd /c IF NOT EXIST `"$RemoteDir`" MKDIR `"$RemoteDir`"" -Wait
        # Copiar log
        Invoke-RunAsAD "cmd /c COPY /Y `"$($Global:CAUSession.LogFile)`" `"$RemotePath`"" -Wait
        
        Write-CAULog "Log sincronizado en: $RemotePath" "SUCCESS"
    } catch {
        Write-CAULog "No se pudo completar la sincronizacion del log." "WARN"
    }
}

function Initialize-CAUEnvironment {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host "      INICIALIZANDO ENTORNO DE SOPORTE CAU          " -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "====================================================" -ForegroundColor Yellow

    if ($env:COMPUTERNAME -eq $Global:CAUConfig.BlockedHost) {
        Write-CAULog "ERROR: Ejecucion bloqueada en esta terminal ($($Global:CAUConfig.BlockedHost))." "ERROR"
        Pause
        exit
    }

    $ADUser = Read-Host "Introduzca su usuario AD (Tecnico)"
    if ([string]::IsNullOrWhiteSpace($ADUser)) {
        Write-Host "Usuario no valido. Saliendo..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit
    }
    $Global:CAUSession.ADUser = $ADUser

    # Directorio de logs
    $LogDir = Join-Path $env:TEMP "CAUJUS_Logs"
    if (!(Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Global:CAUSession.LogFile = Join-Path $LogDir "$($ADUser)_$($env:COMPUTERNAME)_$Timestamp.log"

    Write-CAULog "Sesion iniciada para el tecnico: $ADUser" "SUCCESS"
    
    $Sys = Get-SystemSummary
    Write-CAULog "Informacion del equipo objetivo:"
    Write-CAULog " - Hostname: $($env:COMPUTERNAME)"
    Write-CAULog " - IP:       $($Sys.IP)"
    Write-CAULog " - S/N:      $($Sys.SN)"
    Write-CAULog " - OS:       $($Sys.OS) (Build $($Sys.Build))"
    Write-CAULog "----------------------------------------------------"

    # ISL Inicial (Silencioso)
    if (Test-Path $Global:CAUConfig.IslExe) {
        Write-CAULog "Lanzando ISL Light AlwaysOn inicial..."
        Invoke-RunAsAD "`"$($Global:CAUConfig.IslExe)`" /S" -Wait
    }
}

# =============================================================================
# ACCIONES PRINCIPALES
# =============================================================================

function Invoke-BateryTest {
    Write-CAULog "Iniciando Bateria de Pruebas Automatizada..." "INFO"
    
    # 1. Finalizar Navegadores
    $Browsers = @('chrome', 'iexplore', 'msedge')
    foreach ($Browser in $Browsers) {
        if (Get-Process -Name $Browser -ErrorAction SilentlyContinue) {
            Write-CAULog "Cerrando $Browser..."
            Stop-Process -Name $Browser -Force -ErrorAction SilentlyContinue
        }
    }

    # 2. Limpieza de Caches
    Write-CAULog "Limpiando caches de red e internet..."
    Clear-DnsClientCache
    Start-Process -FilePath "RunDll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait
    
    # Limpieza de temporales por patron
    Write-CAULog "Eliminando archivos temporales residuales..."
    $Extensions = @('*.bak', '*.tmp', '*._mp', '*.gid', '*.chk', '*.old')
    $CleanupPaths = @($env:windir, $env:systemdrive)
    
    foreach ($Path in $CleanupPaths) {
        Get-ChildItem -Path $Path -Include $Extensions -Recurse -ErrorAction SilentlyContinue | 
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # 3. Optimizacion de Rendimiento (Registro)
    Write-CAULog "Aplicando optimizaciones de efectos visuales..."
    $RegTweaks = @(
        @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = "0"; Type = "String" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = 2; Type = "DWord" }
    )

    foreach ($Tweak in $RegTweaks) {
        try {
            if (-not (Test-Path $Tweak.Path)) {
                New-Item -Path $Tweak.Path -Force | Out-Null
            }
            Set-ItemProperty -Path $Tweak.Path -Name $Tweak.Name -Value $Tweak.Value -Type $Tweak.Type -Force -ErrorAction SilentlyContinue
        } catch {
            Write-CAULog "No se pudo aplicar tweak: $($Tweak.Name)" "WARN"
        }
    }

    # 4. Servicios y GPO
    Write-CAULog "Forzando actualizacion de directivas de grupo (GPUpdate)..."
    & gpupdate /force | Out-Null
    
    Write-CAULog "Limpiando cache de Windows Update..."
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    $UpdateCache = Join-Path $env:windir "SoftwareDistribution\Download"
    if (Test-Path $UpdateCache) {
        Get-ChildItem -Path "$UpdateCache\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

    Write-CAULog "Bateria de pruebas finalizada con exito." "SUCCESS"
    
    $Choice = Read-Host "¿Desea reiniciar el equipo para aplicar todos los cambios? (S/N)"
    if ($Choice -match "^[Ss]$") {
        Upload-Log
        Restart-Computer -Force
    }
}

function Invoke-RemoveDrivers {
    Write-CAULog "Escaneando drivers de lectores de tarjetas para eliminacion..." "INFO"
    try {
        # Obtener drivers OEM que coincidan con patrones de lectores
        $Drivers = pnputil /enum-drivers | Select-String -Pattern "oem\d+\.inf" -Context 0,5
        
        $Count = 0
        foreach ($Match in $Drivers) {
            $Inf = $Match.ToString().Trim()
            if ($Match.Context.PostContext -join "" -match "lector|desconocido|smartcard|gemalto|cherry|scr3") {
                Write-CAULog "Eliminando driver conflictivo: $Inf" "WARN"
                pnputil /delete-driver $Inf /uninstall /force | Out-Null
                $Count++
            }
        }
        Write-CAULog "Se han eliminado $Count controladores." "SUCCESS"
    } catch {
        Write-CAULog "Error durante el proceso de limpieza de drivers." "ERROR"
    }
}

function Invoke-ForceTimeSync {
    Write-CAULog "Forzando sincronizacion con el servidor de tiempo..." "INFO"
    try {
        Stop-Service -Name "w32time" -Force -ErrorAction SilentlyContinue
        & w32tm /unregister | Out-Null
        & w32tm /register | Out-Null
        Start-Service -Name "w32time" -ErrorAction SilentlyContinue
        & w32tm /resync /nowait | Out-Null
        Write-CAULog "Sincronizacion de hora completada." "SUCCESS"
    } catch {
        Write-CAULog "Fallo al sincronizar la hora." "ERROR"
    }
}

# =============================================================================
# MENÚS
# =============================================================================

function Show-CertMenu {
    do {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "         GESTION DE CERTIFICADOS DIGITALES          " -ForegroundColor White -BackgroundColor DarkCyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host " 1. Configuracion previa FNMT (Silenciosa)"
        Write-Host " 2. Configuracion previa FNMT (Manual)"
        Write-Host " 3. Solicitar Certificado Persona Fisica"
        Write-Host " 4. Renovar Certificado"
        Write-Host " 5. Descargar Certificado"
        Write-Host " 6. <-- Volver al Menu Principal"
        Write-Host ""
        
        $Choice = Read-Host "Seleccione una opcion"
        switch ($Choice) {
            "1" { Invoke-RunAsAD "`"$($Global:CAUConfig.FnmtConfig)`" /S" }
            "2" { Invoke-RunAsAD "`"$($Global:CAUConfig.FnmtConfig)`"" }
            "3" { Start-Process -FilePath "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtSolicitar }
            "4" { Start-Process -FilePath "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtRenovar }
            "5" { Start-Process -FilePath "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtDescargar }
            "6" { return }
            Default { Write-CAULog "Opcion no valida." "WARN"; Start-Sleep -Seconds 1 }
        }
    } while ($true)
}

function Show-UtilitiesMenu {
    do {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "               UTILIDADES DE SOPORTE                " -ForegroundColor White -BackgroundColor DarkCyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host " 1. Opciones de Internet (Control Panel)"
        Write-Host " 2. Instalar Google Chrome (Silencioso)"
        Write-Host " 3. Corregir fondo de pantalla oscuro (Fix)"
        Write-Host " 4. Mostrar informacion de version (winver)"
        Write-Host " 5. Reinstalar drivers Lector (PCT/Satellite)"
        Write-Host " 6. Instalar Autofirma (Completo)"
        Write-Host " 7. Instalar LibreOffice (Silencioso)"
        Write-Host " 8. Forzar Sincronizacion de Hora"
        Write-Host " 9. <-- Volver al Menu Principal"
        Write-Host ""
        
        $Choice = Read-Host "Seleccione una opcion"
        switch ($Choice) {
            "1" { Start-Process -FilePath "RunDll32.exe" -ArgumentList "Shell32.dll,Control_RunDLL Inetcpl.cpl" }
            "2" { Invoke-RunAsAD "msiexec /i `"$($Global:CAUConfig.ChromeMsi)`" /qn" }
            "3" { 
                Write-CAULog "Ajustando modo de pantalla..."
                Start-Process -FilePath "DisplaySwitch.exe" -ArgumentList "/internal" -Wait
                Start-Sleep -Seconds 2
                Start-Process -FilePath "DisplaySwitch.exe" -ArgumentList "/extend"
            }
            "4" { Start-Process -FilePath "winver.exe" }
            "5" { 
                Invoke-RunAsAD "`"$($Global:CAUConfig.DriverPct)`""
                Invoke-RunAsAD "`"$($Global:CAUConfig.DriverSatellite)`""
            }
            "6" { 
                Write-CAULog "Iniciando despliegue de Autofirma..."
                Invoke-RunAsAD "`"$($Global:CAUConfig.AutoFirmaExe)`" /S" -Wait
                Invoke-RunAsAD "msiexec /i `"$($Global:CAUConfig.AutoFirmaMsi)`" /qn"
            }
            "7" { Invoke-RunAsAD "msiexec /i `"$($Global:CAUConfig.LibreOfficeMsi)`" /qn" }
            "8" { Invoke-ForceTimeSync }
            "9" { return }
            Default { Write-CAULog "Opcion no valida." "WARN"; Start-Sleep -Seconds 1 }
        }
    } while ($true)
}

function Show-MainMenu {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "             CAUJUS POWERSHELL v3.1                 " -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host " Tecnico AD: $($Global:CAUSession.ADUser)"
    Write-Host " Equipo:     $($env:COMPUTERNAME)"
    Write-Host " Version:    $($Global:CAUConfig.ScriptVersion)"
    Write-Host "----------------------------------------------------"
    Write-Host " 1. Bateria de pruebas completa (Optimizacion)"
    Write-Host " 2. Gestion de Password MiCuenta (Web)"
    Write-Host " 3. Reiniciar Cola de Impresion"
    Write-Host " 4. Administrador de Dispositivos (Limpiar Drivers)"
    Write-Host " 5. Menu Certificados Digitales (FNMT)"
    Write-Host " 6. Instalar ISL Light AlwaysOn (MSI)"
    Write-Host " 7. Menu de Utilidades Varias"
    Write-Host " 8. FINALIZAR Y SUBIR LOG"
    Write-Host ""
}

# =============================================================================
# BUCLE PRINCIPAL DE EJECUCION
# =============================================================================

try {
    Initialize-CAUEnvironment

    do {
        Show-MainMenu
        $Selection = Read-Host "Seleccione una accion"
        
        switch ($Selection) {
            "1" { Invoke-BateryTest }
            "2" { Start-Process -FilePath "chrome.exe" -ArgumentList $Global:CAUConfig.UrlMiCuenta }
            "3" { 
                Write-CAULog "Reseteando el servicio de cola de impresion..." "INFO"
                Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
                Get-ChildItem -Path "$env:windir\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Start-Service -Name "Spooler" -ErrorAction SilentlyContinue
                Write-CAULog "Cola de impresion lista." "SUCCESS"
                Pause
            }
            "4" { 
                Start-Process -FilePath "devmgmt.msc"
                $Resp = Read-Host "¿Desea iniciar la limpieza automatica de drivers de tarjeta? (S/N)"
                if ($Resp -match "^[Ss]$") { Invoke-RemoveDrivers }
            }
            "5" { Show-CertMenu }
            "6" { Invoke-RunAsAD "msiexec /i `"$($Global:CAUConfig.IslMsi)`" /qn" }
            "7" { Show-UtilitiesMenu }
            "8" { 
                Upload-Log
                Write-CAULog "Cerrando aplicacion de soporte..." "INFO"
                Start-Sleep -Seconds 1
                exit 
            }
            Default { 
                Write-CAULog "Seleccion '$Selection' no valida." "WARN"
                Start-Sleep -Seconds 1 
            }
        }
    } while ($true)
} catch {
    Write-CAULog "Error inesperado en el bucle principal: $($_.Exception.Message)" "ERROR"
    Pause
} finally {
    # Asegurar que se intenta subir el log si algo falla
    if ($Global:CAUSession.LogFile) { Upload-Log }
}
