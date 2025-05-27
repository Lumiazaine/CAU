@ECHO off
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
:: Variable AD
:check
cls
@ECHO off
set AD=
if not defined AD (
    set /p "AD=introduce tu AD:"
)
for /f "tokens=2 delims=\" %%i in ('whoami') do set Perfil=%%i
set "LOG_DIR=%TEMP%\CAUJUS_Logs"
FOR /F "usebackq" %%j IN (`hostname`) DO SET CURRENT_COMPUTERNAME_FOR_LOG=%%j
set "YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "HHMMSS=%HHMMSS: =0%"
set "LOG_FILE=%LOG_DIR%\%AD%_%CURRENT_COMPUTERNAME_FOR_LOG%_%YYYYMMDD%_%HHMMSS%.log"

REM Create Log Directory if it doesn't exist
IF NOT EXIST "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
    ECHO %YYYYMMDD% %HHMMSS% - INFO - Log directory created: %LOG_DIR% >> "%LOG_FILE%"
) ELSE (
    ECHO %YYYYMMDD% %HHMMSS% - INFO - Log directory already exists: %LOG_DIR% >> "%LOG_FILE%"
)
ECHO %YYYYMMDD% %HHMMSS% - INFO - Script CAUJUS.bat started. User: %AD%, Profile: %Perfil%, Machine: %CURRENT_COMPUTERNAME_FOR_LOG%. Logging to: %LOG_FILE% >> "%LOG_FILE%"
cls
goto main
:: Datos equipos
:main
cls
FOR /F "usebackq" %%i IN (`hostname`) DO SET computerName=%%i
FOR /F "Tokens=1* Delims==" %%g In ('WMIC BIOS Get SerialNumber /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET sn=%%i
FOR /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set networkIP=%%a
FOR /F "Tokens=1* Delims==" %%g In ('wmic os get caption /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET win=%%i
FOR /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do (set versionSO=%%B)
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - System Info: User: %Perfil%, AD User: %AD%, Computer: %computerName%, SN: %sn%, IP: %networkIP%, OS: %win% (%versionSO%), Script Version: 2504 >> "%LOG_FILE%"
:check
cls
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO ------------------------------------------
echo(
ECHO Usuario: %Perfil%
ECHO Usuario AD utilizado: %AD%
ECHO Nombre equipo: %computerName%
ECHO Numero de serie: %sn%
ECHO Numero de IP: %networkIP%
ECHO Version: %win%, con la compilacion %versionSO%
ECHO Version Script: 2504
echo(
ECHO 1. Bateria pruebas
ECHO 2. Cambiar password correo
ECHO 3. Reiniciar cola impresion
ECHO 4. Administrador de dispositivos (desinstalar drivers)
ECHO 5. Certificado digital
ECHO 6. ISL Allways on
ECHO 7. Utilidades
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Main menu: User selected option %choice%. Referring to %choice% value. >> "%LOG_FILE%"
if '%choice%'=='1' goto Batery_test
if '%choice%'=='2' goto mail_pass
if '%choice%'=='3' goto print_pool
if '%choice%'=='4' goto Driver_admin
if '%choice%'=='5' goto Cert
if '%choice%'=='6' goto isl
if '%choice%'=='7' goto Bmenu
ECHO "%choice%" opcion no valida, intentalo de nuevo
ECHO.
goto main
del /q "%~f0"
:Batery_test
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting Batery_test. >> "%LOG_FILE%"
taskkill /IM chrome.exe /F > nul 2>&1
taskkill /IM iexplore.exe /F > nul 2>&1
taskkill /IM msedge.exe /F > nul 2>&1
ipconfig /flushdns
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
del /q /s /f "E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Control Panel\Desktop\WindowMetrics\" /v MinAnimate /t REG_SZ /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\" /v TaskbarAnimations /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 2 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v VisualFXSetting /t REG_DWORD /d 2 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ComboBoxAnimation /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v CursorShadow /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v DropShadow /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v ListBoxSmoothScrolling /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v MenuAnimation /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v SelectionFade /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v TooltipAnimation /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\" /v Fade /t REG_DWORD /d 0 /f"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Running gpupdate /force in Batery_test. >> "%LOG_FILE%"
gpupdate /force
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%windir%\*.bak\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\*.bak\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c del /f /s /q \"%systemdrive%\*.old\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.old\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Prompting for restart in Batery_test. >> "%LOG_FILE%"
echo Reiniciar equipo (s/n)
choice /c sn /n
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Script self-deleting and exiting. Triggered in section near/after label: Batery_test_RestartChoice. >> "%LOG_FILE%"

set "L_YYYYMMDD_UPLOAD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS_UPLOAD=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS_UPLOAD=%L_HHMMSS_UPLOAD: =0%"
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Preparing to upload log file %LOG_FILE% to network. >> "%LOG_FILE%"

set "FINAL_LOG_DIR=\\iusnas05\SIJ\CAU-2012\logs"
set "FINAL_LOG_FILENAME=%AD%_%CURRENT_COMPUTERNAME_FOR_LOG%_%YYYYMMDD%_%HHMMSS%.log"
set "FINAL_LOG_PATH=%FINAL_LOG_DIR%\%FINAL_LOG_FILENAME%"

REM Ensure FINAL_LOG_DIR exists on the network using RUNAS
runas /user:%AD%@JUSTICIA /savecred "cmd /c IF NOT EXIST "%FINAL_LOG_DIR%" mkdir "%FINAL_LOG_DIR%"" >> "%LOG_FILE%" 2>&1

ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Attempting to copy log from %LOG_FILE% to %FINAL_LOG_PATH% using RUNAS. >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c copy /Y "%LOG_FILE%" "%FINAL_LOG_PATH%"" >> "%LOG_FILE%" 2>&1
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Log upload attempt finished. >> "%LOG_FILE%"

if errorlevel 2 del "%~f0" & exit
if errorlevel 1 shutdown /r /t 0
@echo off
:mail_pass
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting mail_pass. Opening URL. >> "%LOG_FILE%"
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Script self-deleting and exiting. Triggered in section near/after label: mail_pass_Exit. >> "%LOG_FILE%"

set "L_YYYYMMDD_UPLOAD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS_UPLOAD=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS_UPLOAD=%L_HHMMSS_UPLOAD: =0%"
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Preparing to upload log file %LOG_FILE% to network. >> "%LOG_FILE%"

set "FINAL_LOG_DIR=\\iusnas05\SIJ\CAU-2012\logs"
set "FINAL_LOG_FILENAME=%AD%_%CURRENT_COMPUTERNAME_FOR_LOG%_%YYYYMMDD%_%HHMMSS%.log"
set "FINAL_LOG_PATH=%FINAL_LOG_DIR%\%FINAL_LOG_FILENAME%"

REM Ensure FINAL_LOG_DIR exists on the network using RUNAS
runas /user:%AD%@JUSTICIA /savecred "cmd /c IF NOT EXIST "%FINAL_LOG_DIR%" mkdir "%FINAL_LOG_DIR%"" >> "%LOG_FILE%" 2>&1

ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Attempting to copy log from %LOG_FILE% to %FINAL_LOG_PATH% using RUNAS. >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c copy /Y "%LOG_FILE%" "%FINAL_LOG_PATH%"" >> "%LOG_FILE%" 2>&1
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Log upload attempt finished. >> "%LOG_FILE%"

del "%~f0" & exit
goto main
:print_pool
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting print_pool. Resetting printer queues. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\" >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\""
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Script self-deleting and exiting. Triggered in section near/after label: print_pool_Exit. >> "%LOG_FILE%"

set "L_YYYYMMDD_UPLOAD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS_UPLOAD=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS_UPLOAD=%L_HHMMSS_UPLOAD: =0%"
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Preparing to upload log file %LOG_FILE% to network. >> "%LOG_FILE%"

set "FINAL_LOG_DIR=\\iusnas05\SIJ\CAU-2012\logs"
set "FINAL_LOG_FILENAME=%AD%_%CURRENT_COMPUTERNAME_FOR_LOG%_%YYYYMMDD%_%HHMMSS%.log"
set "FINAL_LOG_PATH=%FINAL_LOG_DIR%\%FINAL_LOG_FILENAME%"

REM Ensure FINAL_LOG_DIR exists on the network using RUNAS
runas /user:%AD%@JUSTICIA /savecred "cmd /c IF NOT EXIST "%FINAL_LOG_DIR%" mkdir "%FINAL_LOG_DIR%"" >> "%LOG_FILE%" 2>&1

ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Attempting to copy log from %LOG_FILE% to %FINAL_LOG_PATH% using RUNAS. >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c copy /Y "%LOG_FILE%" "%FINAL_LOG_PATH%"" >> "%LOG_FILE%" 2>&1
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Log upload attempt finished. >> "%LOG_FILE%"

del "%~f0" & exit
:Driver_admin
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting Driver_admin. Opening Device Manager. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: RunDll32.exe devmgr.dll DeviceManager_Execute >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "RunDll32.exe devmgr.dll DeviceManager_Execute"
goto main
:isl
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting isl. Installing ISL Always On. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
goto main
:Cert
cls
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
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Cert menu: User selected option %choice%. Referring to %choice% value. >> "%LOG_FILE%"
if '%choice%'=='1' goto configurators
if '%choice%'=='2' goto configurator
if '%choice%'=='3' goto solicitude
if '%choice%'=='4' goto renew
if '%choice%'=='5' goto download
if '%choice%'=='6' goto main
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Cert
:configurators
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting configurators. Silent FNMT configuration. >> "%LOG_FILE%"
cd %userprofile%\downloads
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_5.0.0_64bits.exe /S"
goto Cert
:configurator
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting configurator. Manual FNMT configuration. >> "%LOG_FILE%"
cd %userprofile%\downloads
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_5.0.0_64bits.exe"
goto Cert
:solicitude
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting solicitude. Opening certificate request URL. >> "%LOG_FILE%"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
goto Cert
:renew
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting renew. Opening certificate renewal URL. >> "%LOG_FILE%"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
goto Cert
:download
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting download. Opening certificate download URL. >> "%LOG_FILE%"
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
goto Cert
:Bmenu
cls
:Bmenu
cls
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
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Bmenu menu: User selected option %choice%. Referring to %choice% value. >> "%LOG_FILE%"
if '%choice%'=='1' goto ieopcion
if '%choice%'=='2' goto chrome
if '%choice%'=='3' goto black_screen
if '%choice%'=='4' goto winver
if '%choice%'=='5' goto tarjetadrv
if '%choice%'=='6' goto autof
if '%choice%'=='7' goto libreoff
if '%choice%'=='8' goto horafec
if '%choice%'=='9' goto main
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Bmenu
:black_screen
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting black_screen. Fixing black screen issue. >> "%LOG_FILE%"
DisplaySwitch.exe /internal
timeout /t 3
DisplaySwitch.exe /extend
goto main
:autof
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting autof. Installing AutoFirma. >> "%LOG_FILE%"
taskkill /IM chrome.exe /F > nul 2>&1
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: \\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn"
goto main
:ieopcion
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting ieopcion. Opening Internet Options. >> "%LOG_FILE%"
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
goto main
:chrome
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting chrome. Installing Chrome 109. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn"
goto main
:winver
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting winver. Displaying Windows version. >> "%LOG_FILE%"
RunDll32.exe SHELL32.DLL,ShellAboutW
goto main
:tarjetadrv
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting tarjetadrv. Reinstalling card reader drivers. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: \\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe >> "%LOG_FILE%"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"  
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: \\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe >> "%LOG_FILE%"
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
goto main
:horafec
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting horafec. Forcing date and time sync. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: net stop w32time >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "net stop w32time"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: w32tm /unregister >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "w32tm /unregister"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: w32tm /register >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "w32tm /register"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: net start w32time >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "net start w32time"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: w32tm /resync >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "w32tm /resync"
goto main
:libreoff
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting libreoff. Installing LibreOffice. >> "%LOG_FILE%"
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - RUNAS: Attempting to execute: cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn"
goto main
:desinstalador_tarjetas
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Action: Starting desinstalador_tarjetas. Uninstalling unknown/reader drivers. >> "%LOG_FILE%"
@echo off
:remove_drivers
FOR /F "tokens=3,*" %%a in ('pnputil /enum-drivers ^| find "Nombre publicado"') DO (
    rem %%b contiene el identificador del controlador (p.ej. oemXX.inf)
    echo %%b | findstr /I /C:"desconocido" /C:"lector" >nul
    if not errorlevel 1 (
         echo Eliminando el controlador %%b...
         pnputil /delete-driver %%b /uninstall /force
         CLS
    )
)
set "L_YYYYMMDD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS=%L_HHMMSS: =0%"
ECHO %L_YYYYMMDD% %L_HHMMSS% - INFO - Script self-deleting and exiting. Triggered in section near/after label: remove_drivers_Exit. >> "%LOG_FILE%"

set "L_YYYYMMDD_UPLOAD=%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%"
set "L_HHMMSS_UPLOAD=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "L_HHMMSS_UPLOAD=%L_HHMMSS_UPLOAD: =0%"
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Preparing to upload log file %LOG_FILE% to network. >> "%LOG_FILE%"

set "FINAL_LOG_DIR=\\iusnas05\SIJ\CAU-2012\logs"
set "FINAL_LOG_FILENAME=%AD%_%CURRENT_COMPUTERNAME_FOR_LOG%_%YYYYMMDD%_%HHMMSS%.log"
set "FINAL_LOG_PATH=%FINAL_LOG_DIR%\%FINAL_LOG_FILENAME%"

REM Ensure FINAL_LOG_DIR exists on the network using RUNAS
runas /user:%AD%@JUSTICIA /savecred "cmd /c IF NOT EXIST "%FINAL_LOG_DIR%" mkdir "%FINAL_LOG_DIR%"" >> "%LOG_FILE%" 2>&1

ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Attempting to copy log from %LOG_FILE% to %FINAL_LOG_PATH% using RUNAS. >> "%LOG_FILE%"
runas /user:%AD%@JUSTICIA /savecred "cmd /c copy /Y "%LOG_FILE%" "%FINAL_LOG_PATH%"" >> "%LOG_FILE%" 2>&1
ECHO %L_YYYYMMDD_UPLOAD% %L_HHMMSS_UPLOAD% - INFO - Log upload attempt finished. >> "%LOG_FILE%"

del "%~f0" & exit
goto main
