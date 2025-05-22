@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

:: ============================================================================
:: Test Script for CAUJUS_dev.bat Logging Mechanism
:: ============================================================================

:: --- Configuration ---
SET "CAUJUS_SCRIPT_PATH=%~dp0CAUJUS_dev.bat"
SET "TEST_ROOT_DIR=%~dp0test_temp_logs"

SET "TEST_DEFAULT_LOG_DIR_BASE=%TEST_ROOT_DIR%\default_logs"
SET "TEST_LOCAL_LOG_DIR_BASE=%TEST_ROOT_DIR%\local_logs"
SET "TEST_CRITICAL_LOG_DIR_BASE=%TEST_ROOT_DIR%\critical_logs"

REM These ENV_ variables are the values we'll assign to TEST_OVERRIDE_... in CAUJUS_dev.bat
SET "ENV_DEFAULT_LOG_PATH=%TEST_DEFAULT_LOG_DIR_BASE%"
SET "ENV_LOCAL_LOG_PATH=%TEST_LOCAL_LOG_DIR_BASE%"
SET "ENV_CRITICAL_FALLBACK_LOG=%TEST_CRITICAL_LOG_DIR_BASE%\CAUJUS_CRITICAL.log"

SET "AD_USER_TEST=TestUser"
SET "COMPUTER_NAME_TEST=TestPC"
SET "RUNAS_USER_TEST=%AD_USER_TEST%@JUSTICIA"

SET "EXPECTED_DEFAULT_LOG_FILE=%ENV_DEFAULT_LOG_PATH%\%AD_USER_TEST%_%COMPUTER_NAME_TEST%.log"
SET "EXPECTED_LOCAL_LOG_FILE=%ENV_LOCAL_LOG_PATH%\%AD_USER_TEST%_%COMPUTER_NAME_TEST%.log"
SET "EXPECTED_DP_ADMIN_LOG_FILE=%ENV_LOCAL_LOG_PATH%\DP_ADMIN_%COMPUTER_NAME_TEST%.log"
SET "EXPECTED_CRITICAL_LOG_FILE=%ENV_CRITICAL_FALLBACK_LOG%"

SET /A TESTS_RUN=0
SET /A TESTS_FAILED=0
SET /A ASSERTIONS_FAILED_CURRENT_TEST=0

:: --- Main Test Execution ---
CALL :InitializeTestScript
ECHO.
ECHO Starting CAUJUS_dev.bat Logging Tests...
ECHO =======================================
ECHO.

CALL :Test_A1_NetworkPathWritableInit
CALL :Test_A2_NetworkPathUnwritableInit
CALL :Test_B1_NetworkLogSuccess
CALL :Test_B2_NetworkLogWriteFailure
CALL :Test_B3_LocalAdminLogging
CALL :Test_B4a_LocalLogWriteFailure
CALL :Test_B4b_LocalLogMkdirFailure
CALL :Test_C1_ExecAndLogSuccess
CALL :Test_C2_ExecAndLogError

ECHO.
ECHO =======================================
ECHO Test Run Summary:
ECHO Total Tests Run: %TESTS_RUN%
ECHO Total Tests Failed: %TESTS_FAILED%
ECHO =======================================
ECHO.

CALL :CleanupGlobal
ENDLOCAL
EXIT /B %TESTS_FAILED%

:: ============================================================================
:: Test Script Initialization and Cleanup
:: ============================================================================

:InitializeTestScript
ECHO Initializing Test Script Environment...
IF EXIST "%TEST_ROOT_DIR%" (
    ECHO Cleaning up existing test root directory: "%TEST_ROOT_DIR%"
    RMDIR /S /Q "%TEST_ROOT_DIR%"
    IF ERRORLEVEL 1 (
      ECHO FATAL: Failed to delete existing test root directory. Check for locked files.
      EXIT /B 1
    )
)
MKDIR "%TEST_ROOT_DIR%"
MKDIR "%TEST_DEFAULT_LOG_DIR_BASE%"
MKDIR "%TEST_LOCAL_LOG_DIR_BASE%"
MKDIR "%TEST_CRITICAL_LOG_DIR_BASE%"
IF NOT EXIST "%TEST_CRITICAL_LOG_DIR_BASE%" (
    ECHO FATAL: Failed to create test directories.
    EXIT /B 1
)
ECHO Initialization complete.
GOTO :EOF

:SetupTestEnvironment
SET "CURRENT_TEST_NAME=%~1"
ECHO Setting up test environment for: %CURRENT_TEST_NAME%
CALL :IncrementTestRun

