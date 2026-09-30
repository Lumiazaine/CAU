<#
.SYNOPSIS
    Contrasta la tabla de índices de macros contra el ARCmds real.

.DESCRIPTION
    La macro CAU navega por el formulario Alba con {TAB 2}{End}{Up n}{Enter}. El
    número de macro NO es un ID: es la posición contada desde la última fila de
    una lista ORDENADA ALFABÉTICAMENTE.

        n = (nº de macros - 1) - posición alfabética

    Si se añade, borra o renombra una macro, todas las que están por debajo se
    desplazan y los botones ejecutan otra cosa sin avisar.

    Este script es de SOLO LECTURA: no modifica ni ARCmds ni la macro.

    El nombre visible de cada macro está en la LÍNEA 1 de su .arq, codificada en
    Windows-1252. El prefijo "ZZZ" es lo que fuerza el orden alfabético.

    Comprueba:
      1. Que la tabla del script no asigna un índice a dos macros.
      2. Que el número de .arq coincide con el supuesto de la tabla.
      3. Cada macro de la tabla contra su índice real, calculado desde los .arq.
      4. Las macros de ARCmds que la tabla no conoce.

.PARAMETER Tabla
    Script que contiene la tabla M. Por defecto, el port v2.

.PARAMETER ARCmds
    Carpeta con los .arq. Por defecto busca primero la del repo y luego la del
    %APPDATA% del equipo.

.PARAMETER SoloLectura
    Solo valida la tabla, sin buscar los .arq.

.EXAMPLE
    .\verificar_indices.ps1

.EXAMPLE
    .\verificar_indices.ps1 -Tabla "Core\ButtonManager.ahk"

.NOTES
    Autor: CAU. Si ARCmds no está accesible solo valida la tabla estática y avisa.
#>

[CmdletBinding()]
param(
    [string]$Tabla = "CAU_GUI_BETA_v2.ahk",
    [string]$ARCmds,
    [switch]$SoloLectura
)

$ErrorActionPreference = 'Stop'
$script:Mal = 0

function Write-Ok    { param($t) Write-Host "  [OK]     $t" -ForegroundColor Green }
function Write-Fail  { param($t) Write-Host "  [FALLO]  $t" -ForegroundColor Red; $script:Mal++ }
function Write-Aviso { param($t) Write-Host "  [AVISO]  $t" -ForegroundColor Yellow }
function Write-Tit   { Write-Host "`n$($args[0])" -ForegroundColor Cyan }

# --- Localizar el ARCmds ---------------------------------------------------
function Find-ARCmds {
    $candidatos = @(
        $script:ARCmds
        (Join-Path $PSScriptRoot 'ARCmds\ARCmds')
        "$env:APPDATA\AR System\HOME\ARCmds"
    ) | Where-Object { $_ }
    foreach ($c in $candidatos) {
        if (Test-Path $c) {
            $arq = @(Get-ChildItem -Path $c -Filter 'ZZZ*.arq' -File -ErrorAction SilentlyContinue)
            if ($arq.Count -gt 0) { return @{ Ruta = $c; Ficheros = $arq } }
        }
    }
    return $null
}

# --- Leer el nombre visible (linea 1, Windows-1252) -------------------------
function Get-MacrosReales {
    param([string]$Ruta)
    $cp1252 = [Text.Encoding]::GetEncoding(1252)
    $macros = foreach ($f in Get-ChildItem -Path $Ruta -Filter 'ZZZ*.arq' -File) {
        $bytes = [IO.File]::ReadAllBytes($f.FullName)
        $fin = 0
        while ($fin -lt $bytes.Length -and $bytes[$fin] -ne 0x0A) { $fin++ }
        [pscustomobject]@{
            Fichero = $f.Name
            Nombre  = $cp1252.GetString($bytes, 0, $fin).TrimEnd("`r")
        }
    }
    # Alfabetico sin distinguir mayusculas; desempate por nombre de fichero.
    # Ordenar por BYTE daria un resultado distinto: "S" < "n", que pone
    # ZZZISLApagado antes que ZZZInternetlibre. El formulario va alfabetico.
    $orden = $macros | Sort-Object @{ E = { $_.Nombre.ToLower() } }, Fichero
    $total = @($orden).Count
    $i = 0
    foreach ($m in $orden) {
        $m | Add-Member -NotePropertyName Indice -NotePropertyValue ($total - 1 - $i)
        $i++
    }
    return $orden
}

