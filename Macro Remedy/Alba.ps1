# Ruta base
$Ruta = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds"

# Archivos a excluir
$Excluidos = @(
    "x0x1xxxM.arq","x0xxxMIS.arq","x1xxxCSU.arq","x2x1xxxH.arq","x2xxxHEL.arq",
    "x3x1xxxP.arq","x3x2xxxP.arq","x3x3xxxP.arq","x3x4xxxP.arq","x3xxxPEN.arq",
    "x4x1xxxG.arq","x4x2xxxG.arq","x4xxxGES.arq","x5x1xxxM.arq","x5x2xxxC.arq",
    "x5xxxMIC.arq","x6xxxCSU.arq","x7xxxGES.arq"
)

# Log
$LogPath = Join-Path $Ruta "ARCmds_log.txt"
"=== LOG de actualización de fechas === $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" | Out-File $LogPath -Encoding UTF8

# Fecha actual para reemplazo
$FechaActual = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")

# Obtener todos los archivos .arq excepto los excluidos
$Archivos = Get-ChildItem -Path $Ruta -Filter "*.arq" | Where-Object { $Excluidos -notcontains $_.Name }

foreach ($Archivo in $Archivos) {
    try {
        # Leer el contenido respetando codificación Windows-1252
        $Contenido = Get-Content -Path $Archivo.FullName -Encoding Default
        
        $Modificado = $false
        $FechasEncontradas = @()

        for ($i = 0; $i -lt $Contenido.Count; $i++) {
            $Linea = $Contenido[$i]
            $LineasReemplazadas = $false

            foreach ($Campo in $Linea.Split([char]1, 200)) {
                if ($Campo -match "1010000200=" -or $Campo -match "1010000150=") {
                    $FechaAntigua = $Campo.Substring(11)
                    $FechasEncontradas += $FechaAntigua
                    $Linea = $Linea.Replace($FechaAntigua, $FechaActual)
                    $LineasReemplazadas = $true
                }
            }

            if ($LineasReemplazadas) {
                $Contenido[$i] = $Linea
                $Modificado = $true
            }
        }

        # Si hubo cambios, reescribir respetando la codificación original
        if ($Modificado) {
            $Contenido | Set-Content -Path $Archivo.FullName -Encoding Default
            Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ✅ $($Archivo.Name): Fechas reemplazadas -> $($FechasEncontradas -join ', ')"
        } else {
            Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ⏭️ $($Archivo.Name): Sin coincidencias"
        }

    } catch {
        Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ⚠️ ERROR en $($Archivo.Name): $_"
    }
}

Add-Content -Path $LogPath -Value "=== Proceso finalizado === $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Host "✅ Proceso completado. Revisa el log en: $LogPath"
