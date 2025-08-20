@ECHO OFF
:: =============================================================================
:: Script: CAUJUS_refactored.bat
:: Purpose: CAU IT Support Utility - Refactored Version
:: Version: 3.0 - Clean Architecture
:: Last Modified: 2025-08-20
:: Description: Menu-driven utility for CAU IT support tasks with improved
::              error handling, logging, and maintainability
:: =============================================================================

SETLOCAL EnableDelayedExpansion

:: =============================================================================
:: CONFIGURATION SECTION
:: =============================================================================
CALL :InitializeConfiguration
CALL :ValidateEnvironment
IF !ERRORLEVEL! NEQ 0 EXIT /B 1

:: =============================================================================
:: MAIN EXECUTION FLOW
:: =============================================================================
CALL :InitializeSession
IF !ERRORLEVEL! NEQ 0 EXIT /B 1

CALL :ShowMainMenu
GOTO :EOF

:: =============================================================================
:: CONFIGURATION INITIALIZATION
:: =============================================================================
:InitializeConfiguration
    :: Network paths
    SET "CONFIG_REMOTE_LOG_DIR=\\iusnas05\SIJ\CAU-2012\logs"
    SET "CONFIG_SOFTWARE_BASE=\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
    SET "CONFIG_DRIVER_BASE=\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"
    
    :: Software packages
    SET "CONFIG_ISL_MSI=!CONFIG_SOFTWARE_BASE!\isl.msi"
    SET "CONFIG_FNMT_CONFIG=!CONFIG_SOFTWARE_BASE!\Configurador_FNMT_5.0.0_64bits.exe"
    SET "CONFIG_AUTOFIRMA_EXE=!CONFIG_SOFTWARE_BASE!\AutoFirma_64_v1_8_3_installer.exe"
    SET "CONFIG_AUTOFIRMA_MSI=!CONFIG_SOFTWARE_BASE!\AutoFirma_v1_6_0_JAv05_installer_64.msi"
    SET "CONFIG_CHROME_MSI=!CONFIG_SOFTWARE_BASE!\chrome.msi"
    SET "CONFIG_LIBREOFFICE_MSI=!CONFIG_SOFTWARE_BASE!\LibreOffice.msi"
    
    :: Driver packages
    SET "CONFIG_DRIVER_PCT=!CONFIG_DRIVER_BASE!\PCT-331_V8.52\SCR3xxx_V8.52.exe"
    SET "CONFIG_DRIVER_SATELLITE=!CONFIG_DRIVER_BASE!\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
    
    :: URLs
    SET "CONFIG_URL_MICUENTA=https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
    SET "CONFIG_URL_FNMT_REQUEST=https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
    SET "CONFIG_URL_FNMT_RENEW=https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
    SET "CONFIG_URL_FNMT_DOWNLOAD=https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
    
    :: Script metadata
    SET "CONFIG_SCRIPT_VERSION=3.0-refactored"
    SET "CONFIG_BLOCKED_HOSTNAME=IUSSWRDPCAU02"
    
    GOTO :EOF

:: =============================================================================
:: ENVIRONMENT VALIDATION
:: =============================================================================
:ValidateEnvironment
    :: Check if running on blocked machine
    FOR /F "tokens=*" %%A IN ('hostname') DO SET "CURRENT_HOSTNAME=%%A"
    IF /I "!CURRENT_HOSTNAME!"=="!CONFIG_BLOCKED_HOSTNAME!" (
        CALL :ShowError "Script cannot run on jump server (!CONFIG_BLOCKED_HOSTNAME!)"
        EXIT /B 1
    )
    
    :: Validate critical paths exist
    IF NOT EXIST "!CONFIG_SOFTWARE_BASE!" (
        CALL :ShowError "Software repository not accessible: !CONFIG_SOFTWARE_BASE!"
        EXIT /B 1
    )
    
    GOTO :EOF

