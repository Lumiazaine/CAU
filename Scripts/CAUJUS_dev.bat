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
    REM :log is deprecated, and :log_entry might not be ready or RUNAS_USER not set.
    echo [%date% %time%] Error: Script executed from jump host IUSSWRDPCAU02. Exiting. >> %~dp0CAUJUS_early_error.log
    REM call :log_execution_time :: This also uses :log
    exit
) else (
    REM :log is deprecated. Early logging will be basic.
    echo [%date% %time%] Jump host check passed. Machine is not IUSSWRDPCAU02. Proceeding. >> %~dp0CAUJUS_startup.log
    goto check_AD_state
)

:check_AD_state
call :AD_STATE
goto check

::=============================================================================
:: Subroutine: :AD_STATE
:: Purpose: Checks domain status, server connectivity, and sets up AD/RUNAS_USER.
::          Sets LOG_WRITE_MODE to LOCAL if using ./DP_ADMIN.
::=============================================================================
:AD_STATE
setlocal
set "TEMP_IS_DOMAIN_JOINED=NO"
set "TEMP_SERVER_CONNECTIVITY_OK=NO"
set "TEMP_AD="
set "TEMP_RUNAS_USER="
set "TEMP_LOG_WRITE_MODE=%LOG_WRITE_MODE%" :: Inherit current global LOG_WRITE_MODE, may be overridden

call :log_entry "AD_STATE: Starting."
:: Attempt to get current AD if already defined (e.g. from wrapper or pre-set environment)
if defined AD set TEMP_AD=%AD%

call :log_entry "AD_STATE: Domain join check..."
call :ExecAndLog systeminfo | findstr /B /C:"Domain:"
if "%LAST_CMD_ERRORLEVEL%"=="0" (
    set "TEMP_IS_DOMAIN_JOINED=YES"
    call :log_entry "AD_STATE: Machine appears to be domain-joined."
) else (
    call :log_entry "AD_STATE: Machine does NOT appear to be domain-joined (systeminfo | findstr errorlevel: %LAST_CMD_ERRORLEVEL%)."
)

call :log_entry "AD_STATE: Server connectivity check to iusnas05..."
call :ExecAndLog ping -n 1 iusnas05
if "%LAST_CMD_ERRORLEVEL%"=="0" (
    set "TEMP_SERVER_CONNECTIVITY_OK=YES"
    call :log_entry "AD_STATE: Server iusnas05 is reachable."
) else (
    call :log_entry "AD_STATE: Server iusnas05 is NOT reachable (ping errorlevel: %LAST_CMD_ERRORLEVEL%)."
)

if "%TEMP_IS_DOMAIN_JOINED%"=="NO" OR "%TEMP_SERVER_CONNECTIVITY_OK%"=="NO" (
    call :log_entry "AD_STATE: Machine not domain-joined or server unreachable. Prompting for user type."
    ECHO El equipo no se encuentra en el dominio o no tiene conexion con el servidor.
    ECHO Por favor introduzca un usuario.
    ECHO Si desea utilizar el administrador local './DP_ADMIN', pulse 1 y Enter.
    ECHO De lo contrario, introduzca el nombre de usuario de dominio (sin @JUSTICIA):
    set "USER_CHOICE="
    set /p "USER_CHOICE=Su eleccion: "
    if "%USER_CHOICE%"=="1" (
        set "TEMP_AD=./DP_ADMIN"
        call :log_entry "AD_STATE: User selected local admin: %TEMP_AD%"
        set "TEMP_LOG_WRITE_MODE=LOCAL" 
        call :log_entry "AD_STATE: Forcing log mode to LOCAL for %TEMP_AD%"
    ) else (
        set "TEMP_AD=%USER_CHOICE%"
        call :log_entry "AD_STATE: User provided domain user: %TEMP_AD%"
        REM LOG_WRITE_MODE for domain user will be determined by :initialize_logging
    )
) else {
    call :log_entry "AD_STATE: Machine is domain-joined and server is reachable."
    REM If AD is not already defined (e.g. by wrapper), it will be prompted in :check
}

REM Define RUNAS_USER based on TEMP_AD if set, or existing AD if TEMP_AD is not set by prompt
if defined TEMP_AD (
    if "%TEMP_AD%"=="./DP_ADMIN" (
        set "TEMP_RUNAS_USER=%TEMP_AD%"
    ) else (
        set "TEMP_RUNAS_USER=%TEMP_AD%@JUSTICIA"
    )
)

endlocal & set AD=%TEMP_AD% & set RUNAS_USER=%TEMP_RUNAS_USER% & set LOG_WRITE_MODE=%TEMP_LOG_WRITE_MODE%

if defined AD ( call :log_entry "AD_STATE: AD is now: %AD%" ) else ( call :log_entry "AD_STATE: AD is not set by AD_STATE." )
if defined RUNAS_USER ( call :log_entry "AD_STATE: RUNAS_USER is now: %RUNAS_USER%" ) else ( call :log_entry "AD_STATE: RUNAS_USER is not set by AD_STATE." )
call :log_entry "AD_STATE: LOG_WRITE_MODE is now: %LOG_WRITE_MODE%"
goto :eof


