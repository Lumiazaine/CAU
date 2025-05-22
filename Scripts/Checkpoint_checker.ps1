@echo off
rem Verifica si Check Point VPN está instalado
set "vpnCmd=C:\Program Files (x86)\CheckPoint\Endpoint Security\Endpoint Connect\trac.exe"
if not exist "%vpnCmd%" (
    echo Check Point VPN Client no está instalado.
    exit /b 1
)

rem Verificar certificado digital válido
echo Verificando certificados disponibles asociados
"%vpnCmd%" list

rem Intenta conectar a la VPN con el certificado encontrado
set "siteName=nisepvpn.juntadeandalucia.es"
echo Intentando conectar a la VPN
"%vpnCmd%" start
"%vpnCmd%" connectgui -s "%siteName%"
pause
