@ECHO off
set "BOOTSTRAP_LOG_FILE=%~dp0caujus_bootstrap_temp.log"
echo [%date% %time%] CAUJUS_dev.bat bootstrap log started. > "%BOOTSTRAP_LOG_FILE%"
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
    call :log "Error: Script executed from jump host IUSSWRDPCAU02. Exiting."
    call :log_execution_time
    exit
) else (
    call :log "Jump host check passed. Machine is not IUSSWRDPCAU02. Proceeding with script."
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
    echo [%date% %time%] [BOOTSTRAP] AD variable not defined. Prompting user. >> "%BOOTSTRAP_LOG_FILE%"
    set /p "AD=introduce tu AD:"
    echo [%date% %time%] [BOOTSTRAP] User provided AD: %AD% >> "%BOOTSTRAP_LOG_FILE%"
) else (
    echo [%date% %time%] [BOOTSTRAP] AD variable already defined: %AD% >> "%BOOTSTRAP_LOG_FILE%"
)

:: Date/Month Logic
echo [%date% %time%] [BOOTSTRAP] Getting system date/time for MonthlyFolder... >> "%BOOTSTRAP_LOG_FILE%"
for /f "tokens=2 delims==" %%a in ('wmic os get LocalDateTime /value') do set datetime=%%a
if not defined datetime (
    echo [%date% %time%] [BOOTSTRAP] ERROR: Failed to get LocalDateTime from WMIC. >> "%BOOTSTRAP_LOG_FILE%"
    set datetime=00000000000000.000000+000 :: Fallback to prevent script crash
)
echo [%date% %time%] [BOOTSTRAP] LocalDateTime: %datetime% >> "%BOOTSTRAP_LOG_FILE%"
set "YY=%datetime:~2,2%"
set "MesNum=%datetime:~4,2%"

echo [%date% %time%] [BOOTSTRAP] Determining Spanish month name for MesNum: %MesNum% ... >> "%BOOTSTRAP_LOG_FILE%"
if "%MesNum%"=="01" set "MesNombre=ene"
if "%MesNum%"=="02" set "MesNombre=feb"
if "%MesNum%"=="03" set "MesNombre=mar"
if "%MesNum%"=="04" set "MesNombre=abr"
if "%MesNum%"=="05" set "MesNombre=may"
if "%MesNum%"=="06" set "MesNombre=jun"
if "%MesNum%"=="07" set "MesNombre=jul"
if "%MesNum%"=="08" set "MesNombre=ago"
if "%MesNum%"=="09" set "MesNombre=sep"
if "%MesNum%"=="10" set "MesNombre=oct"
if "%MesNum%"=="11" set "MesNombre=nov"
if "%MesNum%"=="12" set "MesNombre=dic"
if not defined MesNombre (
    echo [%date% %time%] [BOOTSTRAP] ERROR: MesNombre could not be determined. Defaulting to 'MES_DESCONOCIDO'. >> "%BOOTSTRAP_LOG_FILE%"
    set "MesNombre=MES_DESCONOCIDO"
)
set "MonthlyFolder=%MesNombre%_%YY%"
echo [%date% %time%] [BOOTSTRAP] MonthlyFolder determined as: %MonthlyFolder% >> "%BOOTSTRAP_LOG_FILE%"
echo [%date% %time%] [BOOTSTRAP] AD user for log path: %AD% >> "%BOOTSTRAP_LOG_FILE%"

:: >> START: Basic Network Directory Creation and Usage
set "ruta_log_base_network=\\iusnas05\SIJ\CAU-2012\logs"
echo [%date% %time%] [NET_LOG_SETUP] Base network log path set to: %ruta_log_base_network% >> "%BOOTSTRAP_LOG_FILE%"
set "TARGET_NETWORK_MONTHLY_DIR=%ruta_log_base_network%\%MonthlyFolder%"
echo [%date% %time%] [NET_LOG_SETUP] Target network monthly directory set to: %TARGET_NETWORK_MONTHLY_DIR% >> "%BOOTSTRAP_LOG_FILE%"