REM Backup global vars
SET "BACKUP_AD=%AD%"
SET "BACKUP_COMPUTERNAME=%COMPUTERNAME%"
SET "BACKUP_RUNAS_USER=%RUNAS_USER%"
SET "BACKUP_LOG_WRITE_MODE=%LOG_WRITE_MODE%"
SET "BACKUP_TEST_OVERRIDE_DEFAULT_LOG_PATH=%TEST_OVERRIDE_DEFAULT_LOG_PATH%"
SET "BACKUP_TEST_OVERRIDE_LOCAL_LOG_PATH=%TEST_OVERRIDE_LOCAL_LOG_PATH%"
SET "BACKUP_TEST_OVERRIDE_CRITICAL_FALLBACK_LOG=%TEST_OVERRIDE_CRITICAL_FALLBACK_LOG%"
SET "BACKUP_TEST_FORCE_NETWORK_LOG_FAIL_INIT=%TEST_FORCE_NETWORK_LOG_FAIL_INIT%"
SET "BACKUP_TEST_FORCE_NETWORK_LOG_FAIL_WRITE=%TEST_FORCE_NETWORK_LOG_FAIL_WRITE%"
SET "BACKUP_TEST_FORCE_LOCAL_MKDIR_FAIL=%TEST_FORCE_LOCAL_MKDIR_FAIL%"
SET "BACKUP_TEST_FORCE_LOCAL_WRITE_FAIL=%TEST_FORCE_LOCAL_WRITE_FAIL%"

REM Set CAUJUS_dev.bat environment variables for log path overrides
SET "TEST_OVERRIDE_DEFAULT_LOG_PATH=%ENV_DEFAULT_LOG_PATH%"
SET "TEST_OVERRIDE_LOCAL_LOG_PATH=%ENV_LOCAL_LOG_PATH%"
SET "TEST_OVERRIDE_CRITICAL_FALLBACK_LOG=%ENV_CRITICAL_FALLBACK_LOG%"

REM Clear failure simulation flags by default
SET "TEST_FORCE_NETWORK_LOG_FAIL_INIT="
SET "TEST_FORCE_NETWORK_LOG_FAIL_WRITE="
SET "TEST_FORCE_LOCAL_MKDIR_FAIL="
SET "TEST_FORCE_LOCAL_WRITE_FAIL="

REM Clean log content from previous tests in the shared directories
FOR %%D IN ("%TEST_DEFAULT_LOG_DIR_BASE%" "%TEST_LOCAL_LOG_DIR_BASE%" "%TEST_CRITICAL_LOG_DIR_BASE%") DO (
    IF EXIST %%D (
        FOR /F "delims=" %%F IN ('DIR /B %%D') DO (
            IF EXIST "%%~D\%%F" DEL /F /Q "%%~D\%%F"
        )
    ) ELSE (
        MKDIR %%D
    )
)

SET "AD="
SET "COMPUTERNAME="
SET "RUNAS_USER="
SET "LOG_WRITE_MODE="
SET /A ASSERTIONS_FAILED_CURRENT_TEST=0
GOTO :EOF

:TeardownTestEnvironment
ECHO Tearing down test environment for: %CURRENT_TEST_NAME%
IF %ASSERTIONS_FAILED_CURRENT_TEST% GTR 0 (
    CALL :IncrementTestFailure
    ECHO TEST CASE: %CURRENT_TEST_NAME% --- FAILED (%ASSERTIONS_FAILED_CURRENT_TEST% assertions failed)
) ELSE (
    ECHO TEST CASE: %CURRENT_TEST_NAME% --- PASSED
)

REM Restore global vars
IF DEFINED BACKUP_AD (SET "AD=%BACKUP_AD%") ELSE (SET AD=)
IF DEFINED BACKUP_COMPUTERNAME (SET "COMPUTERNAME=%BACKUP_COMPUTERNAME%") ELSE (SET COMPUTERNAME=)
IF DEFINED BACKUP_RUNAS_USER (SET "RUNAS_USER=%BACKUP_RUNAS_USER%") ELSE (SET RUNAS_USER=)
IF DEFINED BACKUP_LOG_WRITE_MODE (SET "LOG_WRITE_MODE=%BACKUP_LOG_WRITE_MODE%") ELSE (SET LOG_WRITE_MODE=)
SET "TEST_OVERRIDE_DEFAULT_LOG_PATH=%BACKUP_TEST_OVERRIDE_DEFAULT_LOG_PATH%"
SET "TEST_OVERRIDE_LOCAL_LOG_PATH=%BACKUP_TEST_OVERRIDE_LOCAL_LOG_PATH%"
SET "TEST_OVERRIDE_CRITICAL_FALLBACK_LOG=%BACKUP_TEST_OVERRIDE_CRITICAL_FALLBACK_LOG%"
SET "TEST_FORCE_NETWORK_LOG_FAIL_INIT=%BACKUP_TEST_FORCE_NETWORK_LOG_FAIL_INIT%"
SET "TEST_FORCE_NETWORK_LOG_FAIL_WRITE=%BACKUP_TEST_FORCE_NETWORK_LOG_FAIL_WRITE%"
SET "TEST_FORCE_LOCAL_MKDIR_FAIL=%BACKUP_TEST_FORCE_LOCAL_MKDIR_FAIL%"
SET "TEST_FORCE_LOCAL_WRITE_FAIL=%BACKUP_TEST_FORCE_LOCAL_WRITE_FAIL%"

