$NombreArchivo = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Zmac.arq"
$fechas = @()
$contenido = Get-Content -Path $NombreArchivo
foreach ($valor in $contenido[3].Split([char]1, 200)) {
    if ($valor -match "1010000200=" -or $valor -match "1010000150=") {
        $fechas += $valor.Substring(11)
    }
}

$FechaActual = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$contenido = $contenido -replace [regex]::Escape($fechas[0]), $FechaActual
$contenido = $contenido -replace [regex]::Escape($fechas[1]), $FechaActual
$contenido | Set-Content -Path $NombreArchivo
