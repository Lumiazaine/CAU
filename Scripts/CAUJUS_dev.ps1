<#
.SYNOPSIS
    Script: CAUJUS_dev.ps1 (Migrado desde CAUJUS_dev.bat)
    Propósito: Proporciona una utilidad de menú para varias tareas de soporte de TI de CAU.
.DESCRIPTION
    Este script de PowerShell es una migración del archivo .bat original, 
    adaptado para funcionar en PowerShell v2.0 (Windows 7) y superior (Windows 10/11).
    Solicita credenciales de administrador (usuario AD) una vez al inicio y las utiliza
    para ejecutar tareas elevadas de forma segura.
.VERSION
    2504 - PowerShell Migration
#>

# --- Variables de Configuración ---
$config_RemoteLogDir = "\\iusnas05\SIJ\CAU-2012\logs"
$config_SoftwareBasePath = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
$config_DriverBasePath = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"

$config_IslMsiPath = Join-Path $config_SoftwareBasePath "isl.msi"
$config_FnmtConfigExe = Join-Path $config_SoftwareBasePath "Configurador_FNMT_5.0.3_64bits.exe"
$config_AutoFirmaExe = Join-Path $config_SoftwareBasePath "AutoFirma_64_v1_8_3_installer.exe"
$config_AutoFirmaMsi = Join-Path $config_SoftwareBasePath "AutoFirma_v1_6_0_JAv05_installer_64.msi"
$config_ChromeMsiPath = Join-Path $config_SoftwareBasePath "chrome.msi"
$config_LibreOfficeMsiPath = Join-Path $config_SoftwareBasePath "LibreOffice.msi"

$config_DriverPctPath = Join-Path $config_DriverBasePath "PCT-331_V8.52\SCR3xxx_V8.52.exe"
$config_DriverSatellitePath = Join-Path $config_DriverBasePath "satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"

$config_UrlMiCuentaJunta = "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
$config_UrlFnmtSolicitar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
$config_UrlFnmtRenovar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
$config_UrlFnmtDescargar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"

$config_ScriptVersion = "JUS-021125-PS"
# --- Fin de Variables de Configuración ---

# --- Funciones Auxiliares ---

# Función robusta para auto-eliminar el script
function global:Invoke-SelfDelete {
    # $MyInvocation.MyCommand.Path solo funciona si se ejecuta desde un archivo
    $MyScriptPath = $MyInvocation.MyCommand.Path
    
    if (-not [string]::IsNullOrEmpty($MyScriptPath)) {
        LogMessage "INFO - Self-deleting script: $MyScriptPath"
        Remove-Item $MyScriptPath -Force -ErrorAction SilentlyContinue
    } else {
        LogMessage "WARN - Could not determine script path for self-deletion. (Possibly running in console/ISE)."
    }
}

# Escribe un mensaje en el archivo de log global
function global:LogMessage {
    param([string]$Message)
    
    $TimestampLog = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$TimestampLog - $Message"
    Add-Content -Path $Global:LogFile -Value $LogEntry
}

# ... (justo después de la línea $Global:LogFile = ...)

# --- Intento de descarga dinámica del último Configurador FNMT (Win 10/11) ---
LogMessage "INFO - Starting dynamic download of latest FNMT configurator..."

# 1. URL de la PÁGINA de descargas (esta es estable)
$downloadPageUrl = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/configuracion-previa"
$baseUrl = "https://www.sede.fnmt.gob.es"
$keyword = "Configurador_FNMT_RCM_64bits.exe" # Buscamos el de 64 bits
$localFnmtPath = Join-Path $env:TEMP $keyword

