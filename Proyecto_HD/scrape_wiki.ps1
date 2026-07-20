param([string]$OutputDir = "$PSScriptRoot\wiki_data", [int]$DelayMs = 300)

Add-Type -AssemblyName System.Web | Out-Null
$BASE = "https://extranet.chap.junta-andalucia.es/dokuwiki/!ssdj"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
Write-Host "=== Wiki scraper SSDJ v3 (profundo) ===" -ForegroundColor Cyan; Write-Host "Output: $OutputDir`n"

foreach ($d in @("raw","html")) { $p = "$OutputDir\$d"; if (!(Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }
$downloaded = @{}
if (Test-Path "$OutputDir\raw") { Get-ChildItem "$OutputDir\raw" -Name | ForEach-Object { $downloaded[$_ -replace '\.txt$',''] = $true } }
Write-Host "Already downloaded: $($downloaded.Count)" -ForegroundColor DarkYellow

$cc = New-Object System.Net.CookieContainer
function newCookie($n,$v,$p) { $c=New-Object System.Net.Cookie; $c.Name=$n; $c.Value=$v; $c.Path=$p; $c.Domain="extranet.chap.junta-andalucia.es"; $cc.Add($c) }
newCookie "DokuWiki" "us4t3smfngb0mvsp3j3erfrjq4" "/dokuwiki/!ssdj/"
newCookie "DWc4fc8116f3d2910c745622ac4bdeb5eb" "anVzdDkuc2FuZGV0ZWwuZXh0%7C1%7CIs3XKoi43WvbnPsskKXMXWb31l%2FEdYMA9TEuTomoXneL88M4z1GlohR%2FeH0eth4P" "/dokuwiki/!ssdj/"
newCookie "FCK_NmSp_acl" "us4t3smfngb0mvsp3j3erfrjq4" "/"
newCookie "FCK_NmSp" "pag_procedimientos_generales%3Agesti" "/"
newCookie "FCK_SCAYT_AUTO" "off" "/"
newCookie "FCK_media" "%2Fdokuwiki%2F%21ssdj%2Fimage%2F" "/"

$Global:session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$Global:session.Cookies = $cc

function Get-Url($url) {
    Start-Sleep -Milliseconds $DelayMs
    try { return Invoke-WebRequest -Uri $url -WebSession $Global:session -UseBasicParsing -UserAgent $UA -TimeoutSec 30 }
    catch { return $null }
}

function Save-Page($pageId, $tag) {
    $safeName = $pageId -replace '[/:<>"|?*=&#'']', '_' -replace '\s', '_'
    if ($downloaded.ContainsKey($safeName)) { return $false }
    Write-Host "  [$tag] $pageId"
    $text = $null
    $r = Get-Url "$BASE/doku.php?id=$pageId&do=edit"
    if ($r) {
        $c = $r.Content
        $taIdx = $c.IndexOf('<textarea')
        if ($taIdx -ge 0) {
            $taStart = $c.IndexOf('>', $taIdx) + 1
            $taEnd = $c.IndexOf('</textarea>', $taStart)
            if ($taEnd -gt $taStart) {
                $wt = [System.Web.HttpUtility]::HtmlDecode($c.Substring($taStart, $taEnd - $taStart))
                Set-Content -Path "$OutputDir\raw\$safeName.txt" -Value $wt -Encoding UTF8
                $text = $wt
                Write-Host "    raw: $($wt.Length) chars"
            }
        }
    }
    $r2 = Get-Url "$BASE/doku.php?id=$pageId&do=export_xhtml"
    if ($r2 -and $r2.Content -notmatch 'Permiso Denegado') {
        try {
            $htmlStr = $r2.Content
            Set-Content -Path "$OutputDir\html\$safeName.html" -Value $htmlStr -Encoding UTF8
            Write-Host "    html: $($htmlStr.Length) bytes"
        } catch { Write-Host "    html: FAILED" -ForegroundColor DarkYellow }
    }
    $downloaded[$safeName] = $true
    return ($text -ne $null)
}

function Sanitize-PageId($id) {
    $id = $id.Trim()
    $id = $id -replace '<.*$', ''
    $id = $id -replace '#.*$', ''
    $id = $id -replace '\?.*$', ''
    $id = $id -replace '\.\.\..*$', ''
    $id = $id -replace '[<>"|?*=\\]', ''
    $id = $id.Trim()
    # Skip near-empty IDs
    if ($id.Length -le 2) { return '' }
    return $id
}

function Extract-Links($text) {
    $links = @{}
    if (!$text) { return $links }
    # DokuWiki internal links: [[namespace:page]] or [[namespace:page|label]]
    foreach ($m in [regex]::Matches($text, '\[\[:?([^\]]+?)(?:\|[^\]]*)?\]\]')) {
        $target = $m.Groups[1].Value -replace '^:','' -replace '#.*$',''
        $target = $target.Trim()
        if ($target -and $target -ne 'start' -and $target -notmatch '^https?://' -and $target -notmatch '^#' -and $target -notmatch '^\*' -and $target -notmatch '^\.+:' -and $target -notmatch '^[a-z]+>' -and $target -notmatch '^\.\.' -and $target -notmatch '\s' -and $target.Length -gt 2) {
            $links[$target] = $true
        }
    }
    # Full URLs to internal pages (from HTML content)
    foreach ($m in [regex]::Matches($text, 'doku\.php\?id=([^\s"&]+)')) {
        $target = [System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value) -replace '#.*$',''
        if ($target -and $target -ne 'start') { $links[$target] = $true }
    }
    return $links
}

function Extract-Namespaces($pageId) {
    # Extract potential sub-namespaces from a page ID
    $parts = $pageId -split ':'
    if ($parts.Length -ge 2) {
        # The parent namespace is everything except the last part
        return ($parts[0..($parts.Length-2)] -join ':')
    }
    return $null
}

# ============================================================
# STEP 1: Verify auth
# ============================================================
Write-Host "=== STEP 1: Auth ===" -ForegroundColor Green
$t = Get-Url "$BASE/doku.php?id=start&do=edit"
if (!$t -or !$t.Content.Contains('<textarea')) {
    Write-Host "AUTH FAILED" -ForegroundColor Red; exit 1
}
Write-Host "Auth OK!" -ForegroundColor Green

# ============================================================
# STEP 2: Initial discovery — collect page IDs
# ============================================================
Write-Host "`n=== STEP 2: Discover pages ===" -ForegroundColor Green
$allIds = @{}
$knownNamespaces = @{}  # track namespaces for recursive listing

# 2a. Index page
Write-Host "--- Index ---" -ForegroundColor Yellow
$a = Get-Url "$BASE/doku.php?do=index"
if ($a) {
    Set-Content -Path "$OutputDir\index.html" -Value $a.Content -Encoding UTF8
    Write-Host "Index: $($a.Content.Length) bytes"
    foreach ($m in [regex]::Matches($a.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
        $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
        if ($id -and $id -ne "start" -and !$allIds.ContainsKey($id)) { $allIds[$id] = $true }
    }
}
Write-Host "  $($allIds.Count) from index"

# 2b. AJAX index (full tree without JS)
Write-Host "--- AJAX Index ---" -ForegroundColor Yellow
$ajaxIdx = Get-Url "$BASE/lib/exe/ajax.php?call=index"
if ($ajaxIdx) {
    Write-Host "AJAX index: $($ajaxIdx.Content.Length) bytes"
    foreach ($m in [regex]::Matches($ajaxIdx.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
        $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
        if ($id -and $id -ne "start" -and !$allIds.ContainsKey($id)) { $allIds[$id] = $true; Write-Host "  AJAX: $id" -ForegroundColor Cyan }
    }
    # Also extract namespace directories
    foreach ($m in [regex]::Matches($ajaxIdx.Content, 'data-ns-name="([^"]+)"')) {
        $ns = [System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)
        if ($ns -and !$knownNamespaces.ContainsKey($ns)) { $knownNamespaces[$ns] = $true }
    }
}
Write-Host "  $($allIds.Count) after AJAX index, $($knownNamespaces.Count) namespaces"

# 2c. Try root namespace listing
Write-Host "--- Root listing ---" -ForegroundColor Yellow
$rootList = Get-Url "$BASE/doku.php?do=list"
if ($rootList) {
    foreach ($m in [regex]::Matches($rootList.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
        $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
        if ($id -and $id -ne "start" -and !$allIds.ContainsKey($id)) { $allIds[$id] = $true; Write-Host "  ROOT: $id" -ForegroundColor Cyan }
    }
}
Write-Host "  $($allIds.Count) after root listing"

# 2d. Hardcoded known namespaces + derive namespaces from collected IDs
Write-Host "--- Namespace enumeration ---" -ForegroundColor Yellow
$hardcodedNs = @("pag_novedades","pag_calendar","pag_contactos","pag_enlaces_interes","pag_editor","pag_busquedas","pag_procedimientos_generales","pag_apli","pag_vdi","pag_comunicaciones","pag_ciberseg","pag_hgis","pag_audio","pag_formu","pag_active_directory","net","solicitudes","wiki","pag_direc_despli","pag_asesoria","pag_backups","pag_calculadora","pag_capacitacion","pag_ciberj","pag_cpd_cica","pag_devops","pag_dici","pag_digi","pag_emaat","pag_etiqueta_rf","pag_expediente_digital","pag_f5","pag_fabricantes","pag_gesti_oojj","pag_glosario","pag_gruptrab","pag_gtab","pag_gtbd","pag_gtsl","pag_hermes","pag_hgis","pag_implantacion","pag_infra","pag_infraes","pag_infraestructuras","pag_inventario","pag_jara","pag_juzgados_de_paz","pag_lineas_oojj","pag_mapas","pag_monitorizacion","pag_org","pag_paneles","pag_portal","pag_procedimientos","pag_proye","pag_prueba2","pag_puesto","pag_reparto","pag_revision_continua","pag_rma","pag_rpa","pag_sacoep","pag_sede","pag_sedes","pag_seguridad","pag_solicitudes","pag_textu","pag_tipo","pag_traslado_oojj","pag_ubic","pag_urls_rcja","pag_validada","pag_webex","pag_wintel","areas","tags","playground","howto","cau")
foreach ($ns in $hardcodedNs) { if (!$knownNamespaces.ContainsKey($ns)) { $knownNamespaces[$ns] = $true } }

# Also derive namespaces from all collected IDs
$allIds.Keys | ForEach-Object {
    $ns = Extract-Namespaces $_
    if ($ns -and !$knownNamespaces.ContainsKey($ns)) { $knownNamespaces[$ns] = $true }
}

# List each known namespace
$nsListed = @{}
foreach ($ns in ($knownNamespaces.Keys | Sort-Object)) {
    if ($nsListed.ContainsKey($ns)) { continue }
    $nsListed[$ns] = $true
    foreach ($listUrl in @("$BASE/doku.php?do=list&ns=$ns", "$BASE/doku.php?id=$ns`:start&do=list&ns=$ns")) {
        $r = Get-Url $listUrl
        if ($r) {
            foreach ($m in [regex]::Matches($r.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
                $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
                if ($id -and $id -ne "start" -and !$allIds.ContainsKey($id)) {
                    $allIds[$id] = $true
                    # Derive further namespaces from this new ID
                    $subNs = Extract-Namespaces $id
                    if ($subNs -and !$knownNamespaces.ContainsKey($subNs)) { $knownNamespaces[$subNs] = $true }
                }
            }
        }
    }
}
Write-Host "  $($allIds.Count) after namespace enumeration, $($knownNamespaces.Count) namespaces"

# 2e. Backlinks for key pages (routing tables, procedures, assignments)
Write-Host "--- Backlinks ---" -ForegroundColor Yellow
$keyPages = @("pag_apli:remedy:asignaciones_remedy","pag_apli:adriano:problemas_gya","pag_apli:adriano:problemas_motor","pag_apli:adriano:alta","pag_apli:adriano:altanumo","pag_procedimientos_generales:gesti_certificados_adriano","pag_apli:remedy:problemas","pag_apli:remedy_itsm:problemas","pag_hgis:puesto_de_trabajo","pag_apli:hermes:problemas","pag_apli:temis:problemas","pag_apli:portal_adriano:problemas","pag_apli:consultasadriano:problemas","pag_apli:escritoriojudicial:problemas","pag_apli:agenda_senalamientos:problemas")
foreach ($kp in $keyPages) {
    $bl = Get-Url "$BASE/doku.php?id=$kp&do=backlink"
    if ($bl) {
        foreach ($m in [regex]::Matches($bl.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
            $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
            if ($id -and $id -ne "start" -and !$allIds.ContainsKey($id)) {
                $allIds[$id] = $true
                Write-Host "  BACKLINK[$kp]: $id" -ForegroundColor Cyan
            }
        }
    }
}
Write-Host "  $($allIds.Count) after backlinks"

# 2f. Search for key terms (super expanded)
Write-Host "--- Search keywords ---" -ForegroundColor Yellow
$searchTerms = @(
    "adriano","alba","CAU","incidencias","asignacion","macro","routing","procedimiento",
    "caso","grupo","justicia","remedy","usuario","contrasena","certificado","impresora",
    "firma","nuevo","soporte","ticket","hermes","temis","jara","portafirmas","lexnet",
    "escritorio judicial","sede electronica","vpn","crip","ciberseguridad","iml","agenda",
    "consumibles","fortuny","nexo","diraya","guia","plantilla","problemas","puesto",
    "alta","baja","inventario","backup","net","seguridad","virtualizacion",
    "active directory","almacenamiento","aplicaciones","arconte","ateneo","audio",
    "cargador","cita previa","comunicaciones","base de datos","dhcp","dns",
    "escritorio","expediente","formacion","gestor documental","hgis","infraestructura",
    "lexnet","monitorizacion","navegador","office","oracle","orfila","puesto trabajo",
    "quenda","sava","siraj","suministro","tartessos","telefonia","textualizacion",
    "verifirma","vdi","webex","wifi","wintel","xwiki","alfresco","apostilla",
    "consignaciones","directorio corporativo","dokuwiki","dragon","epm","evid",
    "ficheros","ganes","historiales iml","inforeg","limesurvey","pdf-xchange",
    "pima","prisma","prodam","punto neutro","sede judicial","sm intercau",
    "web","conectividad","correo","dominio","equipo","hardware","incidencia",
    "instalacion","ip","licencia","migracion","navegacion","pantalla","perfil",
    "red","servidor","switch","tablet","teclado","terminal","ticket","wifi",
    # New terms focused on casuistics, assignments, groups
    "nivel 1","nivel 2","nivel 3","devops","soporte tecnico","servicio","asignacion grupo",
    "resolucion","incidencia","peticion","cambio","problema conocido","workaround",
    "solucion","configuracion","instalacion","procedimiento actuacion","asignacion remedio",
    "categoria","subtipo","clasificacion","macro alba","grupo asignacion","ruta",
    "flujo trabajo","workflow","escalado","asistencia","solicitud","contraseña",
    "alta usuario","baja usuario","modificacion","permiso","acceso","rol",
    "perfil usuario","grupo ad","ou","unidad organizativa","dominio",
    "servidor aplicacion","servidor base datos","servidor ficheros","cluster",
    "backup","restauracion","copia seguridad","monitorizacion","alerta",
    "incidente seguridad","virus","malware","phishing","spam",
    "vpn acceso","acceso remoto","escritorio remoto","citrix","vdi",
    "telefonia ip","centralita","extension","llamada","conferencia",
    "impresora","fotocopiadora","escanner","multifuncion","consumible",
    "toner","cartucho","papel","mantenimiento impresora",
    "equipo","ordenador","portatil","sobremesa","monitor","docking",
    "periferico","teclado","raton","webcam","altavoz","microfono",
    "tablet","movil","smartphone","dispositivo movil",
    "aplicacion","sistema","plataforma","portal","modulo",
    "adriano","temis","hermes","jara","lexnet","portafirmas",
    "sede electronica","escritorio judicial","expediente digital",
    "firma electronica","certificado digital","dni electronico",
    "notificacion","notificacion electronica","lexnet notificacion",
    "atestado","policia","guardia civil","organismos externos",
    "cendoj","consejo general","poder judicial","ministerio justicia",
    "cau","helpdesk","mesa ayuda","soporte nivel 1",
    "remedy","itsm","incidencia","problema","cambio","release",
    "acuerdo nivel servicio","sla","prioridad","urgencia","impacto"
)
foreach ($term in $searchTerms) {
    $s = Get-Url "$BASE/doku.php?do=search&q=$([System.Web.HttpUtility]::UrlEncode($term))"
    if ($s) {
        foreach ($m in [regex]::Matches($s.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
            $id = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
            if ($id -and !$allIds.ContainsKey($id)) { $allIds[$id] = $true; Write-Host "  SEARCH[$term]: $id" -ForegroundColor Cyan }
        }
    }
}
Write-Host "  $($allIds.Count) after searches"

# 2g. Ensure namespace root pages are included + derive fresh namespaces
foreach ($ns in $knownNamespaces.Keys) {
    if (!$allIds.ContainsKey($ns)) { $allIds[$ns] = $true }
    $nsStart = "${ns}:start"
    if (!$allIds.ContainsKey($nsStart)) { $allIds[$nsStart] = $true }
}

Write-Host "Total unique before download: $($allIds.Count)" -ForegroundColor Cyan

# ============================================================
# STEP 3: Download with recursive link & namespace discovery
# ============================================================
Write-Host "`n=== STEP 3: Download (max 5 iterations) ===" -ForegroundColor Green
$iter = 0
$maxIter = 5
$newThisIter = $allIds.Count

while ($iter -lt $maxIter -and $newThisIter -gt 0) {
    $iter++
    $pending = @($allIds.Keys | Where-Object { $sn = ($_ -replace '[/:<>"|?*=&#'']', '_') -replace '\s', '_'; !$downloaded.ContainsKey($sn) })
    Write-Host "`n--- Iteration ${iter}: $($pending.Count) pending, $($allIds.Count) total IDs ---" -ForegroundColor Yellow
    if ($pending.Count -eq 0) { break }
    
    $c = 0
    $linksFromThisIter = @{}
    foreach ($id in ($pending | Sort-Object)) {
        $c++
        Write-Host "[$c/$($pending.Count)]"
        $saved = Save-Page $id "it${iter}"
        
        # Extract links from raw text (wiki links)
        if ($saved) {
            $safeName = $id -replace '[/:<>"|?*=&#'']', '_' -replace '\s', '_'
            $path = "$OutputDir\raw\$safeName.txt"
            if (Test-Path $path) {
                $rawText = Get-Content $path -Raw -Encoding UTF8
                $extracted = Extract-Links $rawText
                foreach ($linkId in $extracted.Keys) {
                    $cleanId = Sanitize-PageId $linkId
                    if ($cleanId -and !$allIds.ContainsKey($cleanId)) {
                        $allIds[$cleanId] = $true
                        $linksFromThisIter[$cleanId] = $true
                        Write-Host "    [[link]]: $cleanId" -ForegroundColor Magenta
                    }
                }
            }
        }
        
        # Also extract links from HTML content (XHTML export), even if raw wasn't saved
        $htmlSafeName = $id -replace '[/:<>"|?*=&#'']', '_' -replace '\s', '_'
        $htmlPath = "$OutputDir\html\$htmlSafeName.html"
        if (Test-Path $htmlPath) {
            $htmlText = Get-Content $htmlPath -Raw -Encoding UTF8
            $extracted = Extract-Links $htmlText
            foreach ($linkId in $extracted.Keys) {
                $cleanId = Sanitize-PageId $linkId
                if ($cleanId -and !$allIds.ContainsKey($cleanId)) {
                    $allIds[$cleanId] = $true
                    $linksFromThisIter[$cleanId] = $true
                    Write-Host "    [html]: $cleanId" -ForegroundColor Magenta
                }
            }
        }
    }
    
    $newThisIter = $linksFromThisIter.Count
    Write-Host "Discovered $newThisIter new links in iteration $iter" -ForegroundColor Green
    
    # After each iteration, derive new namespaces and try to list them
    if ($newThisIter -gt 0) {
        $newNsThisPass = @{}
        $linksFromThisIter.Keys | ForEach-Object {
            $ns = Extract-Namespaces $_
            if ($ns -and !$knownNamespaces.ContainsKey($ns)) {
                $knownNamespaces[$ns] = $true
                $newNsThisPass[$ns] = $true
            }
        }
        if ($newNsThisPass.Count -gt 0) {
            Write-Host "  New namespaces discovered: $($newNsThisPass.Count)" -ForegroundColor Yellow
            foreach ($ns in ($newNsThisPass.Keys | Sort-Object)) {
                Write-Host "    Listing: $ns" -ForegroundColor DarkYellow
                foreach ($listUrl in @("$BASE/doku.php?do=list&ns=$ns", "$BASE/doku.php?id=$ns`:start&do=list&ns=$ns")) {
                    $r = Get-Url $listUrl
                    if ($r) {
                        foreach ($m in [regex]::Matches($r.Content, 'href="[^"]*doku\.php\?id=([^"&]+)')) {
                            $nsId = Sanitize-PageId ([System.Web.HttpUtility]::UrlDecode($m.Groups[1].Value))
                            if ($nsId -and $nsId -ne "start" -and !$allIds.ContainsKey($nsId)) {
                                $allIds[$nsId] = $true
                                $linksFromThisIter[$nsId] = $true  # also download in next iter
                                Write-Host "      ADDED: $nsId" -ForegroundColor Cyan
                            }
                        }
                    }
                }
                # Also ensure namespace root is included
                if (!$allIds.ContainsKey($ns)) { $allIds[$ns] = $true }
                $nsStart = "${ns}:start"
                if (!$allIds.ContainsKey($nsStart)) { $allIds[$nsStart] = $true }
            }
            # Recalculate newThisIter with namespaced additions
            $newThisIter = $linksFromThisIter.Count
        }
    }
}

# ============================================================
# STEP 4: Summary
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
if (Test-Path "$OutputDir\raw") {
    $rf = Get-ChildItem "$OutputDir\raw" | Sort-Object Length -Descending
    Write-Host "Raw files: $($rf.Count)"
    $totalSize = ($rf | Measure-Object -Property Length -Sum).Sum
    Write-Host "Total size: $([Math]::Round($totalSize/1KB)) KB"
    $rf | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Name): $($_.Length) bytes" }
}
if (Test-Path "$OutputDir\html") {
    $hf = Get-ChildItem "$OutputDir\html"
    Write-Host "HTML: $($hf.Count) files, $([Math]::Round(($hf | Measure-Object -Property Length -Sum).Sum/1KB)) KB"
}
Write-Host "Unique IDs collected: $($allIds.Count)" -ForegroundColor Cyan
Write-Host "Namespaces discovered: $($knownNamespaces.Count)" -ForegroundColor Cyan
Write-Host "Page list: $OutputDir\pages.txt" -ForegroundColor Yellow
$allIds.Keys | Sort-Object | Set-Content -Path "$OutputDir\pages.txt"
Write-Host "Done!" -ForegroundColor Green