:: =============================================================================
:: SESSION INITIALIZATION
:: =============================================================================
:InitializeSession
    CLS
    
    :: Get AD credentials
    IF NOT DEFINED AD_USER (
        SET /P "AD_USER=Enter your AD username: "
    )
    
    IF "!AD_USER!"=="" (
        CALL :ShowError "AD username is required"
        EXIT /B 1
    )
    
    :: Get current user profile
    FOR /F "tokens=2 delims=\" %%i IN ('whoami') DO SET "USER_PROFILE=%%i"
    
    :: Set up logging
    CALL :InitializeLogging
    
    :: Log session start
    CALL :LogInfo "Session started - User: !USER_PROFILE!, AD: !AD_USER!, Machine: !CURRENT_HOSTNAME!"
    
    GOTO :EOF

:: =============================================================================
:: LOGGING SYSTEM
:: =============================================================================
:InitializeLogging
    :: Create timestamp
    SET "TIMESTAMP=!DATE:~-4,4!!DATE:~-10,2!!DATE:~-7,2!_!TIME:~0,2!!TIME:~3,2!!TIME:~6,2!"
    SET "TIMESTAMP=!TIMESTAMP: =0!"
    
    :: Set log paths
    SET "LOG_DIR=!TEMP!\CAUJUS_Logs"
    SET "LOG_FILE=!LOG_DIR!\!AD_USER!_!CURRENT_HOSTNAME!_!TIMESTAMP!.log"
    
    :: Create log directory
    IF NOT EXIST "!LOG_DIR!" (
        MKDIR "!LOG_DIR!" 2>NUL
        IF !ERRORLEVEL! NEQ 0 (
            ECHO Warning: Could not create log directory
            SET "LOG_FILE=NUL"
        )
    )
    
    GOTO :EOF

:LogInfo
    CALL :LogMessage "INFO" "%~1"
    GOTO :EOF

:LogError
    CALL :LogMessage "ERROR" "%~1"
    GOTO :EOF

:LogWarning
    CALL :LogMessage "WARN" "%~1"
    GOTO :EOF

:LogMessage
    SETLOCAL
    SET "LOG_LEVEL=%~1"
    SET "LOG_MSG=%~2"
    SET "LOG_TIME=!DATE! !TIME:~0,8!"
    
    IF "!LOG_FILE!" NEQ "NUL" (
        ECHO !LOG_TIME! [!LOG_LEVEL!] !LOG_MSG! >> "!LOG_FILE!"
    )
    ENDLOCAL
    GOTO :EOF

:: =============================================================================
:: USER INTERFACE
:: =============================================================================
:ShowMainMenu
    CLS
    CALL :GetSystemInfo
    
    ECHO ==========================================
    ECHO                   CAU
    ECHO      IT Support Utility v!CONFIG_SCRIPT_VERSION!
    ECHO ==========================================
    ECHO.
    ECHO System Information:
    ECHO   User: !USER_PROFILE!
    ECHO   AD User: !AD_USER!
    ECHO   Computer: !CURRENT_HOSTNAME!
    ECHO   Serial: !SYSTEM_SERIAL!
    ECHO   IP: !SYSTEM_IP!
    ECHO   OS: !SYSTEM_OS! (Build !SYSTEM_BUILD!)
    ECHO.
    ECHO Available Options:
    ECHO   1. System Optimization (Battery Test)
    ECHO   2. Change Email Password
    ECHO   3. Reset Print Spooler
    ECHO   4. Device Manager
    ECHO   5. Digital Certificate Management
    ECHO   6. Install ISL Always On
    ECHO   7. Utilities
    ECHO   8. Exit
    ECHO.
    
    CALL :GetUserChoice "Select an option (1-8): " choice 1 8
    
    CALL :LogInfo "Main menu selection: !choice!"
    
    IF "!choice!"=="1" CALL :SystemOptimization
    IF "!choice!"=="2" CALL :ChangeEmailPassword
    IF "!choice!"=="3" CALL :ResetPrintSpooler
    IF "!choice!"=="4" CALL :OpenDeviceManager
    IF "!choice!"=="5" CALL :CertificateMenu
    IF "!choice!"=="6" CALL :InstallISLAlwaysOn
    IF "!choice!"=="7" CALL :UtilitiesMenu
    IF "!choice!"=="8" CALL :ExitScript
    
    GOTO ShowMainMenu

