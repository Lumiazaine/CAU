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