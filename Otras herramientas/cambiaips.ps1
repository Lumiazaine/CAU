# Verificar si el script se está ejecutando con permisos de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere permisos de administrador. Reiniciando el script con permisos de administrador..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-File", $MyInvocation.MyCommand.Path)
    Exit
}

# Función para obtener el adaptador deseado
function Get-NetworkInterface {
    # Se intenta obtener el adaptador "Realtek PCIe GbE Family Controller #2"
    $adapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Name -eq 'Realtek PCIe GbE Family Controller #2' }
    
    if ($null -eq $adapter) {
        Write-Host "El adaptador 'Realtek PCIe GbE Family Controller #2' no fue encontrado."
        Write-Host "Seleccione uno de los siguientes adaptadores disponibles:"
        # Listar adaptadores que tengan NetConnectionID (para evitar entradas sin conexión asignada)
        $availableAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.NetConnectionID -ne $null }
        for ($i = 0; $i -lt $availableAdapters.Count; $i++) {
            Write-Host "$i. $($availableAdapters[$i].Name) - $($availableAdapters[$i].NetConnectionID)"
        }
        $selection = Read-Host "Ingrese el número correspondiente al adaptador deseado"
        try {
            $selectionIndex = [int]$selection
        }
        catch {
            Write-Host "Selección inválida. Saliendo del script."
            exit
        }
        if ($selectionIndex -ge 0 -and $selectionIndex -lt $availableAdapters.Count) {
            $adapter = $availableAdapters[$selectionIndex]
        }
        else {
            Write-Host "Selección inválida. Saliendo del script."
            exit
        }
    }
    
    # Obtener la configuración de red para el adaptador seleccionado (mediante su Index)
    $netConfig = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $adapter.Index }
    if ($null -eq $netConfig) {
        Write-Host "No se encontró la configuración de red para el adaptador seleccionado."
        exit
    }
    return $netConfig
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
            $SubnetMask = "X.X.X.X"       # Máscara de subred deseada
            $Gateway = "X.X.X.X"          # Puerta de enlace predeterminada deseada
            $DNS1 = "X.X.X.X"             # Servidor DNS preferido deseado
            $DNS2 = "X.X.X.X"             # Servidor DNS alternativo deseado
            
            # Se obtiene la configuración únicamente para el adaptador seleccionado
            $networkInterface = Get-NetworkInterface
            
            # Configurar la dirección IP
            $networkInterface.EnableStatic($IP, $SubnetMask)
            
            # Configurar la puerta de enlace predeterminada
            $networkInterface.SetGateways($Gateway, 1)
            
            # Configurar los servidores DNS
            $dnsServers = $networkInterface.DNSServerSearchOrder
            if ($dnsServers -eq $null) {
                $dnsServers = @()
            }
            $dnsServers[0] = $DNS1
            $dnsServers[1] = $DNS2
            $networkInterface.SetDNSServerSearchOrder($dnsServers)
            
            Write-Host "La configuración de red se ha actualizado correctamente para '$($networkInterface.Description)'."
        }
        2 {
            # Se obtiene la configuración únicamente para el adaptador seleccionado
            $networkInterface = Get-NetworkInterface
            
            # Configurar la dirección IP para obtener automáticamente
            $networkInterface.EnableDHCP()
            
            # Configurar los servidores DNS para obtener automáticamente
            $networkInterface.SetDNSServerSearchOrder()
            
            Write-Host "La configuración de red se ha actualizado para obtener direcciones automáticamente en '$($networkInterface.Description)'."
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