:GetSystemInfo
    :: Get system information
    FOR /F "tokens=*" %%A IN ('hostname') DO SET "CURRENT_HOSTNAME=%%A"
    
    FOR /F "tokens=2 delims==" %%A IN ('wmic bios get serialnumber /value 2^>NUL') DO (
        IF NOT "%%A"=="" SET "SYSTEM_SERIAL=%%A"
    )
    IF NOT DEFINED SYSTEM_SERIAL SET "SYSTEM_SERIAL=Unknown"
    
    FOR /F "delims=[] tokens=2" %%A IN ('ping -4 -n 1 !CURRENT_HOSTNAME! 2^>NUL ^| findstr [') DO SET "SYSTEM_IP=%%A"
    IF NOT DEFINED SYSTEM_IP SET "SYSTEM_IP=Unknown"
    
    FOR /F "tokens=2 delims==" %%A IN ('wmic os get caption /value 2^>NUL') DO (
        IF NOT "%%A"=="" SET "SYSTEM_OS=%%A"
    )
    IF NOT DEFINED SYSTEM_OS SET "SYSTEM_OS=Unknown"
    
    FOR /F "skip=2 tokens=2,*" %%A IN ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>NUL') DO SET "SYSTEM_BUILD=%%B"
    IF NOT DEFINED SYSTEM_BUILD SET "SYSTEM_BUILD=Unknown"
    
    GOTO :EOF

:GetUserChoice
    SET "PROMPT_TEXT=%~1"
    SET "VAR_NAME=%~2"
    SET "MIN_VAL=%~3"
    SET "MAX_VAL=%~4"
    
    :GetChoiceLoop
    SET /P "!VAR_NAME!=!PROMPT_TEXT!"
    
    :: Validate input is numeric and in range
    SET "VALID=0"
    FOR /L %%i IN (!MIN_VAL!,1,!MAX_VAL!) DO (
        IF "!%VAR_NAME%!"=="%%i" SET "VALID=1"
    )
    
    IF !VALID!==0 (
        ECHO Invalid option. Please enter a number between !MIN_VAL! and !MAX_VAL!.
        GOTO GetChoiceLoop
    )
    
    GOTO :EOF

:ShowError
    ECHO.
    ECHO ERROR: %~1
    ECHO.
    PAUSE
    GOTO :EOF

:ShowSuccess
    ECHO.
    ECHO SUCCESS: %~1
    ECHO.
    PAUSE
    GOTO :EOF

:: =============================================================================
:: MAIN FUNCTIONS
:: =============================================================================
:SystemOptimization
    CALL :LogInfo "Starting system optimization"
    
    ECHO.
    ECHO Starting System Optimization...
    ECHO.
    
    CALL :KillBrowsers
    CALL :ClearSystemCaches
    CALL :ApplyPerformanceTweaks
    CALL :RunSystemMaintenance
    
    ECHO.
    ECHO System optimization completed.
    ECHO.
    CHOICE /C YN /M "Restart computer now"
    IF !ERRORLEVEL!==1 (
        CALL :LogInfo "User chose to restart system"
        CALL :UploadLogFile
        SHUTDOWN /r /t 5 /c "System restart initiated by CAU utility"
        EXIT
    )
    
    GOTO :EOF

:ChangeEmailPassword
    CALL :LogInfo "Opening email password change URL"
    START chrome "!CONFIG_URL_MICUENTA!"
    CALL :ShowSuccess "Email password change page opened in browser"
    GOTO :EOF

:ResetPrintSpooler
    CALL :LogInfo "Resetting print spooler"
    CALL :ExecuteWithElevation "net stop spooler && net start spooler"
    CALL :ShowSuccess "Print spooler has been reset"
    GOTO :EOF

:OpenDeviceManager
    CALL :LogInfo "Opening Device Manager"
    CALL :ExecuteWithElevation "devmgmt.msc"
    GOTO :EOF

