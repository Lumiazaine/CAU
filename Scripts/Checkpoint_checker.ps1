param(
    [string]$VpnCommand = 'C:\Program Files (x86)\CheckPoint\Endpoint Security\Endpoint Connect\trac.exe',
    [string]$SiteName = 'nisepvpn.juntadeandalucia.es',
    [switch]$ListOnly
)

# PowerShell counterpart of the original batch commands. The .bat remains independent.
if (-not (Test-Path -LiteralPath $VpnCommand -PathType Leaf)) {
    throw 'Check Point VPN Client no esta instalado.'
}
Write-Host 'Verificando certificados disponibles asociados'
& $VpnCommand list
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar Check Point VPN Client.' }
if ($ListOnly) { return }

Write-Host 'Intentando conectar a la VPN'
& $VpnCommand start
if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar Check Point VPN Client.' }
& $VpnCommand connectgui -s $SiteName
if ($LASTEXITCODE -ne 0) { throw 'Check Point no pudo iniciar la conexion.' }