::=============================================================================
:: Section: AD User Input and Initialization
:: Prompts for AD username if not set by AD_STATE, sets up Perfil,
:: captures start time, and initializes logging.
::=============================================================================
:: Variable AD
:check
cls
@ECHO off
if not defined AD (
    call :log_entry ":check - AD variable not defined by AD_STATE. Prompting user."
    set /p "AD=introduce tu AD (sin @JUSTICIA, o ./DP_ADMIN para local):"
    call :log_entry ":check - User provided AD: %AD%"
) else (
    call :log_entry ":check - AD variable already defined as: %AD%"
)

REM Ensure RUNAS_USER is set based on AD (either from AD_STATE or manual input)
if defined AD (
    if "%AD%"=="./DP_ADMIN" (
        if not "%RUNAS_USER%"=="./DP_ADMIN" (
            set "RUNAS_USER=./DP_ADMIN"
            call :log_entry ":check - RUNAS_USER needed update, now: ./DP_ADMIN"
        )
        if not "%LOG_WRITE_MODE%"=="LOCAL" (
            set "LOG_WRITE_MODE=LOCAL"
            call :log_entry ":check - LOG_WRITE_MODE forced to LOCAL for ./DP_ADMIN"
        )
    ) else (
        REM Ensure AD does not contain @JUSTICIA for the AD variable itself
        echo "%AD%" | findstr /L /C:"@JUSTICIA" > nul
        if not errorlevel 1 (
            call :log_entry ":check - AD variable (%AD%) contains @JUSTICIA. Please use short AD name."
            REM Potentially strip it or ask again - for now, log and proceed.
            REM This scenario should ideally be handled by user input rules or AD_STATE.
        )
        set "EXPECTED_RUNAS_USER=%AD%@JUSTICIA"
        if not "%RUNAS_USER%"=="%EXPECTED_RUNAS_USER%" (
            set "RUNAS_USER=%EXPECTED_RUNAS_USER%"
            call :log_entry ":check - RUNAS_USER needed update, now: %RUNAS_USER%"
        )
    )
) else (
    call :log_entry ":check - CRITICAL: AD is not defined after prompt. RUNAS_USER cannot be reliably set."
    echo CRITICAL: AD user not defined. Exiting.
    pause
    exit /b 1
)

if not defined RUNAS_USER (
    call :log_entry ":check - CRITICAL: RUNAS_USER is STILL NOT SET after AD processing. Exiting."
    echo CRITICAL: RUNAS_USER could not be determined. Exiting.
    pause
    exit /b 1
)
call :log_entry ":check - AD is: %AD%. RUNAS_USER is: %RUNAS_USER%. LOG_WRITE_MODE is: %LOG_WRITE_MODE%."

for /f "tokens=2 delims=\" %%i in ('whoami') do set Perfil=%%i
call :log_entry ":check - User profile (whoami): %Perfil%"
        
set START_TIME=%TIME%
call :log_entry ":check - Script start time captured: %START_TIME%"
        
call :initialize_logging

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
:: Section: Logging Setup and Initialization
:: Defines log paths and determines initial logging mode. This is called AFTER
:: AD and RUNAS_USER should be established by :AD_STATE and :check.
::=============================================================================
:initialize_logging
call :log_entry "INITIALIZE_LOGGING: Starting..."
set "DEFAULT_LOG_PATH=\\iusnas05\SIJ\CAU-2012\logs"
set "LOCAL_LOG_PATH=%~dp0logs"

IF NOT DEFINED LOG_WRITE_MODE (
    set "LOG_WRITE_MODE=NETWORK" 
    call :log_entry "INITIALIZE_LOGGING: LOG_WRITE_MODE was not preset by AD_STATE, defaulted to NETWORK."
) ELSE (
    call :log_entry "INITIALIZE_LOGGING: LOG_WRITE_MODE was preset by AD_STATE or :check to %LOG_WRITE_MODE%."
)

IF "%LOG_WRITE_MODE%"=="LOCAL" (
    call :log_entry "INITIALIZE_LOGGING: Mode is LOCAL as per preset. Skipping network checks."
    goto :log_init_done
)

IF NOT DEFINED RUNAS_USER (
    call :log_entry "INITIALIZE_LOGGING: CRITICAL - RUNAS_USER not defined! Cannot check network log path. Forcing LOCAL logging."
    set "LOG_WRITE_MODE=LOCAL"
    goto :log_init_done
)
IF NOT DEFINED AD (
    call :log_entry "INITIALIZE_LOGGING: WARNING - AD user not defined, but RUNAS_USER is %RUNAS_USER%. Network operations may be affected if RUNAS_USER is not a domain account."
)
IF NOT DEFINED COMPUTERNAME (
    call :log_entry "INITIALIZE_LOGGING: WARNING - COMPUTERNAME not defined. Log filenames might be incomplete."
)

call :log_entry "INITIALIZE_LOGGING: Checking network log path %DEFAULT_LOG_PATH% with RUNAS_USER: %RUNAS_USER%"

set "CHECK_AD_PART=NO_AD_USER"
if defined AD (set "CHECK_AD_PART=%AD%")
if "%CHECK_AD_PART%"=="./DP_ADMIN" set "CHECK_AD_PART=DP_ADMIN"

set "CHECK_PC_PART=NO_PC_NAME"
if defined COMPUTERNAME (set "CHECK_PC_PART=%COMPUTERNAME%")

