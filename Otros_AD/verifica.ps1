# 1. Definición de la estructura de dominios
$dominios = @(
    "justicia.junta-andalucia.es",
    "almeria.justicia.junta-andalucia.es",
    "cadiz.justicia.junta-andalucia.es",
    "cordoba.justicia.junta-andalucia.es",
    "formacion.justicia.junta-andalucia.es",
    "granada.justicia.junta-andalucia.es",
    "huelva.justicia.junta-andalucia.es",
    "jaen.justicia.junta-andalucia.es",
    "malaga.justicia.junta-andalucia.es",
    "sevilla.justicia.junta-andalucia.es",
    "vdi.justicia.junta-andalucia.es"
)

Write-Host "--- Auditoría Global de Accesos (Evento 4769) ---" -ForegroundColor Yellow
$usuario = Read-Host "Introduce el nombre del usuario (ej: dlunag)"
$horasAtras = 8 # Aumentamos a 8 horas para dar más margen
$fechaFiltro = (Get-Date).AddHours(-$horasAtras)

if ([string]::IsNullOrWhiteSpace($usuario)) { 
    Write-Host "Debe introducir un usuario válido." -ForegroundColor Red
    exit 
}

$resultadosGlobales = @()

foreach ($dom in $dominios) {
    Write-Host "`n[+] BUSCANDO EN DOMINIO: $dom" -ForegroundColor Cyan
    try {
        $dcs = Get-ADDomainController -Filter * -Server $dom -ErrorAction Stop
    } catch {
        Write-Warning "    No se pudo conectar al dominio $dom."
        continue
    }

    foreach ($dc in $dcs) {
        Write-Host "    -> Consultando DC: $($dc.HostName)... " -NoNewline
        
        $xmlQuery = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
        *[System[(EventID=4769) and TimeCreated[@SystemTime&gt;='$(($fechaFiltro).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"))']]] 
        and 
        *[EventData[Data[@Name='TargetUserName']='$usuario']]
    </Select>
  </Query>
</QueryList>
"@

        try {
            $eventos = Get-WinEvent -ComputerName $dc.HostName -FilterXml $xmlQuery -ErrorAction Stop
            $conteo = 0
            
            foreach ($ev in $eventos) {
                $xml = [xml]$ev.ToXml()
                $serviceName = ($xml.Event.EventData.Data | Where-Object {$_.Name -eq "ServiceName"})."#text"
                $ipClient = ($xml.Event.EventData.Data | Where-Object {$_.Name -eq "IpAddress"})."#text"
                
                # Solo nos interesan nombres de máquinas, no servicios internos como krbtgt
                if ($serviceName -and $serviceName -notlike "krbtgt" -and $serviceName -notlike "*$") {
                    $resultadosGlobales += [PSCustomObject]@{
                        'Fecha y Hora'  = $ev.TimeCreated
                        'Equipo Destino'= $serviceName -replace "host/", ""
                        'IP de Origen'  = $ipClient
                        'Dominio'       = $dom
                        'DC de Registro'= $dc.HostName
                    }
                    $conteo++
                }
            }
            Write-Host "OK ($conteo eventos)" -ForegroundColor Green
        } catch {
            Write-Host "Sin eventos recientes." -ForegroundColor Gray
        }
    }
}

# --- PARTE FINAL (Donde fallaba antes) ---
Write-Host "`nProcesamiento finalizado." -ForegroundColor Yellow

if ($resultadosGlobales.Count -gt 0) {
    Write-Host "Mostrando tabla de resultados..." -ForegroundColor Green
    $resultadosGlobales | Sort-Object 'Fecha y Hora' -Descending | Out-GridView -Title "Historial de accesos: $usuario"
} else {
    Write-Host "No se encontraron registros de acceso para '$usuario' en el periodo consultado." -ForegroundColor Red
}