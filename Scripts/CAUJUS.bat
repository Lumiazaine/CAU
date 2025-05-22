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
taskkill /IM chrome.exe /F > nul 2>&1
taskkill /IM iexplore.exe /F > nul 2>&1
taskkill /IM msedge.exe /F > nul 2>&1
ipconfig /flushdns
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
del /q /s /f "E:\Users\%Perfil%\AppData\Local\Google\Chrome\User Data\Default\Cache\*"
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
@echo off
:mail_pass
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
del "%~f0" & exit
goto main
:print_pool
runas /user:%AD%@JUSTICIA /savecred "cmd /c FOR /F \"tokens=3,*\" %%a in ('cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnmngr.vbs -l ^| find \"Nombre de impresora\"') DO cscript c:\\windows\\System32\\printing_Admin_Scripts\\es-ES\\prnqctl.vbs -m -p \"%%b\""
del "%~f0" & exit
:Driver_admin
runas /user:%AD%@JUSTICIA /savecred "RunDll32.exe devmgr.dll DeviceManager_Execute"
goto main
:isl
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
cd %userprofile%\downloads
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe /S"
goto Cert
:configurator
cd %userprofile%\downloads
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_4.0.6_64bits.exe"
goto Cert
:solicitude
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
goto Cert
:renew
start chrome "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
goto Cert
:download
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
DisplaySwitch.exe /internal
timeout /t 3
DisplaySwitch.exe /extend
goto main
:autof
taskkill /IM chrome.exe /F > nul 2>&1
runas /user:%AD%@JUSTICIA /savecred "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe /S"
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi\" /qn"
goto main
:ieopcion
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
goto main
:chrome
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi\" /qn"
goto main
:winver
RunDll32.exe SHELL32.DLL,ShellAboutW
goto main
:tarjetadrv
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"  
runas /user:%AD%@justicia /savecred "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
goto main
:horafec
runas /user:%AD%@JUSTICIA /savecred "net stop w32time"
runas /user:%AD%@JUSTICIA /savecred "w32tm /unregister"
runas /user:%AD%@JUSTICIA /savecred "w32tm /register"
runas /user:%AD%@JUSTICIA /savecred "net start w32time"
runas /user:%AD%@JUSTICIA /savecred "w32tm /resync"
goto main
:libreoff
runas /user:%AD%@JUSTICIA /savecred "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi\" /qn"
goto main
:desinstalador_tarjetas
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
del "%~f0" & exit
goto main