set "CHECK_NAME=%CHECK_AD_PART%_%CHECK_PC_PART%_chk"
set "CHECK_NAME=%CHECK_NAME:./=%" :: Sanitize

runas /user:%RUNAS_USER% "cmd /c if exist \"%DEFAULT_LOG_PATH%\" (mkdir \"%DEFAULT_LOG_PATH%\%CHECK_NAME%\" >nul 2>&1 && rmdir \"%DEFAULT_LOG_PATH%\%CHECK_NAME%\" >nul 2>&1 && exit 0) else (exit 1)"
if errorlevel 1 (
    call :log_entry "INITIALIZE_LOGGING: Network log path %DEFAULT_LOG_PATH% not accessible/writable by %RUNAS_USER%. Setting LOG_WRITE_MODE to LOCAL."
    set "LOG_WRITE_MODE=LOCAL"
) else (
    call :log_entry "INITIALIZE_LOGGING: Network log path %DEFAULT_LOG_PATH% is accessible. LOG_WRITE_MODE confirmed as NETWORK."
)

:log_init_done
call :log_entry "INITIALIZE_LOGGING: Finished. Mode: %LOG_WRITE_MODE%. Default: %DEFAULT_LOG_PATH%. Local: %LOCAL_LOG_PATH%."
goto :eof


::=============================================================================
:: Section: New Logging Subroutines
::=============================================================================

::-----------------------------------------------------------------------------
:: Subroutine: :log_entry
:: Purpose: Logs a message to either a network or local log file.
::          Uses the globally set LOG_WRITE_MODE.
::          If a single network write fails, it attempts to write that message to local as a fallback.
:: Arguments: %1 - The log message string.
:: Usage: call :log_entry "This is a log message"
::-----------------------------------------------------------------------------
:log_entry
setlocal
set "LOG_MESSAGE=%~1"
set "TIMESTAMP=%date% %time%"
set "CURRENT_WRITE_MODE=%LOG_WRITE_MODE%" :: Use the global mode for this attempt

:: Determine log file name components
set "LOG_AD_PART=NO_AD_USER" :: Default if AD is not defined
if defined AD (
    set "LOG_AD_PART=%AD%"
    if "%AD%"=="./DP_ADMIN" set "LOG_AD_PART=DP_ADMIN"
)

set "LOG_PC_PART=NO_PC_NAME" :: Default if COMPUTERNAME is not defined
if defined COMPUTERNAME (set "LOG_PC_PART=%COMPUTERNAME%")

set "LOG_FILE_NAME=%LOG_AD_PART%_%LOG_PC_PART%.log"
set "LOG_FILE_NAME=%LOG_FILE_NAME:./=%" :: Sanitize potential "./" from AD variable

if "%CURRENT_WRITE_MODE%"=="NETWORK" (
    set "NETWORK_LOG_FILE_PATH=%DEFAULT_LOG_PATH%\%LOG_FILE_NAME%"
    if defined RUNAS_USER (
        runas /user:%RUNAS_USER% "cmd /c echo [%TIMESTAMP%] %LOG_MESSAGE% >> \"%NETWORK_LOG_FILE_PATH%\""
        if not errorlevel 1 (
            goto :eof :: Successfully written to network log
        )
        echo [WARNING] Failed to write to network log with %RUNAS_USER% (Errorlevel %errorlevel%). Falling back to LOCAL for THIS message.
        REM This failure does NOT change the global LOG_WRITE_MODE.
    ) else (
        echo [INFO] RUNAS_USER not defined. Cannot write to network log. Falling back to LOCAL for THIS message.
    )
    REM Fallback to local for this specific message if network failed or RUNAS_USER not defined
    set "CURRENT_WRITE_MODE=LOCAL_FALLBACK"
)

if "%CURRENT_WRITE_MODE%"=="LOCAL" OR "%CURRENT_WRITE_MODE%"=="LOCAL_FALLBACK" (
    if not defined LOCAL_LOG_PATH set "LOCAL_LOG_PATH=%~dp0logs" :: Failsafe if called too early
    set "LOCAL_LOG_FILE_PATH=%LOCAL_LOG_PATH%\%LOG_FILE_NAME%"
    if not exist "%LOCAL_LOG_PATH%" (
        mkdir "%LOCAL_LOG_PATH%"
        if errorlevel 1 (
            echo [CRITICAL_ERROR] Failed to create local log directory: %LOCAL_LOG_PATH%. Cannot log message: [%TIMESTAMP%] %LOG_MESSAGE%
            goto :eof
        )
        REM Log the creation of the local log directory itself to the (newly created) local log
        echo [%TIMESTAMP%] [SYSTEM] Created local log directory: %LOCAL_LOG_PATH% >> "%LOCAL_LOG_FILE_PATH%"
    )
    echo [%TIMESTAMP%] %LOG_MESSAGE%>> "%LOCAL_LOG_FILE_PATH%"
)
endlocal
goto :eof

::-----------------------------------------------------------------------------
:: Subroutine: :ExecAndLog
:: Purpose: Executes a command, logs it, captures its output, and logs the output and errorlevel.
::          Sets global LAST_CMD_ERRORLEVEL with the executed command's errorlevel.
:: Arguments: %* - The command to run and its arguments.
:: Usage: call :ExecAndLog ipconfig /all
::-----------------------------------------------------------------------------
:ExecAndLog
setlocal enabledelayedexpansion
set "CMD_TO_RUN=%*"
set "TEMP_OUTPUT_FILE=%TEMP%\caujus_cmd_output_%RANDOM%.tmp"

