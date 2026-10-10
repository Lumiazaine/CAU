@echo off
setlocal
cd /d "%~dp0"
set "COMPILER=C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe"
if not exist "%COMPILER%" (
    echo Compilador AHK no disponible. No se instala automaticamente.
    exit /b 1
)
if not exist "CAU_GUI_BETA_v2.ahk" exit /b 1
rem Icono opcional omitido: Assets\icon.ico no forma parte del repositorio.
"%COMPILER%" /in "CAU_GUI_BETA_v2.ahk" /out "CAU_GUI_v2.exe"
if errorlevel 1 (
    echo Error durante la compilacion.
    exit /b 1
)
echo Compilacion exitosa: CAU_GUI_v2.exe
exit /b 0
