param([string]$WikiDir = "$PSScriptRoot\wiki_data\raw", [string]$OutFile = "$PSScriptRoot\wiki_knowledge.js")

Add-Type -AssemblyName System.Web | Out-Null
Write-Host "=== Procesador Wiki -> wiki_knowledge.js v2 ===" -ForegroundColor Cyan

function Read-File($name) {
    $path = "$WikiDir\$name"
    if (Test-Path $path) { return Get-Content $path -Raw -Encoding UTF8 }
    return $null
}

function Strip-Wiki($text) {
    $t = $text -replace '<WRAP[^>]*>', '' -replace '</WRAP>', ''
    $t = $t -replace '<panel[^>]*>', '' -replace '</panel>', ''
    $t = $t -replace '<html>', '' -replace '</html>', ''
    $t = $t -replace '<[^>]+>', ''
    $t = $t -replace '\{\{[^}]*\}\}', ''
    $t = $t -replace '\[\[[^|]*\|([^\]]+)\]\]', '$1'
    $t = $t -replace '\[\[[^\]]+\]\]', ''
    $t = $t -replace '={2,}', ''
    $t = $t -replace '\*\*', ''
    $t = $t -replace '//', ''
    return $t.Trim()
}

$sb = New-Object System.Text.StringBuilder

# ============================================================
# 1. Parse routing tables from asignaciones_remedy
# ============================================================
Write-Host "=== Step 1: Routing tables ===" -ForegroundColor Green
$content = Read-File "pag_apli_remedy_asignaciones_remedy.txt"
$routing = @{}
$clase = ""

if ($content) {
    # Split by sections: each ==== Section ==== line
    $lines = $content -split "`n"
    $inTable = $false
    $headers = @()
    
    foreach ($line in $lines) {
        $t = $line.Trim()
        
        # Section headers: ==== ADRIANO ====, ==== APLICACIONES ==== etc
        if ($t -match '^={4,}\s*(\w+(?:\s*\w+)*)\s*={4,}') {
            $clase = $matches[1].Trim()
            Write-Host "  Section: $clase"
            $inTable = $false; $headers = @()
            continue
        }
        
        # DokuWiki table header: ^ Col1 ^ Col2 ^ Col3 ^
        if ($t -match '^\^.*\^$') {
            $cols = $t -split '\^' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            $headers = $cols
            $inTable = $true
            continue
        }
        
        # DokuWiki table row: | val1 | val2 | val3 |
        if ($inTable -and $t -match '^\|.*\|$' -and $t -notmatch '^\|+\s*$') {
            $cols = $t -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            if ($cols.Count -ge 3 -and $clase) {
                $rowClase = $cols[0]
                $tipo = $cols[1]
                $grupo = if ($cols.Count -ge 3) { $cols[2] } else { "" }
                # Use normalized section header as clase key
                $key = $clase -replace '\s+', '_'
                if ($tipo -and $grupo -and $grupo -ne '?' -and $grupo -ne '') {
                    if (!$routing.ContainsKey($key)) { $routing[$key] = @{} }
                    $routing[$key][$tipo] = $grupo
                    Write-Host "    $key | ($tipo) => $grupo" -ForegroundColor Green
                }
            }
        }
    }
}

Write-Host "Routes: $(($routing.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum) entries"

# ============================================================
# 2. Extract case keywords from Adriano problem pages
# ============================================================
Write-Host "`n=== Step 2: Case keywords ===" -ForegroundColor Green
$wikiKW = @{}
$wikiText = @{}

$files = @{
    "pag_apli_adriano_problemas_gya.txt" = "gya"
    "pag_apli_adriano_problemas_motor.txt" = "motor"
    "pag_apli_adriano_start.txt" = "start"
    "pag_apli_adriano_alta.txt" = "alta"
    "pag_apli_adriano_altanumo.txt" = "altanumo"
    "pag_apli_escritoriojudicial_problemas.txt" = "escritorio"
    "pag_apli_portal_adriano_problemas.txt" = "portal"
    "pag_apli_consultasadriano_problemas.txt" = "consulta"
    "pag_procedimientos_generales_gesti_certificados_adriano.txt" = "cert"
}