try {
    LogMessage "INFO - Scraping download page: $downloadPageUrl"
    
    # 2. Descargamos el contenido de la PÁGINA (sin -UseBasicParsing)
    # Necesitamos que PowerShell analice el HTML para encontrar los enlaces.
    $response = Invoke-WebRequest -Uri $downloadPageUrl
    
    # 3. Buscamos el enlace (tag <a>) que contenga la palabra clave
    $link = $response.Links | Where-Object { $_.href -like "*$keyword*" } | Select-Object -First 1
    
    if ($link) {
        # 4. Enlace encontrado. Construimos la URL completa
        # El enlace en la página es relativo (ej: /documents/11614/115456/...)
        $fullUrl = $baseUrl + $link.href
        LogMessage "INFO - Found dynamic link: $fullUrl"
        
        # 5. Descargamos el archivo .exe (esta vez SÍ usamos -UseBasicParsing)
        # Es mucho más rápido para descargar archivos binarios.
        Invoke-WebRequest -Uri $fullUrl -OutFile $localFnmtPath -UseBasicParsing
        
        LogMessage "INFO - Download successful. Using downloaded version: $localFnmtPath"
        
        # 6. Sobrescribimos la variable global
        $Global:config_FnmtConfigExe = $localFnmtPath
        
    } else {
        LogMessage "ERROR - Could not find a link containing '$keyword' on the page. Using network fallback."
    }
    
} catch {
    LogMessage "ERROR - Failed to scrape or download FNMT configurator: $_. Falling back to network path: $config_FnmtConfigExe"
    # Si falla CUALQUIER COSA (sin internet, FNMT cambia la web), 
    # el script simplemente usará el valor original de $config_FnmtConfigExe (la ruta de red)
}
# --- Fin del bloque de descarga ---

LogMessage "INFO - Script CAUJUS.ps1 started. User: $Global:adUser, Profile: $userProfileName, Machine: $Global:currentHostname. Logging to: $Global:LogFile"

# Ejecuta un comando con las credenciales de AD proporcionadas
function global:Invoke-AdminCommand {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [switch]$Wait = $true,
        [switch]$Silent
    )
    
    LogMessage "RUNAS - Attempting to execute: $FilePath $Arguments"
    try {
        $psArgs = @{
            FilePath     = $FilePath
            ArgumentList = $Arguments
            Credential   = $Global:credential
            PassThru     = $true
        }
        
        if ($WorkingDirectory) { $psArgs.Add("WorkingDirectory", $WorkingDirectory) }
        if ($Wait)             { $psArgs.Add("Wait", $true) }
        if ($Silent)           { $psArgs.Add("WindowStyle", "Hidden") }

        Start-Process @psArgs
        
    } catch {
        LogMessage "ERROR - Failed to execute '$FilePath $Arguments': $_"
    }
}

# Sube el archivo de log al repositorio central
function global:UploadLogFile {
    LogMessage "INFO - Preparing to upload log file $LogFile to network."
    $FinalLogDir = $config_RemoteLogDir
    $FinalLogFilename = "${Global:adUser}_${Global:currentHostname}_${Global:TimestampFile}.log"
    $FinalLogPath = Join-Path $FinalLogDir $FinalLogFilename
    
    # Crear el directorio de red si no existe (usando credenciales de admin)
    $MkdirCommand = "IF NOT EXIST `"$FinalLogDir`" MKDIR `"$FinalLogDir`""
    Invoke-AdminCommand -FilePath "cmd.exe" -Arguments "/c $MkdirCommand" -Silent -Wait
    
    # Copiar el log (usando credenciales de admin)
    $CopyCommand = "COPY /Y `"$Global:LogFile`" `"$FinalLogPath`""
    Invoke-AdminCommand -FilePath "cmd.exe" -Arguments "/c $CopyCommand" -Silent -Wait
    
    LogMessage "INFO - Log upload attempt finished."
}

# --- Funciones de Acciones de Batería de Pruebas ---

function BT-KillBrowsers {
    LogMessage "INFO - Killing browser processes."
    Stop-Process -Name "chrome", "iexplore", "msedge" -ErrorAction SilentlyContinue -Force
}