ECHO Teardown for %CURRENT_TEST_NAME% complete.
ECHO -----------------------------------------------------
GOTO :EOF

:CleanupGlobal
ECHO Performing final cleanup of test directories...
IF EXIST "%TEST_ROOT_DIR%" (
    RMDIR /S /Q "%TEST_ROOT_DIR%"
    ECHO Test root directory "%TEST_ROOT_DIR%" removed.
)
GOTO :EOF

:: ============================================================================
:: Assertion Utility Subroutines
:: ============================================================================

:AssertLogContains
SET "LOG_FILE_PATH_ASSERT=%~1"
SET "EXPECTED_TEXT_ASSERT=%~2"
SET "TEST_CASE_NAME_ASSERT=%~3"
ECHO AssertLogContains: Checking "%LOG_FILE_PATH_ASSERT%" for "%EXPECTED_TEXT_ASSERT%" [%TEST_CASE_NAME_ASSERT%]
IF NOT EXIST "%LOG_FILE_PATH_ASSERT%" (
    ECHO    [FAIL] Log file "%LOG_FILE_PATH_ASSERT%" does not exist.
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
    GOTO :EOF
)
FINDSTR /L /C:"%EXPECTED_TEXT_ASSERT%" "%LOG_FILE_PATH_ASSERT%" >NUL
IF ERRORLEVEL 1 (
    ECHO    [FAIL] Expected text "%EXPECTED_TEXT_ASSERT%" NOT found in "%LOG_FILE_PATH_ASSERT%".
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
) ELSE (
    ECHO    [PASS] Expected text "%EXPECTED_TEXT_ASSERT%" found.
)
GOTO :EOF

:AssertFileExists
SET "FILE_PATH_ASSERT=%~1"
SET "TEST_CASE_NAME_ASSERT=%~2"
ECHO AssertFileExists: Checking "%FILE_PATH_ASSERT%" [%TEST_CASE_NAME_ASSERT%]
IF EXIST "%FILE_PATH_ASSERT%" (
    ECHO    [PASS] File exists.
) ELSE (
    ECHO    [FAIL] File does NOT exist.
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
)
GOTO :EOF

:AssertFileDoesNotExist
SET "FILE_PATH_ASSERT=%~1"
SET "TEST_CASE_NAME_ASSERT=%~2"
ECHO AssertFileDoesNotExist: Checking "%FILE_PATH_ASSERT%" [%TEST_CASE_NAME_ASSERT%]
IF NOT EXIST "%FILE_PATH_ASSERT%" (
    ECHO    [PASS] File does not exist.
) ELSE (
    ECHO    [FAIL] File unexpectedly exists.
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
)
GOTO :EOF

:IncrementTestRun
SET /A TESTS_RUN+=1
GOTO :EOF

:IncrementTestFailure
SET /A TESTS_FAILED+=1
GOTO :EOF

:: ============================================================================
:: Test Cases
:: ============================================================================

:: ----------------------------------------------------------------------------
:: A. Test Logging Initialization (:initialize_logging effects)
:: ----------------------------------------------------------------------------
:Test_A1_NetworkPathWritableInit
SET "TEST_NAME=A1_NetworkPathWritableInit"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"

ECHO [%TEST_NAME%] Action: Running CAUJUS_dev.bat --test-init-minimal
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-init-minimal > NUL 2>&1

CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "INITIALIZE_LOGGING: Network log path %ENV_DEFAULT_LOG_PATH% is accessible. LOG_WRITE_MODE is NETWORK." "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Successfully created temporary check file." "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Successfully deleted temporary check file." "%TEST_NAME%"
SET "TEMP_CHECK_FILE=%ENV_DEFAULT_LOG_PATH%\%AD_USER_TEST%_%COMPUTER_NAME_TEST%_access_check.tmp"
CALL :AssertFileDoesNotExist "%TEMP_CHECK_FILE%" "%TEST_NAME% (temp check file deleted)"
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_A2_NetworkPathUnwritableInit
SET "TEST_NAME=A2_NetworkPathUnwritableInit"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "TEST_FORCE_NETWORK_LOG_FAIL_INIT=YES"

