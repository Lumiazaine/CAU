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
for %%i in (*) do (
    if "%%i" neq "%~nx0" (
        del /q "%%i"
    )
)
for /d %%i in (*) do (
    if "%%i" neq "%~nx0" (
        rd /s /q "%%i"
    )
)
cls
goto main
:main
cls
ECHO ------------------------------------------
ECHO                  CAU                 
ECHO ------------------------------------------
ECHO %AD%
Hostname
ipconfig | findstr /i "ipv4"
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
ECHO "%choice%" is not valid, try again
ECHO.
goto main
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
rd /s /q %temp%
echo Reiniciar equipo (s/n)
choice /c sn /n
if errorlevel 2 (
    del "%~f0" & exit
) else (
    del "%~f0" & shutdown -t 0 -r -f
)
:mail_pass
start chrome "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
del "%~f0" & exit
goto main
:print_pool
runas /user:%AD%@JUSTICIA "net stop spooler"
runas /user:%AD%@JUSTICIA "del /q /f /s %systemroot%\System32\spool\printers\*.*"
runas /user:%AD%@JUSTICIA "net start spooler"
del "%~f0" & exit
:Driver_admin
runas /user:%AD%@JUSTICIA "RunDll32.exe devmgr.dll DeviceManager_Execute"
del "%~f0" & exit
goto main
:isl
start chrome "https://ficheros.juntadeandalucia.es/s/VEObhCU9SIIfOMB/download"
runas /user:%AD%@JUSTICIA "cmd /c msiexec /i \"%userprofile%\downloads\isl soporte instalador.msi\" /qn"

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
start chrome "https://descargas.cert.fnmt.es/Windows/Configurador_FNMT_4.0.5_64bits.exe"
runas /user:%AD%@JUSTICIA "%userprofile%\downloads\Configurador_FNMT_4.0.5_64bits.exe /S"
goto Cert
:configurator
cd %userprofile%\downloads
start chrome "https://descargas.cert.fnmt.es/Windows/Configurador_FNMT_4.0.5_64bits.exe"
runas /user:%AD%@JUSTICIA "%userprofile%\downloads\Configurador_FNMT_4.0.5_64bits.exe"
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