if not exist "%TARGET_NETWORK_MONTHLY_DIR%" (
    echo [%date% %time%] [NET_LOG_SETUP] Network monthly directory does not exist. Attempting to create: %TARGET_NETWORK_MONTHLY_DIR% >> "%BOOTSTRAP_LOG_FILE%"
    mkdir "%TARGET_NETWORK_MONTHLY_DIR%"
    if errorlevel 1 (
        echo [%date% %time%] [NET_LOG_SETUP] FAILED to create network monthly directory %TARGET_NETWORK_MONTHLY_DIR%. Errorlevel: %errorlevel%. Logging may fail. >> "%BOOTSTRAP_LOG_FILE%"
        set NETWORK_DIR_READY=false
    ) else (
        echo [%date% %time%] [NET_LOG_SETUP] Successfully created network monthly directory %TARGET_NETWORK_MONTHLY_DIR%. >> "%BOOTSTRAP_LOG_FILE%"
        set NETWORK_DIR_READY=true
    )
) else (
    echo [%date% %time%] [NET_LOG_SETUP] Network monthly directory %TARGET_NETWORK_MONTHLY_DIR% already exists. >> "%BOOTSTRAP_LOG_FILE%"
    set NETWORK_DIR_READY=true
)

set "LOGFILE=%TARGET_NETWORK_MONTHLY_DIR%\%AD%_%COMPUTERNAME%.log"
set "CURRENT_LOG_DIR=%TARGET_NETWORK_MONTHLY_DIR%"
set "USE_FALLBACK_LOG=false" 
set "FALLBACK_TYPE=NONE"
set "LOG_PATH_INITIALIZED=true"
echo [%date% %time%] [NET_LOG_SETUP] Initial LOGFILE attempt: %LOGFILE% >> "%BOOTSTRAP_LOG_FILE%"

if /I "%NETWORK_DIR_READY%" NEQ "true" (
    echo [%date% %time%] [FALLBACK_SETUP] Network path failed (NETWORK_DIR_READY is '%NETWORK_DIR_READY%'). Initializing fallback to script root. >> "%BOOTSTRAP_LOG_FILE%"
    set "LOGFILE=%~dp0%AD%_%COMPUTERNAME%.log"
    set "CURRENT_LOG_DIR=%~dp0"
    set "USE_FALLBACK_LOG=true"
    set "FALLBACK_TYPE=ROOT"
    echo [%date% %time%] [FALLBACK_SETUP] LOGFILE is now %LOGFILE%. Fallback active (ROOT). >> "%BOOTSTRAP_LOG_FILE%"
) else (
    echo [%date% %time%] [NET_LOG_SETUP] Network path OK. LOGFILE is %LOGFILE%. Fallback not active. >> "%BOOTSTRAP_LOG_FILE%"
)
:: << END: Basic Network Directory Creation and Usage / Basic Root Directory Fallback

for /f "tokens=2 delims=\" %%i in ('whoami') do set Perfil=%%i
call :log "User profile determined: %Perfil%" 
set START_TIME=%TIME%
call :log "Script start time captured: %START_TIME%"
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
REM if not defined LOG_PATH_INITIALIZED call :setup_logfile_path <- This will be part of future fallback logic
setlocal enabledelayedexpansion
:: LOGFILE should be globally set by the main script body in :check
if not defined LOGFILE (
    echo %DATE% %TIME% - [CRITICAL_ERROR] LOGFILE variable not defined in :log. Attempting emergency log. >> "%~dp0caujus_critical_error.log"
    echo %DATE% %TIME% - [%~0] %~1 >> "%~dp0caujus_critical_error.log"
    goto :eof
)

set "TIMESTAMP=%date% %time%"
:: Directory creation for the primary path is now handled in :check
echo [%TIMESTAMP%] %~1>> "%LOGFILE%"
endlocal
goto :eof
:: End of Section: Logging Function (Primary :log)

::=============================================================================
:: Sub-Section: Basic Logging Function (:basic_log)
:: This function is now simplified. Its main purpose was early logging.
:: :setup_logfile_path handles the core path logic and bootstrap logging.
:: This can be a fallback or for specific messages if needed, but :log should be preferred.
::=============================================================================
:basic_log
REM if not defined LOG_PATH_INITIALIZED call :setup_logfile_path <- This will be part of future fallback logic
setlocal enabledelayedexpansion

set "TEMP_AD_BASIC=%AD%"
set "TEMP_COMPUTERNAME_BASIC=%COMPUTERNAME%"

if not defined TEMP_AD_BASIC (set "TEMP_AD_BASIC=UNKNOWN_AD_BASIC"})
if not defined TEMP_COMPUTERNAME_BASIC (set "TEMP_COMPUTERNAME_BASIC=UNKNOWN_PC_BASIC"})

