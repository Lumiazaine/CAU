@ECHO OFF
ECHO.
ECHO ======================================================
ECHO          CAUJUS_dev.bat Unit Test Runner
ECHO ======================================================
ECHO.

:: Test Setup
:: ======================================================
ECHO Setting up test environment...

SET AD_ORIGINAL=%AD%
SET COMPUTERNAME_ORIGINAL=%COMPUTERNAME%
SET RUTA_LOG_ORIGINAL=%ruta_log%

SET AD=TESTUSER
SET COMPUTERNAME=TESTPC
SET "ruta_log_test=%~dp0test_logs"
SET "CAUJUS_SCRIPT_PATH=%~dp0CAUJUS_dev.bat"
SET "TEST_LOG_FILE=%ruta_log_test%\%AD%_%COMPUTERNAME%.log"

:: Override ruta_log for the CAUJUS_dev.bat script
SET "ruta_log=%ruta_log_test%"

ECHO Test User (AD): %AD%
ECHO Test PC (COMPUTERNAME): %COMPUTERNAME%
ECHO Test Log Path (ruta_log): %ruta_log%
ECHO Script to Test: %CAUJUS_SCRIPT_PATH%
ECHO Expected Log File: %TEST_LOG_FILE%
ECHO.

ECHO Creating test log directory if it doesn't exist...
IF NOT EXIST "%ruta_log_test%" (
    MKDIR "%ruta_log_test%"
    IF ERRORLEVEL 1 (
        ECHO FAILED to create test log directory: %ruta_log_test%
        GOTO TeardownAndExit
    ) ELSE (
        ECHO Test log directory created or already exists: %ruta_log_test%
    )
) ELSE (
    ECHO Test log directory already exists: %ruta_log_test%
)
ECHO.

ECHO Cleaning up previous test log file (if any)...
IF EXIST "%TEST_LOG_FILE%" (
    DEL /Q "%TEST_LOG_FILE%"
    ECHO Previous test log file deleted: %TEST_LOG_FILE%
) ELSE (
    ECHO No previous test log file to delete.
)
ECHO.
ECHO Setup complete.
ECHO ======================================================
ECHO.

:: Test Cases
:: ======================================================

:: Test Case 1: Initial Log Entry via --test-logging
ECHO Running Test Case 1: --test-logging mode
ECHO ------------------------------------------------------
CALL "%CAUJUS_SCRIPT_PATH%" --test-logging
IF ERRORLEVEL 1 (
    ECHO Test Case 1 FAILED: CAUJUS_dev.bat --test-logging returned an error.
    GOTO TeardownAndExit
)

ECHO Verifying log content...
IF NOT EXIST "%TEST_LOG_FILE%" (
    ECHO Test Case 1 FAILED: Log file not found at %TEST_LOG_FILE%
    GOTO TeardownAndExit
)

FINDSTR /C:"Test log entry from --test-logging mode" "%TEST_LOG_FILE%" >NUL
IF ERRORLEVEL 0 (
    ECHO Test Case 1 PASSED: Found expected log entry.
) ELSE (
    ECHO Test Case 1 FAILED: Did not find "Test log entry from --test-logging mode" in %TEST_LOG_FILE%
    ECHO Log content:
    TYPE "%TEST_LOG_FILE%"
)
ECHO ------------------------------------------------------
ECHO.

:: Add more test cases here if needed

:: Teardown and Exit
:: ======================================================
:TeardownAndExit
ECHO.
ECHO Restoring original environment variables...
SET AD=%AD_ORIGINAL%
SET COMPUTERNAME=%COMPUTERNAME_ORIGINAL%
SET ruta_log=%RUTA_LOG_ORIGINAL%

IF DEFINED AD_ORIGINAL (SET AD_ORIGINAL=)
IF DEFINED COMPUTERNAME_ORIGINAL (SET COMPUTERNAME_ORIGINAL=)
IF DEFINED RUTA_LOG_ORIGINAL (SET RUTA_LOG_ORIGINAL=)

ECHO.
ECHO ======================================================
ECHO                    Testing Finished
ECHO ======================================================
ECHO.

EXIT /B %ERRORLEVEL%
