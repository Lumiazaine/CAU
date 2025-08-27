@echo off
cd /d "%~dp0"
echo Compilando CAU_GUI_Refactored.ahk...
"C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe" /in "CAU_GUI_Refactored.ahk" /out "CAU_GUI_v2.exe" /icon "Assets\icon.ico"
if %errorlevel% equ 0 (
    echo Compilacion exitosa! Se creo CAU_GUI_v2.exe
) else (
    echo Error durante la compilacion
)
pause