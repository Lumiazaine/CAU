param(
    [Parameter(Mandatory=$false)]
    [switch]$unlockedonly  # Si lo incluyes al ejecutar, oculta los errores
)

# 1. Obtener la lista de dominios del bosque
$Dominios = (Get-ADForest).Domains

Write-Host "--- SERVICIO DE DESBLOQUEO SELECTIVO ---" -ForegroundColor Cyan
if ($unlockedonly) { 
    Write-Host "MODO: Solo mostrando éxitos (-unlockedonly activo)" -ForegroundColor Yellow 
}
Write-Host "Presiona Ctrl+C para detener.`n" -ForegroundColor Gray

while($true) {
    foreach ($Dom in $Dominios) {
        try {
            # Búsqueda de usuarios bloqueados
            $UsuariosBloqueados = Get-ADUser -Filter 'Enabled -eq $true' -Server $Dom -Properties msDS-User-Account-Control-Computed -ErrorAction SilentlyContinue | 
                                  Where-Object { ($_. "msDS-User-Account-Control-Computed" -band 0x10) -eq 0x10 }

            if ($UsuariosBloqueados) {
                foreach ($User in $UsuariosBloqueados) {
                    $Timestamp = Get-Date -Format "HH:mm:ss"
                    try {
                        # Intentar desbloqueo
                        Unlock-ADAccount -Identity $User.DistinguishedName -Server $Dom -Confirm:$false -ErrorAction Stop
                        
                        Write-Host "[$Timestamp] [$Dom] DESBLOQUEADO: $($User.SamAccountName)" -ForegroundColor Green
                    } catch {
                        # SOLO mostrar error si el flag -unlockedonly NO está activo
                        if (-not $unlockedonly) {
                            Write-Host "[$Timestamp] [$Dom] ERROR (Sin Permisos): $($User.SamAccountName)" -ForegroundColor Red
                        }
                    }
                }
            }
        } catch {
            if (-not $unlockedonly) { Write-Warning "Dominio $Dom no accesible." }
        }
    }
    
    Start-Sleep -Seconds 20
}