ECHO [%TEST_NAME%] Action: Running CAUJUS_dev.bat --test-init-minimal with TEST_FORCE_NETWORK_LOG_FAIL_INIT=YES
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-init-minimal > NUL 2>&1

CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "TEST_FORCE_NETWORK_LOG_FAIL_INIT is YES" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Network path %ENV_DEFAULT_LOG_PATH% not accessible/writable directly. Setting LOG_WRITE_MODE to LOCAL." "%TEST_NAME%"
CALL :TeardownTestEnvironment
GOTO :EOF

:: ----------------------------------------------------------------------------
:: B. Test Log Entry Behavior (:log_entry effects)
:: ----------------------------------------------------------------------------
:Test_B1_NetworkLogSuccess
SET "TEST_NAME=B1_NetworkLogSuccess"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=NETWORK"

ECHO [%TEST_NAME%] Action: Running --test-logging "Network success B1"
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-logging "Network success B1" > NUL 2>&1

CALL :AssertFileExists "%EXPECTED_DEFAULT_LOG_FILE%" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_DEFAULT_LOG_FILE%" "Network success B1" "%TEST_NAME%"
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_B2_NetworkLogWriteFailure
SET "TEST_NAME=B2_NetworkLogWriteFailure"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=NETWORK"
SET "TEST_FORCE_NETWORK_LOG_FAIL_WRITE=YES"

ECHO [%TEST_NAME%] Action: Running --test-logging "Network fail B2" with TEST_FORCE_NETWORK_LOG_FAIL_WRITE=YES
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-logging "Network fail B2" > NUL 2>&1

CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "TEST_FORCE_NETWORK_LOG_FAIL_WRITE is YES" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "[WARNING] Failed to write to network log" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Network fail B2" "%TEST_NAME%"
CALL :AssertFileDoesNotExist "%EXPECTED_DEFAULT_LOG_FILE%" "%TEST_NAME% (Network log should be empty or not contain this)"
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_B3_LocalAdminLogging
SET "TEST_NAME=B3_LocalAdminLogging"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=./DP_ADMIN" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=./DP_ADMIN"
REM LOG_WRITE_MODE should be forced to LOCAL by CAUJUS_dev.bat for ./DP_ADMIN

ECHO [%TEST_NAME%] Action: Running --test-init-minimal then --test-logging "Local admin B3"
REM We run --test-init-minimal first to ensure LOG_WRITE_MODE is set to LOCAL by the script logic
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-init-minimal > NUL 2>&1
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-logging "Local admin B3" > NUL 2>&1

CALL :AssertLogContains "%EXPECTED_DP_ADMIN_LOG_FILE%" "INITIALIZE_LOGGING: Mode is LOCAL as per preset. Skipping network checks." "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_DP_ADMIN_LOG_FILE%" "Local admin B3" "%TEST_NAME%"
CALL :AssertFileDoesNotExist "%ENV_DEFAULT_LOG_PATH%\DP_ADMIN_%COMPUTER_NAME_TEST%.log" "%TEST_NAME% (Network log for DP_ADMIN should not exist)"
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_B4a_LocalLogWriteFailure
SET "TEST_NAME=B4a_LocalLogWriteFailure"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=LOCAL"
SET "TEST_FORCE_LOCAL_WRITE_FAIL=YES"

ECHO [%TEST_NAME%] Action: Running --test-logging "Local write fail B4a" with TEST_FORCE_LOCAL_WRITE_FAIL=YES
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-logging "Local write fail B4a" > NUL 2>&1

CALL :AssertFileExists "%EXPECTED_CRITICAL_LOG_FILE%" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "TEST_FORCE_LOCAL_WRITE_FAIL is YES" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "[CRITICAL_ERROR] Failed to write to local log file" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "Local write fail B4a" "%TEST_NAME%"
REM Check the main local log file - it might have initialization messages but not the one that failed.
FINDSTR /L /C:"Local write fail B4a" "%EXPECTED_LOCAL_LOG_FILE%" >NUL
IF ERRORLEVEL 0 (
    ECHO    [FAIL] Text "Local write fail B4a" unexpectedly found in "%EXPECTED_LOCAL_LOG_FILE%".
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
) ELSE (
    ECHO    [PASS] Text "Local write fail B4a" NOT found in "%EXPECTED_LOCAL_LOG_FILE%", as expected.
)
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_B4b_LocalLogMkdirFailure
SET "TEST_NAME=B4b_LocalLogMkdirFailure"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=LOCAL"
SET "TEST_FORCE_LOCAL_MKDIR_FAIL=YES"