function BT-ClearSystemCaches {
    LogMessage "INFO - Clearing system caches."
    ipconfig /flushdns
    Rundll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
    Rundll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
    Rundll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
    Rundll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
    Remove-Item -Path (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache\*") -Recurse -Force -ErrorAction SilentlyContinue
}

function BT-ApplyVisualEffectRegTweaks {
    LogMessage "INFO - Applying visual effect registry tweaks (under admin context)."
    # NOTA: Al igual que el script batch original, esto modifica el HKCU del *usuario admin* ($adUser),
    # no el del usuario que ha iniciado sesión. Se replica el comportamiento original.
    $RegCommands = @(
        "REG ADD `"HKCU\Control Panel\Desktop\WindowMetrics`" /v MinAnimate /t REG_SZ /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v TaskbarAnimations /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v VisualFXSetting /t REG_DWORD /d 2 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v ComboBoxAnimation /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v CursorShadow /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v DropShadow /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v MenuAnimation /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v SelectionFade /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v TooltipAnimation /t REG_DWORD /d 0 /f",
        "REG ADD `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v Fade /t REG_DWORD /d 0 /f"
    )
    $FullRegCommand = $RegCommands -join " && "
    Invoke-AdminCommand -FilePath "cmd.exe" -Arguments "/c $FullRegCommand" -Silent -Wait
}

function BT-SystemMaintenanceTasks {
    LogMessage "INFO - Performing system maintenance tasks (under admin context)."
    LogMessage "INFO - Action: Running gpupdate /force in Batery_test."
    gpupdate /force
    
    Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_IslMsiPath`" /qn" -Silent -Wait
    
    # NOTA: Al igual que el script original, las variables %appdata% y %userprofile% se resuelven
    # en el contexto del usuario admin, limpiando *su* perfil, no el del usuario local.
    $DelCommands = @(
        "DEL /F /S /Q `"%windir%\*.bak`"",
        "DEL /F /S /Q `"%windir%\SoftwareDistribution\Download\*.*`"",
        "DEL /F /S /Q `"%systemdrive%\*.tmp`"",
        "DEL /F /S /Q `"%systemdrive%\*._mp`"",
        "DEL /F /S /Q `"%systemdrive%\*.gid`"",
        "DEL /F /S /Q `"%systemdrive%\*.chk`"",
        "DEL /F /S /Q `"%systemdrive%\*.old`"",
        "IF EXIST `"%appdata%\Microsoft\Windows\cookies`" DEL /F /S /Q `"%appdata%\Microsoft\Windows\cookies\*.*`"",
        "IF EXIST `"%appdata%\Local\Microsoft\Windows\Temporary Internet Files`" DEL /F /S /Q `"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*`"",
        "IF EXIST `"%appdata%\Local\Microsoft\Windows\INetCache`" DEL /F /S /Q `"%appdata%\Local\Microsoft\Windows\INetCache\*.*`"",
        "IF EXIST `"%appdata%\Local\Microsoft\Windows\INetCookies`" DEL /F /S /Q `"%appdata%\Local\Microsoft\Windows\INetCookies\*.*`"",
        "IF EXIST `"%appdata%\Local\Microsoft\Terminal Server Client\Cache`" DEL /F /S /Q `"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*`"",
        "IF EXIST `"%appdata%\Local\CrashDumps`" DEL /F /S /Q `"%appdata%\Local\CrashDumps\*.*`"",
        "IF EXIST `"%userprofile%\Local Settings\Temporary Internet Files`" DEL /F /S /Q `"%userprofile%\Local Settings\Temporary Internet Files\*.*`"",
        "IF EXIST `"%userprofile%\Local Settings\Temp`" DEL /F /S /Q `"%userprofile%\Local Settings\Temp\*.*`"",
        "IF EXIST `"%userprofile%\AppData\Local\Temp`" DEL /F /S /Q `"%userprofile%\AppData\Local\Temp\*.*`"",
        "IF EXIST `"%userprofile%\Local Settings\Temp`" ( RMDIR /S /Q `"%userprofile%\Local Settings\Temp`" & MKDIR `"%userprofile%\Local Settings\Temp`" )",
        "IF EXIST `"%windir%\Temp`" ( RMDIR /S /Q `"%windir%\Temp`" & MKDIR `"%windir%\Temp`" )"
    )
    $FullDelCommand = $DelCommands -join " && "
    Invoke-AdminCommand -FilePath "cmd.exe" -Arguments "/c $FullDelCommand" -Silent -Wait
}


# --- Funciones del Menú Principal ---

function Start-BateryTest {
    # ... (código)
    UploadLogFile
    # $MyScriptPath = $MyInvocation.MyCommand.Path # <-- ELIMINA ESTA LÍNEA
    
    if ($key.KeyChar -eq 's') {
        LogMessage "INFO - User chose to restart."
        Invoke-SelfDelete # <-- REEMPLAZO
        Restart-Computer -Force
    } else {
        LogMessage "INFO - User chose not to restart. Exiting."
        Invoke-SelfDelete # <-- REEMPLAZO
        exit
    }
}