# --- Si algo no cuadra, ensena como se ha leido el fichero -----------------
function Show-Diagnostico {
    param([string]$Ruta, [string[]]$Lineas)
    Write-Host ""
    Write-Host "  DIAGNOSTICO de $Ruta" -ForegroundColor Yellow
    if (-not (Test-Path $Ruta)) { Write-Host "    el fichero no existe"; return }
    $bytes = [IO.File]::ReadAllBytes($Ruta)
    $cr = 0; $lf = 0
    foreach ($x in $bytes) { if ($x -eq 13) { $cr++ } elseif ($x -eq 10) { $lf++ } }
    Write-Host "    $($bytes.Length) bytes, $($Lineas.Count) lineas"
    Write-Host "    CR=$cr  LF=$lf  ->  $(if ($cr -eq 0) { 'solo LF' } elseif ($cr -eq $lf) { 'CRLF' } else { 'MIXTO, raro' })"
    Write-Host "    primeras lineas no vacias:"
    $n = 0
    foreach ($linea in $Lineas) {
        if ($linea.Trim() -and $n -lt 12) { Write-Host "      | $linea"; $n++ }
    }
}

# --- Leer la tabla M del script --------------------------------------------
function Get-TablaIndices {
    param([string]$Ruta)
    if (-not (Test-Path $Ruta)) { throw "No existe el fichero de tabla: $Ruta" }

    # Leer bytes y decodificar a mano en vez de Get-Content -Raw: este depende
    # de la version de PowerShell y del BOM, y con -Encoding UTF8 sobre un
    # fichero sin BOM no es de fiar en Windows PowerShell 5.1.
    $bytes = [IO.File]::ReadAllBytes($Ruta)
    $texto = [Text.Encoding]::UTF8.GetString($bytes)
    $texto = $texto -replace "`r`n", "`n" -replace "`r", "`n"
    $lineas = $texto -split "`n"

    # Linea a linea, sin modo multilinea y sin anclar $: el resultado no depende
    # de como esten los finales de linea ni de como interprete el motor .NET
    # las anclas. La primera version usaba un unico regex con (?m) sobre todo
    # el fichero y en el equipo del usuario devolvio 1 entrada de 46.
    $res = @()
    foreach ($linea in $lineas) {
        if ($linea -match '^\s*"([^"]+)"\s*:\s*(\d+)\s*,?\s*$') {
            $res += [pscustomobject]@{ Nombre = $Matches[1]; Indice = [int]$Matches[2] }
        }
    }
    if ($res.Count -gt 0) { return $res }

    # Formato antiguo de Core/ButtonManager.ahk: Map("name", "X", "albaParam", N)
    $res = @()
    foreach ($linea in $lineas) {
        if ($linea -match 'Map\("name",\s*"([^"]+)",\s*"albaParam",\s*(\d+)') {
            $res += [pscustomobject]@{ Nombre = $Matches[1]; Indice = [int]$Matches[2] }
        }
    }
    if ($res.Count -gt 0) { return $res }

    Show-Diagnostico -Ruta $Ruta -Lineas $lineas
    throw "No se reconoce el formato de la tabla en $Ruta"
}

# Lineas del fichero de tabla, para diagnosticar sin volver a leerlo.
$lineasCache = @()
if (Test-Path $Tabla) {
    $b = [IO.File]::ReadAllBytes($Tabla)
    $t = [Text.Encoding]::UTF8.GetString($b) -replace "`r`n", "`n" -replace "`r", "`n"
    $lineasCache = $t -split "`n"
}

# ============================================================================
Write-Tit "Verificacion de la tabla de indices de macros"
Write-Host "  Tabla  : $Tabla"

Write-Tit "1. Coherencia interna de la tabla"
try {
    $tabla = @(Get-TablaIndices -Ruta $Tabla)
} catch {
    Write-Fail $_.Exception.Message
    exit 1
}
Write-Host "  $($tabla.Count) macros con nombre"

