:: Script: CAUJUS_dev.bat
:: Purpose: Provides a menu-driven utility for various CAU IT support tasks.
:: Version: 2504 - Refactored for Clean Code
:: Last Modified: %DATE%

@ECHO OFF

:: --- Configuration Variables ---
SET "config_RemoteLogDir=\\iusnas05\SIJ\CAU-2012\logs"
SET "config_SoftwareBasePath=\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
SET "config_DriverBasePath=\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"

SET "config_IslMsiPath=%config_SoftwareBasePath%\isl.msi"
SET "config_FnmtConfigExe=%config_SoftwareBasePath%\Configurador_FNMT_5.0.0_64bits.exe"
SET "config_AutoFirmaExe=%config_SoftwareBasePath%\AutoFirma_64_v1_8_3_installer.exe"
SET "config_AutoFirmaMsi=%config_SoftwareBasePath%\AutoFirma_v1_6_0_JAv05_installer_64.msi"
SET "config_ChromeMsiPath=%config_SoftwareBasePath%\chrome.msi"
SET "config_LibreOfficeMsiPath=%config_SoftwareBasePath%\LibreOffice.msi"

SET "config_DriverPctPath=%config_DriverBasePath%\PCT-331_V8.52\SCR3xxx_V8.52.exe"
SET "config_DriverSatellitePath=%config_DriverBasePath%\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"

SET "config_UrlMiCuentaJunta=https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
SET "config_UrlFnmtSolicitar=https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
SET "config_UrlFnmtRenovar=https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
SET "config_UrlFnmtDescargar=https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"

SET "config_ScriptVersion=2504-refactored"
:: --- End Configuration Variables ---

:: Bloqueo para máquina de salto
FOR /F "tokens=*" %%A IN ('hostname') DO SET "hostname=%%A"
IF "%hostname%"=="IUSSWRDPCAU02" (
    CLS
    ECHO Error, se está ejecutando el script desde la máquina de salto.
    PAUSE
    EXIT
) ELSE (
    GOTO check_initial_setup
)

::=============================================================================
:: Initial Setup & Main Logic
::=============================================================================

:check_initial_setup
    CLS
    @ECHO OFF

    SET adUser=
    IF NOT DEFINED adUser (
        SET /P "adUser=introduce tu AD:"
    )
    FOR /F "tokens=2 delims=\" %%i IN ('whoami') DO SET userProfileName=%%i
    runas /user:%adUser%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
    SET "LOG_DIR=%TEMP%\CAUJUS_Logs"
    FOR /F "usebackq" %%j IN ('hostname') DO SET currentHostname=%%j
    SET "YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
    SET "HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
    SET "HHMMSS=%HHMMSS: =0%"
    SET "LOG_FILE=%LOG_DIR%\%adUser%_%currentHostname%_%YYYYMMDD%_%HHMMSS%.log"

    REM Create Log Directory if it doesn't exist
    IF NOT EXIST "%LOG_DIR%" (
        MKDIR "%LOG_DIR%"
        CALL :LogMessage "INFO - Log directory created: %LOG_DIR%"
    ) ELSE (
        CALL :LogMessage "INFO - Log directory already exists: %LOG_DIR%"
    )
    CALL :LogMessage "INFO - Script CAUJUS.bat started. User: %adUser%, Profile: %userProfileName%, Machine: %currentHostname%. Logging to: %LOG_FILE%"
    CLS
    GOTO main_menu

