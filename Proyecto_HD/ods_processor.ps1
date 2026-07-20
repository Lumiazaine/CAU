# ods_processor.ps1 - Convierte datos ODS en JS de asignaciones por caso
$json = Get-Content -Path "$PSScriptRoot\ods_data.json" -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$rows = $data.Nuevo_Adriano
Write-Host "Nuevo_Adriano rows: $($rows.Count)" -ForegroundColor Cyan

# Skip header rows (1 header + row 0 is merged header)
# Find first row that starts with a digit (case number) or similar
$dataRows = @()
$started = $false
foreach ($r in $rows) {
    $case = "$($r[1])".Trim()
    # Only keep rows with actual case numbers
    if ($case -notmatch '^\d') { continue }
    $dataRows += ,$r
}
Write-Host "Data rows: $($dataRows.Count)" -ForegroundColor Green

# Build ODS_DATA constant
$odsEntries = @()
foreach ($r in $dataRows) {
    $caso = "$($r[1])".Trim()
    $desc = "$($r[2])".Trim()
    $clase = "$($r[3])".Trim()
    $tipo = "$($r[4])".Trim()
    $cat = "$($r[5])".Trim()
    $casuistica = "$($r[6])".Trim()
    $datos = "$($r[7])".Trim()
    $grupoPre = "$($r[8])".Trim()
    $nivelCSU = "$($r[9])".Trim()  # Actually empty for most rows, grupo is at [9]
    $agrupacion = "$($r[10])".Trim()
    $enlaces = "$($r[11])".Trim()
    
    # Clean up: remove leading/trailing pipes, normalize whitespace
    $casuistica = $casuistica -replace '^\s*\|\s*', '' -replace '\s*\|\s*$', '' -replace '\s*\|\s*', ' | '
    $datos = $datos -replace '^\s*\|\s*', '' -replace '\s*\|\s*$', ''
    
    # Escape for JS
    $jsEsc = { param($s) $s -replace '\\', '\\' -replace "'", "\'" -replace "`n", '\n' -replace "`r", '' -replace "`t", '\t' }
    
    $casoEsc = & $jsEsc $caso
    $descEsc = & $jsEsc $desc
    $claseEsc = & $jsEsc $clase
    $tipoEsc = & $jsEsc $tipo
    $catEsc = & $jsEsc $cat
    $casuisticaEsc = & $jsEsc $casuistica
    $datosEsc = & $jsEsc $datos
    $grupoPreEsc = & $jsEsc $grupoPre
    $nivelCSUEsc = & $jsEsc $nivelCSU
    $agrupacionEsc = & $jsEsc $agrupacion
    $enlacesEsc = & $jsEsc $enlaces
    
    $odsEntries += @"
  {caso:'$casoEsc', desc:'$descEsc', clase:'$claseEsc', tipo:'$tipoEsc', cat:'$catEsc', grupoPre:'$grupoPreEsc', nivelCSU:'$nivelCSUEsc', agrupacion:'$agrupacionEsc', enlaces:'$enlacesEsc'},
"@
}

# Build group map: caso -> grupo (use whichever has data: grupoPre [8] or nivelCSU [9])
$grupoMap = @{}
foreach ($r in $dataRows) {
    $caso = "$($r[1])".Trim()
    $grupo = "$($r[8])".Trim()
    if (!$grupo) { $grupo = "$($r[9])".Trim() }  # fallback to nivelCSU
    if ($caso -and $grupo) { $grupoMap[$caso] = $grupo }
}
$grupoJson = $grupoMap | ConvertTo-Json

# Build nivelCSU map
$nivelMap = @{}
foreach ($r in $dataRows) {
    $caso = "$($r[1])".Trim()
    $nivel = "$($r[9])".Trim()
    if ($caso -and $nivel) { $nivelMap[$caso] = $nivel }
}
$nivelJson = $nivelMap | ConvertTo-Json

# Build tipo map for TIPO->caso
$tipoCaso = @{}
foreach ($r in $dataRows) {
    $caso = "$($r[1])".Trim()
    $tipo = "$($r[4])".Trim()
    if ($caso -and $tipo) {
        if (!$tipoCaso.ContainsKey($tipo)) { $tipoCaso[$tipo] = @() }
        $tipoCaso[$tipo] += $caso
    }
}
$tipoJson = $tipoCaso | ConvertTo-Json

$js = @"
// ods_data.js - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')
// Source: Asignaciones Nuevo Adriano V7.04.ods ($($dataRows.Count) entries)
'use strict';

const ODS_CASOS = [
$($odsEntries -join "`n")
];

const ODS_GRUPO = $grupoJson;

const ODS_NIVEL_CSU = $nivelJson;

const ODS_TIPO_CASO = $tipoJson;

const ODS_STATS = {total:$($dataRows.Count),generated:'$(Get-Date -Format 'yyyy-MM-dd')'};
"@

$jsPath = "$PSScriptRoot\ods_data.js"
Set-Content -Path $jsPath -Value $js -Encoding UTF8
Write-Host "Generated: $jsPath ($($js.Length) bytes)" -ForegroundColor Green
Write-Host "Entries: $($dataRows.Count), Grupo maps: $($grupoMap.Count), Nivel maps: $($nivelMap.Count)" -ForegroundColor Cyan

# Summary statistics
$clases = @{}
$sinGrupo = 0
foreach ($r in $dataRows) {
    $clase = "$($r[3])".Trim()
    $g1 = "$($r[8])".Trim(); $g2 = "$($r[9])".Trim()
    $grupo = if ($g1) { $g1 } else { $g2 }
    if ($clase) { if (!$clases.ContainsKey($clase)) { $clases[$clase]=0 }; $clases[$clase]++ }
    if (!$grupo) { $sinGrupo++ }
}
Write-Host "`n=== Summary ===" -ForegroundColor Yellow
foreach ($c in $clases.Keys | Sort-Object) { Write-Host "  $c`: $($clases[$c])" }
Write-Host "  Sin grupo asignado: $sinGrupo"
