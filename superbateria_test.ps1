# ¡IMPORTANTE!  Si no funciona, ejecutra - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
#Prueba de update v0.8 Beta


# Verificar si el script se está ejecutando con permisos de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere permisos de administrador. Reiniciando el script con permisos de administrador..."
    
    # Ejecutar el script nuevamente con los permisos de administrador
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    
    # Salir del script actual
    Exit
}
# Usuario
$usuario = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "El usuario actual es: $usuario"


# Comprobar la versión de Windows
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption

# Determinar si se está ejecutando en Windows 7 o Windows 10
if ($osVersion -like "*Windows 7*") {
    Write-Host "Estás ejecutando Windows 7."
}
elseif ($osVersion -like "*Windows 10*") {
    Write-Host "Estás ejecutando Windows 10."
}
else {
    Write-Host "No se pudo detectar la versión de Windows."
}

# Comprobar ip equipo
$ipAddress = (Test-Connection -ComputerName (hostname) -Count 1).IPv4Address.IPAddressToString

# Variable ruta equipo
$scriptPath = $MyInvocation.MyCommand.Definition
$scriptDirectory = Split-Path -Path $scriptPath -Parent


function Mostrar-Menu {
    Clear-Host
    Write-Host "El sistema operativo es $osVersion" 
    Write-Host "El usuario es $usuario"
    Write-Host "La IP del equipo es: $ipAddress"
    Write-Host ""
    Write-Host "1. Bateria de pruebas"
    Write-Host "2. Reparacion sistema corrupto"
    Write-Host "3. Actualizar script"
    Write-Host "4. Salir"
    Write-Host
}
function EjecutarOpcion {
    param([string]$opcion)
    switch ($opcion) {
        1 { 
            if ($osVersion -like "*Windows 7*") {
            # Eliminar archivos temporales de %Temp%
            Remove-Item -Path $env:Temp\* -Force -Recurse

            #Limpiar DNS
            ipconfig /flushdns
            
            # Desinstalar applets de Java 1.6
            $java16Applets = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Java(TM) 6*Applet*" }
            $java16Applets | ForEach-Object { $_.Uninstall() }
            
            # Limpiar la caché de Java 1.6
            Remove-Item -Path "$env:APPDATA\Sun\Java\Deployment\cache\6.0" -Force -Recurse

            #Cerrar navegadores
            taskkill /IM chrome.exe /F > nul 2>&1
            taskkill /IM iexplore.exe /F > nul 2>&1

            #Limpiar caché chrome

            $chromeCachePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"

            # Verificar si la carpeta de caché de Chrome existe
            if (Test-Path $chromeCachePath) {
                # Eliminar todos los archivos dentro de la carpeta de caché
                Get-ChildItem $chromeCachePath | Remove-Item -Force -Recurse
                Write-Host "La caché de Google Chrome ha sido eliminada correctamente."
            } else {
                Write-Host "No se encontró la carpeta de caché de Google Chrome."
            }
            
            # Vaciar la Papelera de reciclaje
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { $recycleBin.InvokeVerb("Delete") }
            
            # Actualizar las directivas
            gpupdate /force
            
            # Preguntar si desea reiniciar el equipo
            $reiniciar = Read-Host "¿Deseas reiniciar el equipo? (Sí/No)"
            if ($reiniciar -eq "Sí" -or $reiniciar -eq "si") {
                Restart-Computer -Force
            }
            }
            elseif ($osVersion -like "*Windows 10*") {
            
            # Eliminar archivos temporales de %Temp%
            Remove-Item -Path $env:Temp\* -Force -Recurse
            
            #Limpiar DNS
            ipconfig /flushdns

            #Cerrar navegadores
            taskkill /IM chrome.exe /F > nul 2>&1
            taskkill /IM iexplore.exe /F > nul 2>&1
            taskkill /IM msedge.exe /F > nul 2>&1

            # Desinstalar applets de Java 1.6
            $java16Applets = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Java(TM) 6*Applet*" }
            $java16Applets | ForEach-Object { $_.Uninstall() }

            # Limpiar la caché de Java 1.6
            Remove-Item -Path "$env:APPDATA\LocalLow\Sun\Java\Deployment\cache\6.0" -Force -Recurse

            #Limpiar cache chrome

            $chromeCachePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"

            # Verificar si la carpeta de caché de Chrome existe
            if (Test-Path $chromeCachePath) {
                # Eliminar todos los archivos dentro de la carpeta de caché
                Get-ChildItem $chromeCachePath | Remove-Item -Force -Recurse
                Write-Host "La caché de Google Chrome ha sido eliminada correctamente."
            } else {
                Write-Host "No se encontró la carpeta de caché de Google Chrome."
            }


            # Vaciar la Papelera de reciclaje
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { $recycleBin.InvokeVerb("Delete") }

            # Actualizar las directivas
            gpupdate /force

            # Preguntar si desea reiniciar el equipo
            $reiniciar = Read-Host "¿Deseas reiniciar el equipo? (Sí/No)"
            if ($reiniciar -eq "Sí" -or $reiniciar -eq "si") {
                Restart-Computer -Force
}

            }
            else {
                Write-Host "El sisitema en el que estás ejecutando este script no parece compatible, de todas formas, se ejecutara una bateria de pruebas"
                # Eliminar archivos temporales de %Temp%
                Remove-Item -Path $env:Temp\* -Force -Recurse

                # Desinstalar applets de Java 1.6
                $java16Applets = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Java(TM) 6*Applet*" }
                $java16Applets | ForEach-Object { $_.Uninstall() }

                # Limpiar la caché de Java 1.6
                Remove-Item -Path "$env:APPDATA\LocalLow\Sun\Java\Deployment\cache\6.0" -Force -Recurse

                # Vaciar la Papelera de reciclaje
                $shell = New-Object -ComObject Shell.Application
                $recycleBin = $shell.Namespace(0xA)
                $recycleBin.Items() | ForEach-Object { $recycleBin.InvokeVerb("Delete") }

                # Actualizar las directivas
                gpupdate /force

                # Preguntar si desea reiniciar el equipo
                $reiniciar = Read-Host "¿Deseas reiniciar el equipo? (Sí/No)"
                if ($reiniciar -eq "Sí" -or $reiniciar -eq "si") {
                    Restart-Computer -Force
                }

            }
            
             }
        2 { 
            DISM /Online /Cleanup-Image /CheckHealth
            DISM /Online /Cleanup-Image /ScanHealth
            DISM /Online /Cleanup-Image /RestoreHealth
            sfc /scannow 
        }
        3 { 

            if ($osVersion -like "*Windows 7*") {
            # Actualización W7
            $scriptUrl = "https://raw.githubusercontent.com/JUST3EXT/CAU/main/superbateria_test.ps1"
            $localScriptPath = $scriptDirectory
            
            # Verificar si se están ejecutando con privilegios de administrador
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if ($isAdmin) {
                # Descargar el script actualizado desde la URL de GitHub
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($scriptUrl, $localScriptPath)
            
                # Verificar si la descarga fue exitosa
                if (Test-Path $localScriptPath) {
                    Write-Host "El script se ha actualizado correctamente."
                } else {
                    Write-Host "No se pudo descargar el script actualizado desde la URL de GitHub."
                }
            } else {
                # Solicitar permisos de administrador y volver a ejecutar el script
                Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
                Exit
            }
            
            }
            elseif ($osVersion -like "*Windows 10*") {
                 #Actualizar script Windows 10
            $scriptUrl = "https://raw.githubusercontent.com/JUST3EXT/CAU/main/superbateria_test.ps1"
            $localScriptPath = $scriptDirectory

            # Descargar el script actualizado desde la URL de GitHub
            Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath -ErrorAction Stop

            # Verificar si la descarga fue exitosa
            if (Test-Path $localScriptPath) {
                Write-Host "El script se ha actualizado correctamente."
            } else {
                Write-Host "No se pudo descargar el script actualizado desde la URL de GitHub."
            }
            }
            else {

                # Actualización primitiva
                $scriptUrl = "https://raw.githubusercontent.com/JUST3EXT/CAU/main/superbateria_test.ps1"
                $localScriptPath = $scriptDirectory
                
                # Verificar si se están ejecutando con privilegios de administrador
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                
                if ($isAdmin) {
                    # Descargar el script actualizado desde la URL de GitHub
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($scriptUrl, $localScriptPath)
                
                    # Verificar si la descarga fue exitosa
                    if (Test-Path $localScriptPath) {
                        Write-Host "El script se ha actualizado correctamente."
                    } else {
                        Write-Host "No se pudo descargar el script actualizado desde la URL de GitHub."
                    }
                } else {
                    # Solicitar permisos de administrador y volver a ejecutar el script
                    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
                    Exit
                }
                

            }
            
         }
        4 { exit }
        default { Write-Host "Opción inválida" }
    }
}

do {
    Mostrar-Menu
    $opcion = Read-Host "Escoge una opcion"
    EjecutarOpcion -opcion $opcion
    Write-Host "Presiona cualquier tecla para volver al menú..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)