# Build combined text indexed by case number (use hashtable, not array)
$allSections = @{}
foreach ($fname in $files.Keys) {
    $fc = Read-File $fname
    if ($fc) {
        Write-Host "  Reading $fname ($($fc.Length) chars)"
        # Split by explicit case markers: "Caso X.Y" or "====" headers
        $parts = $fc -split '(?=Caso\s*[\d.]+\b|(?<==== ))'
        foreach ($part in $parts) {
            $cm = [regex]::Match($part, 'Caso\s+([\d]+(?:\.[\d]+)?)')
            if ($cm.Success) {
                $cn = $cm.Groups[1].Value
                if (!$allSections.ContainsKey($cn)) { $allSections[$cn] = @() }
                $allSections[$cn] += $part
            }
        }
    }
}

# Also scan cleaned text for case number mentions to capture surrounding context
foreach ($fname in $files.Keys) {
    $fc = Read-File $fname
    if (!$fc) { continue }
    $clean = Strip-Wiki($fc)
    $lines = $clean -split "`n"
    $currentCase = $null
    $currentLines = @()
    foreach ($line in $lines) {
        $cm = [regex]::Match($line, 'Caso\s+([\d]+(?:\.[\d]+)?)')
        if ($cm.Success) {
            # Save previous case's lines
            if ($currentCase -and $currentLines.Count -gt 1) {
                $joined = $currentLines -join " "
                if (!$allSections.ContainsKey($currentCase)) { $allSections[$currentCase] = @() }
                $allSections[$currentCase] += $joined
            }
            $currentCase = $cm.Groups[1].Value
            $currentLines = @($line)
        } elseif ($currentCase) {
            $currentLines += $line
        }
    }
    # Last case
    if ($currentCase -and $currentLines.Count -gt 1) {
        $joined = $currentLines -join " "
        if (!$allSections.ContainsKey($currentCase)) { $allSections[$currentCase] = @() }
        $allSections[$currentCase] += $joined
    }
}

Write-Host "Found sections for $($allSections.Count) case numbers"

# Extract keywords for each case
foreach ($cn in $allSections.Keys) {
    $combined = $allSections[$cn] -join " "
    $text = Strip-Wiki($combined)
    $words = [regex]::Matches($text.ToLower(), '\b([a-záéíóúñü]{4,20})\b') | ForEach-Object { $_.Groups[1].Value }
    $wc = @{}
    foreach ($w in $words) { $wc[$w] = if ($wc.ContainsKey($w)) { $wc[$w] + 1 } else { 1 } }
    $kws = @(($wc.GetEnumerator() | Where-Object { $_.Value -ge 2 } | Sort-Object Value -Descending).Key | Select-Object -First 30)
    if ($kws.Count -ge 2) {
        $wikiKW[$cn] = $kws
        $wikiText[$cn] = $text.Substring(0, [Math]::Min(300, $text.Length))
        Write-Host "  Case ${cn}: $($kws.Count) keywords" -ForegroundColor Green
    }
}

# ============================================================
# 3. PT keywords from hgis_puesto_de_trabajo
# ============================================================
Write-Host "`n=== Step 3: PT keywords ===" -ForegroundColor Green
$ptText = ""
$ptFiles = @("pag_hgis_puesto_de_trabajo.txt", "pag_puesto_impresoras.txt", "pag_puesto_telefonia.txt", "pag_puesto_crip.txt", "pag_puesto_compra.txt", "pag_puesto_alta_equipos.txt")
foreach ($f in $ptFiles) {
    $c = Read-File $f
    if ($c) { $ptText += " " + $c }
}
$ptClean = Strip-Wiki($ptText)
$ptWords = [regex]::Matches($ptClean.ToLower(), '\b([a-záéíóúñ]{4,20})\b') | ForEach-Object { $_.Groups[1].Value }
$ptWc = @{}
foreach ($w in $ptWords) { $ptWc[$w] = if ($ptWc.ContainsKey($w)) { $ptWc[$w] + 1 } else { 1 } }
$ptKWs = @(($ptWc.GetEnumerator() | Where-Object { $_.Value -ge 2 } | Sort-Object Value -Descending).Key | Select-Object -First 50)
Write-Host "PT keywords: $($ptKWs.Count)"