::=============================================================================
:: Main Menu and System Information Display
::=============================================================================
:main_menu
    CLS
    :: Gather system information
    FOR /F "usebackq" %%i IN ('hostname') DO SET computerName=%%i
    FOR /F "Tokens=1* Delims==" %%g IN ('WMIC BIOS GET SerialNumber /Value') DO FOR /F "Tokens=*" %%i IN ("%%h") DO SET serialNumber=%%i
    FOR /F "delims=[] tokens=2" %%a IN ('PING -4 -n 1 %ComputerName% ^| FINDSTR [') DO SET networkIP=%%a
    FOR /F "Tokens=1* Delims==" %%g IN ('WMIC OS GET Caption /Value') DO FOR /F "Tokens=*" %%i IN ("%%h") DO SET osCaption=%%i
    FOR /F "SKIP=2 tokens=2,*" %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') DO (SET osBuildNumber=%%B)

    CALL :LogMessage "INFO - System Info: User: %userProfileName%, AD User: %adUser%, Computer: %computerName%, SN: %serialNumber%, IP: %networkIP%, OS: %osCaption% (%osBuildNumber%), Script Version: %config_ScriptVersion%"

    :: Display system information and menu
    ECHO ------------------------------------------
    ECHO                  CAU
    ECHO ------------------------------------------
    ECHO.
    ECHO Usuario: %userProfileName%
    ECHO Usuario AD utilizado: %adUser%
    ECHO Nombre equipo: %computerName%
    ECHO Numero de serie: %serialNumber%
    ECHO Numero de IP: %networkIP%
    ECHO Version: %osCaption%, con la compilacion %osBuildNumber%
    ECHO Version Script: %config_ScriptVersion%
    ECHO.
    ECHO 1. Bateria pruebas
    ECHO 2. Cambiar password correo
    ECHO 3. Reiniciar cola impresion
    ECHO 4. Administrador de dispositivos (desinstalar drivers)
    ECHO 5. Certificado digital
    ECHO 6. ISL Allways on
    ECHO 7. Utilidades

    SET choice=
    SET /P "choice=Escoge una opcion: "
    IF NOT "%choice%"=="" SET choice=%choice:~0,1%

    CALL :LogMessage "INFO - Main menu: User selected option %choice%. Referring to %choice% value."

    IF "%choice%"=="1" GOTO Batery_test
    IF "%choice%"=="2" GOTO mail_pass
    IF "%choice%"=="3" GOTO print_pool
    IF "%choice%"=="4" GOTO Driver_admin
    IF "%choice%"=="5" GOTO Cert_Menu
    IF "%choice%"=="6" GOTO isl_always_on
    IF "%choice%"=="7" GOTO Utilities_Menu

    ECHO "%choice%" opcion no valida, intentalo de nuevo
    ECHO.
    GOTO main_menu

::=============================================================================
:: Main Action Blocks
::=============================================================================

:Batery_test
    CALL :LogMessage "INFO - Action: Starting Batery_test."
    CALL :BT_KillBrowsers
    CALL :BT_ClearSystemCaches
    CALL :BT_ApplyVisualEffectRegTweaks
    CALL :BT_SystemMaintenanceTasks
    CALL :LogMessage "INFO - Action: Prompting for restart in Batery_test."
    ECHO Reiniciar equipo (s/n)
    CHOICE /C sn /N
    SET "CHOICE_RESULT=%ERRORLEVEL%"
    CALL :LogMessage "INFO - Script self-deleting and exiting. Triggered in section near/after label: Batery_test_RestartChoice."
    CALL :UploadLogFile
    IF %CHOICE_RESULT%==2 (
        DEL "%~f0"
        EXIT
    ) ELSE IF %CHOICE_RESULT%==1 (
        SHUTDOWN /r /t 0
    )
    GOTO :EOF

:mail_pass
    CALL :LogMessage "INFO - Action: Starting mail_pass. Opening URL."
    START chrome "%config_UrlMiCuentaJunta%"
    CALL :LogMessage "INFO - Script self-deleting and exiting. Triggered in section near/after label: mail_pass_Exit."
    CALL :UploadLogFile
    DEL "%~f0"
    EXIT

:print_pool
    CALL :LogMessage "INFO - Action: Starting print_pool. Resetting printer queues."
    CALL :ExecuteWithRunas "cmd /c FOR /F \"tokens=3,*\" %%a IN ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| FINDSTR \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\""
    CALL :LogMessage "INFO - Script self-deleting and exiting. Triggered in section near/after label: print_pool_Exit."
    CALL :UploadLogFile
    DEL "%~f0"
    EXIT

:Driver_admin
    CALL :LogMessage "INFO - Action: Starting Driver_admin. Opening Device Manager."
    CALL :ExecuteWithRunas "RunDll32.exe devmgr.dll DeviceManager_Execute"
    GOTO main_menu

:isl_always_on
    CALL :LogMessage "INFO - Action: Starting isl_always_on. Installing ISL Always On."
    CALL :ExecuteWithRunas "cmd /c MSIEXEC /i \"%config_IslMsiPath%\" /qn"
    GOTO main_menu