:InstallISLAlwaysOn
    CALL :LogInfo "Installing ISL Always On"
    IF NOT EXIST "!CONFIG_ISL_MSI!" (
        CALL :ShowError "ISL installer not found: !CONFIG_ISL_MSI!"
        GOTO :EOF
    )
    
    CALL :ExecuteWithElevation "msiexec /i \"!CONFIG_ISL_MSI!\" /qn"
    CALL :ShowSuccess "ISL Always On installation completed"
    GOTO :EOF

:ExitScript
    CALL :LogInfo "Script exit requested by user"
    CALL :UploadLogFile
    ECHO.
    ECHO Thank you for using CAU IT Support Utility
    ECHO.
    EXIT /B 0

:: =============================================================================
:: CERTIFICATE MANAGEMENT
:: =============================================================================
:CertificateMenu
    CLS
    ECHO ==========================================
    ECHO           Digital Certificate
    ECHO             Management
    ECHO ==========================================
    ECHO.
    ECHO   1. Silent FNMT Configuration
    ECHO   2. Manual FNMT Configuration
    ECHO   3. Request Certificate
    ECHO   4. Renew Certificate
    ECHO   5. Download Certificate
    ECHO   6. Back to Main Menu
    ECHO.
    
    CALL :GetUserChoice "Select an option (1-6): " choice 1 6
    
    CALL :LogInfo "Certificate menu selection: !choice!"
    
    IF "!choice!"=="1" CALL :ConfigureFNMTSilent
    IF "!choice!"=="2" CALL :ConfigureFNMTManual
    IF "!choice!"=="3" CALL :RequestCertificate
    IF "!choice!"=="4" CALL :RenewCertificate
    IF "!choice!"=="5" CALL :DownloadCertificate
    IF "!choice!"=="6" GOTO :EOF
    
    PAUSE
    GOTO CertificateMenu

:ConfigureFNMTSilent
    CALL :LogInfo "Running silent FNMT configuration"
    IF NOT EXIST "!CONFIG_FNMT_CONFIG!" (
        CALL :ShowError "FNMT configurator not found"
        GOTO :EOF
    )
    
    CD /D "!USERPROFILE!\Downloads"
    CALL :ExecuteWithElevation "\"!CONFIG_FNMT_CONFIG!\" /S"
    CALL :ShowSuccess "FNMT configuration completed silently"
    GOTO :EOF

:ConfigureFNMTManual
    CALL :LogInfo "Running manual FNMT configuration"
    IF NOT EXIST "!CONFIG_FNMT_CONFIG!" (
        CALL :ShowError "FNMT configurator not found"
        GOTO :EOF
    )
    
    CD /D "!USERPROFILE!\Downloads"
    CALL :ExecuteWithElevation "\"!CONFIG_FNMT_CONFIG!\""
    GOTO :EOF

:RequestCertificate
    CALL :LogInfo "Opening certificate request URL"
    START chrome "!CONFIG_URL_FNMT_REQUEST!"
    GOTO :EOF

:RenewCertificate
    CALL :LogInfo "Opening certificate renewal URL"
    START chrome "!CONFIG_URL_FNMT_RENEW!"
    GOTO :EOF

:DownloadCertificate
    CALL :LogInfo "Opening certificate download URL"
    START chrome "!CONFIG_URL_FNMT_DOWNLOAD!"
    GOTO :EOF

