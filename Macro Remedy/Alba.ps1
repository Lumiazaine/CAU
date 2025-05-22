param(
    [bool] $Instala = $false,
    [bool] $Actualiza = $false
)

if ($Instala) {
    Out-Default -InputObject "Proceso de Instalación"
    break
}
if ($Actualiza) {
    Out-Default -InputObject "Proceso de Actualización"
    break
}

if (-not $Instala -and -not $Actualiza) {

    # Función para mostrar el menú (se mantiene para la selección interactiva si se llegara a usar)
    function PintaMenu($Datos, $seleccionados = $null) {
        Clear
        if ($null -ne $seleccionados) {
            $seleccion = $seleccionados.Split(" ", 2000)
        }
        for ($i = 0; $i -lt $Archivos.count; $i++) {
            if ($null -eq $seleccionados) {
                $texto = " " + [string]$i + ".- " + $Archivos[$i].Name
            } else {
                if ($seleccion -match $i) {
                    $texto = "*" + [string]$i + ".- " + $Archivos[$i].Name
                } else {
                    $texto = " " + [string]$i + ".- " + $Archivos[$i].Name
                }
            }
            Out-Default -InputObject $texto
        }
    }

    function SeleccionaArchivos($ruta) {
        $Archivos = Get-ChildItem -Path $ruta | Sort-Object Name
        $salida = $false
        while (-not $salida) {
            PintaMenu($Archivos.Name)
            $Selecciones = Read-Host -Prompt "Selecciona los archivos separados por espacios"
            PintaMenu($Archivos.Name)($Selecciones)
            $Finaliza = Read-Host -Prompt "¿Es correcta la selección? (s/n)"
            if ($Finaliza.ToUpper() -like "S") {
                $salida = $true
                $selec = @()
                foreach ($seleccion in ($Selecciones.Split(" ", 200))) {
                    if ($seleccion -ge 0 -and $seleccion -lt $Archivos.Count) {
                        $selec += $Archivos[$seleccion]
                    }
                }
                return $selec
            }
        }
    }

    ## Definimos la ruta de los archivos .arq
    $Ruta = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\*.arq"
    $TodosLosArchivos = Get-ChildItem -Path $Ruta | Sort-Object Name

    ## Lista de exclusión (archivos que NO se deben procesar)
    $Exclusiones = @(
        "x0x1xxxM.arq",
        "x0xxxMIS.arq",
        "x1xxxCSU.arq",
        "x2x1xxxH.arq",
        "x2xxxHEL.arq",
        "x3x1xxxP.arq",
        "x3x2xxxP.arq",
        "x3x3xxxP.arq",
        "x3x4xxxP.arq",
        "x3xxxPEN.arq",
        "x4x1xxxG.arq",
        "x4x2xxxG.arq",
        "x4xxxGES.arq",
        "x5x1xxxM.arq",
        "x5x2xxxC.arq",
        "x5xxxMIC.arq",
        "x6xxxCSU.arq",
        "x7xxxGES.arq"
    )

    ## Seleccionamos TODOS los archivos .arq EXCEPTO los que están en la lista de exclusión
    $archivos = $TodosLosArchivos | Where-Object { $Exclusiones -notcontains $_.Name }

    # Aquí se podrían agregar otras operaciones sobre los archivos seleccionados.
    Out-Default -InputObject "Archivos seleccionados para procesar:"
    foreach ($archivo in $archivos) {
        Out-Default -InputObject $archivo.Name
    }
}
