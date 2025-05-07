@ECHO off
:: ——— CONFIGURACIÓN DE LOG ———
set "LOG_DIR=C:\Logs"
if not exist "%LOG_DIR%" md "%LOG_DIR%"

call :GetDateTime
set "LOG_FILE=%LOG_DIR%\%~n0_%COMPUTERNAME%_%YYYY%-%MM%-%DD%_%hh%-%mm%-%ss%.log"

call :GetSeconds START_SEC

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
for /f "tokens=2 delims=\\" %%i in ('whoami') do set Perfil=%%i
cls
goto main

:: Datos equipos
:main
cls
FOR /F "usebackq" %%i IN (`hostname`) DO SET computerName=%%i
FOR /F "Tokens=1* Delims==" %%g In ('WMIC BIOS Get SerialNumber /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET sn=%%i
FOR /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set networkIP=%%a
FOR /F "Tokens=1* Delims==" %%g In ('wmic os get caption /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET win=%%i
FOR /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\\...T\CurrentVersion" /v CurrentBuildNumber') do (set versionSO=%%B)
:menu
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
ECHO Version Script: 2505
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
:Batery_test
...   (continúa tu lógica existente de subrutas y acciones)
taskkill /IM chrome.exe /F > nul 2>&1
taskkill /IM iexplore.exe /F > nul 2>&1
taskkill /IM msedge.exe /F > nul 2>&1
ipconfig /flushdns
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
del /q /s /f "E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
gpupdate /force
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\*.bak\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%windir%\SoftwareDistribution\Download\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.tmp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*._mp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.gid\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.chk\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c del /f /s /q \"%systemdrive%\*.old\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Microsoft\Windows\cookies\" del /f /s /q \"%appdata%\Microsoft\Windows\cookies\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\Temporary Internet Files\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCache\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCache\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Windows\INetCookies\" del /f /s /q \"%appdata%\Local\Microsoft\Windows\INetCookies\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\" del /f /s /q \"%appdata%\Local\Microsoft\Terminal Server Client\Cache\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%appdata%\Local\CrashDumps\" del /f /s /q \"%appdata%\Local\CrashDumps\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temporary Internet Files\" del /f /s /q \"%userprofile%\Local Settings\Temporary Internet Files\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" del /f /s /q \"%userprofile%\Local Settings\Temp\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\AppData\Local\Temp\" del /f /s /q \"%userprofile%\AppData\Local\Temp\*.*\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%userprofile%\Local Settings\Temp\" rmdir /s /q \"%userprofile%\Local Settings\Temp\" & md \"%userprofile%\Local Settings\Temp\""
runas /user:%AD%@JUSTICIA /savecred "cmd.exe /c if exist \"%windir%\Temp\" rmdir /s /q \"%windir%\Temp\" & md \"%windir%\Temp\""
echo Reiniciar equipo (s/n)
choice /c sn /n
if errorlevel 2 del "%~f0" & exit
if errorlevel 1 shutdown /r /t 0
:: ——————————————————————————————————————————————
:GetDateTime
  rem Parsear %date% (asumiendo formato DD/MM/YYYY o D/M/YYYY)
  for /f "tokens=1-3 delims=/. " %%D in ("%date%") do (
    set "DD=%%D" & set "MM=%%E" & set "YYYY=%%F"
  )
  rem Parsear %time% (asumiendo hh:mm:ss.cc o h:mm:ss.cc)
  for /f "tokens=1-3 delims=:. " %%h in ("%time%") do (
    set "hh=%%h" & set "mm=%%i" & set "ss=%%j"
  )
  rem Asegurar dobles dígitos
  if %hh% LSS 10 set "hh=0%%hh%%"
  if %mm% LSS 10 set "mm=0%%mm%%"
  if %ss% LSS 10 set "ss=0%%ss%%"
  set "TIMESTAMP=%YYYY%-%MM%-%DD% %hh%:%mm%:%ss%"
  goto :eof

:GetSeconds
  rem %~1 = nombre de variable (START_SEC o END_SEC)
  for /f "tokens=1-3 delims=:. " %%h in ("%time%") do (
    set "H=%%h" & set "M=%%i" & set "S=%%j"
  )
  if %H% LSS 10 set "H=0%%H%%"
  if %M% LSS 10 set "M=0%%M%%"
  if %S% LSS 10 set "S=0%%S%%"
  set /a TOTAL=H*3600 + M*60 + S
  set "%~1=%TOTAL%"
  goto :eof

:Log
  rem call :Log "mensaje"
  setlocal enabledelayedexpansion
  call :GetDateTime
  >>"%LOG_FILE%" echo [!TIMESTAMP!] %~1
  endlocal
  goto :eof