if not defined LOGFILE (
    REM Ultimate fallback for basic_log if LOGFILE is somehow not set
    set "BASIC_LOG_FILE_FINAL=%~dp0%TEMP_AD_BASIC%_%TEMP_COMPUTERNAME_BASIC%_basic_emergency.log"
    echo %DATE% %TIME% - [CRITICAL_ERROR] LOGFILE variable not defined in :basic_log. Using emergency: %BASIC_LOG_FILE_FINAL% >> "%BASIC_LOG_FILE_FINAL%"
) else (
    set "BASIC_LOG_FILE_FINAL=%LOGFILE%"
)

set "TIMESTAMP_BASIC=%date% %time%"
echo [%TIMESTAMP_BASIC%] [BASIC_LOG] %~1>> "%BASIC_LOG_FILE_FINAL%"
endlocal
goto :eof
:: End of Sub-Section: Basic Logging Function
:: End of Section: Logging Function

::=============================================================================
:: Subroutine: Setup Logfile Path
:: Determines and creates the log file path, with network and local fallback.
::=============================================================================
:setup_logfile_path
setlocal
set "BOOTSTRAP_LOG_FILE=%~dp0caujus_bootstrap_log.txt"
set "CURRENT_TIMESTAMP_BOOTSTRAP=%date% %time%"

echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Attempting to set up log path. AD: %AD%, COMPUTERNAME: %COMPUTERNAME%, MonthlyFolder: %MonthlyFolder% >> "%BOOTSTRAP_LOG_FILE%"

set "NETWORK_LOG_DIR_INTERNAL=%ruta_log_base_network%\%MonthlyFolder%"
set "FALLBACK_LOG_DIR_BASE_INTERNAL=%ruta_fallback_base%"
set "FALLBACK_LOG_DIR_MONTHLY_INTERNAL=%FALLBACK_LOG_DIR_BASE_INTERNAL%\%MonthlyFolder%"
set "USE_FALLBACK_LOG_INTERNAL=false"
set "FINAL_LOG_DIR_INTERNAL="
set "FINAL_LOGFILE_INTERNAL="

echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Trying network log path: %NETWORK_LOG_DIR_INTERNAL% >> "%BOOTSTRAP_LOG_FILE%"
if not exist "%NETWORK_LOG_DIR_INTERNAL%" (
    echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Network directory %NETWORK_LOG_DIR_INTERNAL% does not exist. Attempting to create. >> "%BOOTSTRAP_LOG_FILE%"
    mkdir "%NETWORK_LOG_DIR_INTERNAL%"
    if errorlevel 1 (
        echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] FAILED to create network directory %NETWORK_LOG_DIR_INTERNAL%. Errorlevel: %errorlevel%. Switching to fallback. >> "%BOOTSTRAP_LOG_FILE%"
        set USE_FALLBACK_LOG_INTERNAL=true
    ) else (
        echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Successfully created network directory %NETWORK_LOG_DIR_INTERNAL%. >> "%BOOTSTRAP_LOG_FILE%"
    )
) else (
    echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Network directory %NETWORK_LOG_DIR_INTERNAL% already exists. >> "%BOOTSTRAP_LOG_FILE%"
)

if "%USE_FALLBACK_LOG_INTERNAL%"=="true" (
    echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Using fallback log path. Fallback base: %FALLBACK_LOG_DIR_BASE_INTERNAL%, Fallback monthly dir: %FALLBACK_LOG_DIR_MONTHLY_INTERNAL% >> "%BOOTSTRAP_LOG_FILE%"
    if not exist "%FALLBACK_LOG_DIR_BASE_INTERNAL%" mkdir "%FALLBACK_LOG_DIR_BASE_INTERNAL%" >nul 2>&1
    if not exist "%FALLBACK_LOG_DIR_MONTHLY_INTERNAL%" (
        mkdir "%FALLBACK_LOG_DIR_MONTHLY_INTERNAL%"
        if errorlevel 1 (
             echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] FAILED to create fallback directory %FALLBACK_LOG_DIR_MONTHLY_INTERNAL%. Logging to script root. >> "%BOOTSTRAP_LOG_FILE%"
             set FINAL_LOG_DIR_INTERNAL=%~dp0
        ) else (
             echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Successfully created fallback directory %FALLBACK_LOG_DIR_MONTHLY_INTERNAL%. >> "%BOOTSTRAP_LOG_FILE%"
             set FINAL_LOG_DIR_INTERNAL=%FALLBACK_LOG_DIR_MONTHLY_INTERNAL%
        )
    ) else (
        echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Fallback monthly directory %FALLBACK_LOG_DIR_MONTHLY_INTERNAL% already exists. >> "%BOOTSTRAP_LOG_FILE%"
        set FINAL_LOG_DIR_INTERNAL=%FALLBACK_LOG_DIR_MONTHLY_INTERNAL%
    )
) else (
    set FINAL_LOG_DIR_INTERNAL=%NETWORK_LOG_DIR_INTERNAL%
)