:: =============================================================================
:: UTILITIES MENU
:: =============================================================================
:UtilitiesMenu
    CLS
    ECHO ==========================================
    ECHO              Utilities
    ECHO ==========================================
    ECHO.
    ECHO   1. Internet Options
    ECHO   2. Install Chrome 109
    ECHO   3. Fix Black Screen
    ECHO   4. Windows Version Info
    ECHO   5. Reinstall Card Reader Drivers
    ECHO   6. Install AutoFirma
    ECHO   7. Install LibreOffice
    ECHO   8. Force Time Sync
    ECHO   9. Back to Main Menu
    ECHO.
    
    CALL :GetUserChoice "Select an option (1-9): " choice 1 9
    
    CALL :LogInfo "Utilities menu selection: !choice!"
    
    IF "!choice!"=="1" CALL :OpenInternetOptions
    IF "!choice!"=="2" CALL :InstallChrome
    IF "!choice!"=="3" CALL :FixBlackScreen
    IF "!choice!"=="4" CALL :ShowWindowsVersion
    IF "!choice!"=="5" CALL :ReinstallCardReaderDrivers
    IF "!choice!"=="6" CALL :InstallAutoFirma
    IF "!choice!"=="7" CALL :InstallLibreOffice
    IF "!choice!"=="8" CALL :ForceTimeSync
    IF "!choice!"=="9" GOTO :EOF
    
    PAUSE
    GOTO UtilitiesMenu

:OpenInternetOptions
    CALL :LogInfo "Opening Internet Options"
    START inetcpl.cpl
    GOTO :EOF

:InstallChrome
    CALL :LogInfo "Installing Chrome 109"
    IF NOT EXIST "!CONFIG_CHROME_MSI!" (
        CALL :ShowError "Chrome installer not found"
        GOTO :EOF
    )
    
    CALL :ExecuteWithElevation "msiexec /i \"!CONFIG_CHROME_MSI!\" /qn"
    CALL :ShowSuccess "Chrome installation completed"
    GOTO :EOF

:FixBlackScreen
    CALL :LogInfo "Fixing black screen issue"
    DisplaySwitch.exe /internal
    TIMEOUT /T 3 /NOBREAK >NUL
    DisplaySwitch.exe /extend
    CALL :ShowSuccess "Display configuration reset"
    GOTO :EOF

:ShowWindowsVersion
    CALL :LogInfo "Showing Windows version"
    RunDll32.exe SHELL32.DLL,ShellAboutW
    GOTO :EOF

:ReinstallCardReaderDrivers
    CALL :LogInfo "Reinstalling card reader drivers"
    
    IF EXIST "!CONFIG_DRIVER_PCT!" (
        CALL :ExecuteWithElevation "\"!CONFIG_DRIVER_PCT!\""
    ) ELSE (
        CALL :LogWarning "PCT driver not found: !CONFIG_DRIVER_PCT!"
    )
    
    IF EXIST "!CONFIG_DRIVER_SATELLITE!" (
        CALL :ExecuteWithElevation "\"!CONFIG_DRIVER_SATELLITE!\""
    ) ELSE (
        CALL :LogWarning "Satellite driver not found: !CONFIG_DRIVER_SATELLITE!"
    )
    
    CALL :ShowSuccess "Driver installation completed"
    GOTO :EOF

:InstallAutoFirma
    CALL :LogInfo "Installing AutoFirma"
    
    :: Kill Chrome first
    TASKKILL /IM chrome.exe /F >NUL 2>&1
    
    IF EXIST "!CONFIG_AUTOFIRMA_EXE!" (
        CALL :ExecuteWithElevation "\"!CONFIG_AUTOFIRMA_EXE!\" /S"
    )
    
    IF EXIST "!CONFIG_AUTOFIRMA_MSI!" (
        CALL :ExecuteWithElevation "msiexec /i \"!CONFIG_AUTOFIRMA_MSI!\" /qn"
    )
    
    CALL :ShowSuccess "AutoFirma installation completed"
    GOTO :EOF

:InstallLibreOffice
    CALL :LogInfo "Installing LibreOffice"
    IF NOT EXIST "!CONFIG_LIBREOFFICE_MSI!" (
        CALL :ShowError "LibreOffice installer not found"
        GOTO :EOF
    )
    
    CALL :ExecuteWithElevation "msiexec /i \"!CONFIG_LIBREOFFICE_MSI!\" /qn"
    CALL :ShowSuccess "LibreOffice installation completed"
    GOTO :EOF

:ForceTimeSync
    CALL :LogInfo "Forcing time synchronization"
    CALL :ExecuteWithElevation "net stop w32time && w32tm /unregister && w32tm /register && net start w32time && w32tm /resync"
    CALL :ShowSuccess "Time synchronization completed"
    GOTO :EOF

