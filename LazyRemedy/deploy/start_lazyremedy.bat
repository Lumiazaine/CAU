@echo off
REM =====================================================================
REM  LazyRemedy - lanzador del servidor dual REST+MCP (LAP06776)
REM  Uso desde la tarea programada "LazyRemedy" (schtasks /sc onlogon).
REM =====================================================================
setlocal
cd /d "%~dp0.."

set "PYTHON=C:\Users\CAU\AppData\Local\Programs\Python\Python313\python.exe"
set "CONFIG=%~dp0..\lazyremedy.config.json"
set "LOGDIR=%~dp0..\logs"

if not exist "%LOGDIR%" mkdir "%LOGDIR%"

REM Rotación simple: si el log supera 5 MB se renombra a .old
for %%F in ("%LOGDIR%\lazyremedy.log") do (
    if %%~zF GTR 5242880 (
        move /Y "%LOGDIR%\lazyremedy.log" "%LOGDIR%\lazyremedy.log.old" >nul 2>&1
    )
)

REM Servidor dual (REST + MCP montado en /mcp). Bloquea mientras viva.
"%PYTHON%" -m lazyremedy both --config "%CONFIG%" >> "%LOGDIR%\lazyremedy.log" 2>&1

endlocal