::-----------------------------------------------------------------------------
:: Certificate Management Menu
::-----------------------------------------------------------------------------
:Cert_Menu
    CLS
    ECHO ------------------------------------------
    ECHO                  CAU
    ECHO     Gestiones del certificado digital
    ECHO ------------------------------------------
    ECHO 1. Configuracion previa (Silenciosa)
    ECHO 2. Configuracion previa (Manual)
    ECHO 3. Solicitar certificado digital
    ECHO 4. Renovar certificado digital
    ECHO 5. Descargar certificado digital
    ECHO 6. Inicio

    SET choice=
    SET /P "choice=Escoge una opcion: "
    IF NOT "%choice%"=="" SET choice=%choice:~0,1%

    CALL :LogMessage "INFO - Cert_Menu: User selected option %choice%. Referring to %choice% value."

    IF "%choice%"=="1" GOTO Cert_Config_Silent
    IF "%choice%"=="2" GOTO Cert_Config_Manual
    IF "%choice%"=="3" GOTO Cert_Request
    IF "%choice%"=="4" GOTO Cert_Renew
    IF "%choice%"=="5" GOTO Cert_Download
    IF "%choice%"=="6" GOTO main_menu

    ECHO "%choice%" no es valido, intentalo de nuevo
    ECHO.
    GOTO Cert_Menu

:Cert_Config_Silent
    CALL :LogMessage "INFO - Action: Starting Cert_Config_Silent. Silent FNMT configuration."
    CD /D %userprofile%\downloads
    CALL :ExecuteWithRunas "\"%config_FnmtConfigExe%\" /S"
    GOTO Cert_Menu

:Cert_Config_Manual
    CALL :LogMessage "INFO - Action: Starting Cert_Config_Manual. Manual FNMT configuration."
    CD /D %userprofile%\downloads
    CALL :ExecuteWithRunas "\"%config_FnmtConfigExe%\""
    GOTO Cert_Menu

:Cert_Request
    CALL :LogMessage "INFO - Action: Starting Cert_Request. Opening certificate request URL."
    START chrome "%config_UrlFnmtSolicitar%"
    GOTO Cert_Menu

:Cert_Renew
    CALL :LogMessage "INFO - Action: Starting Cert_Renew. Opening certificate renewal URL."
    START chrome "%config_UrlFnmtRenovar%"
    GOTO Cert_Menu

:Cert_Download
    CALL :LogMessage "INFO - Action: Starting Cert_Download. Opening certificate download URL."
    START chrome "%config_UrlFnmtDescargar%"
    GOTO Cert_Menu

::-----------------------------------------------------------------------------
:: Utilities Menu
::-----------------------------------------------------------------------------
:Utilities_Menu
    CLS
    ECHO ------------------------------------------
    ECHO                  CAU
    ECHO               Utilidades
    ECHO ------------------------------------------
    ECHO 1. Ver opciones de internet
    ECHO 2. Instalar Chrome 109
    ECHO 3. Arreglar pantalla oscura (no aparece fondo de pantalla)
    ECHO 4. Ver version de Windows
    ECHO 5. Reinstalar drivers tarjeta
    ECHO 6. Instalar Autofirmas
    ECHO 7. Instalar Libreoffice
    ECHO 8. Forzar fecha y hora
    ECHO 9. Inicio

    SET choice=
    SET /P "choice=Escoge una opcion: "
    IF NOT "%choice%"=="" SET choice=%choice:~0,1%

    CALL :LogMessage "INFO - Utilities_Menu: User selected option %choice%. Referring to %choice% value."

    IF "%choice%"=="1" GOTO Util_InternetOptions
    IF "%choice%"=="2" GOTO Util_InstallChrome
    IF "%choice%"=="3" GOTO Util_FixBlackScreen
    IF "%choice%"=="4" GOTO Util_ShowWinVer
    IF "%choice%"=="5" GOTO Util_ReinstallCardReaderDrivers
    IF "%choice%"=="6" GOTO Util_InstallAutofirma
    IF "%choice%"=="7" GOTO Util_InstallLibreOffice
    IF "%choice%"=="8" GOTO Util_ForceDateTimeSync
    IF "%choice%"=="9" GOTO main_menu

    ECHO "%choice%" no es valido, intentalo de nuevo
    ECHO.
    GOTO Utilities_Menu

:Util_FixBlackScreen
    CALL :LogMessage "INFO - Action: Starting Util_FixBlackScreen. Fixing black screen issue."
    DisplaySwitch.exe /internal
    TIMEOUT /T 3 /NOBREAK
    DisplaySwitch.exe /extend
    GOTO main_menu

:Util_InstallAutofirma
    CALL :LogMessage "INFO - Action: Starting Util_InstallAutofirma. Installing AutoFirma."
    TASKKILL /IM chrome.exe /F > nul 2>&1
    CALL :ExecuteWithRunas "\"%config_AutoFirmaExe%\" /S"
    CALL :ExecuteWithRunas "cmd /c MSIEXEC /i \"%config_AutoFirmaMsi%\" /qn"
    GOTO main_menu