function Start-MailPass {
    LogMessage "INFO - Action: Starting mail_pass. Opening URL."
    Start-Process "chrome" -ArgumentList $config_UrlMiCuentaJunta
    UploadLogFile
    Invoke-SelfDelete # <-- REEMPLAZO
    exit
}

function Start-PrintPool {
    # ... (código)
    Invoke-AdminCommand -FilePath "cmd.exe" -Arguments "/c $Command" -Silent -Wait
    
    UploadLogFile
    Invoke-SelfDelete # <-- REEMPLAZO
    exit
}
function Start-DesinstaladorTarjetas {
    # ... (código)
    LogMessage "INFO - Driver removal loop finished."
    UploadLogFile
    Invoke-SelfDelete # <-- REEMPLAZO
    exit
}

function Start-ISLAlwaysOn {
    LogMessage "INFO - Action: Starting isl_always_on. Installing ISL Always On."
    Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_IslMsiPath`" /qn" -Silent -Wait
    # Vuelve al menú principal
}

function Show-CertMenu {
    $exitMenu = $false
    do {
        Clear-Host
        Write-Host "------------------------------------------"
        Write-Host "                 CAU"
        Write-Host "    Gestiones del certificado digital"
        Write-Host "------------------------------------------"
        Write-Host "1. Configuracion previa (Silenciosa)"
        Write-Host "2. Configuracion previa (Manual)"
        Write-Host "3. Solicitar certificado digital"
        Write-Host "4. Renovar certificado digital"
        Write-Host "5. Descargar certificado digital"
        Write-Host "6. Inicio"
        Write-Host
        
        $choice = Read-Host "Escoge una opcion"
        LogMessage "INFO - Cert_Menu: User selected option $choice."
        
        $downloadDir = Join-Path $env:USERPROFILE "Downloads"
        
        switch ($choice) {
            "1" {
                LogMessage "INFO - Action: Starting Cert_Config_Silent."
                Invoke-AdminCommand -FilePath $config_FnmtConfigExe -Arguments "/S" -WorkingDirectory $downloadDir -Silent -Wait
            }
            "2" {
                LogMessage "INFO - Action: Starting Cert_Config_Manual."
                Invoke-AdminCommand -FilePath $config_FnmtConfigExe -WorkingDirectory $downloadDir -Wait
            }
            "3" {
                LogMessage "INFO - Action: Starting Cert_Request."
                Start-Process "chrome" -ArgumentList $config_UrlFnmtSolicitar
            }
            "4" {
                LogMessage "INFO - Action: Starting Cert_Renew."
                Start-Process "chrome" -ArgumentList $config_UrlFnmtRenovar
            }
            "5" {
                LogMessage "INFO - Action: Starting Cert_Download."
                Start-Process "chrome" -ArgumentList $config_UrlFnmtDescargar
            }
            "6" {
                $exitMenu = $true # Vuelve al menú principal
            }
            default {
                Write-Host "'$choice' no es valido, intentalo de nuevo"
                Start-Sleep -Seconds 2
            }
        }
    } while ($exitMenu -eq $false)
}

function Show-UtilitiesMenu {
    $exitMenu = $false
    do {
        Clear-Host
        Write-Host "------------------------------------------"
        Write-Host "                 CAU"
        Write-Host "              Utilidades"
        Write-Host "------------------------------------------"
        Write-Host "1. Ver opciones de internet"
        Write-Host "2. Instalar Chrome 109"
        Write-Host "3. Arreglar pantalla oscura (no aparece fondo de pantalla)"
        Write-Host "4. Ver version de Windows"
        Write-Host "5. Reinstalar drivers tarjeta"
        Write-Host "6. Instalar Autofirmas"
        Write-Host "7. Instalar Libreoffice"
        Write-Host "8. Forzar fecha y hora"
        Write-Host "9. Inicio"
        Write-Host

        $choice = Read-Host "Escoge una opcion"
        LogMessage "INFO - Utilities_Menu: User selected option $choice."
        
        switch ($choice) {
            "1" { # Util_InternetOptions
                LogMessage "INFO - Action: Starting Util_InternetOptions."
                Rundll32.exe Shell32.dll,Control_RunDLL Inetcpl.cpl
            }
            "2" { # Util_InstallChrome
                LogMessage "INFO - Action: Starting Util_InstallChrome."
                Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_ChromeMsiPath`" /qn" -Silent -Wait
            }
            "3" { # Util_FixBlackScreen
                LogMessage "INFO - Action: Starting Util_FixBlackScreen."
                DisplaySwitch.exe /internal
                Start-Sleep -Seconds 3
                DisplaySwitch.exe /extend
            }
            "4" { # Util_ShowWinVer
                LogMessage "INFO - Action: Starting Util_ShowWinVer."
                Rundll32.exe SHELL32.DLL,ShellAboutW
            }
            "5" { # Util_ReinstallCardReaderDrivers
                LogMessage "INFO - Action: Starting Util_ReinstallCardReaderDrivers."
                Invoke-AdminCommand -FilePath $config_DriverPctPath -Wait
                Invoke-AdminCommand -FilePath $config_DriverSatellitePath -Wait
            }
            "6" { # Util_InstallAutofirma
                LogMessage "INFO - Action: Starting Util_InstallAutofirma."
                Stop-Process -Name "chrome" -ErrorAction SilentlyContinue -Force
                Invoke-AdminCommand -FilePath $config_AutoFirmaExe -Arguments "/S" -Silent -Wait
                Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_AutoFirmaMsi`" /qn" -Silent -Wait
            }
            "7" { # Util_InstallLibreOffice
                LogMessage "INFO - Action: Starting Util_InstallLibreOffice."
                Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_LibreOfficeMsiPath`" /qn" -Silent -Wait
            }
            "8" { # Util_ForceDateTimeSync
                LogMessage "INFO - Action: Starting Util_ForceDateTimeSync."
                Invoke-AdminCommand -FilePath "NET.exe" -Arguments "STOP w32time" -Silent -Wait
                Invoke-AdminCommand -FilePath "W32TM.exe" -Arguments "/unregister" -Silent -Wait
                Invoke-AdminCommand -FilePath "W32TM.exe" -Arguments "/register" -Silent -Wait
                Invoke-AdminCommand -FilePath "NET.exe" -Arguments "START w32time" -Silent -Wait
                Invoke-AdminCommand -FilePath "W32TM.exe" -Arguments "/resync" -Silent -Wait
            }
            "9" {
                $exitMenu = $true # Vuelve al menú principal
            }
            default {
                Write-Host "'$choice' no es valido, intentalo de nuevo"
                Start-Sleep -Seconds 2
            }
        }
    } while ($exitMenu -eq $false)
}

