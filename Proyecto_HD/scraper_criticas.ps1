#Requires -Version 5.1
# scraper_criticas.ps1 — Monitor de incidencias críticas en Remedy
# Uso: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "scraper_criticas.ps1"
# Genera criticas_data.js para el dashboard

$script:url = "https://infosistemas.justicia.junta-andalucia.es/remedy-criticas/admin/informe.php?f=statspat&type=CRITICAS"
$script:outJs = Join-Path $PSScriptRoot "criticas_data.js"
$script:pollSec = 60
$script:errorCount = 0

function Write-Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host ("[$ts] $msg")
}

function Get-CellText($cellHtml) {
    $text = $cellHtml -replace '<[^>]+>', ''
    return $text.Trim()
}

function Get-CellTitle($cellHtml) {
    $m = [regex]::Match($cellHtml, 'TITLE="([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Parse-Statspat($html) {
    $flat = $html -replace "`r`n", " " -replace "`n", " "
    $rowPattern = '<tr>(.*?ViewFormServlet.*?)</tr>'
    $rows = [regex]::Matches($flat, $rowPattern)
    $result = @()

    foreach ($m in $rows) {
        $rowHtml = $m.Groups[1].Value
        $tds = [regex]::Matches($rowHtml, '<td[^>]*>(.*?)</td>')
        if ($tds.Count -lt 13) { continue }

        # Col 0: INC — TITLE = descripción, <font> text = ID
        $c0 = $tds[0].Value
        $desc = Get-CellTitle $c0
        $idMatch = [regex]::Match($c0, '<font[^>]*>([^<]*)</font>')
        if (-not $idMatch.Success) { continue }
        $id = $idMatch.Groups[1].Value.Trim()
        if ($id -eq '') { continue }

        # Col 2-11: datos básicos
        $prov   = Get-CellText $tds[2].Value
        $loc    = Get-CellText $tds[3].Value
        $sede   = Get-CellText $tds[4].Value
        $uf     = Get-CellText $tds[5].Value
        $clase  = Get-CellText $tds[6].Value
        $tipo   = Get-CellText $tds[7].Value
        $creador = Get-CellText $tds[8].Value
        $grupo  = Get-CellText $tds[9].Value
        $asignado = Get-CellText $tds[10].Value
        $usuario = Get-CellText $tds[11].Value

        # Col 12: DIAS ABIERTA — TITLE = fecha apertura, text = días
        $c12 = $tds[12].Value
        $fecha = Get-CellTitle $c12
        $diasMatch = [regex]::Match($c12, '<font[^>]*>([^<]*)</font>')
        $dias = 0
        if ($diasMatch.Success) {
            $diasText = $diasMatch.Groups[1].Value.Trim()
            $dias = [int]($diasText -replace '\D', '')
        }

        # Only include rows with valid IDs
        if ($id -match '^IN\d+$' -or $id -match '^\d+$') {
            $result += @{
                id = $id
                desc = $desc
                provincia = $prov
                localidad = $loc
                sede = $sede
                unidadFuncional = $uf
                clase = $clase
                tipo = $tipo
                creador = $creador
                grupo = $grupo
                asignado = $asignado
                usuario = $usuario
                fechaApertura = $fecha
                diasAbierta = $dias
            }
        }
    }
    return $result
}

function Write-CriticasJs($data) {
    $json = ConvertTo-Json -InputObject $data -Depth 3 -Compress
    $content = "window.CRITICAS_DATA = $json;"
    [System.IO.File]::WriteAllText($script:outJs, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Log "Escrito criticas_data.js - $($data.Count) incidencias"
}

function Main-Loop {
    Write-Log "Iniciando monitor de incidencias críticas (cada ${pollSec}s)"
    Write-Log "URL: $($script:url)"
    Write-Log ("Salida: " + $script:outJs)
    Write-Log "---"

    while ($true) {
        try {
            $wc = New-Object System.Net.WebClient
            $bytes = $wc.DownloadData($script:url)
            $html = [System.Text.Encoding]::UTF8.GetString($bytes)
            $data = Parse-Statspat $html
            if ($data.Count -gt 0) {
                $sorted = $data | Sort-Object { [int]$_.diasAbierta }
                Write-CriticasJs $sorted
                $script:errorCount = 0
            } else {
                Write-Log "ADVERTENCIA: No se encontraron incidencias en la tabla"
            }
        } catch {
            $script:errorCount++
            Write-Log "ERROR ($($script:errorCount)): $($_.Exception.Message)"
            if ($script:errorCount -ge 5) {
                Write-Log "Demasiados errores consecutivos. Esperando 120s..."
                # Write empty data to avoid stale data on dashboard
                Write-CriticasJs @()
                Start-Sleep -Seconds 120
                $script:errorCount = 0
            }
        }

        Start-Sleep -Seconds $script:pollSec
    }
}

Main-Loop
