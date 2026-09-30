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

# --- Anclar las rutas al script, no al directorio actual --------------------
# [IO.File]::ReadAllBytes resuelve una ruta relativa contra el CWD de .NET, que
# NO es el de PowerShell: Get-Location devuelve ...\Macro Remedy mientras que
# [Environment]::CurrentDirectory sigue en la carpeta desde la que arranco el
# proceso. Por eso Test-Path encontraba el fichero y ReadAllBytes no.
# Se resuelve todo a rutas absolutas antes de tocar nada.
$script:Base = $PSScriptRoot
if (-not $script:Base) { $script:Base = (Get-Location).Path }

if (-not [IO.Path]::IsPathRooted($Tabla))   { $Tabla   = Join-Path $script:Base $Tabla }
if ($ARCmds -and -not [IO.Path]::IsPathRooted($ARCmds)) { $ARCmds = Join-Path $script:Base $ARCmds }

function Write-Ok    { param($t) Write-Host "  [OK]     $t" -ForegroundColor Green }
function Write-Fail  { param($t) Write-Host "  [FALLO]  $t" -ForegroundColor Red; $script:Mal++ }
function Write-Aviso { param($t) Write-Host "  [AVISO]  $t" -ForegroundColor Yellow }
function Write-Tit   { Write-Host "`n$($args[0])" -ForegroundColor Cyan }

