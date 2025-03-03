@echo off
TITLE "Datos del equipo & OCS force"
CLS
ECHO *********************
ECHO *  COLECTANDO INFO  *
ECHO *********************
ECHO.

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

REM Captura el SN y el RFID cargados manualmente con RegistroInventario.exe
FOR /f "tokens=2*" %%i in ('reg query HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\RegInv /v 1') do Set "SNregister=%%j"
FOR /f "tokens=2*" %%i in ('reg query HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\RegInv /v 3') do Set "RFIDregister=%%j"


CLS
ECHO *********************
ECHO *  COLECTANDO INFO  *
ECHO *********************
ECHO.


REM SECCIÓN OCS, Comprueba y fuerza sincro, o deriva al informe error

IF EXIST "%ProgramFiles%\OCS Inventory agent\OCSInventory.exe" GOTO OCSforce
IF NOT EXIST "%ProgramFiles(x86)%\OCS Inventory agent\OCSInventory.exe" GOTO OCSnotExist

:OCSforce
C:
"c:\Program Files (x86)\OCS inventory Agent\OCSInventory.exe" /FORCE & CLS

:continueCheck
ECHO Nombre AD: %computerName%
ECHO Numero de serie: %sn%
ECHO Numero de IP: %networkIP%
ECHO Posee instalado: %win%, con la compilacion %versionSO%
IF DEFINED RFIDregister (echo RFID Registrado manual: %RFIDregister%) Else (echo RFID NO REGISTRADO  MANUALMENTE !!!)
IF DEFINED SNregister (echo SN Registrado manual: %SNregister%) Else (echo SN NO REGISTRADO MANUALMENTE !!!)

ECHO.
IF DEFINED SNregister (GOTO validateDS)
IF NOT DEFINED SNregister (COLOR 4F & ECHO LOS NUMEROS DE SERIE MANUALES NO FUERON REGISTRADOS ES NECESARIO COMPROBAR !!!!! )
ECHO.
ECHO ****************
ECHO *  COMPLETADO  *
ECHO ****************
PAUSE>nul
EXIT
pause


:validateDS
IF "%sn%" == "Default string" (COLOR 4F & ECHO EL NUMERO DE SERIE DE LA BIOS NO SE PUEDE RECUPERAR !!!!! ) ELSE (GOTO validateSN)
ECHO.
ECHO ****************
ECHO *  COMPLETADO  *
ECHO ****************
PAUSE>nul
EXIT



:validateSN
IF %sn% == %SNregister% (COLOR 2F & ECHO LOS NUMEROS DE SERIE COINCIDEN CORRECTAMENTE !!!!!) ELSE (COLOR 4F & ECHO LOS NUMEROS DE SERIE NO COINCIDEN ES NECESARIO COMPROBAR !!!!! )
ECHO.
ECHO ****************
ECHO *  COMPLETADO  *
ECHO ****************
PAUSE>nul
EXIT




:OCSnotExist
COLOR 4F
CLS
ECHO NO SE ENCUENTRA OCS Instalado, INSTALAR MANUALMENTE Y REINTENTAR !!!!!
ECHO.
ECHO ****************
ECHO *  COMPLETADO  *
ECHO ****************
ECHO.
@ECHO A continuacion presionar ENTER o cerrar la ventana para proceder al cierre
@ECHO y poder instalar OCS para luego reintentar
@ECHO.
@ECHO O si deseamos continuar con las comprobaciones presionar " S "
SET /P CONTINUAMOS=
IF "%CONTINUAMOS%" == "S" (CLS & GOTO continueCheck)
IF "%CONTINUAMOS%" == "s" (CLS & GOTO continueCheck)
EXIT