:Util_InternetOptions
    CALL :LogMessage "INFO - Action: Starting Util_InternetOptions. Opening Internet Options."
    Rundll32 Shell32.dll,Control_RunDLL Inetcpl.cpl
    GOTO main_menu

:Util_InstallChrome
    CALL :LogMessage "INFO - Action: Starting Util_InstallChrome. Installing Chrome 109."
    CALL :ExecuteWithRunas "cmd /c MSIEXEC /i \"%config_ChromeMsiPath%\" /qn"
    GOTO main_menu

:Util_ShowWinVer
    CALL :LogMessage "INFO - Action: Starting Util_ShowWinVer. Displaying Windows version."
    RunDll32.exe SHELL32.DLL,ShellAboutW
    GOTO main_menu

:Util_ReinstallCardReaderDrivers
    CALL :LogMessage "INFO - Action: Starting Util_ReinstallCardReaderDrivers. Reinstalling card reader drivers."
    CALL :ExecuteWithRunas "\"%config_DriverPctPath%\""
    CALL :ExecuteWithRunas "\"%config_DriverSatellitePath%\""
    GOTO main_menu

:Util_ForceDateTimeSync
    CALL :LogMessage "INFO - Action: Starting Util_ForceDateTimeSync. Forcing date and time sync."
    CALL :ExecuteWithRunas "NET STOP w32time"
    CALL :ExecuteWithRunas "W32TM /unregister"
    CALL :ExecuteWithRunas "W32TM /register"
    CALL :ExecuteWithRunas "NET START w32time"
    CALL :ExecuteWithRunas "W32TM /resync"
    GOTO main_menu

:Util_InstallLibreOffice
    CALL :LogMessage "INFO - Action: Starting Util_InstallLibreOffice. Installing LibreOffice."
    CALL :ExecuteWithRunas "cmd /c MSIEXEC /i \"%config_LibreOfficeMsiPath%\" /qn"
    GOTO main_menu

:desinstalador_tarjetas
    CALL :LogMessage "INFO - Action: Starting desinstalador_tarjetas. Uninstalling unknown/reader drivers."
    @ECHO OFF
    :: This loop iterates through installed drivers and uninstalls those matching specific keywords.
    :remove_drivers_loop
    FOR /F "tokens=3,*" %%a IN ('PNPUTIL /enum-drivers ^| FINDSTR "Nombre publicado"') DO (
        REM %%b contiene el identificador del controlador (p.ej. oemXX.inf)
        ECHO %%b | FINDSTR /I /C:"desconocido" /C:"lector" >nul
        IF NOT ERRORLEVEL 1 (
             ECHO Eliminando el controlador %%b...
             PNPUTIL /delete-driver %%b /uninstall /force
             CLS
        )
    )
    CALL :LogMessage "INFO - Script self-deleting and exiting. Triggered in section near/after label: remove_drivers_loop_Exit."
    CALL :UploadLogFile
    DEL "%~f0"
    EXIT

::=============================================================================
:: Subroutines
::=============================================================================

::-----------------------------------------------------------------------------
:: Subroutine: LogMessage
:: Purpose: Writes a timestamped message to the global log file (%LOG_FILE%).
:: Usage: CALL :LogMessage "INFO - Your message here"
:: Arguments: %1 - The message string to log.
::-----------------------------------------------------------------------------
:LogMessage
    SETLOCAL
    SET "logMessage=%~1"
    SET "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
    SET "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
    SET "L_HHMMSS=%L_HHMMSS: =0%"
    ECHO %L_YYYYMMDD% %L_HHMMSS% - %logMessage% >> "%LOG_FILE%"
    ENDLOCAL
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine: UploadLogFile
:: Purpose: Uploads the current log file to a central network share.
:: Usage: CALL :UploadLogFile
:: Arguments: None. Relies on global variables for paths and names.
::-----------------------------------------------------------------------------
:UploadLogFile
    SETLOCAL
    CALL :LogMessage "INFO - Preparing to upload log file %LOG_FILE% to network."
    SET "FINAL_LOG_DIR=%config_RemoteLogDir%"
    SET "FINAL_LOG_FILENAME=%adUser%_%currentHostname%_%YYYYMMDD%_%HHMMSS%.log"
    SET "FINAL_LOG_PATH=%FINAL_LOG_DIR%\%FINAL_LOG_FILENAME%"
    REM Ensure FINAL_LOG_DIR exists on the network using RUNAS
    CALL :ExecuteWithRunas "cmd /c IF NOT EXIST "%FINAL_LOG_DIR%" MKDIR "%FINAL_LOG_DIR%""
    CALL :ExecuteWithRunas "cmd /c COPY /Y "%LOG_FILE%" "%FINAL_LOG_PATH%""
    CALL :LogMessage "INFO - Log upload attempt finished."
    ENDLOCAL
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine: ExecuteWithRunas
:: Purpose: Executes a given command string with elevated privileges using RUNAS.
::          Logs the attempt and redirects RUNAS output to the main log file.
:: Usage: CALL :ExecuteWithRunas "command_to_execute_with_args"
:: Arguments: %1 - The command string to execute.
::-----------------------------------------------------------------------------
:ExecuteWithRunas
    SETLOCAL
    SET "commandToRun=%~1"
    CALL :LogMessage "RUNAS - Attempting to execute: %commandToRun%"
    runas /user:%adUser%@JUSTICIA /savecred "%commandToRun%" >> "%LOG_FILE%" 2>&1
    ENDLOCAL
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine Group: Batery_test Helpers
:: Purpose: These subroutines modularize actions within the Batery_test.
::-----------------------------------------------------------------------------

