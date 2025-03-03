@ECHO off
for /f "tokens=*" %%A in ('hostname') do set "hostname=%%A"
if "%hostname%"=="IUSSWRDPCAU01" (
    cls
    echo Las palabras del CAU01 resuenan en tu cabeza ahora mismo: "los script en la maquina de salto no."
    pause
    exit
) else (
    goto check
)
:check
cls
@ECHO off
set AD=dlunag
if not defined AD (
    set /p "AD=introduce tu AD:"
)
cls
goto main
:main
cls
REM Captura el nombre de equipo.
FOR /F "usebackq" %%i IN (`hostname`) DO SET computerName=%%i

REM Captura el numero de serie del equipo.
FOR /F "Tokens=1* Delims==" %%g In ('WMIC BIOS Get SerialNumber /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET sn=%%i

REM Captura la IP del equipo.
FOR /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set networkIP=%%a

REM Captura el sistema operativo.
FOR /F "Tokens=1* Delims==" %%g In ('wmic os get caption /Value') Do FOR /F "Tokens=*" %%i In ("%%h") Do SET win=%%i

REM Captura la version del sistema opetativo.
FOR /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do (set versionSO=%%B)

ECHO ------------------------------------------
ECHO                  CAU                 
ECHO ------------------------------------------
echo(
ECHO Usuario AD utilizado: %AD%
ECHO Nombre equipo: %computerName%
ECHO Numero de serie: %sn%
ECHO Numero de IP: %networkIP%
ECHO Posee instalado: %win%, con la compilacion %versionSO%
echo(
ECHO 1. Bateria pruebas
ECHO 2. Cambiar password correo
ECHO 3. Reiniciar cola impresion
ECHO 4. Administrador de dispositivos (desinstalar drivers)
ECHO 5. Certificado digital
ECHO 6. ISL Allways on
ECHO 7. Otros
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
javac -cache-dir c:\temp\jws
javaws -clearcache
javaws -Xclearcache -silent -Xnosplash
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
gpupdate /force
rd /s /q %temp% 2>nul
runas /user:%AD%@JUSTICIA "rd /s /q C:\Windows\Temp 2>nul"
runas /user:%AD%@JUSTICIA "rd /s /q C:\Windows\Prefetch 2>nul"
echo Reiniciar equipo (s/n)
choice /c sn /n
if errorlevel 1 shutdown /r /t 0
@echo off
del "%~f0" & exit
:mail_pass
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
del "%~f0" & exit
goto main
REM "Aporte hecho por Tomás para eliminar cola de impresión"
:print_pool
FOR /F "tokens=3,*" %%a in ('cscript c:windows\System32\printing_Admin_Scripts\es-ES\prnmngr.vbs -l ^| find "Nombre de impresora"') DO cscript c:windows\System32\printing_Admin_Scripts\es-ES\prnqctl.vbs -m -p "%%b" & CLS
del "%~f0" & exit
:Driver_admin
runas /user:%AD%@JUSTICIA "RunDll32.exe devmgr.dll DeviceManager_Execute"
del "%~f0" & exit
:isl
runas /user:%AD%@JUSTICIA "cmd /c msiexec /i \"\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi\" /qn"
goto main
:Cert
cls
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO       Renovar certificado digital
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
start chrome "https://descargas.cert.fnmt.es/Windows/Configurador_FNMT_4.0.6_64bits.exe"
runas /user:%AD%@JUSTICIA "%userprofile%\downloads\Configurador_FNMT_4.0.6_64bits.exe /S"
goto Cert
:configurator
cd %userprofile%\downloads
start chrome "https://descargas.cert.fnmt.es/Windows/Configurador_FNMT_4.0.6_64bits.exe"
runas /user:%AD%@JUSTICIA "%userprofile%\downloads\Configurador_FNMT_4.0.6_64bits.exe"
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
ECHO             Otras opciones             
ECHO ------------------------------------------
ECHO 1. Ver opciones de internet
ECHO 2. Ver impresoras
ECHO 3. Ver administrador de certificados
ECHO 4. Ver version de Windows
ECHO 5. Reinstalar drivers tarjeta
ECHO 6. Inicio
set choice=
set /p choice=Escoge una opcion:
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='1' goto ieopcion
if '%choice%'=='2' goto printerpop
if '%choice%'=='3' goto Certmgr
if '%choice%'=='4' goto winver
if '%choice%'=='5' goto tarjetadrv
if '%choice%'=='6' goto main
ECHO "%choice%" no es valido, intentalo de nuevo
ECHO.
goto Bmenu
:ieopcion
Rundll32 Shell32.dll, Control_RunDLL Inetcpl.cpl
goto main
:printerpop
start control printers
goto main
:winver
RunDll32.exe SHELL32.DLL,ShellAboutW
goto main
:Certmgr
Certmgr.msc
goto main
:tarjetadrv
runas /user:%AD%@justicia "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"  
runas /user:%AD%@justicia "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
goto main