# ============================================================
# 4. Generate wiki_knowledge.js
# ============================================================
Write-Host "`n=== Step 4: Generate JS ===" -ForegroundColor Green

[void]$sb.AppendLine("// wiki_knowledge.js - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$sb.AppendLine("// Source: SSDJ Extranet Wiki")
[void]$sb.AppendLine("'use strict';")
[void]$sb.AppendLine()

# Routing JSON
[void]$sb.Append("const WIKI_ROUTING = {")
$first = $true
foreach ($clase in ($routing.Keys | Sort-Object)) {
    if (!$first) { [void]$sb.Append(",") }; $first = $false
    [void]$sb.Append("`n  '$([System.Web.HttpUtility]::JavaScriptStringEncode($clase))':{")
    $ifirst = $true
    foreach ($tipo in ($routing[$clase].Keys | Sort-Object)) {
        if (!$ifirst) { [void]$sb.Append(",") }; $ifirst = $false
        [void]$sb.Append("'$([System.Web.HttpUtility]::JavaScriptStringEncode($tipo))':'$([System.Web.HttpUtility]::JavaScriptStringEncode($routing[$clase][$tipo]))'")
    }
    [void]$sb.Append("}")
}
[void]$sb.AppendLine("`n};")
[void]$sb.AppendLine()

# Case keywords
[void]$sb.Append("const WIKI_KW = {")
$first = $true
foreach ($cn in ($wikiKW.Keys | Sort-Object)) {
    if (!$first) { [void]$sb.Append(",") }; $first = $false
    $escapedKws = @()
    foreach ($kw in $wikiKW[$cn]) { $escapedKws += "'$([System.Web.HttpUtility]::JavaScriptStringEncode($kw))'" }
    [void]$sb.Append("`n  '${cn}':[$($escapedKws -join ',')]")
}
[void]$sb.AppendLine("`n};")
[void]$sb.AppendLine()

# Case descriptions
[void]$sb.Append("const WIKI_DESC = {")
$first = $true
foreach ($cn in ($wikiText.Keys | Sort-Object)) {
    if (!$first) { [void]$sb.Append(",") }; $first = $false
    $d = $wikiText[$cn].Substring(0, [Math]::Min(300, $wikiText[$cn].Length))
    [void]$sb.Append("`n  '${cn}':'$([System.Web.HttpUtility]::JavaScriptStringEncode($d))'")
}
[void]$sb.AppendLine("`n};")
[void]$sb.AppendLine()

# PT keywords
$escPT = @()
foreach ($kw in $ptKWs) { $escPT += "'$([System.Web.HttpUtility]::JavaScriptStringEncode($kw))'" }
[void]$sb.AppendLine("const WIKI_PT_KW = [$($escPT -join ',')];")
[void]$sb.AppendLine()

# Stats
$routeCount = ($routing.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
$caseCount = $wikiKW.Count
[void]$sb.AppendLine("const WIKI_STATS = {routes:$routeCount, cases:$caseCount, ptKeywords:$($ptKWs.Count), generated:'$(Get-Date -Format 'yyyy-MM-dd')'};")
[void]$sb.AppendLine()

# Write file without BOM
$bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
[System.IO.File]::WriteAllBytes($OutFile, $bytes)
Write-Host "Output: $OutFile ($($bytes.Length) bytes)" -ForegroundColor Cyan

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Routing entries: $routeCount across $($routing.Count) clases"
Write-Host "  Cases with keywords: $caseCount"
Write-Host "  PT keywords: $($ptKWs.Count)"