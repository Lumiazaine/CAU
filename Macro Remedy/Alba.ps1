$NombreArchivo = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\zmac.arq"
$fechas = @()
$contenido = get-content -path $NombreArchivo
foreach ($valor in $contenido[3].Split([char]1,200)){
    if ($valor -match "1010000200=" -or $valor -match "1010000150="){
        $fechas += $valor.Substring(11)
        }
    }

$FechaActual = (get-date).ToString("dd/MM/yyyy hh:mm:ss")
((get-content -path $NombreArchivo).Replace($fechas[0],$FechaActual)).Replace($fechas[1],$FechaActual) | Set-Content -Path $NombreArchivo