# --- Función NO UTILIZADA (Migrada por completitud) ---
# Esta función existe en el .bat original pero nunca se llama.
# Se ha migrado mejorando la lógica (el bucle del .bat estaba roto).
function Start-DesinstaladorTarjetas {
    LogMessage "INFO - Action: Starting desinstalador_tarjetas. Uninstalling unknown/reader drivers."
    
    # Obtiene la salida de pnputil y la divide en bloques por driver
    $driverBlocks = (pnputil /enum-drivers | Out-String) -split '---------------------------'
    
    foreach ($block in $driverBlocks) {
        # Busca si la clase o el proveedor coinciden con 'lector' o 'desconocido' (case-insensitive)
        if ($block -match "Nombre de clase:.*(lector|desconocido)" -or $block -match "Proveedor:.*(lector|desconocido)") {
            
            # Si coincide, extrae el "Nombre publicado" (oemXX.inf)
            $oemLine = $block | Select-String "Nombre publicado:"
            if ($oemLine) {
                $oemFile = ($oemLine.ToString() -split ":")[1].Trim()
                if ($oemFile) {
                    Write-Host "Eliminando el controlador $oemFile (Clase/Proveedor coincide con 'lector' o 'desconocido')..."
                    LogMessage "INFO - Deleting driver $oemFile"
                    Invoke-AdminCommand -FilePath "PNPUTIL.exe" -Arguments "/delete-driver $oemFile /uninstall /force" -Silent -Wait
                }
            }
        }
    }
    
    Clear-Host
    LogMessage "INFO - Driver removal loop finished."
    UploadLogFile
    Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
    exit
}

#=============================================================================
# Bloque de Inicio y Configuración
#=============================================================================

Clear-Host
$Global:currentHostname = $env:COMPUTERNAME

# --- Bloqueo para máquina de salto ---
if ($Global:currentHostname -eq "IUSSWRDPCAU02") {
    Write-Host "Error, se está ejecutando el script desde la máquina de salto." -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit
}