::-----------------------------------------------------------------------------
:: Subroutine: BT_KillBrowsers
:: Purpose: Terminates common web browser processes.
:: Usage: CALL :BT_KillBrowsers
::-----------------------------------------------------------------------------
:BT_KillBrowsers
    TASKKILL /IM chrome.exe /F > nul 2>&1
    TASKKILL /IM iexplore.exe /F > nul 2>&1
    TASKKILL /IM msedge.exe /F > nul 2>&1
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine: BT_ClearSystemCaches
:: Purpose: Clears various system and browser caches.
:: Usage: CALL :BT_ClearSystemCaches
::-----------------------------------------------------------------------------
:BT_ClearSystemCaches
    IPCONFIG /flushdns
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
    DEL /Q /S /F "E:\Users\%userProfileName%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine: BT_ApplyVisualEffectRegTweaks
:: Purpose: Applies registry tweaks to disable various visual effects for performance.
:: Usage: CALL :BT_ApplyVisualEffectRegTweaks
::-----------------------------------------------------------------------------
:BT_ApplyVisualEffectRegTweaks
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 2 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithRunas "cmd.exe /c REG ADD \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f"
    GOTO :EOF

::-----------------------------------------------------------------------------
:: Subroutine: BT_SystemMaintenanceTasks
:: Purpose: Performs various system cleanup and maintenance tasks.
:: Usage: CALL :BT_SystemMaintenanceTasks
::-----------------------------------------------------------------------------
:BT_SystemMaintenanceTasks
    CALL :LogMessage "INFO - Action: Running gpupdate /force in Batery_test."
    GPUPDATE /force
    CALL :ExecuteWithRunas "cmd /c MSIEXEC /i \"%config_IslMsiPath%\" /qn"
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%windir%\*.bak\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%windir%\SoftwareDistribution\Download\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%systemdrive%\*.tmp\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%systemdrive%\*._mp\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%systemdrive%\*.gid\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%systemdrive%\*.chk\""
    CALL :ExecuteWithRunas "cmd.exe /c DEL /F /S /Q \"%systemdrive%\*.old\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Microsoft\Windows\cookies\" DEL /F /S /Q \"%appdata%\Microsoft\Windows\cookies\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" DEL /F /S /Q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Local\Microsoft\Windows\INetCache\" DEL /F /S /Q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Local\Microsoft\Windows\INetCookies\" DEL /F /S /Q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" DEL /F /S /Q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%appdata%\Local\CrashDumps\" DEL /F /S /Q \"%appdata%\Local\CrashDumps\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%userprofile%\Local Settings\Temporary Internet Files\" DEL /F /S /Q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%userprofile%\Local Settings\Temp\" DEL /F /S /Q \"%userprofile%\Local Settings\Temp\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%userprofile%\AppData\Local\Temp\" DEL /F /S /Q \"%userprofile%\AppData\Local\Temp\*.*\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%userprofile%\Local Settings\Temp\" RMDIR /S /Q \"%userprofile%\Local Settings\Temp\" & MKDIR \"%userprofile%\Local Settings\Temp\""
    CALL :ExecuteWithRunas "cmd.exe /c IF EXIST \"%windir%\Temp\" RMDIR /S /Q \"%windir%\Temp\" & MKDIR \"%windir%\Temp\""
    GOTO :EOF
