
:main
@ECHO off
cls
:main
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO         Creado por David Luna
ECHO ------------------------------------------
Hostname
ipconfig | findstr /i "ipv4"
ECHO 1. Bateria pruebas
ECHO 2. Reparacion equipo (25 min aprox)
ECHO 3. Enlaces
ECHO 4. Otros
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto Bateria_pruebas
if '%choice%'=='2' goto Repair
if '%choice%'=='3' goto enlaces
if '%choice%'=='4' goto other
ECHO "%choice%" is not valid, try again
ECHO.
goto start
:Bateria_pruebas
taskkill /IM chrome.exe /F > nul 2>&1
taskkill /IM iexplore.exe /F > nul 2>&1
taskkill /IM msedge.exe /F > nul 2>&1
ipconfig /flushdns
rd /s /q %temp%
explorer %temp%
javac -cache-dir c:\temp\jws
javaws -clearcache
javaws -Xclearcache -silent -Xnosplash
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
rd /s /q %systemdrive%\$Recycle.bin 
rd /s /q $Recycle.Bin
gpupdate /force
shutdown /r /t 2
goto end
:Repair
DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
gpupdate /force
shutdown /r /t 2
goto start
:enlaces
ECHO 1. Cambio password correo
ECHO 2. Correo corporativo
ECHO 3. SIRAJ2
ECHO 4. Lexnet
ECHO 5. inicio
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto link1
if '%choice%'=='2' goto link2
if '%choice%'=='3' goto link3
if '%choice%'=='4' goto link4
if '%choice%'=='5' goto main
ECHO "%choice%" is not valid, try again
ECHO.
goto start
:link1
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
goto enlaces
:link2
start chrome "https://correo.juntadeandalucia.es/"
goto enlaces
:link3
start chrome "https://cas.justicia.es/cas/login?service=https%3A%2F%2Fsiraj2.justicia.es%2FSIRAJGLB-webapp%2Fj_spring_cas_security_check"
goto enlaces
:link4
start chrome "https://lexnet.justicia.es/"
goto enlaces
cls
:other
cls
ECHO ------------------------------------------
ECHO            Otras herramientas    
ECHO ------------------------------------------
ECHO 1. Ver Key Windows
ECHO 2. Restablecer cola impresion
ECHO 3. Resolucion pantalla
ECHO 4. Administrador de dispositivos
ECHO 5. Ver version
ECHO 6. Opciones internet
ECHO 7. inicio
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto key
if '%choice%'=='2' goto pool
if '%choice%'=='3' goto screen
if '%choice%'=='4' goto driver
if '%choice%'=='5' goto version
if '%choice%'=='6' goto ieopcion
if '%choice%'=='7' goto main
ECHO "%choice%" is not valid, try again
ECHO.
goto start
:key
@echo off
For /F "Tokens=*" %%a in ('wmic path softwarelicensingservice get OA3xOriginalProductKey ^|findstr /r "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-"') Do (set KEY=%%a)
echo CLAVE WINDOWS: [%KEY%]
pause
cls
goto other
cls
:pool
runas /user:DLUNA@JUSTICIA "net stop spooler"
runas /user:DLUNA@JUSTICIA rd /s /q C:\Windows\System32\spool\PRINTERS\
runas /user:DLUNA@JUSTICIA net start spooler
goto other
:screen
rundll32.exe shell32.dll,Control_RunDLL desk.cpl
goto other
:driver
runas /user:DLUNA@JUSTICIA RunDll32.exe devmgr.dll DeviceManager_Execute
goto other
:version
RunDll32.exe SHELL32.DLL,ShellAboutW
goto other
:ieopcion
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
goto other
goto end
:end
pause