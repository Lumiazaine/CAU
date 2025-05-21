@ECHO OFF
set TEST_START_TIME=%TIME%
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
ECHO Running Test Case 1: Basic Log Functionality Test
ECHO   Purpose: Verify that CAUJUS_dev.bat creates a log entry when called with --test-logging.
ECHO   Action: Calling CAUJUS_dev.bat --test-logging
ECHO ------------------------------------------------------
CALL "%CAUJUS_SCRIPT_PATH%" --test-logging
IF ERRORLEVEL 1 (
    ECHO Test Case 1 FAILED: CAUJUS_dev.bat --test-logging returned an error.
    GOTO TeardownAndExit
)

ECHO Verifying log content for Test Case 1...
IF NOT EXIST "%TEST_LOG_FILE%" (
    ECHO Test Case 1 FAILED: Log file not found at %TEST_LOG_FILE%
    GOTO TeardownAndExit
)

FINDSTR /C:"Test log entry from --test-logging mode" "%TEST_LOG_FILE%" >NUL
IF ERRORLEVEL 0 (
    ECHO Test Case 1 PASSED: Found expected log entry "Test log entry from --test-logging mode".
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

set TEST_END_TIME=%TIME%
set /A T_START_H=1%TEST_START_TIME:~0,2% - 100
set /A T_START_M=1%TEST_START_TIME:~3,2% - 100
set /A T_START_S=1%TEST_START_TIME:~6,2% - 100
set /A T_START_CS=1%TEST_START_TIME:~9,2% - 100
set /A T_START_TOTAL_CS=(%T_START_H%*360000) + (%T_START_M%*6000) + (%T_START_S%*100) + %T_START_CS%

set /A T_END_H=1%TEST_END_TIME:~0,2% - 100
set /A T_END_M=1%TEST_END_TIME:~3,2% - 100
set /A T_END_S=1%TEST_END_TIME:~6,2% - 100
set /A T_END_CS=1%TEST_END_TIME:~9,2% - 100
set /A T_END_TOTAL_CS=(%T_END_H%*360000) + (%T_END_M%*6000) + (%T_END_S%*100) + %T_END_CS%

IF %T_END_TOTAL_CS% LSS %T_START_TOTAL_CS% (
    set /A T_END_TOTAL_CS = %T_END_TOTAL_CS% + (24 * 360000)
)
set /A T_DURATION_CS=%T_END_TOTAL_CS% - %T_START_TOTAL_CS%

set /A T_DURATION_S = %T_DURATION_CS% / 100
set /A T_DURATION_DEC = %T_DURATION_CS% %% 100
IF %T_DURATION_DEC% LSS 10 set T_DURATION_DEC=0%T_DURATION_DEC%

set /A T_DURATION_M = %T_DURATION_S% / 60
set /A T_DURATION_S_REM = %T_DURATION_S% %% 60
IF %T_DURATION_S_REM% LSS 10 set T_DURATION_S_REM=0%T_DURATION_S_REM%

set /A T_DURATION_H = %T_DURATION_M% / 60
set /A T_DURATION_M_REM = %T_DURATION_M% %% 60
IF %T_DURATION_M_REM% LSS 10 set T_DURATION_M_REM=0%T_DURATION_M_REM%

ECHO Total test script execution time: %T_DURATION_H%:%T_DURATION_M_REM%:%T_DURATION_S_REM%.%T_DURATION_DEC%
ECHO.

EXIT /B %ERRORLEVEL%
