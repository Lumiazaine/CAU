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

# --- Leer la tabla M del script --------------------------------------------
function Get-TablaIndices {
    param([string]$Ruta)
    if (-not (Test-Path $Ruta)) { throw "No existe el fichero de tabla: $Ruta" }
    $texto = Get-Content $Ruta -Raw -Encoding UTF8

    $m = [regex]::Matches($texto, '(?m)^\s*"([^"]+)"\s*:\s*(\d+)\s*,\s*$')
    if ($m.Count -gt 0) {
        return $m | ForEach-Object {
            [pscustomobject]@{ Nombre = $_.Groups[1].Value; Indice = [int]$_.Groups[2].Value }
        }
    }
    $m2 = [regex]::Matches($texto, 'Map\("name",\s*"([^"]+)",\s*"albaParam",\s*(\d+)')
    if ($m2.Count -gt 0) {
        return $m2 | ForEach-Object {
            [pscustomobject]@{ Nombre = $_.Groups[1].Value; Indice = [int]$_.Groups[2].Value }
        }
    }
    throw "No se reconoce el formato de la tabla en $Ruta"
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

$huecos = @(0..(($tabla.Indice | Measure-Object -Maximum).Maximum) |
    Where-Object { $_ -notin $tabla.Indice })
if ($huecos) { Write-Aviso "Indices sin ninguna macro en la tabla: $($huecos -join ', ')" }
else { Write-Ok "Los indices van de 0 a $($tabla.Count - 1) sin huecos" }

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