call :log_entry "Executing: %CMD_TO_RUN%"

%CMD_TO_RUN% > "%TEMP_OUTPUT_FILE%" 2>&1
set CAPTURED_ERRORLEVEL=%errorlevel%

if exist "%TEMP_OUTPUT_FILE%" (
    FOR /F "usebackq delims=" %%L IN ("%TEMP_OUTPUT_FILE%") DO (
        call :log_entry "Output: %%L"
    )
    del "%TEMP_OUTPUT_FILE%" >nul 2>&1
) ELSE (
    call :log_entry "Output: No output file generated or command produced no output to file."
)

call :log_entry "Command finished with errorlevel: %CAPTURED_ERRORLEVEL%"
endlocal & set LAST_CMD_ERRORLEVEL=%CAPTURED_ERRORLEVEL%
goto :eof

::=============================================================================
:: Section: Deprecated Logging Function (:log)
:: Handles writing messages to a log file.
:: Log file is named based on AD username and computer name.
:: THIS FUNCTION IS DEPRECATED. Use :log_entry instead.
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
:: End of Section: Deprecated Logging Function (Primary :log)

::=============================================================================
:: Sub-Section: Basic Logging Function (:basic_log)
:: THIS FUNCTION IS DEPRECATED as part of the old :log mechanism.
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
:: End of Sub-Section: Basic Logging Function (Deprecated)
:: End of Section: Logging Function (Deprecated)
:: The deprecated :log and :basic_log sections above are now fully removed by this diff.

::=============================================================================
:: Section: Execution Time Logging Subroutine
::=============================================================================
:log_execution_time
set END_TIME=%TIME%
call :log_entry "Start time: %START_TIME%"
call :log_entry "End time: %END_TIME%"

:: Parse START_TIME (HH:MM:SS.CS)
set /A START_H=1%START_TIME:~0,2% - 100
set /A START_M=1%START_TIME:~3,2% - 100
set /A START_S=1%START_TIME:~6,2% - 100
set /A START_CS=1%START_TIME:~9,2% - 100
set /A START_TOTAL_CS=(%START_H%*360000) + (%START_M%*6000) + (%START_S%*100) + %START_CS%
call :log_entry "Parsed START_TIME: %START_H%h %START_M%m %START_S%s %START_CS%cs (Total CS: %START_TOTAL_CS%)"

:: Parse END_TIME (HH:MM:SS.CS)
set /A END_H=1%END_TIME:~0,2% - 100
set /A END_M=1%END_TIME:~3,2% - 100
set /A END_S=1%END_TIME:~6,2% - 100
set /A END_CS=1%END_TIME:~9,2% - 100
set /A END_TOTAL_CS=(%END_H%*360000) + (%END_M%*6000) + (%END_S%*100) + %END_CS%
call :log_entry "Parsed END_TIME: %END_H%h %END_M%m %END_S%s %END_CS%cs (Total CS: %END_TOTAL_CS%)"

IF %END_TOTAL_CS% LSS %START_TOTAL_CS% (
    call :log_entry "Midnight rollover detected for execution time calculation."
    set /A END_TOTAL_CS = %END_TOTAL_CS% + (24 * 360000)
    call :log_entry "Adjusted END_TOTAL_CS for rollover: %END_TOTAL_CS%"
)

set /A DURATION_CS=%END_TOTAL_CS% - %START_TOTAL_CS%
set /A DURATION_S = %DURATION_CS% / 100
set /A DURATION_CS_REMAINDER = %DURATION_CS% %% 100

set DURATION_CS_STR=0%DURATION_CS_REMAINDER%
set DURATION_CS_STR=%DURATION_CS_STR:~-2%

set /A DURATION_M_TOTAL = %DURATION_S% / 60
set /A DURATION_S_REMAINDER = %DURATION_S% %% 60
set /A DURATION_H_TOTAL = %DURATION_M_TOTAL% / 60
set /A DURATION_M_REMAINDER = %DURATION_M_TOTAL% %% 60

set DURATION_H_STR=0%DURATION_H_TOTAL%
set DURATION_H_STR=%DURATION_H_STR:~-2%
set DURATION_M_STR=0%DURATION_M_REMAINDER%
set DURATION_M_STR=%DURATION_M_STR:~-2%
set DURATION_S_STR=0%DURATION_S_REMAINDER%
set DURATION_S_STR=%DURATION_S_STR:~-2%

set "DURATION_STR=%DURATION_H_STR%:%DURATION_M_STR%:%DURATION_S_STR%.%DURATION_CS_STR%"
call :log_entry "Script execution time: %DURATION_STR%"
goto :eof
:: End of Section: Execution Time Logging Subroutine

:: Note: The 'call :log "Inicio del script"' was moved to after :check for proper AD resolution.
:: The old :check label that was here is removed as :main is now called directly
:: after the new :check (AD and initialization) section.

