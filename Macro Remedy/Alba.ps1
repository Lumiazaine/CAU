# Ruta base
$Ruta = "C:\Users\david\AppData\Roaming\AR System\HOME\ARCmds"

# Archivos a excluir
$Excluidos = @(
    "x0x1xxxM.arq","x0xxxMIS.arq","x1xxxCSU.arq","x2x1xxxH.arq","x2xxxHEL.arq",
    "x3x1xxxP.arq","x3x2xxxP.arq","x3x3xxxP.arq","x3x4xxxP.arq","x3xxxPEN.arq",
    "x4x1xxxG.arq","x4x2xxxG.arq","x4xxxGES.arq","x5x1xxxM.arq","x5x2xxxC.arq",
    "x5xxxMIC.arq","x6xxxCSU.arq","x7xxxGES.arq"
)

# Log
$LogPath = Join-Path $Ruta "ARCmds_log.txt"
"=== LOG de actualización a constantes AR === $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" | Out-File $LogPath -Encoding UTF8

# NUEVO VALOR: Constantes de AR System
$ValorNuevo = '$DATE$ $TIME$'

# Obtener archivos .arq excepto los excluidos
$Archivos = Get-ChildItem -Path $Ruta -Filter "*.arq" | Where-Object { $Excluidos -notcontains $_.Name }

foreach ($Archivo in $Archivos) {
    try {
        # Leer contenido (Encoding Default suele ser Windows-1252 en sistemas ES)
        $Contenido = Get-Content -Path $Archivo.FullName -Encoding Default
        
        $Modificado = $false
        $CambiosRealizados = 0

        for ($i = 0; $i -lt $Contenido.Count; $i++) {
            $Linea = $Contenido[$i]
            
            # Buscamos los campos específicos mediante Regex para mayor precisión
            # Captura lo que hay después del ID de campo hasta el final de la cadena o delimitador
            if ($Linea -match "1010000200=" -or $Linea -match "1010000150=") {
                
                # Expresión regular para encontrar el ID y capturar el valor antiguo
                # Busca 1010000150= o 1010000200= seguido de cualquier cosa hasta el siguiente carácter especial o fin de línea
                $NuevaLinea = $Linea -replace "(1010000200=)[^]*", "`${1}$ValorNuevo"
                $NuevaLinea = $NuevaLinea -replace "(1010000150=)[^]*", "`${1}$ValorNuevo"

                if ($NuevaLinea -ne $Linea) {
                    $Contenido[$i] = $NuevaLinea
                    $Modificado = $true
                    $CambiosRealizados++
                }
            }
        }

        if ($Modificado) {
            $Contenido | Set-Content -Path $Archivo.FullName -Encoding Default
            Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ✅ $($Archivo.Name): Se aplicó '$ValorNuevo' ($CambiosRealizados campos)"
        } else {
            Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ⏭️ $($Archivo.Name): Sin campos de fecha detectados"
        }

    } catch {
        Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] ⚠️ ERROR en $($Archivo.Name): $_"
    }
}

Add-Content -Path $LogPath -Value "=== Proceso finalizado === $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Host "✅ Proceso completado. Los archivos ahora usan `$DATE$ `$TIME$."