# Un recuento absurdo no es "la tabla tiene pocas macros": es que no se ha leido
# bien. La primera version leia 1 entrada de 46 y concluia que faltaban 45
# macros en ARCmds, senalando la tabla como desviada cuando lo roto era el
# parser. Menos de 10 entradas es lectura fallida, no tabla corta.
if ($tabla.Count -lt 10) {
    Write-Fail "Solo $($tabla.Count) entradas leidas de $Tabla. Es una lectura fallida, no una tabla corta."
    Show-Diagnostico -Ruta $Tabla -Lineas $lineasCache
    exit 1
}

$dupIdx = $tabla | Group-Object Indice | Where-Object Count -gt 1
if ($dupIdx) {
    foreach ($d in $dupIdx) {
        Write-Fail "Indice $($d.Name) asignado a $($d.Count) macros: $(($d.Group.Nombre) -join '  /  ')"
    }
} else { Write-Ok "Ningun indice esta asignado a dos macros" }

$dupNom = $tabla | Group-Object Nombre | Where-Object Count -gt 1
if ($dupNom) {
    foreach ($d in $dupNom) { Write-Fail "Nombre repetido: $($d.Name)" }
} else { Write-Ok "Ningun nombre aparece dos veces" }

$maxIdx = ($tabla.Indice | Measure-Object -Maximum).Maximum
$huecos = @(0..$maxIdx | Where-Object { $_ -notin $tabla.Indice })
if ($huecos) { Write-Aviso "Indices sin ninguna macro en la tabla: $($huecos -join ', ')" }
else { Write-Ok "Los indices van de 0 a $maxIdx sin huecos" }

# --- 2. Contraste con los .arq ---------------------------------------------
Write-Tit "2. Contraste con los .arq de ARCmds"

$arc = $null
if (-not $SoloLectura) { $arc = Find-ARCmds }

if ($null -eq $arc) {
    Write-Aviso "ARCmds no accesible desde esta sesion. Solo tabla estatica validada."
    Write-Host "         Para el contraste, ejecutar en un equipo con Remedy abierto o con"
    Write-Host "         el ARCmds del repo a mano."
} else {
    Write-Host "  ARCmds : $($arc.Ruta)"
    $reales = @(Get-MacrosReales -Ruta $arc.Ruta)
    $total = $reales.Count
    Write-Host "  $total macros ZZZ*.arq, indices 0..$($total - 1)"

    if ($tabla.Count -ne $total) {
        Write-Fail "La tabla tiene $($tabla.Count) macros y ARCmds tiene $total. TODOS los indices estan desplazados."
        $diff = $total - $tabla.Count
        Write-Host "         Se han anadido $diff macro(s). Los de la zona alta van +$diff."
        Write-Host "         Copia ARCmds/ARCmds/ al equipo y vuelve a pasar esto."
    } else {
        Write-Ok "El numero de macros coincide con el supuesto de la tabla"
    }

    Write-Host "`n  Indice | Fichero .arq                      | Nombre visible"
    Write-Host "  -------+----------------------------------+---------------------------"
    foreach ($m in $reales) {
        $marca = ''
        if (-not ($tabla.Indice -contains $m.Indice)) { $marca = '  <- sin entrada en la tabla' }
        Write-Host ("  {0,6} | {1,-32} | {2}{3}" -f $m.Indice, $m.Fichero, $m.Nombre, $marca)
    }

    # Cada .arq debe tener una fila de la tabla, por indice o por nombre.
    $sinCubrir = @($reales | Where-Object { $_.Indice -notin $tabla.Indice })
    if ($sinCubrir.Count -gt 0) {
        Write-Host ""
        Write-Aviso "$($sinCubrir.Count) macro(s) de ARCmds sin fila propia en la tabla:"
        foreach ($m in $sinCubrir) { Write-Host "         fila $($m.Indice)  $($m.Fichero)  ($($m.Nombre))" }
    } else {
        Write-Ok "Todas las macros de ARCmds tienen fila en la tabla"
    }
}

# --- Resumen ---------------------------------------------------------------
Write-Tit "Resumen"
if ($script:Mal -eq 0) {
    Write-Host "  Todo correcto." -ForegroundColor Green
} else {
    Write-Host "  $script:Mal problema(s). La tabla se ha desfasado: corrige el objeto M." -ForegroundColor Red
}
Write-Host ""
exit ($(if ($script:Mal -eq 0) { 0 } else { 1 }))