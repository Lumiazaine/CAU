param([switch]$WhatIf)

# ============================================================
# LAZYDIRECTORY - Terminal Directorio Correo
# ============================================================

$script:VERSION = "1.1"
$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "lazydirectory.log"
$script:DEBUG_DIR = Join-Path $script:SCRIPT_DIR "debug"
$null = New-Item -ItemType Directory -Path $script:DEBUG_DIR -Force
$script:BASE = "https://directorio.juntadeandalucia.es/myServlets/es.sadesi.admdirectorio.servlets"
$script:ENV_FILE = Join-Path $env:USERPROFILE ".env"
$script:webSession = $null
$script:token = $null
$script:lastResultData = @()
$script:lastProfileFields = $null
$script:lastRawHtml = $null
$script:authenticated = $false
$script:columns = 80
$script:ramaLdap = "jus"
$script:isInterno = $false

function ui {
    $script:columns = [Math]::Max(80, [Console]::WindowWidth)
}
function bar { param([string]$c = "DarkGray"); Write-Host ("-" * $script:columns) -ForegroundColor $c }
function empty { Write-Host (" " * $script:columns) -ForegroundColor DarkGray }

function header {
    Clear-Host
    $w = $script:columns
    $conn = if ($script:authenticated) { "CONECTADO" } else { "DESCONECTADO" }
    $cc = if ($script:authenticated) { "Green" } else { "Red" }
    Write-Host ("." + ("-" * ($w - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + (" " * ($w - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("|  LAZYDIRECTORY v$script:VERSION") -ForegroundColor Yellow -NoNewline
    $rest = $w - 28 - $conn.Length
    if ($rest -gt 0) { Write-Host (" " * $rest) -NoNewline } else { Write-Host "" -NoNewline }
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host ("|  " + (" " * 22)) -NoNewline
    Write-Host $conn -ForegroundColor $cc -NoNewline
    Write-Host (" " * ($w - 28 - $conn.Length)) -NoNewline; Write-Host "|" -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor DarkGray
    Write-Host ""
}

function footer {
    param([string[]]$Keys)
    $w = $script:columns
    $text = ""
    foreach ($k in $Keys) { $text += "  $k" }
    if ($text.Length -ge $w - 2) { $text = $text.Substring(0, $w - 5) }
    Write-Host ("." + ("-" * ($w - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + $text.PadRight($w - 2) + "|") -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor DarkGray
}

function prompt {
    param([string]$Text, [string]$Default = "")
    Write-Host $Text -ForegroundColor Yellow -NoNewline
    $val = Read-Host
    if (-not $val) { return $Default }
    return $val
}

function pause {
    Write-Host "Presiona Enter para continuar..." -ForegroundColor DarkGray -NoNewline
    $null = Read-Host
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "OK"    { Write-Host "  [$time] $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "  [$time] $Message" -ForegroundColor Red }
        "WARN"  { Write-Host "  [$time] $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "  [$time] $Message" -ForegroundColor Cyan }
        default { Write-Host "  [$time] $Message" }
    }
    $logLine = "$(Get-Date -Format 'yyyy-MM-dd') [$time] [$Level] $Message"
    Add-Content -Path $script:LOG_FILE -Value $logLine -Encoding UTF8
}

function panel {
    param([string]$Title, [scriptblock]$Body)
    $w = $script:columns
    Write-Host (".- " + $Title + (" " * ($w - 6 - $Title.Length)) + ".") -ForegroundColor Cyan
    & $Body
    Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor DarkGray
}

function row {
    param([string]$Label, [string]$Value, [string]$Color = "White")
    Write-Host ("|  " + $Label.PadRight(18) + ": ") -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

# ============================================================
# AUTH
# ============================================================

function Get-Credentials {
    if (Test-Path $script:ENV_FILE) {
        $content = Get-Content $script:ENV_FILE -Encoding UTF8 | ForEach-Object { $_.Trim() }
        $user = ($content | Where-Object { $_ -match '^ADMIN_USER=(.+)$' } | ForEach-Object { $Matches[1] }) -join ''
        $pass = ($content | Where-Object { $_ -match '^ADMIN_PASS=(.+)$' } | ForEach-Object { $Matches[1] }) -join ''
        if ($user -and $pass) {
            Write-Log "Credenciales cargadas desde $($script:ENV_FILE)" "INFO"
            return @{ User = $user; Pass = $pass }
        }
    }
    return $null
}

function Save-Credentials {
    param([string]$User, [string]$Pass)
    $lines = @("ADMIN_USER=$User", "ADMIN_PASS=$Pass")
    $lines | Set-Content -Path $script:ENV_FILE -Encoding UTF8
    Write-Log "Credenciales guardadas en $($script:ENV_FILE)" "OK"
}

function Get-CredentialsInteractive {
    Write-Log "Solicitando credenciales de administrador..." "WARN"
    $user = Read-Host "Usuario administrador"
    $pass = Read-Host "Contrasena" -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $save = prompt "Guardar credenciales en .env? (s/n): " "s"
    if ($save -eq 's') { Save-Credentials -User $user -Pass $plainPass }
    return @{ User = $user; Pass = $plainPass }
}

function Extract-Token {
    param([string]$Html)
    if ($Html -match 'name="tokenParametro"\s*value="([^"]+)"') { return $Matches[1] }
    if ($Html -match '"tokenParametro"\s*:\s*"([^"]+)"') { return $Matches[1] }
    return $null
}

function Extract-FormFields {
    param([string]$Html)
    $fields = @{}

    # Match name="val" or name='val' — handles both quote styles
    $re = '<input[^>]*?\bname\s*=\s*(["''])([^"'']*?)\1[^>]*?\bvalue\s*=\s*(["''])([^"'']*?)\3[^>]*?>'
    [regex]::Matches($Html, $re) | ForEach-Object { $fields[$_.Groups[2].Value] = $_.Groups[4].Value }
    # Also match value before name
    $re2 = '<input[^>]*?\bvalue\s*=\s*(["''])([^"'']*?)\1[^>]*?\bname\s*=\s*(["''])([^"'']*?)\3[^>]*?>'
    [regex]::Matches($Html, $re2) | ForEach-Object { $fields[$_.Groups[4].Value] = $_.Groups[2].Value }

    # Selects: match name with both quote styles
    [regex]::Matches($Html, '<select[^>]*?\bname\s*=\s*(["''])([^"'']*?)\1[^>]*?>(.*?)</select>') | ForEach-Object {
        $n = $_.Groups[2].Value; $selectInner = $_.Groups[3].Value
        $opt = [regex]::Match($selectInner, '<option[^>]*?\bselected\b[^>]*?>(.*?)</option>')
        if ($opt.Success) {
            $fields[$n] = $opt.Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&'
            $vOpt = [regex]::Match($selectInner, '<option[^>]*?\bvalue\s*=\s*(["''])([^"'']*?)\1[^>]*?\bselected\b[^>]*?>')
            if (-not $vOpt.Success) {
                $vOpt = [regex]::Match($selectInner, '<option[^>]*?\bselected\b[^>]*?\bvalue\s*=\s*(["''])([^"'']*?)\1[^>]*?>')
            }
            if ($vOpt.Success) { $fields[$n + '_value'] = $vOpt.Groups[2].Value }
        }
    }

    # Textareas
    [regex]::Matches($Html, '<textarea[^>]*?\bname\s*=\s*(["''])([^"'']*?)\1[^>]*?>(.*?)</textarea>') | ForEach-Object {
        $fields[$_.Groups[2].Value] = $_.Groups[3].Value -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]+>', ''
    }

    return $fields
}

function Extract-DisplayData {
    param([string]$Html)
    $data = @{}

    function Clean-Val {
        param([string]$s)
        $s = $s -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&'
        $s = $s -replace '&lt;', '<' -replace '&gt;', '>' -replace '\s+', ' '
        return $s.Trim()
    }

    # Map Directorio field names to our display names
    # Keys use . as regex wildcard (matches any char, e.g. ó, ñ, Ú)
    $fieldMap = @{
        'Nombre y apellidos' = 'nombreUsuario'
        'Nombre' = 'nombreUsuario'
        'Identificador' = 'uid'
        'Tipo de entrada' = 'tipoEntrada'
        'Tipo de usuario' = 'tipoEntrada'
        'Correo electr.nico' = 'mail'
        '.ltimo cambio de contrase.a' = 'ultimoCambioPassword'
        'Cuota' = 'cuota'
        'departmentNumber' = 'departmentNumber'
        'Cargo' = 'cargo'
        'Edificio' = 'edificio'
        'Servicio' = 'servicio'
        'Puesto de Trabajo' = 'puestoTrabajo'
        'Tel.fono Fijo' = 'telefonoFijo'
        'Tel.fono M.vil' = 'telefonoMovil'
        'Fax' = 'fax'
        'Dni' = 'dni'
        'Provincia' = 'provincia'
        'Reserva de Recursos' = 'JAreserva'
        'Habilitar Consigna' = 'consigna'
        'Perfil de acceso WiFi' = 'JAperfilAcceso'
        'Caducar contrase.a' = 'passCaducado'
        'Comentarios' = 'comentarios'
    }
    # Sort by descending length so more specific labels match first
    $sortedKeys = $fieldMap.Keys | Sort-Object { $_.Length } -Descending

    # Strategy 1: Password overlay form_fields (within capa_password_* div)
    # Locate the password overlay section first, then parse its form_fields
    $pwStart = $Html.IndexOf('id="capa_password_', [System.StringComparison]::OrdinalIgnoreCase)
    if ($pwStart -ge 0) {
        # Rewind to opening <div
        $pwStart = $Html.LastIndexOf('<div', $pwStart)
        if ($pwStart -ge 0) {
            # Find the closing: capa_password's </div> + parent </div> followed by <!-- or <h2>
            $endMarkers = @('</div>\s*</div>\s*<!--', '</div>\s*</div>\s*<h2', '</div>\s*</div>\s*$')
            $pwEnd = -1
            foreach ($marker in $endMarkers) {
                $m = [regex]::Match($Html, $marker, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [System.TimeSpan]::FromSeconds(1))
                if ($m.Success -and $m.Index -gt $pwStart) {
                    if ($pwEnd -eq -1 -or $m.Index -lt $pwEnd) { $pwEnd = $m.Index }
                }
            }
            if ($pwEnd -gt $pwStart) {
                $pwContent = $Html.Substring($pwStart, $pwEnd - $pwStart)
                # Parse form_fields within capa_password (always has plain text values, no inputs)
                [regex]::Matches($pwContent, '(?s)<div\s+class="form_field">(.*?)</div>\s*</div>') | ForEach-Object {
                    $blockHtml = $_.Groups[1].Value
                    $labelM = [regex]::Match($blockHtml, '<div\s+class="form_field_label[^"]*">(.*?)</div>')
                    $valM = [regex]::Match($blockHtml, '<div\s+class="form_field_value[^"]*">(.*?)</div>')
                    if (-not $labelM.Success -or -not $valM.Success) { return }
                    $valInner = $valM.Groups[1].Value
                    if ($valInner -match '<(input|select|textarea)\b') { return }
                    $labelText = Clean-Val $labelM.Groups[1].Value
                    $valText = Clean-Val $valInner
                    if (-not $labelText -or -not $valText) { return }
                    foreach ($fk in $sortedKeys) {
                        if ($labelText -match $fk) {
                            $target = $fieldMap[$fk]
                            # Prefer first match (delete overlay Nombre:uid comes before password overlay Nombre:real)
                            # But password overlay comes last, so we actually want LAST match
                            # Simple approach: keep first, since password-overlay has the right data for JUS
                            if (-not $data.ContainsKey($target) -or [string]::IsNullOrEmpty($data[$target])) {
                                $data[$target] = $valText
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    # Strategy 2: search result rows (email + name in search results)
    $resultRows = [regex]::Matches($Html, '(?s)<div\s+class="fila_par"[^>]*>.*?<span\s+class="campo ancho2">(.*?)</span>\s*<span\s+class="campo ancho2">(.*?)</span>')
    if ($resultRows.Count -gt 0) {
        $email = Clean-Val $resultRows[0].Groups[1].Value
        $name = Clean-Val $resultRows[0].Groups[2].Value
        if ($email -and -not $data.ContainsKey('mail')) { $data['mail'] = $email }
        if ($name -and -not $data.ContainsKey('nombreUsuario')) { $data['nombreUsuario'] = $name }
    }

    # Strategy 3: form_field divs (modify form + delete overlay)
    $fieldBlocks = [regex]::Matches($Html, '(?s)<div\s+class="form_field">(.*?)</div>\s*</div>')
    if ($fieldBlocks.Count -eq 0) {
        $fieldBlocks = [regex]::Matches($Html, '(?s)<div\s+class="form_field">(.*?)</div>')
    }
    foreach ($block in $fieldBlocks) {
        $blockHtml = $block.Groups[1].Value
        $labelM = [regex]::Match($blockHtml, '<div\s+class="form_field_label[^"]*">(.*?)</div>')
        $valM = [regex]::Match($blockHtml, '<div\s+class="form_field_value[^"]*">(.*?)</div>')
        if (-not $labelM.Success -or -not $valM.Success) { continue }

        # Skip if value div contains input/select/textarea
        $valInner = $valM.Groups[1].Value
        if ($valInner -match '<(input|select|textarea)\b') { continue }

        $labelText = Clean-Val $labelM.Groups[1].Value
        $valText = Clean-Val $valInner
        if (-not $labelText -or -not $valText) { continue }

        foreach ($fk in $sortedKeys) {
            if ($labelText -match $fk) {
                $target = $fieldMap[$fk]
                if (-not $data.ContainsKey($target) -or [string]::IsNullOrEmpty($data[$target])) {
                    $data[$target] = $valText
                }
                break
            }
        }
    }

    # Strategy 4: hidden inputs with user data
    $hiddenM = [regex]::Match($Html, 'name="nombreUsuario"\s*value="([^"]*)"')
    if ($hiddenM.Success -and $hiddenM.Groups[1].Value -and -not $data.ContainsKey('nombreUsuario')) {
        $data['nombreUsuario'] = $hiddenM.Groups[1].Value
    }

    return $data
}

$script:cachedCreds = $null

function Connect-Directorio {
    param([string]$Branch = "jus")

    $script:ramaLdap = $Branch
    $script:isInterno = ($Branch -eq "ius")

    if (-not $script:cachedCreds) {
        $script:cachedCreds = Get-Credentials
        if (-not $script:cachedCreds) { $script:cachedCreds = Get-CredentialsInteractive }
    }
    $adminUser = $script:cachedCreds.User
    $adminPass = $script:cachedCreds.Pass

    Write-Log "Paso 1/4: Obteniendo token de login..." "INFO"
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginInicial" -UseBasicParsing -SessionVariable script:webSession
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token de login" }

    Write-Log "Paso 2/4: Iniciando sesion como $adminUser..." "INFO"
    $body = @{
        accionInicial = 'inicio'; tokenParametro = $script:token
        administrador = $adminUser; clave = $adminPass; login = 'Entrar'
    }
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginInicial" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content
    if (-not $script:token) {
        if ($r.Content -match 'error|Error|incorrecto|incorrecta') { throw "Credenciales incorrectas" }
        $script:token = Extract-Token ($r.Content -replace '\\n', '')
    }

    Write-Log "Paso 3/4: Seleccionando modo administrador..." "INFO"
    $body = @{
        botonPulsado = 'administrarRamas'
        dnEmpleado = 'uid=just9.sandetel.ext,o=sandetel,o=empleados,o=juntadeandalucia,c=es'
        datoAuxiliar = ''; esUsuarioGuia = 'NO'
        tokenParametro = $script:token; employeeType = 'externo'
    }
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginUsuario" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token tras modo admin" }

    Write-Log "Paso 4/4: Seleccionando rama LDAP ($Branch)..." "INFO"
    $body = @{
        botonPulsado = 'administrarRama'
        dnEmpleado = 'uid=just9.sandetel.ext,o=sandetel,o=empleados,o=juntadeandalucia,c=es'
        datoAuxiliar = ''; esUsuarioGuia = 'NO'
        tokenParametro = $script:token; employeeType = 'externo'; ramaLdap = $Branch
    }
    $r = Invoke-WebRequest -Uri "$script:BASE.LoginUsuario" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token tras seleccionar rama" }

    $script:authenticated = $true
    Write-Log ("Directorio conectado: " + $Branch) "OK"
}

# ============================================================
# SEARCH
# ============================================================

function Ensure-Branch {
    param([string]$Query)
    $targetBranch = if ($Query -match '\.ius') { 'ius' } else { 'jus' }
    if ($targetBranch -ne $script:ramaLdap) {
        Write-Log "Cambiando a rama $targetBranch..." "INFO"
        Connect-Directorio -Branch $targetBranch
    }
    return $targetBranch
}

function Search-User {
    param([string]$Query = "", [string]$SearchField = "identificador", [string]$SearchType = "empezando")

    $branch = Ensure-Branch $Query
    $esInt = ($branch -eq "ius")

    Write-Log "Buscando '$Query' por '$SearchField' en $branch..." "INFO"

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token de UsuariosMain" }

    $body = @{
        accion = 'consulta'; botonPulsado = ''; datoAuxiliar = ''
        tokenParametro = $script:token
        filtroAtributo = $SearchField
        filtroTipoBusqueda = $SearchType
        filtroValor = $Query
        marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
        marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
        marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
        numUsuariosAntiguo = '25'; numUsuarios = '25'
    }
    if ($esInt) { $body['seleccionarInternos'] = 'on' }
    else { $body['seleccionarSirhus'] = 'on' }

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $html = $r.Content
    $script:lastRawHtml = $html

    Write-Log ("Respuesta: " + $html.Length + " bytes") "INFO"

    $debugFile = Join-Path $script:DEBUG_DIR ("search_" + $Query.Replace('.','_') + ".html")
    $html | Out-File -FilePath $debugFile -Encoding UTF8

    $users = @()

    # Exact hit — server returned modify form with name="dn"
    $dnMatch = [regex]::Match($html, 'name="dn"\s*value="([^"]+)"')
    if ($dnMatch.Success) {
        $dn = $dnMatch.Groups[1].Value
        $uid = ''
        $u = [regex]::Match($dn, 'uid=([^,]+)')
        if ($u.Success) { $uid = $u.Groups[1].Value }
        $fields = Extract-FormFields $html
        $display = Extract-DisplayData $html
        foreach ($kv in $display.GetEnumerator()) {
            if (-not $fields.ContainsKey($kv.Key) -or [string]::IsNullOrEmpty($fields[$kv.Key])) {
                $fields[$kv.Key] = $kv.Value
            }
        }
        $users += @{ dn = $dn; uid = $uid; nombre = $fields['cn']; apellidos = $fields['sn']; email = $fields['mail']; desc = $fields['description']; branch = $branch; fields = $fields }
        $script:lastProfileFields = $fields
        Write-Log ("Encontrado: " + $uid) "OK"
        $script:lastResultData = $users
        return $users
    }

    # Partial — extract every uid= from HTML, skip system accounts
    $systemUids = @('just9.sandetel.ext', 'sadesi', 'admin', 'just9', 'sirhus', 'externo', 'interno')
    $allUids = [regex]::Matches($html, 'uid=([a-zA-Z0-9._-]+)')
    $seen = @{}
    foreach ($m in $allUids) {
        $uid = $m.Groups[1].Value.ToLower()
        if ($seen.ContainsKey($uid)) { continue }
        if ($systemUids -contains $uid) { continue }
        if ($uid -match '^\d+$') { continue }
        $seen[$uid] = $true
        $users += @{ dn = "uid=$uid,o=$branch,o=empleados,o=juntadeandalucia,c=es"; uid = $uid; nombre = ''; apellidos = ''; email = ''; desc = ''; branch = $branch }
    }
    Write-Log ("uids encontrados en HTML: " + $seen.Count) "INFO"

    Write-Log ("Usuarios: " + $users.Count) "INFO"
    $script:lastResultData = $users
    return $users
}

function Get-UserProfile {
    param([string]$UID)

    $Branch = Ensure-Branch $UID
    $esInt = ($Branch -eq "ius")
    $fields = @{}

    Write-Log "Cargando perfil de $UID..." "INFO"

    # Build common POST body base
    function MkBody {
        param([string]$Action, [string]$Btn, [string]$Aux, [string]$Token)
        $b = @{
            accion = $Action; botonPulsado = $Btn; datoAuxiliar = $Aux
            tokenParametro = $Token
            filtroAtributo = 'identificador'
            filtroTipoBusqueda = 'empezando'
            filtroValor = $UID
            marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
            marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
            marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
            numUsuariosAntiguo = '25'; numUsuarios = '25'
        }
        if ($esInt) { $b['seleccionarInternos'] = 'on' }
        else { $b['seleccionarSirhus'] = 'on' }
        return $b
    }

    # Step 1: buscar -> results page with password overlay
    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token" }

    $body = MkBody 'consulta' '' '' $script:token
    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content
    $searchHtml = $r.Content

    $display = Extract-DisplayData $searchHtml
    foreach ($kv in $display.GetEnumerator()) {
        if (-not $fields.ContainsKey($kv.Key) -or [string]::IsNullOrEmpty($fields[$kv.Key])) {
            $fields[$kv.Key] = $kv.Value
        }
    }

    # Extract DN from password overlay
    $dn = ''
    $dnMatch = [regex]::Match($searchHtml, 'name="dn"\s*value="([^"]+)"')
    if (-not $dnMatch.Success) {
        $dnMatch = [regex]::Match($searchHtml, "datoAuxiliar\s*=\s*'(uid=[^']+)'")
    }
    if ($dnMatch.Success) { $dn = $dnMatch.Groups[1].Value }

    # Step 2: fetch modify form (editable fields) via accion=modificacion
    if ($dn) {
        $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
        $script:token = Extract-Token $r.Content
        if (-not $script:token) { throw "No se pudo extraer token" }

        $body2 = MkBody 'modificacion' 'pantalla1' $dn $script:token
        $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body2
        $html2 = $r2.Content
        $script:lastRawHtml = $html2

        $debugFile = Join-Path $script:DEBUG_DIR ("profile_" + $UID.Replace('.','_') + ".html")
        $html2 | Out-File -FilePath $debugFile -Encoding UTF8

        $formFields = Extract-FormFields $html2
        $display2 = Extract-DisplayData $html2

        # Merge: modify form display + form fields
        $merge = @{}
        foreach ($kv in $display2.GetEnumerator()) { $merge[$kv.Key] = $kv.Value }
        foreach ($kv in $formFields.GetEnumerator()) {
            if (-not $merge.ContainsKey($kv.Key)) { $merge[$kv.Key] = $kv.Value }
        }

        # Add all inputs not already captured
        [regex]::Matches($html2, 'name="([^"]*)"\s*value="([^"]*)"') | ForEach-Object {
            $n = $_.Groups[1].Value; $v = $_.Groups[2].Value
            if (-not $merge.ContainsKey($n)) { $merge[$n] = $v }
        }

        # Handle _modificacion suffix — create base-name entries
        foreach ($k in $merge.Keys) {
            if ($k -match '^(.+)_modificacion$') {
                $base = $Matches[1]
                if (-not $merge.ContainsKey($base)) {
                    $merge[$base] = $merge[$k]
                }
            }
        }

        foreach ($kv in $merge.GetEnumerator()) {
            if (-not $fields.ContainsKey($kv.Key) -or [string]::IsNullOrEmpty($fields[$kv.Key])) {
                $fields[$kv.Key] = $kv.Value
            }
        }

        # Extract dn from modify form too
        $dnM = [regex]::Match($html2, 'name="dn"\s*value="([^"]+)"')
        if ($dnM.Success -and (-not $fields.ContainsKey('dn') -or [string]::IsNullOrEmpty($fields['dn']))) {
            $fields['dn'] = $dnM.Groups[1].Value
        }
    }

    if (-not $fields.ContainsKey('dn') -or [string]::IsNullOrEmpty($fields['dn'])) {
        if ($dn) { $fields['dn'] = $dn }
    }

    $script:lastProfileFields = $fields
    Write-Log ("Campos extraidos: " + $fields.Count) "OK"
    return $fields
}

# ============================================================
# PASSWORD
# ============================================================

function Set-UserPassword {
    param([string]$DN, [string]$UID, [string]$TargetUser, [string]$NewPassword, [switch]$WhatIf)

    $searchId = if ($UID) { $UID } else { $TargetUser }
    $Branch = Ensure-Branch $searchId
    $esInt = ($Branch -eq "ius")

    Write-Log "Obteniendo token para cambio de contrasena..." "INFO"
    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token" }

    $searchUser = if ($UID) { $UID } else { $TargetUser }

    $body = @{
        accion = 'consulta'; botonPulsado = ''; datoAuxiliar = ''
        tokenParametro = $script:token
        filtroAtributo = 'identificador'
        filtroTipoBusqueda = 'empezando'
        filtroValor = $searchUser
        marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
        marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
        marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
        numUsuariosAntiguo = '25'; numUsuarios = '25'
    }
    if ($esInt) { $body['seleccionarInternos'] = 'on' }
    else { $body['seleccionarSirhus'] = 'on' }

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content

    $foundDn = $DN
    if (-not $foundDn) {
        if ($r.Content -match 'name="dn"\s*value="([^"]+)"') { $foundDn = $Matches[1] }
    }
    if (-not $foundDn) {
        $foundDn = "uid=$searchUser,o=$Branch,o=empleados,o=juntadeandalucia,c=es"
        Write-Log "Usando DN construido: $foundDn" "WARN"
    }

    if ($WhatIf) {
        Write-Log "WHATIF - Se cambiaria la contrasena de $searchUser ($foundDn) a $NewPassword" "INFO"
        return
    }

    $body2 = @{
        accion = 'modificacion'; botonPulsado = 'confirmarPassword'
        datoAuxiliar = '0'; tokenParametro = $script:token
        filtroAtributo = 'identificador'
        filtroTipoBusqueda = 'empezando'
        filtroValor = $searchUser
        marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
        marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
        marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
        numUsuariosAntiguo = '25'; numUsuarios = '25'
    }
    if ($esInt) { $body2['seleccionarInternos'] = 'on' }
    else { $body2['seleccionarSirhus'] = 'on' }

    $body2 += @{
        usuarioWindows = 'NO'; passCaducadoCP = 'NO'
        dn = $foundDn
        pwd_modificacion = $NewPassword
        pwd2_modificacion = $NewPassword
    }

    $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body2

    if ($r2.Content -match 'actualiz.+correctamente|mensaje_ok') {
        Write-Log "Contrasena cambiada correctamente a $NewPassword" "OK"
    } elseif ($r2.Content -match 'error|Error|incorrecto') {
        Write-Log "Posible error al cambiar la contrasena" "WARN"
        $debugFile = Join-Path $script:DEBUG_DIR ("passerr_" + $searchUser.Replace('.','_') + ".html")
        $r2.Content | Out-File -FilePath $debugFile -Encoding UTF8
        Write-Log "HTML guardado en $debugFile" "INFO"
    } else {
        Write-Log "Contrasena enviada. Verifica el resultado." "WARN"
    }
}

# ============================================================
# SCREENS
# ============================================================

function screen-main {
    ui
    header
    panel "MENU PRINCIPAL" {
        Write-Host "|"
        Write-Host "|  1. Buscar usuario" -ForegroundColor Cyan
        Write-Host "|  2. Ver perfil" -ForegroundColor Cyan
        Write-Host "|  3. Cambiar contrasena" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Salir" -ForegroundColor Red
        Write-Host "|"
        Write-Host ("|  >> Rama: $script:ramaLdap") -ForegroundColor Green
        if ($script:lastProfileFields -and $script:lastProfileFields['uid']) {
            Write-Host ("|     Usuario: $($script:lastProfileFields['uid'])") -ForegroundColor DarkGray
        }
        Write-Host "|"
    }
    footer @("1-3 opciones", "0/q salir", "s <uid> busqueda rapida")
    Write-Host ""
    Write-Host "Opcion: " -ForegroundColor Yellow -NoNewline
    return Read-Host
}

function screen-search {
    ui
    header
    panel "BUSQUEDA DE USUARIOS" {
        Write-Host "|"
        Write-Host "|  SELECCIONA CAMPO DE BUSQUEDA:" -ForegroundColor White
        Write-Host "|"
        Write-Host "|  1. Identificador (uid)" -ForegroundColor Cyan
        Write-Host "|  2. DNI" -ForegroundColor Cyan
        Write-Host "|  3. Correo electronico" -ForegroundColor Cyan
        Write-Host "|  4. Nombre y/o Apellidos" -ForegroundColor Cyan
        Write-Host "|  5. Tipo de Usuario" -ForegroundColor Cyan
        Write-Host "|  6. Edificio" -ForegroundColor Cyan
        Write-Host "|  7. Servicio" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Volver" -ForegroundColor Red
        Write-Host "|"
    }
    footer @("1-7 campo", "0 volver")
    Write-Host ""
    $opt = prompt "Campo: "

    if ($opt -eq "0") { return $null }

    $fieldMap = @{
        "1" = "identificador"; "2" = "dni"; "3" = "correo"
        "4" = "nombre"; "5" = "tipoUsuario"; "6" = "edificio"; "7" = "servicio"
    }
    $searchField = $fieldMap[$opt]
    if (-not $searchField) { return $null }

    Write-Host ""
    Write-Host "  TIPO DE BUSQUEDA:" -ForegroundColor White
    Write-Host "  1. empezando por" -ForegroundColor Cyan
    Write-Host "  2. igual a" -ForegroundColor Cyan
    Write-Host "  3. terminando en" -ForegroundColor Cyan
    Write-Host "  4. conteniendo a" -ForegroundColor Cyan
    Write-Host ""
    $tOpt = prompt "Tipo (1-4): " "1"
    $typeMap = @{"1" = "empezando"; "2" = "igual"; "3" = "terminando"; "4" = "conteniendo"}
    $searchType = $typeMap[$tOpt]
    if (-not $searchType) { $searchType = "empezando" }

    $query = prompt "Valor a buscar: "
    if (-not $query) { return $null }

    Write-Log "Buscando..." "INFO"
    $users = Search-User -Query $query -SearchField $searchField -SearchType $searchType

    if ($users.Count -eq 0) {
        Write-Log "No se encontraron usuarios" "WARN"
        pause; return $null
    }

    if ($users.Count -eq 1) {
        $profileId = if ($users[0].uid) { $users[0].uid } else { $Query }
        Get-UserProfile -UID $profileId
        screen-profile; return $null
    }

    $sel = screen-results -Users $users -Title "RESULTADOS"
    if ($sel -ge 0) {
        $u = $users[$sel]
        $profileId = if ($u.uid) { $u.uid } else { $u.nombre }
        if (-not $profileId) { $profileId = $Query }
        Write-Log "Cargando perfil de $profileId..." "INFO"
        Get-UserProfile -UID $profileId
        screen-profile
    }
    return $null
}

function screen-results {
    param([array]$Users, [string]$Title = "RESULTADOS")
    $page = 0; $pageSize = 15

    while ($true) {
        ui; header
        $total = $Users.Count
        $pages = [Math]::Max(1, [Math]::Ceiling($total / $pageSize))
        Write-Host (".- $Title ($total usuarios)" + (" " * ($script:columns - 25 - $Title.Length)) + ".") -ForegroundColor Cyan
        Write-Host "|" -NoNewline
        $hdr = "{0,3} {1,-20} {2,-25} {3,-30}" -f "#", "UID", "NOMBRE", "EMAIL"
        Write-Host $hdr.PadRight($script:columns - 3) -NoNewline
        Write-Host "|" -ForegroundColor DarkGray
        $start = $page * $pageSize; $end = [Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $u = $Users[$i]
            $uidStr = if ($u.uid) { $u.uid } else { "-" }
            $emailStr = if ($u.email) { $u.email } else { "-" }
            $fullName = "$($u.nombre) $($u.apellidos)".Trim()
            if (-not $fullName) { $fullName = "-" }
            $line = ("{0,3} {1,-20} {2,-25} {3,-30}" -f ($i+1), $uidStr.Substring(0, [Math]::Min(20, $uidStr.Length)), $fullName.Substring(0, [Math]::Min(25, $fullName.Length)), $emailStr.Substring(0, [Math]::Min(30, $emailStr.Length)))
            if ($line.Length -gt $script:columns - 3) { $line = $line.Substring(0, $script:columns - 6) }
            Write-Host "| " -NoNewline; Write-Host $line -ForegroundColor White -NoNewline
            $pad = $script:columns - 4 - $line.Length
            if ($pad -gt 0) { Write-Host (" " * $pad) -NoNewline }; Write-Host "|" -ForegroundColor DarkGray
        }
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("Pagina $($page+1)/$pages") -ForegroundColor DarkGray -NoNewline
        if ($start -gt 0) { Write-Host "  [a] anterior" -ForegroundColor Cyan -NoNewline }
        if ($end -lt $total - 1) { Write-Host "  [s] siguiente" -ForegroundColor Cyan -NoNewline }
        Write-Host ""

        $input = prompt "Selecciona # para ver perfil (0=volver): " "0"
        if ($input -eq "0") { return -1 }
        elseif ($input -eq "s" -and $end -lt $total - 1) { $page++ }
        elseif ($input -eq "a" -and $page -gt 0) { $page-- }
        elseif ($input -match '^\d+$') {
            $idx = [int]$input - 1
            if ($idx -ge 0 -and $idx -lt $total) { return $idx }
        }
    }
}

function screen-profile {
    $f = $script:lastProfileFields
    if (-not $f) { Write-Log "No hay perfil cargado" "WARN"; pause; return }

    $uid = if ($f['uid']) { $f['uid'] } else { $f['identificador'] }
    $displayId = if ($uid) { $uid } else { "desconocido" }

    ui; header
    Write-Host (".- $displayId" + (" " * ($script:columns - 6 - $displayId.Length)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host "|  DATOS DEL USUARIO" -ForegroundColor Cyan
    Write-Host "|" -ForegroundColor DarkGray
    row "Nombre"        $(if ($f['nombreUsuario']) { $f['nombreUsuario'] } else { $f['cn'] }) "Green"
    row "Identificador" $(if ($f['uid']) { $f['uid'] } else { $f['identificador'] }) "Green"
    row "Tipo usuario"  $f['tipoEntrada']
    row "Correo"        $f['mail'] "DarkYellow"
    row "Ultimo cambio" $f['ultimoCambioPassword'] "DarkYellow"
    row "DN"            $f['dn']
    Write-Host "|"
    Write-Host "|  OPCIONES" -ForegroundColor Cyan
    Write-Host "|  1. Cambiar contrasena" -ForegroundColor Cyan
    Write-Host "|  2. Ver campos raw (todos)" -ForegroundColor Cyan
    Write-Host "|  3. Ver HTML debug" -ForegroundColor Cyan
    Write-Host "|  4. Editar datos" -ForegroundColor Cyan
    Write-Host "|  0. Volver al menu" -ForegroundColor Red
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

    Write-Host ""
    $opt = prompt "Opcion: " "0"
    if ($opt -eq "1") { screen-password }
    elseif ($opt -eq "2") { screen-raw-fields }
    elseif ($opt -eq "3") { screen-debug-html }
    elseif ($opt -eq "4") { screen-edit }
}

function Parse-SelectOptions {
    param([string]$Html, [string]$SelectName)
    $result = @()
    $esc = [regex]::Escape($SelectName)
    $m = [regex]::Match($Html, '(?s)<select[^>]*?\bname\s*=\s*["'']' + $esc + '["''][^>]*?>(.*?)</select>')
    if (-not $m.Success) { return $result }
    [regex]::Matches($m.Groups[1].Value, '<option[^>]*?(?:\bvalue\s*=\s*["'']([^"'']*?)["''])?[^>]*?>(.*?)</option>') | ForEach-Object {
        $v = if ($_.Groups[1].Success) { $_.Groups[1].Value } else { '' }
        $t = $_.Groups[2].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&'
        $result += @{ value = $v; text = $t.Trim() }
    }
    return $result
}

function Select-Option {
    param([string]$Prompt, [string]$Current, [array]$Options, [ref]$OutValue)
    $i = 0
    foreach ($o in $Options) {
        $mark = if ($o.text -eq $Current -or $o.value -eq $Current) { ' *' } else { '' }
        Write-Host ("     $i. " + $o.text + $mark) -ForegroundColor $(if ($mark) { 'Green' } else { 'DarkGray' })
        $i++
    }
    Write-Host ("     Enter = mantener actual: $Current") -ForegroundColor DarkGray
    $choice = prompt ("  $Prompt [$Current]: ")
    if (-not $choice) {
        $match = $Options | Where-Object { $_.text -eq $Current -or $_.value -eq $Current } | Select-Object -First 1
        if ($match) { $OutValue.Value = $match.value; return $match.text }
        $OutValue.Value = $Current; return $Current
    }
    $idx = 0
    if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 0 -and $idx -lt $Options.Count) {
        $OutValue.Value = $Options[$idx].value
        return $Options[$idx].text
    }
    # Try matching by text
    $match = $Options | Where-Object { $_.text -eq $choice -or $_.value -eq $choice } | Select-Object -First 1
    if ($match) { $OutValue.Value = $match.value; return $match.text }
    $OutValue.Value = $choice
    return $choice
}

function screen-edit {
    $f = $script:lastProfileFields
    $html = $script:lastRawHtml
    if (-not $f -or -not $html) { Write-Log "No hay perfil cargado" "WARN"; pause; return }

    $uid = if ($f['uid']) { $f['uid'] } else { $f['identificador'] }
    $dn = if ($f['dn']) { $f['dn'] } else { "uid=$uid,o=$script:ramaLdap,o=empleados,o=juntadeandalucia,c=es" }

    $editableFields = @(
        @{ label = 'DNI'; key = 'dni'; type = 'text' }
        @{ label = 'Tipo entrada'; key = 'tipoEntrada'; type = 'select' }
        @{ label = 'Servidor Correo'; key = 'servidorCorreo'; type = 'select' }
        @{ label = 'Cuota (MB)'; key = 'cuota'; type = 'text' }
        @{ label = 'DepartmentNumber'; key = 'departmentNumber'; type = 'text' }
        @{ label = 'Cargo'; key = 'cargo'; type = 'text' }
        @{ label = 'Servicio'; key = 'servicio'; type = 'text' }
        @{ label = 'Telefono Fijo'; key = 'telefonoFijo'; type = 'text' }
        @{ label = 'Telefono Movil'; key = 'telefonoMovil'; type = 'text' }
        @{ label = 'Fax'; key = 'fax'; type = 'text' }
        @{ label = 'Provincia'; key = 'provincia'; type = 'select' }
        @{ label = 'Comentarios'; key = 'comentarios'; type = 'text' }
    )

    $newValues = @{}
    foreach ($ef in $editableFields) {
        ui; header
        Write-Host (".- EDITANDO $uid" + (" " * ($script:columns - 16 - $uid.Length)) + ".") -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  Introduce nuevos valores. Enter para mantener actual." -ForegroundColor Yellow
        Write-Host "|  Escribe . para dejar vacio." -ForegroundColor Yellow
        Write-Host "|"
        Write-Host ("|  Editando campo $($ef.label):") -ForegroundColor White
        Write-Host "|"
        $current = if ($f.ContainsKey($ef.key) -and $f[$ef.key]) { $f[$ef.key] } else { '' }
        Write-Host ("|  Actual: ") -NoNewline; Write-Host $current -ForegroundColor Green
        Write-Host "|"

        if ($ef.type -eq 'select') {
            $opts = Parse-SelectOptions -Html $html -SelectName $ef.key
            if ($opts.Count -gt 0) {
                # Prefer _value (option value) over display text for matching
                $curText = if ($f.ContainsKey($ef.key + '_value') -and $f[$ef.key + '_value']) { $f[$ef.key + '_value'] } `
                    elseif ($f.ContainsKey($ef.key) -and $f[$ef.key]) { $f[$ef.key] } `
                    else { '' }
                $submitVal = $null
                $selText = Select-Option -Prompt $ef.label -Current $curText -Options $opts -OutValue ([ref]$submitVal)
                $newValues[$ef.key] = $selText
                $newValues[$ef.key + '_submit'] = $submitVal
            } else {
                $v = prompt ("  $($ef.label) [$current]: ") $current
                $newValues[$ef.key] = $v
                $newValues[$ef.key + '_submit'] = $v
            }
        } else {
            $input = prompt ("  $($ef.label) [.] " + "(Enter=keep, .=clear): " ) '~~KEEP~~'
            if ($input -eq '~~KEEP~~') { $val = $current; $newValues[$ef.key] = $val }
            elseif ($input -eq '.') { $newValues[$ef.key] = '' }
            else { $newValues[$ef.key] = $input }
        }
    }

    # Show summary
    ui; header
    Write-Host (".- RESUMEN CAMBIOS" + (" " * ($script:columns - 18)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    $changed = $false
    foreach ($ef in $editableFields) {
        $oldKey = $ef.key
        if ($ef.type -eq 'select') { $oldKey = $ef.key + '_submit' }
        $old = if ($f.ContainsKey($oldKey) -and $f[$oldKey]) { $f[$oldKey] } else { '' }
        if (-not $old -and $f.ContainsKey($ef.key)) { $old = $f[$ef.key] }

        $newKey = if ($ef.type -eq 'select') { $ef.key + '_submit' } else { $ef.key }
        $displayNew = $newValues[$ef.key]
        $new = $newValues[$newKey]

        $mark = if ($new -and $old -ne $new) { ' >>' } else { '' }
        if ($mark) { $changed = $true }
        Write-Host ("|  " + $ef.label.PadRight(20) + ": ") -NoNewline
        if ($mark) { Write-Host ("$old -> $new") -ForegroundColor Yellow }
        else { Write-Host ($old -replace '^(.{30}).*$', '$1...') -ForegroundColor DarkGray }
    }
    Write-Host "|"
    if (-not $changed) { Write-Host "|  Sin cambios" -ForegroundColor DarkGray; pause; return }

    $confirm = prompt "Guardar cambios? (s/N): " "n"
    if ($confirm -ne 's') { Write-Log "Cancelado" "WARN"; pause; return }

    # Save
    try {
        # Get fresh token
        $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
        $script:token = Extract-Token $r.Content
        if (-not $script:token) { throw "No se pudo extraer token" }

        # Build POST body from modify form hidden fields + new values
        $body = @{}
        [regex]::Matches($html, '<input[^>]*type="hidden"[^>]*name="([^"]*)"[^>]*value="([^"]*)"[^>]*>') | ForEach-Object {
            $body[$_.Groups[1].Value] = $_.Groups[2].Value
        }
        [regex]::Matches($html, '<input[^>]*type="hidden"[^>]*value="([^"]*)"[^>]*name="([^"]*)"[^>]*>') | ForEach-Object {
            if (-not $body.ContainsKey($_.Groups[2].Value)) { $body[$_.Groups[2].Value] = $_.Groups[1].Value }
        }

        # Add filter/checkbox fields
        $body['tokenParametro'] = $script:token
        $esInt = ($script:ramaLdap -eq "ius")
        if (-not $body.ContainsKey('filtroAtributo')) { $body['filtroAtributo'] = 'identificador' }
        if (-not $body.ContainsKey('filtroTipoBusqueda')) { $body['filtroTipoBusqueda'] = 'empezando' }
        if (-not $body.ContainsKey('filtroValor')) { $body['filtroValor'] = $uid }
        if (-not $body.ContainsKey('marcarSirhus')) { $body['marcarSirhus'] = $(if ($esInt) { 'NO' } else { 'SI' }) }
        if (-not $body.ContainsKey('marcarInternos')) { $body['marcarInternos'] = $(if ($esInt) { 'SI' } else { 'NO' }) }

        # Override editable fields
        foreach ($ef in $editableFields) {
            $submitKey = if ($ef.type -eq 'select') { $ef.key + '_submit' } else { $ef.key }
            $body[$ef.key] = $newValues[$submitKey]
        }

        # Set save action
        $body['accion'] = 'modificacion'
        $body['botonPulsado'] = 'confirmarModificacion'
        $body['datoAuxiliar'] = $dn

        # Add dn explicitly (needed by server)
        if (-not $body.ContainsKey('dn')) { $body['dn'] = $dn }

        $bodyKeys = ($body.Keys | Sort-Object) -join ', '
        Write-Log ("POST keys: $bodyKeys") "INFO"
        Write-Log ("Enviando cambios...") "INFO"
        $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body

        if ($r2.Content -match 'actualiz.+correctamente|mensaje_ok|Modificaci.n guardada') {
            Write-Log "Datos actualizados correctamente" "OK"
            # Reload profile
            Get-UserProfile -UID $uid
            screen-profile
        } else {
            $debugFile = Join-Path $script:DEBUG_DIR ("edit_" + $uid.Replace('.','_') + ".html")
            $r2.Content | Out-File -FilePath $debugFile -Encoding UTF8
            Write-Log "Parece que hubo un error. HTML guardado en $debugFile" "WARN"
            Write-Log "Revisa el archivo para ver el mensaje del servidor" "WARN"
            pause
        }
    } catch {
        $debugFile = Join-Path $script:DEBUG_DIR ("edit_" + $uid.Replace('.','_') + ".html")
        if ($_.Exception.Response) {
            try {
                $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errHtml = $sr.ReadToEnd(); $sr.Close()
                $errHtml | Out-File -FilePath $debugFile -Encoding UTF8
                Write-Log "HTML error guardado en $debugFile" "WARN"
            } catch { Write-Log "No se pudo leer respuesta del servidor" "WARN" }
        }
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
        pause
    }
}

function screen-raw-fields {
    $f = $script:lastProfileFields
    if (-not $f) { return }
    $keys = $f.Keys | Sort-Object
    $page = 0; $pageSize = 20
    while ($true) {
        ui; header
        $total = $keys.Count
        $pages = [Math]::Max(1, [Math]::Ceiling($total / $pageSize))
        Write-Host (".- CAMPOS RAW ($total)" + (" " * ($script:columns - 18)) + ".") -ForegroundColor Cyan
        $start = $page * $pageSize; $end = [Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $k = $keys[$i]; $v = $f[$k]
            if ($v.Length -gt 40) { $v = $v.Substring(0, 40) + "..." }
            Write-Host ("|  " + $k.PadRight(30) + " = ") -NoNewline; Write-Host $v -ForegroundColor Green
        }
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
        Write-Host ("Pagina $($page+1)/$pages") -ForegroundColor DarkGray -NoNewline
        if ($start -gt 0) { Write-Host "  [a] anterior" -ForegroundColor Cyan -NoNewline }
        if ($end -lt $total - 1) { Write-Host "  [s] siguiente" -ForegroundColor Cyan -NoNewline }
        Write-Host ""
        $input = prompt "Opcion: " "0"
        if ($input -eq "0") { break }
        elseif ($input -eq "s" -and $end -lt $total - 1) { $page++ }
        elseif ($input -eq "a" -and $page -gt 0) { $page-- }
    }
}

function screen-debug-html {
    $f = $script:lastProfileFields
    if (-not $f) { return }
    $uid = if ($f['uid']) { $f['uid'] } else { $f['identificador'] }
    $html = $script:lastRawHtml
    if (-not $html) { Write-Log "No hay HTML guardado" "WARN"; pause; return }
    
    ui; header
    Write-Host (".- HTML DEBUG" + (" " * ($script:columns - 12)) + ".") -ForegroundColor Cyan
    
    # Find sections around known labels
    $labelsToFind = @('Nombre', 'Identificador', 'Correo', 'DN', 'dn', 'uid')
    foreach ($lb in $labelsToFind) {
        $idx = $html.IndexOf($lb, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -ge 0) {
            $start = [Math]::Max(0, $idx - 50)
            $end = [Math]::Min($html.Length, $idx + 150)
            $snippet = $html.Substring($start, $end - $start)
            $snippet = $snippet -replace '<', '<' -replace '>', '>'
            Write-Host ("|  ..." + $snippet + "...") -ForegroundColor DarkYellow
            Write-Host "|"
        }
    }
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
    pause
}

function screen-password {
    $f = $script:lastProfileFields
    if (-not $f) { return }

    $uid = if ($f['uid']) { $f['uid'] } else { $f['identificador'] }
    $dn = $f['dn']

    ui; header
    Write-Host (".- CAMBIAR CONTRASENA" + (" " * ($script:columns - 23)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host ("|  UID:  $uid") -ForegroundColor White
    Write-Host ("|  DN:   $dn") -ForegroundColor White
    Write-Host ("|  Rama: $script:ramaLdap") -ForegroundColor White
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

    $month = Get-Date -Format "MM"; $year = Get-Date -Format "yy"
    $defaultPass = "Justicia.$month$year"
    Write-Host ("  Password por defecto: " + $defaultPass) -ForegroundColor DarkGray
    $pass = prompt "  Nueva password (Enter=defecto): " $defaultPass

    Write-Host ""
    Write-Host "  Confirmar:" -ForegroundColor Yellow
    Write-Host "  [s] Si, cambiar a '$pass'" -ForegroundColor Green
    Write-Host "  [w] WhatIf (solo simular)" -ForegroundColor Yellow
    Write-Host "  [n] No, cancelar" -ForegroundColor Red
    Write-Host ""
    $confirm = prompt "s/n/w: " "n"
    if ($confirm -eq 'n') { Write-Log "Cancelado" "WARN"; pause; return }

    $targetUser = if ($uid) { $uid } else { $f['identificador'] }
    $targetDn = if ($dn) { $dn } else { "uid=$targetUser,o=$script:ramaLdap,o=empleados,o=juntadeandalucia,c=es" }

    try {
        if ($confirm -eq 's' -or $confirm -eq 'S') {
            Set-UserPassword -DN $targetDn -UID $targetUser -TargetUser $targetUser -NewPassword $pass
            Write-Log "Contrasena cambiada exitosamente" "OK"
        } elseif ($confirm -eq 'w' -or $confirm -eq 'W') {
            Set-UserPassword -DN $targetDn -UID $targetUser -TargetUser $targetUser -NewPassword $pass -WhatIf
            Write-Log "Simulacion completada" "OK"
        }
    } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR" }
    pause
}

function screen-quick-search {
    param([string]$Query)
    Write-Log "Buscando $Query..." "INFO"
    $users = Search-User -Query $Query -SearchField "identificador"
    if ($users.Count -eq 0) { Write-Log "No encontrado" "WARN"; pause; return }
    if ($users.Count -eq 1) {
        $u = $users[0]
        $profileId = if ($u.uid) { $u.uid } else { $Query }
        Get-UserProfile -UID $profileId
        screen-profile
        return
    }
    $sel = screen-results -Users $users -Title "RESULTADOS"
    if ($sel -ge 0) {
        $u = $users[$sel]
        $profileId = if ($u.uid) { $u.uid } else { $u.nombre }
        if (-not $profileId) { $profileId = $Query }
        Get-UserProfile -UID $profileId
        screen-profile
    }
}

# ============================================================
# MAIN
# ============================================================

try {
    # Auto-connect at startup
    Write-Log "Conectando al Directorio..." "INFO"
    try { Connect-Directorio -Branch "jus" } catch {
        Write-Log ("Error de conexion: " + $_.Exception.Message) "ERROR"
    }

    $running = $true
    while ($running) {
        $opt = screen-main
        if (-not $script:authenticated) {
            Write-Log "Reconectando..." "WARN"
            try { Connect-Directorio -Branch "jus" } catch {
                Write-Log ("Error: " + $_.Exception.Message) "ERROR"
                pause; continue
            }
        }
        switch -Wildcard ($opt) {
            "1" { screen-search }
            "2" { if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-profile }
            "3" { if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-password }
            "0" { $running = $false }
            "q" { $running = $false }
            default {
                if ($opt -match '^s\s+(.+)') {
                    screen-quick-search $Matches[1]
                } else {
                    Write-Log "Opcion no valida" "WARN"; pause
                }
            }
        }
    }
} finally {
    ui; header
    Write-Host ("." + ("-" * ($script:columns - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + (" " * ($script:columns - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("|  LAZYDIRECTORY finalizado" + (" " * ($script:columns - 25)) + "|") -ForegroundColor Yellow
    Write-Host ("|" + (" " * ($script:columns - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
    Write-Host ""
}