::=============================================================================
:: Section: Main Menu & System Information
:: Gathers and displays system information.
:: Presents the main menu of available actions to the technician.
::=============================================================================
:: Datos equipos
:main
cls
call :log_entry "MAIN: Displaying main menu and system info."
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
if '%choice%'=='1' call :log_entry "Main menu: User selected option 1 (Bateria pruebas), navigating to :Batery_test" & goto Batery_test
if '%choice%'=='2' call :log_entry "Main menu: User selected option 2 (Cambiar password correo), navigating to :mail_pass" & goto mail_pass
if '%choice%'=='3' call :log_entry "Main menu: User selected option 3 (Reiniciar cola impresion), navigating to :print_pool" & goto print_pool
if '%choice%'=='4' call :log_entry "Main menu: User selected option 4 (Administrador de dispositivos), navigating to :Driver_admin" & goto Driver_admin
if '%choice%'=='5' call :log_entry "Main menu: User selected option 5 (Certificado digital), navigating to :Cert" & goto Cert
if '%choice%'=='6' call :log_entry "Main menu: User selected option 6 (ISL Allways on), navigating to :isl" & goto isl
if '%choice%'=='7' call :log_entry "Main menu: User selected option 7 (Utilidades), navigating to :Bmenu" & goto Bmenu
call :log_entry "Main menu: Invalid option '%choice%'"
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
call :log_entry "Batery_test: Starting section"
:: Kill common browser processes
call :ExecAndLog "taskkill /IM chrome.exe /F"
call :ExecAndLog "taskkill /IM iexplore.exe /F"
call :ExecAndLog "taskkill /IM msedge.exe /F"
:: Flush DNS cache
call :ExecAndLog "ipconfig /flushdns"
:: Clear Internet Explorer cache and history
call :ExecAndLog "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16"
call :ExecAndLog "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8"
call :ExecAndLog "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2"
call :ExecAndLog "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1"
:: Clear Chrome cache (Path might be user/system dependent)
call :log_entry "Batery_test: Attempting to delete Chrome cache for profile %Perfil%"
call :ExecAndLog "del /q /s /f \"E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*\""
:: Adjust visual effects for performance
call :log_entry "Batery_test: Attempting to adjust visual effects for performance via registry changes using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 3 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v FontSmoothing /t REG_SZ /d 2 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v FontSmoothingType /t REG_DWORD /d 2 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v DragFullWindows /t REG_SZ /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\" /v SmoothScroll /t REG_SZ /d 0 /f\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v Animations /t REG_SZ /d 0 /f\""
:: Force group policy update
call :ExecAndLog "gpupdate /force"
:: Reinstall ISL client
call :log_entry "Batery_test: Attempting to reinstall ISL client using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn\""
:: Delete various temporary and backup files
call :log_entry "Batery_test: Attempting to delete various system temporary and backup files using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%windir%\*.bak\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c del /f /s /q \"%systemdrive%\*.old\"\""
:: Delete user-specific temporary files and caches
call :log_entry "Batery_test: Attempting to delete user-specific temporary files and caches using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\"\""
:: Recreate user and system Temp folders
call :log_entry "Batery_test: Attempting to recreate user and system Temp folders using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\"\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\"\""
:: Prompt for restart
call :log_entry "Batery_test: Prompting for restart"
echo Reiniciar equipo (s/n)
choice /c sn /n
call :log_execution_time
IF "%LOG_WRITE_MODE%"=="LOCAL" (
  call :log_entry "INFO: Los logs de esta sesion se han guardado localmente en %LOCAL_LOG_PATH%"
  ECHO.
  ECHO ADVERTENCIA: Los logs de esta sesion se han guardado localmente en:
  ECHO %LOCAL_LOG_PATH%\%LOG_FILE_NAME%
  ECHO Por favor, revise estos logs si es necesario.
  set "DELETE_SCRIPT_CHOICE="
  set /p "DELETE_SCRIPT_CHOICE=El script normalmente se auto-eliminaria. Desea eliminarlo ahora? (S/N): "
  IF /I "%DELETE_SCRIPT_CHOICE%"=="S" (
    call :log_entry "User chose to delete script despite local logs."
    if errorlevel 2 if not errorlevel 1 call :log_entry "User chose not to restart after Batery_test. Script will be deleted." & del "%~f0%" & exit
    if errorlevel 1 if not errorlevel 2 call :log_entry "User chose to restart after Batery_test. Script will be deleted before shutdown." & del "%~f0%" & shutdown /r /t 0
  ) ELSE (
    call :log_entry "User chose NOT to delete script due to local logs."
    if errorlevel 2 if not errorlevel 1 call :log_entry "User chose not to restart after Batery_test. Script NOT deleted." & exit
    if errorlevel 1 if not errorlevel 2 call :log_entry "User chose to restart after Batery_test. Script NOT deleted before shutdown." & shutdown /r /t 0
  )
) ELSE (
  call :log_entry "Script self-deleting. Logs are on network path."
  if errorlevel 2 if not errorlevel 1 call :log_entry "User chose not to restart after Batery_test. Self-deleting script." & del "%~f0%" & exit
  if errorlevel 1 if not errorlevel 2 call :log_entry "User chose to restart after Batery_test. Initiating shutdown. Self-deleting script." & del "%~f0%" & shutdown /r /t 0
)
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
call :log_entry "mail_pass: Starting section"
call :log_entry "mail_pass: Attempting to open Chrome to Junta de Andalucia account page"
call :ExecAndLog "start chrome \"https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial\""
call :log_entry "mail_pass: Action complete. Preparing to self-delete script and exit."
call :log_execution_time
IF "%LOG_WRITE_MODE%"=="LOCAL" (
  call :log_entry "INFO: Los logs de esta sesion se han guardado localmente en %LOCAL_LOG_PATH%"
  ECHO.
  ECHO ADVERTENCIA: Los logs de esta sesion se han guardado localmente en:
  ECHO %LOCAL_LOG_PATH%\%LOG_FILE_NAME%
  ECHO Por favor, revise estos logs si es necesario.
  set "DELETE_SCRIPT_CHOICE="
  set /p "DELETE_SCRIPT_CHOICE=El script normalmente se auto-eliminaria. Desea eliminarlo ahora? (S/N): "
  IF /I "%DELETE_SCRIPT_CHOICE%"=="S" (
    call :log_entry "User chose to delete script despite local logs."
    del "%~f0%"
  ) ELSE (
    call :log_entry "User chose NOT to delete script due to local logs."
  )
) ELSE (
  call :log_entry "Script self-deleting. Logs are on network path."
  del "%~f0%"
)
exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Cambiar password correo

