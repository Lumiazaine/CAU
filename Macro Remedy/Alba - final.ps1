## Guardamos la ruta en una variable
#$Ruta = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\*.arq"
$ruta = (Get-Location).Path+"\*.arq"
## Seleccionamos 
$Archivos = Get-ChildItem -Path $Ruta | Out-GridView -PassThru
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