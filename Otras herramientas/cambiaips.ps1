# Verificar si el script se está ejecutando con permisos de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere permisos de administrador. Reiniciando el script con permisos de administrador..."
    
    # Ejecutar el script nuevamente con los permisos de administrador
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    
    # Salir del script actual
    Exit
}

# Menú

function Mostrar-Menu {
    Clear-Host
    Write-Host "¿Donde vas a trabajar?" 
    Write-Host "1. Oficina"
    Write-Host "2. Casa"
}

function EjecutarOpcion {
    param([string]$opcion)
    switch ($opcion) {
        1 {
        $IP = "X.X.X.X"               # Dirección IP deseada
        $SubnetMask = "X.X.X.X"     # Máscara de subred deseada
        $Gateway = "X.X.X.X"          # Puerta de enlace predeterminada deseada
        $DNS1 = "X.X.X.X"              # Servidor DNS preferido deseado
        $DNS2 = "X.X.X.X"              # Servidor DNS alternativo deseado
        
        # Obtener la interfaz de red activa
        $networkInterface = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        
        # Configurar la dirección IP
        $networkInterface.EnableStatic($IP, $SubnetMask)
        
        # Configurar la puerta de enlace predeterminada
        $networkInterface.SetGateways($Gateway, 1)
        
        # Configurar los servidores DNS
        $dnsServers = $networkInterface.DNSServerSearchOrder
        $dnsServers[0] = $DNS1
        $dnsServers[1] = $DNS2
        $networkInterface.SetDNSServerSearchOrder($dnsServers)
        
        Write-Host "La configuración de red se ha actualizado correctamente."
        }



    2{
        # Obtener la interfaz de red activa
        $networkInterface = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }

        # Configurar la dirección IP para obtener automáticamente
        $networkInterface.EnableDHCP()

        # Configurar los servidores DNS para obtener automáticamente
        $networkInterface.SetDNSServerSearchOrder()

        Write-Host "La configuración de red se ha actualizado para obtener direcciones automáticamente."

    }
} 
}


do {
    Mostrar-Menu
    $opcion = Read-Host "Escoge una opcion"
    EjecutarOpcion -opcion $opcion
    Write-Host "Presiona cualquier tecla para volver al menú..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)