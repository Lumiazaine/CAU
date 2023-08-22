
#Función para seleccionar archivos
function PintaMenu($Datos,$seleccionados=$null){
    clear
    if($null -ne $seleccionados){
        $seleccion = $seleccionados.split(" ",2000)
    }
        for($i=0;$i -lt $Archivos.count;$i++){
            if($null -eq $seleccionados){
                $texto = " "+[string]$i+".- "+$Archivos[$i].name
            }else{
                if ($seleccion -match $i){
                    $texto = "*"+[string]$i+".- "+$Archivos[$i].name
                }else{
                    $texto = " "+[string]$i+".- "+$Archivos[$i].name
                }
            }
            Out-Default -InputObject $texto
        }
}
function SeleccionaArchivos($ruta){
    $Archivos = Get-ChildItem -Path $Ruta | Sort-Object Name
    $salida = $false
    while (!($salida)){
        PintaMenu($Archivos.name)
        $Selecciones = Read-Host -Prompt "Selecciona los archivos separados por espacios"
        PintaMenu($Archivos.name)($Selecciones)
        $Finaliza = Read-Host -Prompt "¿Es correcta la selección? (s/n)"
        if ($Finaliza.ToUpper() -like "S"){
            $salida = $true
            $selec = @()
            foreach ($seleccion in ($Selecciones.split(" ",200))) {
                if ($seleccion -ge 0 -and $seleccion -lt $Archivos.Count){
                    $selec += $Archivos[$seleccion]                
                }
            }
            return $selec
        }
    }
}
## Guardamos la ruta en una variable
$Ruta = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\*.arq"
$TodosLosArchivos = Get-ChildItem -Path $Ruta | Sort-Object Name
$ArchivosASeleccionar = @("zmac.arq","Adriano.arq","Lexnet.arq","AD.arq","Correo.arq","Expedien.arq","PNJ.arq","NuevoAdr.arq"."tarjeta.arq")
## Seleccionamos 
$archivos = @()
#$Archivos = SeleccionaArchivos($ruta)
foreach ($archivo in $ArchivosASeleccionar){
    if ($TodosLosArchivos.name -match $archivo){
        $archivos += $TodosLosArchivos | where {$_.name -like $archivo} 
    }
}
## Ahora un bucle para realizar la tarea sobre todos los seleccionados
foreach ($NombreArchivo in $Archivos){
    $fechas = @()
    $contenidos = get-content -path $NombreArchivo
    foreach ($contenido in $contenidos){
        foreach ($valor in $contenido.Split([char]1,200)){
            if ($valor -match "1010000200=" -or $valor -match "1010000150="){
                $fechas += $valor.Substring(11)
            }
        }
    }
    $FechaActual = (get-date).ToString("dd/MM/yyyy HH:mm:ss")
    foreach ($fecha in $fechas){
        (get-content -path $NombreArchivo).Replace($fecha,$FechaActual)| Set-Content -Path $NombreArchivo
    }
    #Fin del bucle
}
