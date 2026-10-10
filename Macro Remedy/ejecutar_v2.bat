@echo off
setlocal
cd /d "%~dp0"
set "AHK=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" (
    echo AutoHotkey v2 no disponible. No se instala automaticamente.
    exit /b 1
)
if not exist "CAU_GUI_BETA_v2.ahk" exit /b 1
"%AHK%" "CAU_GUI_BETA_v2.ahk"
exit /b %errorlevel%