REM Ensure AD and COMPUTERNAME are not empty for filename construction
set "TEMP_AD_SETUP=%AD%"
set "TEMP_COMPUTERNAME_SETUP=%COMPUTERNAME%"
if not defined TEMP_AD_SETUP (set "TEMP_AD_SETUP=UNKNOWN_AD_IN_SETUP"})
if not defined TEMP_COMPUTERNAME_SETUP (set "TEMP_COMPUTERNAME_SETUP=UNKNOWN_PC_IN_SETUP"})

set "FINAL_LOGFILE_INTERNAL=%FINAL_LOG_DIR_INTERNAL%\%TEMP_AD_SETUP%_%TEMP_COMPUTERNAME_SETUP%.log"
echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] Final log file determined: %FINAL_LOGFILE_INTERNAL% >> "%BOOTSTRAP_LOG_FILE%"
echo [%CURRENT_TIMESTAMP_BOOTSTRAP%] USE_FALLBACK_LOG_INTERNAL set to: %USE_FALLBACK_LOG_INTERNAL% >> "%BOOTSTRAP_LOG_FILE%"

endlocal & set "LOGFILE=%FINAL_LOGFILE_INTERNAL%" & set "USE_FALLBACK_LOG=%USE_FALLBACK_LOG_INTERNAL%" & set "CURRENT_LOG_DIR=%FINAL_LOG_DIR_INTERNAL%" & set "LOG_PATH_INITIALIZED=true"
goto :eof
:: End of Subroutine: Setup Logfile Path

::=============================================================================
:: Section: Execution Time Logging Subroutine
::=============================================================================
:log_execution_time
set END_TIME=%TIME%
call :log "Start time: %START_TIME%"
call :log "End time: %END_TIME%"

:: Parse START_TIME (HH:MM:SS.CS)
:: Using 1%%VALUE%% - 100 to avoid issues with numbers like 08, 09 being treated as octal
set /A START_H=1%START_TIME:~0,2% - 100
set /A START_M=1%START_TIME:~3,2% - 100
set /A START_S=1%START_TIME:~6,2% - 100
set /A START_CS=1%START_TIME:~9,2% - 100
set /A START_TOTAL_CS=(%START_H%*360000) + (%START_M%*6000) + (%START_S%*100) + %START_CS%
call :log "Parsed START_TIME: %START_H%h %START_M%m %START_S%s %START_CS%cs (Total CS: %START_TOTAL_CS%)"

:: Parse END_TIME (HH:MM:SS.CS)
set /A END_H=1%END_TIME:~0,2% - 100
set /A END_M=1%END_TIME:~3,2% - 100
set /A END_S=1%END_TIME:~6,2% - 100
set /A END_CS=1%END_TIME:~9,2% - 100
set /A END_TOTAL_CS=(%END_H%*360000) + (%END_M%*6000) + (%END_S%*100) + %END_CS%
call :log "Parsed END_TIME: %END_H%h %END_M%m %END_S%s %END_CS%cs (Total CS: %END_TOTAL_CS%)"

IF %END_TOTAL_CS% LSS %START_TOTAL_CS% (
    call :log "Midnight rollover detected for execution time calculation."
    set /A END_TOTAL_CS = %END_TOTAL_CS% + (24 * 360000)
    call :log "Adjusted END_TOTAL_CS for rollover: %END_TOTAL_CS%"
)

set /A DURATION_CS=%END_TOTAL_CS% - %START_TOTAL_CS%
set /A DURATION_S = %DURATION_CS% / 100
set /A DURATION_CS_REMAINDER = %DURATION_CS% %% 100

REM Formatting DURATION_CS_REMAINDER to always have two digits
set DURATION_CS_STR=0%DURATION_CS_REMAINDER%
set DURATION_CS_STR=%DURATION_CS_STR:~-2%

set /A DURATION_M_TOTAL = %DURATION_S% / 60
set /A DURATION_S_REMAINDER = %DURATION_S% %% 60
set /A DURATION_H_TOTAL = %DURATION_M_TOTAL% / 60
set /A DURATION_M_REMAINDER = %DURATION_M_TOTAL% %% 60