# --- Localizar el ARCmds ---------------------------------------------------
function Find-ARCmds {
    # Los candidatos se construyen uno a uno con comprobacion previa: armar un
    # array con Join-Path sobre $env:APPDATA cuando esa variable no existe
    # revienta con "Cannot bind argument to parameter 'Path' because it is null"
    # y se lleva por delante la busqueda entera.
    $candidatos = New-Object System.Collections.Generic.List[string]
    if ($script:ARCmds) { $candidatos.Add($script:ARCmds) }
    $candidatos.Add((Join-Path $script:Base 'ARCmds\ARCmds'))
    if ($env:APPDATA) {
        $candidatos.Add((Join-Path $env:APPDATA 'AR System\HOME\ARCmds'))
    }
    foreach ($c in $candidatos) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Container)) {
            $arq = @(Get-ChildItem -LiteralPath $c -Filter 'ZZZ*.arq' -File -ErrorAction SilentlyContinue)
            if ($arq.Count -gt 0) { return @{ Ruta = (Resolve-Path -LiteralPath $c).Path; Ficheros = $arq } }
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
# Esta funcion nunca debe lanzar una excepcion: si falla, se pierde el
# diagnostico justo cuando mas hace falta.
function Show-Diagnostico {
    param([string]$Ruta, [string[]]$Lineas)

    Write-Host ""
    Write-Host "  DIAGNOSTICO" -ForegroundColor Yellow
    Write-Host "    $Ruta"

    if (-not $Ruta -or -not (Test-Path $Ruta)) {
        Write-Host "    ruta vacia o fichero inexistente: no hay nada que leer"
        return
    }

    try {
        $bytes = [IO.File]::ReadAllBytes($Ruta)
    } catch {
        Write-Host "    no se pudieron leer los bytes: $($_.Exception.Message)"
        return
    }

    $cr = 0; $lf = 0; $nul = 0
    foreach ($x in $bytes) {
        if ($x -eq 13)     { $cr++ }
        elseif ($x -eq 10) { $lf++ }
        elseif ($x -eq 0)  { $nul++ }
    }
    Write-Host "    $($bytes.Length) bytes   CR=$cr  LF=$lf  NUL=$nul"

    # Codificado. Si el fichero esta en UTF-16 cada caracter ocupa 2 bytes con un
    # NUL intercalado: la tabla deja de encajar y solo casaria una linea suelta.
    $primeros = ($bytes | Select-Object -First 4) -join ' '
    $cod = 'UTF-8 sin BOM'
    if     ($bytes.Length -gt 1 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $cod = 'UTF-16 LE' }
    elseif ($bytes.Length -gt 1 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $cod = 'UTF-16 BE' }
    elseif ($bytes.Length -gt 2 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $cod = 'UTF-8 con BOM' }
    Write-Host "    codificado: $cod  (primeros bytes: $primeros)"

    if ($nul -gt 0) {
        Write-Host "    ATENCION: hay bytes NUL. Si el fichero esta en UTF-16, guardalo como UTF-8." -ForegroundColor Red
    }

    Write-Host "    primeras lineas no vacias:"
    $n = 0
    foreach ($linea in @($Lineas)) {
        if ($linea -and $linea.Trim() -ne '' -and $n -lt 12) {
            Write-Host "      | $($linea -replace "`t", '<TAB>')"
            $n++
        }
    }
    if ($n -eq 0) { Write-Host "      (ninguna linea con contenido)" }

    # El dato que decide la causa: cuantas lineas se han leido, cuantas parecen
    # entradas de tabla y cuantas encajan con el patron. Si hay 46 lineas con
    # "numero": y solo encaja 1, el problema es el patron o el codificado. Si
    # solo hay 1 linea con esa forma, el fichero de disco no es el que creemos.
    $conComillas = @($Lineas | Where-Object { $_ -match '"\s*:\s*\d' })
    $encajan = 0
    foreach ($l in $conComillas) {
        if ($l -match '^\s*"([^"]+)"\s*:\s*(\d+)\s*,?\s*$') { $encajan++ }
    }
    Write-Host "    lineas leidas: $($Lineas.Count)"
    Write-Host "    lineas que parecen entradas de tabla: $($conComillas.Count)"
    Write-Host "    lineas que encajan con el patron: $encajan"

    # La zona de la tabla, que es lo que de verdad importa. Si aqui hay 46 lineas
    # y el parser solo devuelve 1, el problema esta en el patron; si hay menos,
    # el fichero de disco no es el del repositorio.
    $iM = -1
    for ($k = 0; $k -lt $Lineas.Count; $k++) {
        if ($Lineas[$k] -match '^\s*M\s*:=') { $iM = $k; break }
    }
    if ($iM -ge 0) {
        Write-Host "    la tabla empieza en la linea $($iM + 1) de $($Lineas.Count). Primeras 4:"
        for ($k = $iM; $k -lt [Math]::Min($iM + 4, $Lineas.Count); $k++) {
            Write-Host "      linea $($k + 1) | $($Lineas[$k])"
        }
    } else {
        Write-Host "    NO se encuentra ninguna linea 'M :='. Ese fichero no es CAU_GUI_BETA_v2.ahk." -ForegroundColor Red
    }

    if ($conComillas.Count -gt 3 -and $encajan -lt 3) {
        Write-Host "    hay entradas de tabla pero casi ninguna encaja. Primeras 3:" -ForegroundColor Red
        $k = 0
        foreach ($l in $conComillas) {
            if ($k -ge 3) { break }
            Write-Host "      > $l"
            $k++
        }
    }
}

# --- Leer la tabla M del script --------------------------------------------
# Se prueban VARIAS decodificaciones y se queda con la que mas entradas saca.
# Motivo: en el equipo del usuario (Windows PowerShell 5.1) esta funcion devolvio
# un unico $null en vez de las 46 entradas, y el mensaje que llego fue
# "1 macros con nombre" con el nombre en blanco. Un $null unico envuelto en @()
# da .Count = 1 y se imprime como cadena vacia: es exactamente lo que se vio.
# Ninguna variante de fichero (CRLF, CR puro, BOM, cp1252, UTF-16, tabuladores,
# espacio duro) reproduce ese 1 con este codigo, asi que en vez de seguir
# buscandolo se hace la lectura a prueba de el: tres decodificaciones, dos
# formatos de tabla y eleccion de la mejor. Si ninguna llega a 10 entradas se
# dice cual fallo, en vez de propagar un valor a medias.
#
# Arrays de PowerShell y no List[object]: envolver una List[object] en @()
# lanza "Argument types do not match" sin importar cuantos elementos tenga. Con
# 46 entradas no hay nada que ganar con una lista.
function Convertir-Entradas {
    param([string[]]$Lineas)
    $rx = [regex]::new('^\s*"([^"]+)"\s*:\s*(\d+)\s*,?\s*$')
    $salida = @()
    foreach ($linea in $Lineas) {
        if ($null -eq $linea) { continue }
        $m = $rx.Match($linea)
        if (-not $m.Success) { continue }
        $indice = 0
        # TryParse en vez de [int]: si el numero no cabe, TryParse devuelve
        # false y la entrada se descarta en vez de reventar la conversion.
        if ([int]::TryParse($m.Groups[2].Value, [ref]$indice)) {
            $salida += [pscustomobject]@{ Nombre = $m.Groups[1].Value; Indice = $indice }
        }
    }
    return $salida
}

function Convertir-Entradas-Map {
    param([string[]]$Lineas)
    $rx = [regex]::new('Map\("name",\s*"([^"]+)",\s*"albaParam",\s*(\d+)')
    $salida = @()
    foreach ($linea in $Lineas) {
        if ($null -eq $linea) { continue }
        $m = $rx.Match($linea)
        if (-not $m.Success) { continue }
        $indice = 0
        if ([int]::TryParse($m.Groups[2].Value, [ref]$indice)) {
            $salida += [pscustomobject]@{ Nombre = $m.Groups[1].Value; Indice = $indice }
        }
    }
    return $salida
}

function Get-TablaIndices {
    param([string]$Ruta)

    if (-not $Ruta) { throw "Ruta de tabla vacia" }
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) {
        throw "No existe el fichero de tabla: $Ruta"
    }

    # Leer bytes y decodificar a mano en vez de Get-Content -Raw: este depende
    # de la version de PowerShell y del BOM, y con -Encoding UTF8 sobre un
    # fichero sin BOM no es de fiar en Windows PowerShell 5.1.
    $bytes = [IO.File]::ReadAllBytes($Ruta)
    if (-not $bytes -or $bytes.Length -eq 0) { throw "El fichero de tabla esta vacio: $Ruta" }

    $candidatos = @(
        [pscustomobject]@{ Cod = 'UTF-8';        Texto = [Text.Encoding]::UTF8.GetString($bytes) }
        [pscustomobject]@{ Cod = 'Windows-1252'; Texto = [Text.Encoding]::GetEncoding(1252).GetString($bytes) }
        [pscustomobject]@{ Cod = 'UTF-16';       Texto = [Text.Encoding]::Unicode.GetString($bytes) }
    )

    $mejor = @()
    $mejorCod = '(ninguno)'
    $mejorFormato = '(ninguno)'

    Write-Host "  probando $($candidatos.Count) codificados x 2 formatos de tabla:"
    foreach ($c in $candidatos) {
        # Normalizar finales de linea: CRLF, CR puro y LF dan el mismo resultado.
        $normalizado = ($c.Texto -replace "`r`n", "`n") -replace "`r", "`n"
        $lineas = $normalizado -split "`n"

        $a = @(Convertir-Entradas -Lineas $lineas)
        Write-Host ("    {0,-13} {1,4} entradas con el formato tabla M" -f $c.Cod, $a.Count)
        if ($a.Count -gt $mejor.Count) { $mejor = $a; $mejorCod = $c.Cod; $mejorFormato = 'tabla M' }

        $b = @(Convertir-Entradas-Map -Lineas $lineas)
        Write-Host ("    {0,-13} {1,4} entradas con el formato Map(...)" -f $c.Cod, $b.Count)
        if ($b.Count -gt $mejor.Count) { $mejor = $b; $mejorCod = $c.Cod; $mejorFormato = 'Map(...)' }
    }

    if ($mejor.Count -eq 0) {
        $tx = [Text.Encoding]::UTF8.GetString($bytes)
        Show-Diagnostico -Ruta $Ruta -Lineas ((($tx -replace "`r`n", "`n") -replace "`r", "`n") -split "`n")
        throw "No se reconoce el formato de la tabla en $Ruta"
    }

    Write-Host "  mejor lectura: $($mejor.Count) entradas  (codificado $mejorCod, formato $mejorFormato)"
    return $mejor
}

# Lineas del fichero de tabla, para diagnosticar sin volver a leerlo.
# -LiteralPath y try/catch: si algo falla aqui, el diagnostico se queda sin
# lineas pero el resto del script sigue pudiéndose ejecutar.
$lineasCache = @()
try {
    if ($Tabla -and (Test-Path -LiteralPath $Tabla -PathType Leaf)) {
        $b = [IO.File]::ReadAllBytes($Tabla)
        $t = [Text.Encoding]::UTF8.GetString($b)
        $lineasCache = (($t -replace "`r`n", "`n") -replace "`r", "`n") -split "`n"
    }
} catch {
    $lineasCache = @()
}

# ============================================================================
Write-Tit "Verificacion de la tabla de indices de macros"
Write-Host "  Tabla  : $Tabla"

Write-Tit "1. Coherencia interna de la tabla"
try {
    # $tablaM y no $tabla: ver la nota de mas abajo sobre el choque de nombres.
    $tablaM = @(Get-TablaIndices -Ruta $Tabla)
} catch {
    Write-Fail $_.Exception.Message
    exit 1
}
Write-Host "  $($tablaM.Count) macros con nombre"

# Un recuento absurdo no es "la tabla tiene pocas macros": es que no se ha leido
# bien. Menos de 10 entradas es lectura fallida, no tabla corta.
#
# OJO con el nombre: este array se llama $tablaM y no $tabla porque PowerShell
# no distingue mayusculas, $tabla era LA MISMA variable que el parametro $Tabla
# con la ruta del fichero, y al asignarla se perdia la ruta. Despues el
# diagnostico recibia una ruta vacia y ReadAllBytes tiraba "la ruta de acceso no
# tiene un formato valido", que era el sintoma que veia el usuario.
if ($tablaM.Count -lt 10) {
    Write-Fail "Solo $($tablaM.Count) entradas leidas de $Tabla. Es una lectura fallida, no una tabla corta."
    Show-Diagnostico -Ruta $Tabla -Lineas $lineasCache
    exit 1
}

$dupIdx = $tablaM | Group-Object Indice | Where-Object Count -gt 1
if ($dupIdx) {
    foreach ($d in $dupIdx) {
        Write-Fail "Indice $($d.Name) asignado a $($d.Count) macros: $(($d.Group.Nombre) -join '  /  ')"
    }
} else { Write-Ok "Ningun indice esta asignado a dos macros" }

$dupNom = $tablaM | Group-Object Nombre | Where-Object Count -gt 1
if ($dupNom) {
    foreach ($d in $dupNom) { Write-Fail "Nombre repetido: $($d.Name)" }
} else { Write-Ok "Ningun nombre aparece dos veces" }

$maxIdx = ($tablaM.Indice | Measure-Object -Maximum).Maximum
$huecos = @(0..$maxIdx | Where-Object { $_ -notin $tablaM.Indice })
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

    if ($tablaM.Count -ne $total) {
        Write-Fail "La tabla tiene $($tablaM.Count) macros y ARCmds tiene $total. TODOS los indices estan desplazados."
        $diff = $total - $tablaM.Count
        Write-Host "         Se han anadido $diff macro(s). Los de la zona alta van +$diff."
        Write-Host "         Copia ARCmds/ARCmds/ al equipo y vuelve a pasar esto."
    } else {
        Write-Ok "El numero de macros coincide con el supuesto de la tabla"
    }

    Write-Host "`n  Indice | Fichero .arq                      | Nombre visible"
    Write-Host "  -------+----------------------------------+---------------------------"
    foreach ($m in $reales) {
        $marca = ''
        if (-not ($tablaM.Indice -contains $m.Indice)) { $marca = '  <- sin entrada en la tabla' }
        Write-Host ("  {0,6} | {1,-32} | {2}{3}" -f $m.Indice, $m.Fichero, $m.Nombre, $marca)
    }

    # Cada .arq debe tener una fila de la tabla, por indice o por nombre.
    $sinCubrir = @($reales | Where-Object { $_.Indice -notin $tablaM.Indice })
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