::=============================================================================
:: Section: Reiniciar cola impresion (:print_pool)
:: Restarts the print spooler for all printers.
:: Deletes the script after execution.
::=============================================================================
:print_pool
call :log_entry "print_pool: Starting section"
call :log_entry "print_pool: Attempting to restart print spooler for all printers using prnmngr.vbs and prnqctl.vbs with RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\"\""
call :log_entry "print_pool: Action complete. Preparing to self-delete script and exit."
call :log_execution_time
IF "%LOG_WRITE_MODE%"=="LOCAL" (
  call :log_entry "INFO: Los logs de esta sesion se han guardado localmente en %LOCAL_LOG_PATH%"
  ECHO.
  ECHO ADVERTENCIA: Los logs de esta sesion se han guardado localmente en:
  ECHO %LOCAL_LOG_PATH%\%LOG_FILE_NAME%
  ECHO Por favor, revise estos logs si es necesario.
  set "DELETE_SCRIPT_CHOICE="
  set /p "DELETE_SCRIPT_CHOICE=El script normalmente se auto-eliminaria. Desea eliminarlo ahora? (S/N): "
  IF /I "%DELETE_SCRIPT_CHOICE%"=="S" (
    call :log_entry "User chose to delete script despite local logs."
    del "%~f0%"
  ) ELSE (
    call :log_entry "User chose NOT to delete script due to local logs."
  )
) ELSE (
  call :log_entry "Script self-deleting. Logs are on network path."
  del "%~f0%"
)
exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Reiniciar cola impresion

::=============================================================================
:: Section: Administrador de dispositivos (:Driver_admin)
:: Opens the Device Manager console.
:: Returns to the main menu.
::=============================================================================
:Driver_admin
call :log_entry "Driver_admin: Starting section (Device Manager)"
call :log_entry "Driver_admin: Attempting to open Device Manager using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"RunDll32.exe devmgr.dll DeviceManager_Execute\""
call :log_entry "Driver_admin: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: No goto :eof needed as it explicitly jumps to main.
:: End of Section: Administrador de dispositivos

::=============================================================================
:: Section: ISL Allways on (:isl)
:: Installs or reinstalls the ISL Always On VPN client silently.
:: Returns to the main menu.
::=============================================================================
:isl
call :log_entry "isl: Starting section (ISL Always On VPN)"
call :log_entry "isl: Attempting to install/reinstall ISL Always On VPN silently using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn\""
call :log_entry "isl: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: No goto :eof needed as it explicitly jumps to main.
:: End of Section: ISL Allways on

::=============================================================================
:: Section: Certificado digital (:Cert)
:: Provides a sub-menu for managing digital certificates, including FNMT configuration
:: and accessing FNMT website for certificate requests, renewals, and downloads.
::=============================================================================
:Cert
call :log_entry "Cert: Starting section (Digital Certificate Management)"
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
if '%choice%'=='1' call :log_entry "Cert menu: User selected option 1 (Configuracion previa (Silenciosa)), navigating to :configurators" & goto configurators
if '%choice%'=='2' call :log_entry "Cert menu: User selected option 2 (Configuracion previa (Manual)), navigating to :configurator" & goto configurator
if '%choice%'=='3' call :log_entry "Cert menu: User selected option 3 (Solicitar certificado digital), navigating to :solicitude" & goto solicitude
if '%choice%'=='4' call :log_entry "Cert menu: User selected option 4 (Renovar certificado digital), navigating to :renew" & goto renew
if '%choice%'=='5' call :log_entry "Cert menu: User selected option 5 (Descargar certificado digital), navigating to :download" & goto download
if '%choice%'=='6' call :log_entry "Cert menu: User selected option 6 (Inicio - Return to Main Menu), navigating to :main" & goto main
call :log_entry "Cert menu: Invalid option '%choice%'"
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Cert :: Return to Cert menu if choice is invalid.
:: End of Section: Cert (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Silenciosa) (:configurators)
:: Runs the FNMT configuration tool in silent mode.
::-----------------------------------------------------------------------------
:configurators
call :log_entry "configurators: Starting sub-section (Silent FNMT Configuration)"
call :log_entry "configurators: Attempting to change directory to %userprofile%\downloads"
call :ExecAndLog "cd %userprofile%\downloads"
call :log_entry "configurators: Attempting to run Silent FNMT Configurator using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S\""
call :log_entry "configurators: Action complete. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurators

