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


--------------------------------------------------------------------------------

@echo off
setlocal enabledelayedexpansion

:: Verificar si existe el archivo de credenciales
if not exist "credenciales.txt" (
    echo El archivo credenciales.txt no existe.
    pause
    exit /b
)

:: Leer el nombre de usuario y contraseña del archivo credenciales.txt
set count=0
for /f "tokens=*" %%A in (credenciales.txt) do (
    set /a count+=1
    if !count! equ 1 set adminuser=%%A
    if !count! equ 2 set adminpass=%%A
)

:: Verificar si se obtuvieron las credenciales
if "%adminuser%"=="" (
    echo No se pudo obtener el nombre de usuario administrador.
    pause
    exit /b
)

if "%adminpass%"=="" (
    echo No se pudo obtener la contraseña del administrador.
    pause
    exit /b
)

:: Crear un archivo batch temporal con los comandos que requieren privilegios de administrador
set cmdfile=%temp%\admin_commands.bat
(
echo @echo off
echo taskkill /IM chrome.exe /F ^> nul 2^>^&1
echo taskkill /IM iexplore.exe /F ^> nul 2^>^&1
echo taskkill /IM msedge.exe /F ^> nul 2^>^&1
echo ipconfig /flushdns
echo javaws -uninstall ^> nul 2^>^&1
echo javaws -clearcache ^> nul 2^>^&1
echo javaws -Xclearcache -silent -Xnosplash ^> nul 2^>^&1
echo RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
echo gpupdate /force
echo del /f /s /q "%%temp%%\*.*" ^>nul 2^>^&1
echo for /d %%%%p in ("%%temp%%\*.*") do rmdir /s /q "%%%%p" ^>nul 2^>^&1
echo del /f /s /q "%%windir%%\Temp\*.*" ^>nul 2^>^&1
echo for /d %%%%p in ("%%windir%%\Temp\*.*") do rmdir /s /q "%%%%p" ^>nul 2^>^&1
echo reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f
echo reg add "HKCU\Control Panel\Desktop" /v FontSmoothingType /t REG_DWORD /d 2 /f
echo RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
) > "%cmdfile%"

:: Crear una tarea programada que ejecuta el archivo batch temporal con privilegios de administrador
schtasks /create /tn "AdminTasks" /tr "\"%cmdfile%\"" /ru "%adminuser%" /rp "%adminpass%" /sc once /st 00:00 /sd 01/01/2000 >nul

:: Ejecutar la tarea programada inmediatamente
schtasks /run /tn "AdminTasks" >nul

:: Esperar a que la tarea se ejecute
timeout /t 10 /nobreak >nul

:: Eliminar la tarea programada y el archivo batch temporal
schtasks /delete /tn "AdminTasks" /f >nul
del "%cmdfile%" >nul

:: Continuar con el resto del script
echo.
echo ¿Desea reiniciar el equipo? (s/n)
choice /c sn /n
if %errorlevel%==1 (
    echo Reiniciando...
    shutdown /r /t 0
) else (
    echo Operación completada. No se reiniciará el equipo.
)

:: Fin del script
endlocal


------------------------------------------------------------------------------------

DP_ADMIN
280280*
