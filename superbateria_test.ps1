# ¡IMPORTANTE!  Si no funciona, ejecutra - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
#Prueba de update v0.2 Beta


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



function Mostrar-Menu {
    Clear-Host
    Write-Host "El sistema operativo es $osVersion" 
    Write-Host "El usuario es $usuario"
    Write-Host "La IP del equipo es: $ipAddress"
    Write-Host ""
    Write-Host "1. Bateria de pruebas"
    Write-Host "2. Opcion 2"
    Write-Host "3. Opcion 3"
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
            
            # Desinstalar applets de Java 1.6
            $java16Applets = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Java(TM) 6*Applet*" }
            $java16Applets | ForEach-Object { $_.Uninstall() }
            
            # Limpiar la caché de Java 1.6
            Remove-Item -Path "$env:APPDATA\Sun\Java\Deployment\cache\6.0" -Force -Recurse
            
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
        2 { Write-Host "Has elegido la Opción 2" }
        3 { Write-Host "Has elegido la Opción 3" }
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