# --- Configuración Inicial ---

# Obtener usuario AD y credencial
$Global:adUser = Read-Host "Introduce tu AD"
try {
    $Global:credential = Get-Credential -UserName "$Global:adUser@JUSTICIA" -Message "Introduce la contraseña para $Global:adUser@JUSTICIA"
} catch {
    Write-Host "Error al obtener credenciales. Saliendo." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}


$userProfileName = $env:USERNAME

# Configurar Logging
$LogDir = Join-Path $env:TEMP "CAUJUS_Logs"
if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
}

$Global:TimestampFile = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = Join-Path $LogDir "${Global:adUser}_${Global:currentHostname}_${Global:TimestampFile}.log"

LogMessage "INFO - Script CAUJUS.ps1 started. User: $Global:adUser, Profile: $userProfileName, Machine: $Global:currentHostname. Logging to: $Global:LogFile"

# --- Instalación inicial de ISL (como en el .bat original) ---
Invoke-AdminCommand -FilePath "msiexec.exe" -Arguments "/i `"$config_IslMsiPath`" /qn" -Silent -Wait

#=============================================================================
# Bucle del Menú Principal
#=============================================================================

function Show-MainMenu {
    Clear-Host
    
    # --- Recopilar Información del Sistema ---
    $computerName = $Global:currentHostname
    
    try {
        $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber.Trim()
        if ([string]::IsNullOrEmpty($serialNumber)) { $serialNumber = "Desconocido" }
    } catch { $serialNumber = "Desconocido" }
    
    try {
        # Método robusto para PS 2.0+
        $ip = [System.Net.Dns]::GetHostAddresses($computerName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        $networkIP = $ip.IPAddressToString
    } catch { $networkIP = "Desconocida" }
    
    try {
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem
        $osCaption = $osInfo.Caption.Trim()
        $osBuildNumber = $osInfo.BuildNumber
    } catch {
        $osCaption = "Desconocido"
        $osBuildNumber = "Desconocido"
    }

    # Log de la información del sistema
    LogMessage "INFO - System Info: User: $userProfileName, AD User: $Global:adUser, Computer: $computerName, SN: $serialNumber, IP: $networkIP, OS: $osCaption ($osBuildNumber), Script Version: $config_ScriptVersion"

    # --- Mostrar Menú ---
    Write-Host "------------------------------------------"
    Write-Host "                 CAU"
    Write-Host "------------------------------------------"
    Write-Host
    Write-Host "Usuario: $userProfileName"
    Write-Host "Usuario AD utilizado: $Global:adUser"
    Write-Host "Nombre equipo: $computerName"
    Write-Host "Numero de serie: $serialNumber"
    Write-Host "Numero de IP: $networkIP"
    Write-Host "Version: $osCaption, con la compilacion $osBuildNumber"
    Write-Host "Version Script: $config_ScriptVersion"
    Write-Host
    Write-Host "1. Bateria pruebas"
    Write-Host "2. Cambiar password correo"
    Write-Host "3. Reiniciar cola impresion"
    Write-Host "4. Administrador de dispositivos (desinstalar drivers)"
    Write-Host "5. Certificado digital"
    Write-Host "6. ISL Allways on"
    Write-Host "7. Utilidades"
    Write-Host

    $choice = Read-Host "Escoge una opcion"
    LogMessage "INFO - Main menu: User selected option $choice."
    
    return $choice
}

# --- Bucle Principal de Lógica ---
do {
    $choice = Show-MainMenu
    switch ($choice) {
        "1" { Start-BateryTest }       # Esta función contiene 'exit'
        "2" { Start-MailPass }         # Esta función contiene 'exit'
        "3" { Start-PrintPool }        # Esta función contiene 'exit'
        "4" { Start-DriverAdmin }      # Vuelve al menú
        "5" { Show-CertMenu }          # Vuelve al menú
        "6" { Start-ISLAlwaysOn }      # Vuelve al menú
        "7" { Show-UtilitiesMenu }     # Vuelve al menú
        default {
            Write-Host "'$choice' opcion no valida, intentalo de nuevo"
            Start-Sleep -Seconds 2
        }
    }
} while ($true) # El script solo se cierra desde las funciones que contienen 'exit'