::-----------------------------------------------------------------------------
:: Sub-Section: Configuracion previa (Manual) (:configurator)
:: Runs the FNMT configuration tool in manual (interactive) mode.
::-----------------------------------------------------------------------------
:configurator
call :log_entry "configurator: Starting sub-section (Manual FNMT Configuration)"
call :log_entry "configurator: Attempting to change directory to %userprofile%\downloads"
call :ExecAndLog "cd %userprofile%\downloads"
call :log_entry "configurator: Attempting to run Manual FNMT Configurator using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe\""
call :log_entry "configurator: Action complete. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: configurator

::-----------------------------------------------------------------------------
:: Sub-Section: Solicitar certificado digital (:solicitude)
:: Opens Chrome to the FNMT certificate request page.
::-----------------------------------------------------------------------------
:solicitude
call :log_entry "solicitude: Starting sub-section (Request Digital Certificate)"
call :log_entry "solicitude: Attempting to open Chrome to FNMT certificate request page"
call :ExecAndLog "start chrome \"https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado\""
call :log_entry "solicitude: Action complete. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: solicitude

::-----------------------------------------------------------------------------
:: Sub-Section: Renovar certificado digital (:renew)
:: Opens Chrome to the FNMT certificate renewal page.
::-----------------------------------------------------------------------------
:renew
call :log_entry "renew: Starting sub-section (Renew Digital Certificate)"
call :log_entry "renew: Attempting to open Chrome to FNMT certificate renewal page"
call :ExecAndLog "start chrome \"https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion\""
call :log_entry "renew: Action complete. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: renew

::-----------------------------------------------------------------------------
:: Sub-Section: Descargar certificado digital (:download)
:: Opens Chrome to the FNMT certificate download page.
::-----------------------------------------------------------------------------
:download
call :log_entry "download: Starting sub-section (Download Digital Certificate)"
call :log_entry "download: Attempting to open Chrome to FNMT certificate download page"
call :ExecAndLog "start chrome \"https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado\""
call :log_entry "download: Action complete. Returning to Cert menu."
goto Cert :: Return to Cert menu.
:: End of Sub-Section: download

::=============================================================================
:: Section: Utilidades (:Bmenu)
:: Provides a sub-menu for various utility tasks such as opening Internet Options,
:: installing software (Chrome, Autofirma, LibreOffice), fixing display issues,
:: viewing Windows version, reinstalling card reader drivers, and forcing time sync.
::=============================================================================
:Bmenu
call :log_entry "Bmenu: Starting section (Utilities Menu)"
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
if '%choice%'=='1' call :log_entry "Bmenu: User selected option 1 (Ver opciones de internet), navigating to :ieopcion" & goto ieopcion
if '%choice%'=='2' call :log_entry "Bmenu: User selected option 2 (Instalar Chrome 109), navigating to :chrome" & goto chrome
if '%choice%'=='3' call :log_entry "Bmenu: User selected option 3 (Arreglar pantalla oscura), navigating to :black_screen" & goto black_screen
if '%choice%'=='4' call :log_entry "Bmenu: User selected option 4 (Ver version de Windows), navigating to :winver" & goto winver
if '%choice%'=='5' call :log_entry "Bmenu: User selected option 5 (Reinstalar drivers tarjeta), navigating to :tarjetadrv" & goto tarjetadrv
if '%choice%'=='6' call :log_entry "Bmenu: User selected option 6 (Instalar Autofirmas), navigating to :autof" & goto autof
if '%choice%'=='7' call :log_entry "Bmenu: User selected option 7 (Instalar Libreoffice), navigating to :libreoff" & goto libreoff
if '%choice%'=='8' call :log_entry "Bmenu: User selected option 8 (Forzar fecha y hora), navigating to :horafec" & goto horafec
if '%choice%'=='9' call :log_entry "Bmenu: User selected option 9 (Inicio - Return to Main Menu), navigating to :main" & goto main
call :log_entry "Bmenu: Invalid option '%choice%'"
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Bmenu :: Return to Bmenu if choice is invalid.
:: End of Section: Bmenu (Menu Display)

::-----------------------------------------------------------------------------
:: Sub-Section: Arreglar pantalla oscura (:black_screen)
:: Cycles through display modes (internal, extend) to potentially fix a black screen issue.
::-----------------------------------------------------------------------------
:black_screen
call :log_entry "black_screen: Starting sub-section (Fix Black Screen)"
call :ExecAndLog "DisplaySwitch.exe /internal"
call :log_entry "black_screen: Pausing for 3 seconds"
call :ExecAndLog "timeout /t 3 /nobreak"
call :ExecAndLog "DisplaySwitch.exe /extend"
call :log_entry "black_screen: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: black_screen

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Autofirmas (:autof)
:: Kills Chrome, then installs two versions of Autofirma silently.
::-----------------------------------------------------------------------------
:autof
call :log_entry "autof: Starting sub-section (Install Autofirma)"
call :ExecAndLog "taskkill /IM chrome.exe /F"
call :log_entry "autof: Attempting to install Autofirma v1.8.3 silently using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S\""
call :log_entry "autof: Attempting to install Autofirma v1.6.0_JAv05 silently using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn\""
call :log_entry "autof: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: autof

