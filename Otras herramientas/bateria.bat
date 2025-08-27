
:main
@ECHO off
cls
:main
ECHO ------------------------------------------
ECHO             Bateria de pruebas              
ECHO            Creado por David Luna
ECHO ------------------------------------------
ECHO 1. Bateria pruebas
ECHO 2. Reparar imagen corrupta sistema
ECHO 3. Otros
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto Bateria_pruebas
if '%choice%'=='2' goto Repair
if '%choice%'=='3' goto other
ECHO "%choice%" is not valid, try again
ECHO.
goto start
:Bateria_pruebas
ECHO Batería de pruebas
ipconfig /flushdns
del %temp%\*.* /s /q
del C:\Windows\prefetch\*.*/s/q
cleanmgr /verylowdisk
cleanmgr /AUTOCLEAN
javac -cache-dir c:\temp\jws
javaws -clearcache
javaws -Xclearcache -silent -Xnosplash
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
runas /user:justicia\dluna cmd.exe /c rd /s /q %systemdrive%\$Recycle.bin
gpupdate /force 
::shutdown /r /t 2
goto end
:Repair
DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
goto end
:other
-------------------------------------------------------------------------------------------


cls
:start1
ECHO ------------------------------------------
ECHO               Otras herramientas    
ECHO
ECHO ------------------------------------------
ECHO 1. Ver Key Windows
ECHO 2. Ver carpetas en red y rutas
ECHO 3. Fix Reloj hora
ECHO 4. inicio
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto key
if '%choice%'=='2' goto blank
if '%choice%'=='3' goto Reloj
if '%choice%'=='4' goto main
ECHO "%choice%" is not valid, try again
ECHO.
goto start
:key
@echo off
For /F "Tokens=*" %%a in ('wmic path softwarelicensingservice get OA3xOriginalProductKey ^|findstr /r "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-"') Do (set KEY=%%a)
echo CLAVE WINDOWS: [%KEY%]
pause
cls
:start1
cls
:blank
cls
Net use
goto end
:Reloj
cls
w32tm /resync
goto end
:end
pause