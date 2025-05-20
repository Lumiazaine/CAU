@ECHO off
:: Test mode entry point
IF "%1"=="--test-logging" (
    call :log "Test log entry from --test-logging mode"
    exit /b 0
)
::-----------------------------------------------------------------------------
:: Script: CAUJUS_dev.bat
:: Version: 2505.2_dev (as indicated in the script's main menu)
:: Purpose: Provides a menu-driven interface for CAU (Centro de Atención al Usuario)
::          technicians to perform various diagnostic, repair, and software
::          installation tasks on user workstations.
::-----------------------------------------------------------------------------

::=============================================================================
:: Section: Jump Host Check
:: Prevents the script from running on a specific jump host (IUSSWRDPCAU02).
::=============================================================================
:: Bloqueo para máquina de salto
for /f "tokens=*" %%A in ('hostname') do set "hostname=%%A"
if "%hostname%"=="IUSSWRDPCAU02" (
    cls
    echo Error, se está ejecutando el script desde la máquina de salto.
    pause
    exit
) else (
    goto check
)

::=============================================================================
:: Section: AD User Input
:: Prompts for the technician's AD username if not already set.
:: Retrieves the current Windows user profile name.
::=============================================================================
:: Variable AD
:check
cls
@ECHO off
set AD=
if not defined AD (
    set /p "AD=introduce tu AD:"
)
for /f "tokens=2 delims=\" %%i in ('whoami') do set Perfil=%%i
cls
goto main

::=============================================================================
:: Section: Main Menu & System Information
:: Gathers and displays system information.
:: Presents the main menu of available actions to the technician.
::=============================================================================
:: Datos equipos
:main
cls
FOR /F "usebackq" %%i IN (`hostname`) DO SET computerName=%%i
FOR /F "Tokens=1* Delims==" %%g In ('WMIC BIOS Get SerialNumber /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET sn=%%i
FOR /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set networkIP=%%a
FOR /F "Tokens=1* Delims==" %%g In ('wmic os get caption /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET win=%%i
FOR /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do (set versionSO=%%B)

::=============================================================================
:: Section: Logging Function (:log)
:: Handles writing messages to a log file.
:: Log file is named based on AD username and computer name.
::=============================================================================
:log
setlocal enabledelayedexpansion
:: Define log directory and file
IF NOT DEFINED ruta_log (
    set "ruta_log=\\iusnas05\SIJ\CAU-2012\logs"
)
:: The following log line is for debugging the log path in tests.
:: It's not strictly part of the original script's logging but useful for verification.
:: Check if AD and COMPUTERNAME are defined before attempting to log with them.
if defined AD if defined COMPUTERNAME (
    call :basic_log "Using log path: %ruta_log%"
) else (
    REM Cannot log to the main file yet if AD or COMPUTERNAME are not set.
    REM This typically happens if --test-logging is called before AD is set.
    REM The :basic_log function itself will handle %AD% and %COMPUTERNAME% being empty for the log filename.
    call :basic_log "Using log path: %ruta_log% (AD or COMPUTERNAME might be undefined at this point for filename)"
)

set "LOGFILE=%ruta_log%\%AD%_%COMPUTERNAME%.log"
:: Get current timestamp
set "TIMESTAMP=%date% %time%"
:: Check if log directory exists
if not exist "%ruta_log%" (
    echo [ERROR] No se puede acceder al directorio de logs: %ruta_log%
    exit /b 1
)
:: Append message to log file
echo [%TIMESTAMP%] %~1>> "%LOGFILE%"
endlocal
goto :eof
:: End of Section: Logging Function (Primary :log)

::=============================================================================
:: Sub-Section: Basic Logging Function (:basic_log)
:: This is a simplified logger used by the main :log function for the
:: "Using log path" message, ensuring it can log even if AD/COMPUTERNAME
:: are not yet fully resolved for the main LOGFILE path.
:: It uses a fixed name or a name based on available info if AD/COMPUTERNAME are empty.
::=============================================================================
:basic_log
setlocal enabledelayedexpansion
:: Ensure ruta_log is available; if not, this sub-logger can't do much.
IF NOT DEFINED ruta_log (
    echo [ERROR] ruta_log not defined for :basic_log
    exit /b 1
)
:: Construct a log file name for this basic log entry.
:: If AD or COMPUTERNAME are empty, it will result in a log file like "_.log" or "TESTUSER_.log" etc.
set "BASIC_LOG_FILE=%ruta_log%\%AD%_%COMPUTERNAME%.log"
set "TIMESTAMP_BASIC=%date% %time%"

if not exist "%ruta_log%" (
    mkdir "%ruta_log%" >nul 2>&1
    if not exist "%ruta_log%" (
        echo [ERROR] No se pudo crear el directorio de logs para basic_log: %ruta_log%
        exit /b 1
    )
)
echo [%TIMESTAMP_BASIC%] %~1>> "%BASIC_LOG_FILE%"
endlocal
goto :eof
:: End of Sub-Section: Basic Logging Function
:: End of Section: Logging Function
:: Note: The 'call :log "Inicio del script"' was moved to after :check for proper AD resolution.

::=============================================================================
:: Section: AD User Input (Continued from above, duplicate :check label)
:: This :check label seems to be a duplicate or misplaced.
:: The primary AD input and profile gathering is done under the first :check.
:: This part appears to be the start of the Main Menu display.
::=============================================================================
:check :: This label is duplicated, the script jumps here from the initial AD check.
cls
call :log "Inicio del script" :: Log script start after AD is set.
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO ------------------------------------------
echo(
ECHO Usuario: %Perfil%                                :: Displays current Windows user profile.
ECHO Usuario AD utilizado: %AD%                        :: Displays AD username provided by technician.
ECHO Nombre equipo: %computerName%                   :: Displays computer's hostname.
ECHO Numero de serie: %sn%                           :: Displays computer's serial number.
ECHO Numero de IP: %networkIP%                         :: Displays computer's IP address.
ECHO Version: %win%, con la compilacion %versionSO%   :: Displays Windows version and build number.
ECHO Version Script: 2505.2_dev                      :: Displays current script version.
echo(
ECHO 1. Bateria pruebas                               :: Runs diagnostic tests and cleanup tasks.
ECHO 2. Cambiar password correo                       :: Opens browser to change email password.
ECHO 3. Reiniciar cola impresion                      :: Restarts the print spooler service.
ECHO 4. Administrador de dispositivos (desinstalar drivers) :: Opens Device Manager.
ECHO 5. Certificado digital                           :: Manages digital certificates.
ECHO 6. ISL Allways on                                :: Installs/Reinstalls ISL Always On VPN.
ECHO 7. Utilidades                                    :: Opens a sub-menu with more utilities.
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto Batery_test                   :: Jump to Bateria pruebas section.
if '%choice%'=='2' goto mail_pass                   :: Jump to Cambiar password correo section.
if '%choice%'=='3' goto print_pool                  :: Jump to Reiniciar cola impresion section.
if '%choice%'=='4' goto Driver_admin                :: Jump to Administrador de dispositivos section.
if '%choice%'=='5' goto Cert                        :: Jump to Certificado digital section.
if '%choice%'=='6' goto isl                         :: Jump to ISL Allways on section.
if '%choice%'=='7' goto Bmenu                       :: Jump to Utilidades (sub-menu) section.
ECHO "%choice%" opcion no valida, intentalo de nuevo
ECHO.
goto main :: Return to main menu if choice is invalid.
:: Note: The 'del /q "%~f0"' command below this point is unreachable due to the 'goto main' above.
:: This command, if reached, would delete the script itself.
del /q "%~f0" 

::=============================================================================
:: Section: Bateria pruebas (:Batery_test)
:: Performs various cleanup and optimization tasks.
:: Kills browser processes, flushes DNS, clears caches, adjusts visual effects,
:: applies group policies, reinstalls ISL, and cleans temporary files.
:: Finally, prompts for a system restart.
::=============================================================================
:Batery_test
call :log "Starting section Batery_test"
:: Kill common browser processes
call :log "Performing action: taskkill chrome.exe"
taskkill /IM chrome.exe /F > nul 2>&1
call :log "Performing action: taskkill iexplore.exe"
taskkill /IM iexplore.exe /F > nul 2>&1
call :log "Performing action: taskkill msedge.exe"
taskkill /IM msedge.exe /F > nul 2>&1
:: Flush DNS cache
call :log "Performing action: ipconfig /flushdns"
ipconfig /flushdns
:: Clear Internet Explorer cache and history
call :log "Performing action: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16 (History)"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
call :log "Performing action: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8 (Cache)"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
call :log "Performing action: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2 (Cookies)"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
call :log "Performing action: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1 (Temporary Internet Files)"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
:: Clear Chrome cache (Path might be user/system dependent)
call :log "Performing action: del E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
del /q /s /f "E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
:: Adjust visual effects for performance
call :log "Performing action: reg add HKCU various keys for visual effects"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 2 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f"
:: Force group policy update
call :log "Performing action: gpupdate /force"
gpupdate /force
:: Reinstall ISL client
call :log "Performing action: msiexec /i isl.msi"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
:: Delete various temporary and backup files
call :log "Performing action: Deleting various system temporary files"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\*.bak\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.old\""
:: Delete user-specific temporary files and caches
call :log "Performing action: Deleting user profile temporary files and caches"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\""
:: Recreate user and system Temp folders
call :log "Performing action: Recreating Temp folders"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\""
:: Prompt for restart
call :log "Prompting for restart after Batery_test"
echo Reiniciar equipo (s/n)
choice /c sn /n
if errorlevel 2 call :log "User chose not to restart" & del "%~f0%" & exit :: Deletes script and exits if 'n' is chosen.
if errorlevel 1 call :log "User chose to restart" & shutdown /r /t 0    :: Restarts computer if 's' is chosen.
@echo off
goto :eof :: End of Batery_test section
:: End of Section: Bateria pruebas

::=============================================================================
:: Section: Cambiar password correo (:mail_pass)
:: Opens a Chrome browser window to the Junta de Andalucia account page
:: for changing the email password.
:: Deletes the script after execution.
::=============================================================================
:mail_pass
call :log "Starting section mail_pass"
call :log "Performing action: start chrome https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
call :log "Performing action: del %~f0% & exit (self-deleting script)"
del "%~f0%" & exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Cambiar password correo

::=============================================================================
:: Section: Reiniciar cola impresion (:print_pool)
:: Restarts the print spooler for all printers.
:: Deletes the script after execution.
::=============================================================================
:print_pool
call :log "Starting section print_pool"
call :log "Performing action: Restarting print spooler for all printers"
runas /user:%AD%@JUSTICIA /savecred "cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\""
call :log "Performing action: del %~f0% & exit (self-deleting script)"
del "%~f0%" & exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Reiniciar cola impresion

::=============================================================================
:: Section: Administrador de dispositivos (:Driver_admin)
:: Opens the Device Manager console.
:: Returns to the main menu.
::=============================================================================
:Driver_admin
call :log "Starting section Driver_admin"
call :log "Performing action: RunDll32.exe devmgr.dll DeviceManager_Execute"
runas /user:%AD%@JUSTICIA /savecred "RunDll32.exe devmgr.dll DeviceManager_Execute"
goto main :: Returns to the main menu.
:: No goto :eof needed as it explicitly jumps to main.
:: End of Section: Administrador de dispositivos

::=============================================================================
:: Section: ISL Allways on (:isl)
:: Installs or reinstalls the ISL Always On VPN client silently.
:: Returns to the main menu.
::=============================================================================
:isl
call :log "Starting section isl"
call :log "Performing action: msiexec /i isl.msi (reinstall ISL)"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
goto main :: Returns to the main menu.
:: No goto :eof needed as it explicitly jumps to main.
:: End of Section: ISL Allways on

::=============================================================================
:: Section: Certificado digital (:Cert)
:: Provides a sub-menu for managing digital certificates, including FNMT configuration
:: and accessing FNMT website for certificate requests, renewals, and downloads.
::=============================================================================
:Cert
call :log "Starting section Cert (Digital Certificate Management)"
cls
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO     Gestiones del certificado digital
ECHO ------------------------------------------
ECHO 1. Configuracion previa (Silenciosa)         :: Runs FNMT configurator silently.
ECHO 2. Configuracion previa (Manual)           :: Runs FNMT configurator manually (shows UI).
ECHO 3. Solicitar certificado digital             :: Opens FNMT website to request a certificate.
ECHO 4. Renovar certificado digital               :: Opens FNMT website to renew a certificate.
ECHO 5. Descargar certificado digital             :: Opens FNMT website to download a certificate.
ECHO 6. Inicio                                    :: Returns to the main menu.
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' call :log "Cert menu: User selected option 1" & goto configurators
if '%choice%'=='2' call :log "Cert menu: User selected option 2" & goto configurator
if '%choice%'=='3' call :log "Cert menu: User selected option 3" & goto solicitude
if '%choice%'=='4' call :log "Cert menu: User selected option 4" & goto renew
if '%choice%'=='5' call :log "Cert menu: User selected option 5" & goto download
if '%choice%'=='6' call :log "Cert menu: User selected option 6 (Return to Main Menu)" & goto main
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Cert :: Return to Cert menu if choice is invalid.
:: End of Section: Cert (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Silenciosa) (:configurators)
:: Runs the FNMT configuration tool in silent mode.
::-----------------------------------------------------------------------------
:configurators
call :log "Starting sub-section configurators"
call :log "Performing action: cd %userprofile%\downloads"
cd %userprofile%\downloads
call :log "Performing action: Silent FNMT Configurator"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S"
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurators

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Manual) (:configurator)
:: Runs the FNMT configuration tool in manual (interactive) mode.
::-----------------------------------------------------------------------------
:configurator
call :log "Starting sub-section configurator"
call :log "Performing action: cd %userprofile%\downloads"
cd %userprofile%\downloads
call :log "Performing action: Manual FNMT Configurator"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe"
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurator

::-----------------------------------------------------------------------------
:: Sub-Section: Solicitar certificado digital (:solicitude)
:: Opens Chrome to the FNMT certificate request page.
::-----------------------------------------------------------------------------
:solicitude
call :log "Starting sub-section solicitude"
call :log "Performing action: Opening Chrome to FNMT certificate request page"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
goto Cert :: Return to Cert menu.
:: End of Sub-Section: solicitude

::-----------------------------------------------------------------------------
:: Sub-Section: Renovar certificado digital (:renew)
:: Opens Chrome to the FNMT certificate renewal page.
::-----------------------------------------------------------------------------
:renew
call :log "Starting sub-section renew"
call :log "Performing action: Opening Chrome to FNMT certificate renewal page"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
goto Cert :: Return to Cert menu.
:: End of Sub-Section: renew

::-----------------------------------------------------------------------------
:: Sub-Section: Descargar certificado digital (:download)
:: Opens Chrome to the FNMT certificate download page.
::-----------------------------------------------------------------------------
:download
call :log "Starting sub-section download"
call :log "Performing action: Opening Chrome to FNMT certificate download page"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
goto Cert :: Return to Cert menu.
:: End of Sub-Section: download

::=============================================================================
:: Section: Utilidades (:Bmenu)
:: Provides a sub-menu for various utility tasks such as opening Internet Options,
:: installing software (Chrome, Autofirma, LibreOffice), fixing display issues,
:: viewing Windows version, reinstalling card reader drivers, and forcing time sync.
::=============================================================================
:Bmenu
call :log "Starting section Bmenu (Utilities Menu)"
cls
:: The :Bmenu label is duplicated here, but it's harmless as it just re-clears the screen.
:Bmenu 
cls
ECHO ------------------------------------------
ECHO                  CAU    
ECHO               Utilidades            
ECHO ------------------------------------------
ECHO 1. Ver opciones de internet                     :: Opens Internet Options control panel.
ECHO 2. Instalar Chrome 109                        :: Installs Chrome version 109.
ECHO 3. Arreglar pantalla oscura (no aparece fondo de pantalla) :: Attempts to fix black screen issue by cycling display modes.
ECHO 4. Ver version de Windows                     :: Shows Windows version information.
ECHO 5. Reinstalar drivers tarjeta                 :: Reinstalls card reader drivers.
ECHO 6. Instalar Autofirmas                        :: Installs Autofirma software.
ECHO 7. Instalar Libreoffice                       :: Installs LibreOffice.
ECHO 8. Forzar fecha y hora                        :: Forces time synchronization.
ECHO 9. Inicio                                     :: Returns to the main menu.
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' call :log "Bmenu: User selected option 1" & goto ieopcion
if '%choice%'=='2' call :log "Bmenu: User selected option 2" & goto chrome
if '%choice%'=='3' call :log "Bmenu: User selected option 3" & goto black_screen
if '%choice%'=='4' call :log "Bmenu: User selected option 4" & goto winver
if '%choice%'=='5' call :log "Bmenu: User selected option 5" & goto tarjetadrv
if '%choice%'=='6' call :log "Bmenu: User selected option 6" & goto autof
if '%choice%'=='7' call :log "Bmenu: User selected option 7" & goto libreoff
if '%choice%'=='8' call :log "Bmenu: User selected option 8" & goto horafec
if '%choice%'=='9' call :log "Bmenu: User selected option 9 (Return to Main Menu)" & goto main
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Bmenu :: Return to Bmenu if choice is invalid.
:: End of Section: Bmenu (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Arreglar pantalla oscura (:black_screen)
:: Cycles through display modes (internal, extend) to potentially fix a black screen issue.
::-----------------------------------------------------------------------------
:black_screen
call :log "Starting sub-section black_screen"
call :log "Performing action: DisplaySwitch.exe /internal"
DisplaySwitch.exe /internal
call :log "Performing action: timeout /t 3"
timeout /t 3
call :log "Performing action: DisplaySwitch.exe /extend"
DisplaySwitch.exe /extend
goto main :: Returns to the main menu.
:: End of Sub-Section: black_screen

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Autofirmas (:autof)
:: Kills Chrome, then installs two versions of Autofirma silently.
::-----------------------------------------------------------------------------
:autof
call :log "Starting sub-section autof (Install Autofirma)"
call :log "Performing action: taskkill chrome.exe"
taskkill /IM chrome.exe /F > nul 2>&1
call :log "Performing action: Install Autofirma v1.8.3"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S"
call :log "Performing action: Install Autofirma v1.6.0_JAv05"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn"
goto main :: Returns to the main menu.
:: End of Sub-Section: autof

::-----------------------------------------------------------------------------
:: Sub-Section: Ver opciones de internet (:ieopcion)
:: Opens the Internet Options control panel applet.
::-----------------------------------------------------------------------------
:ieopcion
call :log "Starting sub-section ieopcion (Internet Options)"
call :log "Performing action: Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl"
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
goto main :: Returns to the main menu.
:: End of Sub-Section: ieopcion

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Chrome 109 (:chrome)
:: Installs Google Chrome version 109 silently.
::-----------------------------------------------------------------------------
:chrome
call :log "Starting sub-section chrome (Install Chrome 109)"
call :log "Performing action: msiexec /i chrome.msi"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn"
goto main :: Returns to the main menu.
:: End of Sub-Section: chrome

::-----------------------------------------------------------------------------
:: Sub-Section: Ver version de Windows (:winver)
:: Shows the Windows "About" dialog with version information.
::-----------------------------------------------------------------------------
:winver
call :log "Starting sub-section winver (Windows Version)"
call :log "Performing action: RunDll32.exe SHELL32.DLL,ShellAboutW"
RunDll32.exe SHELL32.DLL,ShellAboutW
goto main :: Returns to the main menu.
:: End of Sub-Section: winver

::-----------------------------------------------------------------------------
:: Sub-Section: Reinstalar drivers tarjeta (:tarjetadrv)
:: Installs two different card reader drivers.
::-----------------------------------------------------------------------------
:tarjetadrv
call :log "Starting sub-section tarjetadrv (Card Reader Drivers)"
call :log "Performing action: Install SCR3xxx_V8.52.exe"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"  
call :log "Performing action: Install TCJ0023500B.exe"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
goto main :: Returns to the main menu.
:: End of Sub-Section: tarjetadrv

::-----------------------------------------------------------------------------
:: Sub-Section: Forzar fecha y hora (:horafec)
:: Stops, unregisters, reregisters, starts, and resyncs the Windows Time service.
::-----------------------------------------------------------------------------
:horafec
call :log "Starting sub-section horafec (Force Time Sync)"
call :log "Performing action: net stop w32time"
runas /user:%AD%@JUSTICIA /savecred "net stop w32time"
call :log "Performing action: w32tm /unregister"
runas /user:%AD%@JUSTICIA /savecred "w32tm /unregister"
call :log "Performing action: w32tm /register"
runas /user:%AD%@JUSTICIA /savecred "w32tm /register"
call :log "Performing action: net start w32time"
runas /user:%AD%@JUSTICIA /savecred "net start w32time"
call :log "Performing action: w32tm /resync"
runas /user:%AD%@JUSTICIA /savecred "w32tm /resync"
goto main :: Returns to the main menu.
:: End of Sub-Section: horafec

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Libreoffice (:libreoff)
:: Installs LibreOffice silently.
::-----------------------------------------------------------------------------
:libreoff
call :log "Starting sub-section libreoff (Install LibreOffice)"
call :log "Performing action: msiexec /i LibreOffice.msi"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn"
goto main :: Returns to the main menu.
:: End of Sub-Section: libreoff

::=============================================================================
:: Section: Desinstalador Tarjetas (:desinstalador_tarjetas and :remove_drivers)
:: This section seems intended to uninstall unknown or generic card reader drivers.
:: It iterates through published drivers and removes those matching "desconocido" or "lector".
:: Deletes the script after execution.
::=============================================================================
:desinstalador_tarjetas
@echo off
:: This label is the entry point for the driver removal logic.
:remove_drivers
call :log "Starting section remove_drivers (Uninstall Card Reader Drivers)"
FOR /F "tokens=3,*" %%a in ('pnputil /enum-drivers ^| find "Nombre publicado"') DO (
    rem %%b contiene el identificador del controlador (p.ej. oemXX.inf)
    echo %%b | findstr /I /C:"desconocido" /C:"lector" >nul
    if not errorlevel 1 (
         echo Eliminando el controlador %%b...
         call :log "Performing action: pnputil /delete-driver %%b /uninstall /force"
         pnputil /delete-driver %%b /uninstall /force
         CLS
    )
)
call :log "Performing action: del %~f0% & exit (self-deleting script after driver removal)"
del "%~f0%" & exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Desinstalador Tarjetas
goto main :: This goto main is unreachable due to the 'del %~f0% & exit' above.