REM Formatting to HH:MM:SS.cs
set DURATION_H_STR=0%DURATION_H_TOTAL%
set DURATION_H_STR=%DURATION_H_STR:~-2%
set DURATION_M_STR=0%DURATION_M_REMAINDER%
set DURATION_M_STR=%DURATION_M_STR:~-2%
set DURATION_S_STR=0%DURATION_S_REMAINDER%
set DURATION_S_STR=%DURATION_S_STR:~-2%

set "DURATION_STR=%DURATION_H_STR%:%DURATION_M_STR%:%DURATION_S_STR%.%DURATION_CS_STR%"
call :log "Script execution time: %DURATION_STR%"
goto :eof
:: End of Section: Execution Time Logging Subroutine

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
if '%choice%'=='1' call :log "Main menu: User selected option 1 (Bateria pruebas), navigating to :Batery_test" & goto Batery_test
if '%choice%'=='2' call :log "Main menu: User selected option 2 (Cambiar password correo), navigating to :mail_pass" & goto mail_pass
if '%choice%'=='3' call :log "Main menu: User selected option 3 (Reiniciar cola impresion), navigating to :print_pool" & goto print_pool
if '%choice%'=='4' call :log "Main menu: User selected option 4 (Administrador de dispositivos), navigating to :Driver_admin" & goto Driver_admin
if '%choice%'=='5' call :log "Main menu: User selected option 5 (Certificado digital), navigating to :Cert" & goto Cert
if '%choice%'=='6' call :log "Main menu: User selected option 6 (ISL Allways on), navigating to :isl" & goto isl
if '%choice%'=='7' call :log "Main menu: User selected option 7 (Utilidades), navigating to :Bmenu" & goto Bmenu
call :log "Main menu: Invalid option '%choice%'"
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
call :log "Attempting to kill Chrome process: taskkill /IM chrome.exe /F"
taskkill /IM chrome.exe /F > nul 2>&1
call :log "Attempting to kill Internet Explorer process: taskkill /IM iexplore.exe /F"
taskkill /IM iexplore.exe /F > nul 2>&1
call :log "Attempting to kill MS Edge process: taskkill /IM msedge.exe /F"
taskkill /IM msedge.exe /F > nul 2>&1
:: Flush DNS cache
call :log "Attempting to flush DNS: ipconfig /flushdns"
ipconfig /flushdns
:: Clear Internet Explorer cache and history
call :log "Attempting to clear IE History: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
call :log "Attempting to clear IE Cache: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
call :log "Attempting to clear IE Cookies: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
call :log "Attempting to clear IE Temporary Internet Files: RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1"
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
:: Clear Chrome cache (Path might be user/system dependent)
call :log "Attempting to delete Chrome cache: del /q /s /f E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
del /q /s /f "E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
:: Adjust visual effects for performance
call :log "Attempting to adjust visual effects for performance via registry changes."
call :log "Setting MinAnimate to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f"
call :log "Setting TaskbarAnimations to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f"
call :log "Setting VisualFXSetting to 3 (Custom)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 3 /f"
call :log "Setting ComboBoxAnimation to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f"
call :log "Setting CursorShadow to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f"
call :log "Setting DropShadow to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f"
call :log "Setting ListBoxSmoothScrolling to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f"
call :log "Setting MenuAnimation to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f"
call :log "Setting SelectionFade to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f"
call :log "Setting TooltipAnimation to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f"
call :log "Setting Fade to 0"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f"
call :log "Enabling FontSmoothing (set to 2)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v FontSmoothing /t REG_SZ /d 2 /f"
call :log "Enabling FontSmoothingType (set to 2 for ClearType)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v FontSmoothingType /t REG_DWORD /d 2 /f"
call :log "Setting DragFullWindows to 0 (Disabled)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v DragFullWindows /t REG_SZ /d 0 /f"
call :log "Setting SmoothScroll to 0 (Disabled in Control Panel\Desktop, ListBoxSmoothScrolling handled separately)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v SmoothScroll /t REG_SZ /d 0 /f"
call :log "Setting Animations in WindowMetrics to 0 (Disabled)"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v Animations /t REG_SZ /d 0 /f"
:: Force group policy update
call :log "Attempting to force group policy update: gpupdate /force"
gpupdate /force
:: Reinstall ISL client
call :log "Attempting to reinstall ISL client: msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
:: Delete various temporary and backup files
call :log "Attempting to delete various system temporary and backup files."
call :log "Deleting *.bak files in %windir%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\*.bak\""
call :log "Deleting SoftwareDistribution\Download contents"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\""
call :log "Deleting *.tmp files in %systemdrive%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\""
call :log "Deleting *._mp files in %systemdrive%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\""
call :log "Deleting *.gid files in %systemdrive%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\""
call :log "Deleting *.chk files in %systemdrive%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\""
call :log "Deleting *.old files in %systemdrive%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.old\""
:: Delete user-specific temporary files and caches
call :log "Attempting to delete user-specific temporary files and caches."
call :log "Deleting user cookies: %appdata%\Microsoft\Windows\cookies\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\""
call :log "Deleting user Temporary Internet Files: %appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\""
call :log "Deleting user INetCache: %appdata%\Local\Microsoft\Windows\INetCache\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\""
call :log "Deleting user INetCookies: %appdata%\Local\Microsoft\Windows\INetCookies\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\""
call :log "Deleting Terminal Server Client Cache: %appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\""
call :log "Deleting CrashDumps: %appdata%\Local\CrashDumps\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\""
call :log "Deleting Local Settings\Temporary Internet Files: %userprofile%\Local Settings\Temporary Internet Files\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\""
call :log "Deleting Local Settings\Temp: %userprofile%\Local Settings\Temp\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\""
call :log "Deleting AppData\Local\Temp: %userprofile%\AppData\Local\Temp\*.*"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\""
:: Recreate user and system Temp folders
call :log "Attempting to recreate user and system Temp folders."
call :log "Recreating user Local Settings\Temp folder"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\""
call :log "Recreating system %windir%\Temp folder"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\""
:: Prompt for restart
call :log "Prompting for restart after Batery_test"
echo Reiniciar equipo (s/n)
choice /c sn /n
if errorlevel 2 call :log "User chose not to restart after Batery_test. Self-deleting script." & call :log_execution_time & del "%~f0%" & exit
if errorlevel 1 call :log "User chose to restart after Batery_test. Initiating shutdown." & call :log_execution_time & shutdown /r /t 0
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
call :log "Attempting to open Chrome to Junta de Andalucia account page: https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
call :log "Action complete: Chrome opened to account page. Preparing to self-delete script and exit."
call :log_execution_time
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
call :log "Attempting to restart print spooler for all printers using prnmngr.vbs and prnqctl.vbs"
runas /user:%AD%@JUSTICIA /savecred "cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\""
call :log "Action complete: Print spooler restart command issued. Preparing to self-delete script and exit."
call :log_execution_time
del "%~f0%" & exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Reiniciar cola impresion