:: =============================================================================
:: SYSTEM OPTIMIZATION HELPERS
:: =============================================================================
:KillBrowsers
    CALL :LogInfo "Terminating browser processes"
    TASKKILL /IM chrome.exe /F >NUL 2>&1
    TASKKILL /IM iexplore.exe /F >NUL 2>&1
    TASKKILL /IM msedge.exe /F >NUL 2>&1
    TASKKILL /IM firefox.exe /F >NUL 2>&1
    GOTO :EOF

:ClearSystemCaches
    CALL :LogInfo "Clearing system caches"
    
    :: DNS cache
    IPCONFIG /flushdns >NUL
    
    :: Internet Explorer caches
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16 2>NUL
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8 2>NUL
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2 2>NUL
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1 2>NUL
    
    :: Chrome cache (if exists)
    IF EXIST "!USERPROFILE!\AppData\Local\Google\Chrome\User Data\Default\Cache" (
        DEL /Q /S /F "!USERPROFILE!\AppData\Local\Google\Chrome\User Data\Default\Cache\*" 2>NUL
    )
    
    GOTO :EOF

:ApplyPerformanceTweaks
    CALL :LogInfo "Applying performance registry tweaks"
    
    :: Disable visual effects for performance
    CALL :ExecuteWithElevation "reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f"
    CALL :ExecuteWithElevation "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f"
    CALL :ExecuteWithElevation "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 2 /f"
    
    GOTO :EOF

:RunSystemMaintenance
    CALL :LogInfo "Running system maintenance tasks"
    
    :: Group Policy update
    GPUPDATE /force >NUL
    
    :: Install ISL
    IF EXIST "!CONFIG_ISL_MSI!" (
        CALL :ExecuteWithElevation "msiexec /i \"!CONFIG_ISL_MSI!\" /qn"
    )
    
    :: Clean temporary files
    CALL :ExecuteWithElevation "del /f /s /q \"%windir%\*.bak\" 2>NUL"
    CALL :ExecuteWithElevation "del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\" 2>NUL"
    CALL :ExecuteWithElevation "del /f /s /q \"%systemdrive%\*.tmp\" 2>NUL"
    CALL :ExecuteWithElevation "del /f /s /q \"%temp%\*.*\" 2>NUL"
    
    GOTO :EOF

:: =============================================================================
:: UTILITY FUNCTIONS
:: =============================================================================
:ExecuteWithElevation
    SETLOCAL
    SET "COMMAND=%~1"
    CALL :LogInfo "Executing with elevation: !COMMAND!"
    
    runas /user:!AD_USER!@JUSTICIA /savecred "!COMMAND!" >NUL 2>&1
    SET "EXEC_RESULT=!ERRORLEVEL!"
    
    IF !EXEC_RESULT! NEQ 0 (
        CALL :LogError "Elevated execution failed with code !EXEC_RESULT!: !COMMAND!"
    ) ELSE (
        CALL :LogInfo "Elevated execution successful: !COMMAND!"
    )
    
    ENDLOCAL & SET "ERRORLEVEL=!EXEC_RESULT!"
    GOTO :EOF

:UploadLogFile
    IF "!LOG_FILE!"=="NUL" GOTO :EOF
    
    CALL :LogInfo "Uploading log file to network"
    
    :: Ensure remote directory exists
    CALL :ExecuteWithElevation "if not exist \"!CONFIG_REMOTE_LOG_DIR!\" mkdir \"!CONFIG_REMOTE_LOG_DIR!\""
    
    :: Copy log file
    SET "REMOTE_LOG=!CONFIG_REMOTE_LOG_DIR!\!AD_USER!_!CURRENT_HOSTNAME!_!TIMESTAMP!.log"
    CALL :ExecuteWithElevation "copy /y \"!LOG_FILE!\" \"!REMOTE_LOG!\""
    
    GOTO :EOF

:: =============================================================================
:: END OF SCRIPT
:: =============================================================================