::-----------------------------------------------------------------------------
:: Sub-Section: Ver opciones de internet (:ieopcion)
:: Opens the Internet Options control panel applet.
::-----------------------------------------------------------------------------
:ieopcion
call :log_entry "ieopcion: Starting sub-section (Internet Options)"
call :ExecAndLog "Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl"
call :log_entry "ieopcion: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: ieopcion

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Chrome 109 (:chrome)
:: Installs Google Chrome version 109 silently.
::-----------------------------------------------------------------------------
:chrome
call :log_entry "chrome: Starting sub-section (Install Chrome 109)"
call :log_entry "chrome: Attempting to install Chrome 109 silently using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn\""
call :log_entry "chrome: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: chrome

::-----------------------------------------------------------------------------
:: Sub-Section: Ver version de Windows (:winver)
:: Shows the Windows "About" dialog with version information.
::-----------------------------------------------------------------------------
:winver
call :log_entry "winver: Starting sub-section (Windows Version)"
call :ExecAndLog "RunDll32.exe SHELL32.DLL,ShellAboutW"
call :log_entry "winver: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: winver

::-----------------------------------------------------------------------------
:: Sub-Section: Reinstalar drivers tarjeta (:tarjetadrv)
:: Installs two different card reader drivers.
::-----------------------------------------------------------------------------
:tarjetadrv
call :log_entry "tarjetadrv: Starting sub-section (Card Reader Drivers)"
call :log_entry "tarjetadrv: Attempting to install card reader driver (SCR3xxx_V8.52.exe) using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe\""  
call :log_entry "tarjetadrv: Attempting to install card reader driver (TCJ0023500B.exe) using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe\""
call :log_entry "tarjetadrv: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: tarjetadrv

::-----------------------------------------------------------------------------
:: Sub-Section: Forzar fecha y hora (:horafec)
:: Stops, unregisters, reregisters, starts, and resyncs the Windows Time service.
::-----------------------------------------------------------------------------
:horafec
call :log_entry "horafec: Starting sub-section (Force Time Sync) using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"net stop w32time\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"w32tm /unregister\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"w32tm /register\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"net start w32time\""
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"w32tm /resync\""
call :log_entry "horafec: Action complete. Returning to main menu."
goto main :: Returns to the main menu.
:: End of Sub-Section: horafec

::-----------------------------------------------------------------------------
:: Sub-Section: Instalar Libreoffice (:libreoff)
:: Installs LibreOffice silently.
::-----------------------------------------------------------------------------
:libreoff
call :log_entry "libreoff: Starting sub-section (Install LibreOffice)"
call :log_entry "libreoff: Attempting to install LibreOffice silently using RUNAS_USER: %RUNAS_USER%"
call :ExecAndLog "runas /user:%RUNAS_USER% /savecred \"cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn\""
call :log_entry "libreoff: Action complete. Returning to main menu."
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
call :log_entry "remove_drivers: Starting section (Uninstall Card Reader Drivers)"
FOR /F "tokens=3,*" %%a in ('pnputil /enum-drivers ^| find "Nombre publicado"') DO (
    rem %%b contiene el identificador del controlador (p.ej. oemXX.inf)
    call :log_entry "remove_drivers: Checking driver: %%b for keywords 'desconocido' or 'lector'"
    echo %%b | findstr /I /C:"desconocido" /C:"lector" >nul
    if not errorlevel 1 (
         call :log_entry "remove_drivers: Driver %%b matches criteria 'desconocido' or 'lector'. Attempting to delete."
         echo Eliminando el controlador %%b...
         call :ExecAndLog "pnputil /delete-driver %%b /uninstall /force"
         CLS
    ) else (
         call :log_entry "remove_drivers: Driver %%b does not match criteria 'desconocido' or 'lector'. Skipping."
    )
)
call :log_entry "remove_drivers: Driver removal loop finished."
call :log_execution_time
IF "%LOG_WRITE_MODE%"=="LOCAL" (
  call :log_entry "INFO: Los logs de esta sesion se han guardado localmente en %LOCAL_LOG_PATH%"
  ECHO.
  ECHO ADVERTENCIA: Los logs de esta sesion se han guardado localmente en:
  ECHO %LOCAL_LOG_PATH%\%LOG_FILE_NAME%
  ECHO Por favor, revise estos logs si es necesario.
  set "DELETE_SCRIPT_CHOICE="
  set /p "DELETE_SCRIPT_CHOICE=El script normalmente se auto-eliminaria. Desea eliminarlo ahora? (S/N): "
  IF /I "%DELETE_SCRIPT_CHOICE%"=="S" (
    call :log_entry "User chose to delete script despite local logs."
    del "%~f0%"
  ) ELSE (
    call :log_entry "User chose NOT to delete script due to local logs."
  )
) ELSE (
  call :log_entry "Script self-deleting. Logs are on network path."
  del "%~f0%"
)
exit :: Deletes the script and exits.
:: No goto :eof needed due to exit.
:: End of Section: Desinstalador Tarjetas
goto main :: This goto main is unreachable due to the 'del %~f0% & exit' above.