::=============================================================================
:: Section: Administrador de dispositivos (:Driver_admin)
:: Opens the Device Manager console.
:: Returns to the main menu.
::=============================================================================
:Driver_admin
call :log "Starting section Driver_admin (Device Manager)"
call :log "Attempting to open Device Manager: RunDll32.exe devmgr.dll DeviceManager_Execute"
runas /user:%AD%@JUSTICIA /savecred "RunDll32.exe devmgr.dll DeviceManager_Execute"
call :log "Action complete: Device Manager opened. Returning to main menu."
goto main :: Returns to the main menu.
:: No goto :eof needed as it explicitly jumps to main.
:: End of Section: Administrador de dispositivos

::=============================================================================
:: Section: ISL Allways on (:isl)
:: Installs or reinstalls the ISL Always On VPN client silently.
:: Returns to the main menu.
::=============================================================================
:isl
call :log "Starting section isl (ISL Always On VPN)"
call :log "Attempting to install/reinstall ISL Always On VPN silently: msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
call :log "Action complete: ISL Always On VPN installation command issued. Returning to main menu."
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
if '%choice%'=='1' call :log "Cert menu: User selected option 1 (Configuracion previa (Silenciosa)), navigating to :configurators" & goto configurators
if '%choice%'=='2' call :log "Cert menu: User selected option 2 (Configuracion previa (Manual)), navigating to :configurator" & goto configurator
if '%choice%'=='3' call :log "Cert menu: User selected option 3 (Solicitar certificado digital), navigating to :solicitude" & goto solicitude
if '%choice%'=='4' call :log "Cert menu: User selected option 4 (Renovar certificado digital), navigating to :renew" & goto renew
if '%choice%'=='5' call :log "Cert menu: User selected option 5 (Descargar certificado digital), navigating to :download" & goto download
if '%choice%'=='6' call :log "Cert menu: User selected option 6 (Inicio - Return to Main Menu), navigating to :main" & goto main
call :log "Cert menu: Invalid option '%choice%'"
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Cert :: Return to Cert menu if choice is invalid.
:: End of Section: Cert (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Silenciosa) (:configurators)
:: Runs the FNMT configuration tool in silent mode.
::-----------------------------------------------------------------------------
:configurators
call :log "Starting sub-section configurators (Silent FNMT Configuration)"
call :log "Attempting to change directory to %userprofile%\downloads"
cd %userprofile%\downloads
call :log "Attempting to run Silent FNMT Configurator: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S"
call :log "Action complete: Silent FNMT Configurator command issued. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurators

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Manual) (:configurator)
:: Runs the FNMT configuration tool in manual (interactive) mode.
::-----------------------------------------------------------------------------
:configurator
call :log "Starting sub-section configurator (Manual FNMT Configuration)"
call :log "Attempting to change directory to %userprofile%\downloads"
cd %userprofile%\downloads
call :log "Attempting to run Manual FNMT Configurator: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe"
call :log "Action complete: Manual FNMT Configurator command issued. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurator

::-----------------------------------------------------------------------------
:: Sub-Section: Solicitar certificado digital (:solicitude)
:: Opens Chrome to the FNMT certificate request page.
::-----------------------------------------------------------------------------
:solicitude
call :log "Starting sub-section solicitude (Request Digital Certificate)"
call :log "Attempting to open Chrome to FNMT certificate request page: https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
call :log "Action complete: Chrome opened to FNMT request page. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: solicitude

::-----------------------------------------------------------------------------
:: Sub-Section: Renovar certificado digital (:renew)
:: Opens Chrome to the FNMT certificate renewal page.
::-----------------------------------------------------------------------------
:renew
call :log "Starting sub-section renew (Renew Digital Certificate)"
call :log "Attempting to open Chrome to FNMT certificate renewal page: https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
call :log "Action complete: Chrome opened to FNMT renewal page. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: renew

::-----------------------------------------------------------------------------
:: Sub-Section: Descargar certificado digital (:download)
:: Opens Chrome to the FNMT certificate download page.
::-----------------------------------------------------------------------------
:download
call :log "Starting sub-section download (Download Digital Certificate)"
call :log "Attempting to open Chrome to FNMT certificate download page: https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
call :log "Action complete: Chrome opened to FNMT download page. Returning to Cert menu."
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
if '%choice%'=='1' call :log "Bmenu: User selected option 1 (Ver opciones de internet), navigating to :ieopcion" & goto ieopcion
if '%choice%'=='2' call :log "Bmenu: User selected option 2 (Instalar Chrome 109), navigating to :chrome" & goto chrome
if '%choice%'=='3' call :log "Bmenu: User selected option 3 (Arreglar pantalla oscura), navigating to :black_screen" & goto black_screen
if '%choice%'=='4' call :log "Bmenu: User selected option 4 (Ver version de Windows), navigating to :winver" & goto winver
if '%choice%'=='5' call :log "Bmenu: User selected option 5 (Reinstalar drivers tarjeta), navigating to :tarjetadrv" & goto tarjetadrv
if '%choice%'=='6' call :log "Bmenu: User selected option 6 (Instalar Autofirmas), navigating to :autof" & goto autof
if '%choice%'=='7' call :log "Bmenu: User selected option 7 (Instalar Libreoffice), navigating to :libreoff" & goto libreoff
if '%choice%'=='8' call :log "Bmenu: User selected option 8 (Forzar fecha y hora), navigating to :horafec" & goto horafec
if '%choice%'=='9' call :log "Bmenu: User selected option 9 (Inicio - Return to Main Menu), navigating to :main" & goto main
call :log "Bmenu: Invalid option '%choice%'"
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Bmenu :: Return to Bmenu if choice is invalid.
:: End of Section: Bmenu (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Arreglar pantalla oscura (:black_screen)
:: Cycles through display modes (internal, extend) to potentially fix a black screen issue.
::-----------------------------------------------------------------------------
:black_screen
call :log "Starting sub-section black_screen (Fix Black Screen)"
call :log "Attempting to switch display to internal: DisplaySwitch.exe /internal"
DisplaySwitch.exe /internal
call :log "Pausing for 3 seconds: timeout /t 3"
timeout /t 3
call :log "Attempting to switch display to extend: DisplaySwitch.exe /extend"
DisplaySwitch.exe /extend
call :log "Action complete: Display mode cycled. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: black_screen

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Autofirmas (:autof)
:: Kills Chrome, then installs two versions of Autofirma silently.
::-----------------------------------------------------------------------------
:autof
call :log "Starting sub-section autof (Install Autofirma)"
call :log "Attempting to kill Chrome process: taskkill /IM chrome.exe /F"
taskkill /IM chrome.exe /F > nul 2>&1
call :log "Attempting to install Autofirma v1.8.3 silently: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S"
call :log "Attempting to install Autofirma v1.6.0_JAv05 silently: msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn"
call :log "Action complete: Autofirma installation commands issued. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: autof

::-----------------------------------------------------------------------------
:: Sub-Section: Ver opciones de internet (:ieopcion)
:: Opens the Internet Options control panel applet.
::-----------------------------------------------------------------------------
:ieopcion
call :log "Starting sub-section ieopcion (Internet Options)"
call :log "Attempting to open Internet Options control panel: Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl"
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
call :log "Action complete: Internet Options opened. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: ieopcion

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Chrome 109 (:chrome)
:: Installs Google Chrome version 109 silently.
::-----------------------------------------------------------------------------
:chrome
call :log "Starting sub-section chrome (Install Chrome 109)"
call :log "Attempting to install Chrome 109 silently: msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn"
call :log "Action complete: Chrome installation command issued. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: chrome

::-----------------------------------------------------------------------------
:: Sub-Section: Ver version de Windows (:winver)
:: Shows the Windows "About" dialog with version information.
::-----------------------------------------------------------------------------
:winver
call :log "Starting sub-section winver (Windows Version)"
call :log "Attempting to show Windows About dialog: RunDll32.exe SHELL32.DLL,ShellAboutW"
RunDll32.exe SHELL32.DLL,ShellAboutW
call :log "Action complete: Windows About dialog shown. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: winver

::-----------------------------------------------------------------------------
:: Sub-Section: Reinstalar drivers tarjeta (:tarjetadrv)
:: Installs two different card reader drivers.
::-----------------------------------------------------------------------------
:tarjetadrv
call :log "Starting sub-section tarjetadrv (Card Reader Drivers)"
call :log "Attempting to install card reader driver: \\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"  
call :log "Attempting to install card reader driver: \\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
call :log "Action complete: Card reader driver installation commands issued. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: tarjetadrv

::-----------------------------------------------------------------------------
:: Sub-Section: Forzar fecha y hora (:horafec)
:: Stops, unregisters, reregisters, starts, and resyncs the Windows Time service.
::-----------------------------------------------------------------------------
:horafec
call :log "Starting sub-section horafec (Force Time Sync)"
call :log "Attempting to stop Windows Time service: net stop w32time"
runas /user:%AD%@JUSTICIA /savecred "net stop w32time"
call :log "Attempting to unregister Windows Time service: w32tm /unregister"
runas /user:%AD%@JUSTICIA /savecred "w32tm /unregister"
call :log "Attempting to register Windows Time service: w32tm /register"
runas /user:%AD%@JUSTICIA /savecred "w32tm /register"
call :log "Attempting to start Windows Time service: net start w32time"
runas /user:%AD%@JUSTICIA /savecred "net start w32time"
call :log "Attempting to resync Windows Time service: w32tm /resync"
runas /user:%AD%@JUSTICIA /savecred "w32tm /resync"
call :log "Action complete: Time synchronization commands issued. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: horafec

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Libreoffice (:libreoff)
:: Installs LibreOffice silently.
::-----------------------------------------------------------------------------
:libreoff
call :log "Starting sub-section libreoff (Install LibreOffice)"
call :log "Attempting to install LibreOffice silently: msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn"
call :log "Action complete: LibreOffice installation command issued. Returning to main menu."
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
    call :log "Checking driver: %%b for keywords 'desconocido' or 'lector'"
    echo %%b | findstr /I /C:"desconocido" /C:"lector" >nul
    if not errorlevel 1 (
         call :log "Driver %%b matches criteria 'desconocido' or 'lector'. Attempting to delete."
         echo Eliminando el controlador %%b...
         call :log "Executing: pnputil /delete-driver %%b /uninstall /force"
         pnputil /delete-driver %%b /uninstall /force
         CLS
    ) else (
         call :log "Driver %%b does not match criteria 'desconocido' or 'lector'. Skipping."
    )
)
call :log "Driver removal loop finished."
call :log "Performing action: del %~f0% & exit (self-deleting script after driver removal)"
call :log_execution_time
del "%~f0%" & exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Desinstalador Tarjetas
goto main :: This goto main is unreachable due to the 'del %~f0% & exit' above.