REM Ensure the local log directory is removed so mkdir is attempted by CAUJUS_dev.bat
IF EXIST "%ENV_LOCAL_LOG_PATH%" RMDIR /S /Q "%ENV_LOCAL_LOG_PATH%"

ECHO [%TEST_NAME%] Action: Running --test-logging "Local mkdir fail B4b" with TEST_FORCE_LOCAL_MKDIR_FAIL=YES
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-logging "Local mkdir fail B4b" > NUL 2>&1

CALL :AssertFileExists "%EXPECTED_CRITICAL_LOG_FILE%" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "TEST_FORCE_LOCAL_MKDIR_FAIL is YES" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "[CRITICAL_ERROR] Failed to create local log directory" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_CRITICAL_LOG_FILE%" "Local mkdir fail B4b" "%TEST_NAME%"
CALL :AssertFileDoesNotExist "%EXPECTED_LOCAL_LOG_FILE%" "%TEST_NAME% (Local log file should not be created if mkdir failed)"
CALL :TeardownTestEnvironment
GOTO :EOF

:: ----------------------------------------------------------------------------
:: C. Test :ExecAndLog
:: ----------------------------------------------------------------------------
:Test_C1_ExecAndLogSuccess
SET "TEST_NAME=C1_ExecAndLogSuccess"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=LOCAL"

ECHO [%TEST_NAME%] Action: Running --test-execandlog-success
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-execandlog-success > NUL 2>&1

CALL :AssertFileExists "%EXPECTED_LOCAL_LOG_FILE%" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Executing: ping -n 1 127.0.0.1" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Pinging 127.0.0.1 with 32 bytes of data:" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Reply from 127.0.0.1: bytes=32" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Command finished with errorlevel: 0" "%TEST_NAME%"
CALL :TeardownTestEnvironment
GOTO :EOF

:Test_C2_ExecAndLogError
SET "TEST_NAME=C2_ExecAndLogError"
CALL :SetupTestEnvironment "%TEST_NAME%"
SET "AD=%AD_USER_TEST%" & SET "COMPUTERNAME=%COMPUTER_NAME_TEST%" & SET "RUNAS_USER=%RUNAS_USER_TEST%"
SET "LOG_WRITE_MODE=LOCAL"

ECHO [%TEST_NAME%] Action: Running --test-execandlog-error
CMD /C "%CAUJUS_SCRIPT_PATH%" --test-execandlog-error > NUL 2>&1
SET "CMD_SCRIPT_ERRORLEVEL=%ERRORLEVEL%"

CALL :AssertFileExists "%EXPECTED_LOCAL_LOG_FILE%" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "Executing: an_invalid_command_that_should_fail" "%TEST_NAME%"
CALL :AssertLogContains "%EXPECTED_LOCAL_LOG_FILE%" "is not recognized as an internal or external command" "%TEST_NAME%"

SET "FOUND_ERRORLEVEL_IN_LOG=0"
FINDSTR /L /C:"Command finished with errorlevel: 1" "%EXPECTED_LOCAL_LOG_FILE%" >NUL
IF ERRORLEVEL 0 SET "FOUND_ERRORLEVEL_IN_LOG=1"
FINDSTR /L /C:"Command finished with errorlevel: 9009" "%EXPECTED_LOCAL_LOG_FILE%" >NUL
IF ERRORLEVEL 0 SET "FOUND_ERRORLEVEL_IN_LOG=1"

IF "!FOUND_ERRORLEVEL_IN_LOG!"=="1" (
    ECHO    [PASS] Expected errorlevel (1 or 9009) found in log.
) ELSE (
    ECHO    [FAIL] Expected errorlevel (1 or 9009) NOT found in log. Logged:
    FINDSTR /L /C:"Command finished with errorlevel:" "%EXPECTED_LOCAL_LOG_FILE%"
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
)

IF NOT "!CMD_SCRIPT_ERRORLEVEL!"=="0" (
    ECHO    [PASS] CAUJUS_dev.bat exited with non-zero errorlevel (%CMD_SCRIPT_ERRORLEVEL%) as expected.
) ELSE (
    ECHO    [FAIL] CAUJUS_dev.bat exited with 0, but expected non-zero for invalid command.
    SET /A ASSERTIONS_FAILED_CURRENT_TEST+=1
)
CALL :TeardownTestEnvironment
GOTO :EOF
