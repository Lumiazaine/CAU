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
$script:sirhusFiltroAtributo = ""
$script:sirhusFiltroTipoBusqueda = ""
$script:sirhusFiltroValor = ""

function ui {
    $script:columns = [Math]::Max(80, [Console]::WindowWidth)
}
function bar { param([string]$c = "DarkGray"); Write-Host ("-" * $script:columns) -ForegroundColor $c }

function header {
    Clear-Host
    $w = $script:columns
    $conn = if ($script:authenticated) { "CONECTADO" } else { "DESCONECTADO" }
    $cc = if ($script:authenticated) { "Green" } else { "Red" }
    $branch = $script:ramaLdap
    $title = " LAZYDIRECTORY v$script:VERSION "
    $status = " $conn | $branch "
    $pad = $w - $title.Length - $status.Length - 2
    if ($pad -lt 1) { $pad = 1 }
    Write-Host ("." + ("-" * ($w - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + $title) -ForegroundColor Yellow -NoNewline
    Write-Host (" " * $pad) -NoNewline
    Write-Host $status -ForegroundColor $cc -NoNewline
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor DarkGray
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
    return Read-KeyLine -Prompt $Text -Default $Default
}

function pause {
    Write-Host "Presiona Enter para continuar..." -ForegroundColor DarkGray -NoNewline
    $null = Get-Key
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

function Get-Key {
    $key = [Console]::ReadKey($true)
    $vk = [int]$key.Key
    $ch = $key.KeyChar
    if ($vk -eq 13) { return @{ Key = 'Enter'; Char = "`r" } }
    if ($vk -eq 27) { return @{ Key = 'Escape'; Char = "`e" } }
    if ($vk -eq 38) { return @{ Key = 'Up'; Char = '' } }
    if ($vk -eq 40) { return @{ Key = 'Down'; Char = '' } }
    if ($vk -eq 37) { return @{ Key = 'Left'; Char = '' } }
    if ($vk -eq 39) { return @{ Key = 'Right'; Char = '' } }
    if ($vk -eq 33) { return @{ Key = 'PageUp'; Char = '' } }
    if ($vk -eq 34) { return @{ Key = 'PageDown'; Char = '' } }
    if ($vk -eq 36) { return @{ Key = 'Home'; Char = '' } }
    if ($vk -eq 35) { return @{ Key = 'End'; Char = '' } }
    if ($vk -eq 32) { return @{ Key = 'Space'; Char = ' ' } }
    if ($vk -eq 9) { return @{ Key = 'Tab'; Char = "`t" } }
    if ($vk -eq 8) { return @{ Key = 'Backspace'; Char = "`b" } }
    return @{ Key = $ch.ToString().ToUpper(); Char = $ch }
}

function Read-KeyLine {
    param([string]$Prompt, [string]$Default = "")
    if ($Prompt) { Write-Host $Prompt -ForegroundColor Yellow -NoNewline }
    $input = ""
    [Console]::CursorVisible = $true
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 13) { break }
        if ($k.Key -eq 27) { [Console]::CursorVisible = $false; Write-Host ""; return $Default }
        if ($k.Key -eq 8) {
            if ($input.Length -gt 0) {
                $input = $input.Substring(0, $input.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
        } elseif ($k.KeyChar -and $k.KeyChar -ge ' ') {
            $input += $k.KeyChar
            Write-Host $k.KeyChar -NoNewline
        }
    }
    [Console]::CursorVisible = $false
    Write-Host ""
    if (-not $input -and $Default) { return $Default }
    return $input
}

function Show-Help {
    param([string]$Screen = "main")
    [Console]::CursorVisible = $false
    $w = $script:columns
    $helpWidth = 52
    $leftPad = [Math]::Max(2, [Math]::Floor(($w - $helpWidth) / 2))

    $shortcuts = @{
        main = @(
            @("1-5", "Acciones del menu"),
            @("0 / Q", "Salir"),
            @("s", "Busqueda rapida (UID)"),
            @("l", "Cambiar rama LDAP"),
            @("?", "Mostrar esta ayuda")
        )
        search = @(
            @("1-7", "Campo de busqueda"),
            @("0", "Volver"),
            @("?", "Mostrar esta ayuda")
        )
        results = @(
            @("j / Up", "Cursor arriba"),
            @("k / Down", "Cursor abajo"),
            @("Enter", "Ver perfil"),
            @("0 / ESC", "Volver"),
            @("?", "Mostrar esta ayuda")
        )
        profile = @(
            @("e", "Editar datos"),
            @("c", "Cambiar password"),
            @("1-4", "Acciones del perfil"),
            @("0 / ESC", "Volver"),
            @("?", "Mostrar esta ayuda")
        )
        sirhus = @(
            @("^ / v", "Navegar"),
            @("Space", "Seleccionar"),
            @("t", "Toggle todos"),
            @("v", "Validar"),
            @("b", "Buscar"),
            @("0 / ESC", "Volver")
        )
    }

    $items = if ($shortcuts.ContainsKey($Screen)) { $shortcuts[$Screen] } else { $shortcuts['main'] }

    $border = "." + ("-" * ($helpWidth - 2)) + "."
    $emptyLine = "|" + (" " * ($helpWidth - 2)) + "|"

    $top = $leftPad
    $row = 0
    $maxRows = 25

    function DrawLine {
        param([string]$Line)
        if ($row -lt $maxRows) {
            Write-Host (" " * $leftPad) -NoNewline; Write-Host $Line
            $script:rowCount++
        }
    }

    $script:rowCount = 0
    $saved = [Console]::CursorTop
    Clear-Host
    header
    $script:rowCount = 3

    for ($i = 0; $i -lt 2 -and $script:rowCount -lt $maxRows; $i++) { Write-Host ""; $script:rowCount++ }
    Write-Host (" " * $leftPad) -NoNewline; Write-Host $border -ForegroundColor Cyan; $script:rowCount++
    Write-Host (" " * $leftPad) -NoNewline; Write-Host $emptyLine; $script:rowCount++
    Write-Host (" " * $leftPad) -NoNewline
    Write-Host ("|  AYUDA - TECLADO") -ForegroundColor Yellow -NoNewline
    Write-Host (" " * ($helpWidth - 21) + "|"); $script:rowCount++
    Write-Host (" " * $leftPad) -NoNewline; Write-Host $emptyLine; $script:rowCount++
    foreach ($s in $items) {
        $line = "|  " + $s[0].PadRight(12) + "  " + $s[1]
        $line = $line.PadRight($helpWidth - 1) + "|"
        Write-Host (" " * $leftPad) -NoNewline; Write-Host $line -ForegroundColor White; $script:rowCount++
    }
    Write-Host (" " * $leftPad) -NoNewline; Write-Host $emptyLine; $script:rowCount++
    Write-Host (" " * $leftPad) -NoNewline; Write-Host ("|  [q / ESC / ?] Cerrar").PadRight($helpWidth - 1) + "|" -ForegroundColor DarkGray; $script:rowCount++
    Write-Host (" " * $leftPad) -NoNewline; Write-Host $border -ForegroundColor Cyan; $script:rowCount++

    while ($true) {
        $k = Get-Key
        if ($k.Key -eq 'Q' -or $k.Key -eq 'Escape' -or $k.Key -eq '?') { break }
    }

    header
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
    $user = Read-KeyLine -Prompt "Usuario administrador: "
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

    # Helper: Parse label+value pairs from form_field blocks directly
    function Parse-FormFields {
        param([string]$HtmlSource)
        $results = @()
        $m = [regex]::Matches($HtmlSource, '(?s)<div\s+class="form_field">.*?<div\s+class="form_field_label[^"]*">(.*?)</div>\s*<div\s+class="form_field_value[^"]*">(.*?)</div>')
        foreach ($mm in $m) {
            $labelText = Clean-Val $mm.Groups[1].Value
            $valText = Clean-Val $mm.Groups[2].Value
            if (-not $labelText -or -not $valText) { continue }
            if ($mm.Groups[2].Value -match '<(input|select|textarea)\b') { continue }
            $results += @{ label = $labelText; value = $valText }
        }
        return $results
    }

    function Note-Data {
        param([string]$Label, [string]$Value)
        if (-not $Label -or -not $Value) { return }
        foreach ($fk in $sortedKeys) {
            if ($Label -match $fk) {
                $target = $fieldMap[$fk]
                if (-not $data.ContainsKey($target) -or [string]::IsNullOrEmpty($data[$target])) {
                    $data[$target] = $Value
                }
                break
            }
        }
    }

    # Strategy 1: Password overlay form_fields (within capa_password_* div)
    $pwIdx = $Html.IndexOf('id="capa_password_', [System.StringComparison]::OrdinalIgnoreCase)
    if ($pwIdx -ge 0) {
        $pwStart = $Html.LastIndexOf('<div', $pwIdx)
        if ($pwStart -ge 0) {
            # Find ALL end-marker candidates past pwStart
            $endMarkers = @('</div>\s*</div>\s*<!--', '</div>\s*</div>\s*<h2', '</div>\s*</div>\s*$')
            $pwEnd = -1
            $allEnds = [regex]::Matches($Html, '(?:' + ($endMarkers -join '|') + ')', 'IgnoreCase, Singleline')
            foreach ($me in $allEnds) {
                if ($me.Index -gt $pwStart -and ($pwEnd -eq -1 -or $me.Index -lt $pwEnd)) {
                    $pwEnd = $me.Index
                }
            }
            if ($pwEnd -gt $pwStart) {
                $pwContent = $Html.Substring($pwStart, $pwEnd - $pwStart)
                foreach ($pair in (Parse-FormFields $pwContent)) {
                    Note-Data $pair.label $pair.value
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
    foreach ($pair in (Parse-FormFields $Html)) {
        Note-Data $pair.label $pair.value
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

function Search-UserBranch {
    param([string]$Query, [string]$SearchField, [string]$SearchType, [string]$Branch, [switch]$AllTypes)

    $esInt = ($Branch -eq "ius")
    Write-Log "Buscando '$Query' por '$SearchField' en $Branch..." "INFO"

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
    if ($AllTypes) {
        $body['marcarSirhus'] = 'SI'; $body['marcarInternos'] = 'SI'
        $body['marcarExternos'] = 'SI'; $body['marcarGenericos'] = 'SI'; $body['marcarNA'] = 'SI'
        $body.Remove('seleccionarInternos')
        $body.Remove('seleccionarSirhus')
    } elseif ($esInt) { $body['seleccionarInternos'] = 'on' }
    else { $body['seleccionarSirhus'] = 'on' }

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $html = $r.Content

    $debugFile = Join-Path $script:DEBUG_DIR ("search_" + $Query.Replace('.','_') + "_$Branch.html")
    $html | Out-File -FilePath $debugFile -Encoding UTF8
    Write-Log ("Respuesta " + $Branch + ": " + $html.Length + " bytes") "INFO"

    $users = @()
    $isExact = $false
    $profileFields = $null

    $dnMatches = [regex]::Matches($html, 'name="dn"\s*value="([^"]+)"')
    if ($dnMatches.Count -eq 1) {
        $dn = $dnMatches[0].Groups[1].Value
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
        $users += @{ dn = $dn; uid = $uid; nombre = $fields['cn']; apellidos = $fields['sn']; email = $fields['mail']; desc = $fields['description']; branch = $Branch; fields = $fields }
        $isExact = $true
        $profileFields = $fields
        Write-Log ("Encontrado en " + $Branch + ": " + $uid) "OK"
        return @{ Users = $users; IsExact = $isExact; ProfileFields = $profileFields; Html = $html }
    }

    $seen = @{}
    [regex]::Matches($html, '(?s)<div\s+class="fila_(?:par|impar)"[^>]*>.*?</div>') | ForEach-Object {
        $rowHtml = $_.Value
        $spans = [regex]::Matches($rowHtml, '<span\s+class="campo ancho2">(.*?)</span>')
        $email = if ($spans.Count -ge 1) { ($spans[0].Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '\s+', ' ').Trim() } else { '' }
        $name  = if ($spans.Count -ge 2) { ($spans[1].Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '\s+', ' ').Trim() } else { '' }

        $uid = ''
        $uidM = [regex]::Match($rowHtml, "enviar\('[^']+','[^']+','uid=([^,]+)")
        if ($uidM.Success) { $uid = $uidM.Groups[1].Value.ToLower() }

        if (-not $uid) {
            $atM = [regex]::Match($email, '^([^@]+)@')
            if ($atM.Success) { $uid = $atM.Groups[1].Value.ToLower() }
        }
        if (-not $uid) { return }
        if ($seen.ContainsKey($uid)) { return }
        $seen[$uid] = $true

        $parts = $name -split '\s+', 2
        $nombre = if ($parts[0]) { $parts[0] } else { '' }
        $apellidos = if ($parts.Count -ge 2) { $parts[1] } else { '' }

        $users += @{
            dn = "uid=$uid,o=$Branch,o=empleados,o=juntadeandalucia,c=es"
            uid = $uid; nombre = $nombre; apellidos = $apellidos
            email = $email; desc = ''; branch = $Branch
        }
    }
    Write-Log ("filas encontradas en " + $Branch + ": " + $seen.Count) "INFO"
    return @{ Users = $users; IsExact = $false; ProfileFields = $null; Html = $html }
}

function Search-User {
    param([string]$Query = "", [string]$SearchField = "identificador", [string]$SearchType = "conteniendo")

    if ($Query -match '^\d{7,8}$') {
        $SearchField = "dni"; $SearchType = "conteniendo"
    }

    if ($SearchField -eq "dni") {
        $allUsers = @()
        $lastHtml = $null
        foreach ($br in @("jus", "ius")) {
            if ($script:ramaLdap -ne $br) {
                Write-Log "Cambiando a rama $br..." "INFO"
                Connect-Directorio -Branch $br
                if (-not $script:authenticated) { Write-Log "Error al cambiar a $br" "ERROR"; continue }
            }
            $result = Search-UserBranch -Query $Query -SearchField $SearchField -SearchType $SearchType -Branch $br -AllTypes
            $allUsers += $result.Users
            if ($result.Html) { $lastHtml = $result.Html }
            if ($result.ProfileFields -and -not $script:lastProfileFields) {
                $script:lastProfileFields = $result.ProfileFields
            }
        }
        $script:lastRawHtml = $lastHtml
        if ($allUsers.Count -eq 0) { $script:lastProfileFields = $null }
        Write-Log ("Total usuarios encontrados: " + $allUsers.Count) "INFO"
        $script:lastResultData = $allUsers
        return $allUsers
    }

    $branch = Ensure-Branch $Query
    $result = Search-UserBranch -Query $Query -SearchField $SearchField -SearchType $SearchType -Branch $branch
    $script:lastRawHtml = $result.Html
    $script:lastProfileFields = $result.ProfileFields
    $script:lastResultData = $result.Users
    Write-Log ("Usuarios: " + $result.Users.Count) "INFO"
    return $result.Users
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
            filtroTipoBusqueda = 'conteniendo'
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
        filtroTipoBusqueda = 'conteniendo'
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
        filtroTipoBusqueda = 'conteniendo'
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
    $menuItems = @(
        @{ key = "1"; label = "Buscar usuario" }
        @{ key = "2"; label = "Crear usuario" }
        @{ key = "3"; label = "Cambiar contrasena" }
        @{ key = "4"; label = "Listas" }
        @{ key = "5"; label = "Sirhus" }
        @{ key = "0"; label = "Salir" }
    )
    $cursor = 0

    while ($true) {
        ui; header
        panel "MENU PRINCIPAL" {
            Write-Host "|"
            for ($i = 0; $i -lt $menuItems.Count; $i++) {
                $item = $menuItems[$i]
                if ($item.key -eq "0") { Write-Host "|" }
                $isCur = ($i -eq $cursor)
                $color = if ($item.key -eq "0") { "Red" } else { "Cyan" }
                if ($isCur) {
                    Write-Host ("|  > ") -NoNewline
                    Write-Host ("$($item.key). $($item.label)") -ForegroundColor White -BackgroundColor DarkCyan
                } else {
                    Write-Host ("|    ") -NoNewline
                    Write-Host ("$($item.key). $($item.label)") -ForegroundColor $color
                }
            }
            Write-Host "|"
            Write-Host ("|  >> Rama: $script:ramaLdap") -ForegroundColor Green
            if ($script:lastProfileFields -and $script:lastProfileFields['uid']) {
                Write-Host ("|     Usuario: $($script:lastProfileFields['uid'])") -ForegroundColor DarkGray
            }
            Write-Host "|"
        }
        footer @("[?] Ayuda", "[1-5] Accion", "[s] Buscar", "[l] Rama", "[q] Salir")

        $k = Get-Key
        if ($k.Key -eq 'Q' -or $k.Key -eq 'ESCAPE') { return "q" }
        if ($k.Key -eq '?' -or $k.Key -eq 'F1') { Show-Help -Screen "main"; continue }
        if ($k.Key -eq 'UP' -and $cursor -gt 0) { $cursor--; continue }
        if ($k.Key -eq 'DOWN' -and $cursor -lt $menuItems.Count - 1) { $cursor++; continue }
        if ($k.Key -eq 'ENTER' -or $k.Key -eq 'SPACE') { return $menuItems[$cursor].key }
        if ($k.Key -match '^[0-5]$') { return $k.Key }
        if ($k.Key -eq 'S') {
            $q = Read-KeyLine -Prompt "UID: "
            if ($q) { screen-quick-search $q }
            continue
        }
        if ($k.Key -eq 'L') {
            $branch = Read-KeyLine -Prompt "Rama LDAP (jus/ius): " "jus"
            if ($branch -and $branch -ne $script:ramaLdap) {
                try { Connect-Directorio -Branch $branch } catch { Write-Log "Error al cambiar rama" "ERROR" }
            }
            continue
        }
    }
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

    $query = prompt "Valor a buscar: "
    if (-not $query) { return $null }

    Write-Log "Buscando..." "INFO"
    $users = Search-User -Query $query -SearchField $searchField -SearchType "conteniendo"

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
    $pageSize = 15; $cursor = 0; $page = 0

    while ($true) {
        $total = $Users.Count
        if ($total -eq 0) { return -1 }
        $pages = [Math]::Max(1, [Math]::Ceiling($total / $pageSize))
        if ($cursor -ge $total) { $cursor = $total - 1 }
        $page = [Math]::Floor($cursor / $pageSize)

        ui; header
        Write-Host (".- $Title ($total usuarios)" + (" " * ($script:columns - 20 - $Title.Length)) + ".") -ForegroundColor Cyan
        $numCol = 4; $uidCol = 18; $nameCol = 22
        $emailCol = $script:columns - 4 - $numCol - $uidCol - $nameCol
        if ($emailCol -lt 15) { $emailCol = 15; $uidCol = 15; $nameCol = $script:columns - 4 - $numCol - $uidCol - $emailCol }
        $hdr = ("{0,$numCol} {1,-$uidCol} {2,-$nameCol} {3,-$emailCol}" -f "#", "UID", "NOMBRE", "EMAIL")
        Write-Host ("| " + $hdr.PadRight($script:columns - 4)) -ForegroundColor DarkGray
        $start = $page * $pageSize; $end = [Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $u = $Users[$i]
            $uidStr = if ($u.uid) { $u.uid } else { "-" }
            $emailStr = if ($u.email) { $u.email } else { "-" }
            $fullName = "$($u.nombre) $($u.apellidos)".Trim()
            if (-not $fullName) { $fullName = "-" }
            $line = ("{0,$numCol} {1,-$uidCol} {2,-$nameCol} {3,-$emailCol}" -f ($i+1), $uidStr.Substring(0, [Math]::Min($uidCol, $uidStr.Length)), $fullName.Substring(0, [Math]::Min($nameCol, $fullName.Length)), $emailStr.Substring(0, [Math]::Min($emailCol, $emailStr.Length)))
            if ($line.Length -gt $script:columns - 5) { $line = $line.Substring(0, $script:columns - 8) }
            $isCur = ($i -eq $cursor)
            if ($isCur) {
                Write-Host "| " -NoNewline; Write-Host $line -ForegroundColor White -BackgroundColor DarkCyan -NoNewline
                $pad = $script:columns - 4 - $line.Length
                if ($pad -gt 0) { Write-Host (" " * $pad) -NoNewline -BackgroundColor DarkCyan }; Write-Host "|" -ForegroundColor DarkGray
            } else {
                Write-Host "| " -NoNewline; Write-Host $line -ForegroundColor White -NoNewline
                $pad = $script:columns - 4 - $line.Length
                if ($pad -gt 0) { Write-Host (" " * $pad) -NoNewline }; Write-Host "|" -ForegroundColor DarkGray
            }
        }
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

        Write-Host ("  Resultado $($cursor+1) de $total") -ForegroundColor DarkGray -NoNewline
        if ($start -gt 0) { Write-Host "  [p] ant" -ForegroundColor Cyan -NoNewline }
        if ($end -lt $total - 1) { Write-Host "  [n] sig" -ForegroundColor Cyan -NoNewline }
        Write-Host ""

        $k = Get-Key
        if ($k.Key -eq 'UP' -or $k.Key -eq 'K') { if ($cursor -gt 0) { $cursor-- }; continue }
        if ($k.Key -eq 'DOWN' -or $k.Key -eq 'J') { if ($cursor -lt $total - 1) { $cursor++ }; continue }
        if ($k.Key -eq 'PAGEUP') { $cursor = [Math]::Max(0, $cursor - $pageSize); continue }
        if ($k.Key -eq 'PAGEDOWN') { $cursor = [Math]::Min($total - 1, $cursor + $pageSize); continue }
        if ($k.Key -eq 'HOME') { $cursor = 0; continue }
        if ($k.Key -eq 'END') { $cursor = $total - 1; continue }
        if ($k.Key -eq 'ENTER') { return $cursor }
        if ($k.Key -eq '0' -or $k.Key -eq 'ESCAPE') { return -1 }
        if ($k.Key -eq '?') { Show-Help -Screen "results"; continue }
        if ($k.Key -eq 'N') { $cursor = [Math]::Min($total - 1, $cursor + $pageSize); continue }
        if ($k.Key -eq 'P') { $cursor = [Math]::Max(0, $cursor - $pageSize); continue }
    }
}

function screen-profile {
    $f = $script:lastProfileFields
    if (-not $f) { Write-Log "No hay perfil cargado" "WARN"; pause; return }

    $uid = if ($f['uid']) { $f['uid'] } else { $f['identificador'] }
    $displayId = if ($uid) { $uid } else { "desconocido" }

    $profileFields = @(
        @{ label = "Nombre";         key = "nombreUsuario"; fallback = "cn";              color = "Green" }
        @{ label = "Identificador";  key = "uid";           fallback = "identificador";   color = "Green" }
        @{ label = "Tipo usuario";   key = "tipoEntrada";                                  color = "White" }
        @{ label = "Correo";         key = "mail";                                         color = "DarkYellow" }
        @{ label = "Ultimo cambio";  key = "ultimoCambioPassword";                         color = "DarkYellow" }
        @{ label = "DNI";            key = "dni";                                          color = "White" }
        @{ label = "Cargo";          key = "cargo";                                        color = "White" }
        @{ label = "Servicio";       key = "servicio";                                     color = "White" }
        @{ label = "Telefono";       key = "telefonoFijo";                                 color = "White" }
        @{ label = "Movil";          key = "telefonoMovil";                                color = "White" }
        @{ label = "Provincia";      key = "provincia";                                    color = "White" }
        @{ label = "Department";     key = "departmentNumber";                             color = "White" }
        @{ label = "Cuota";          key = "cuota";                                        color = "White" }
        @{ label = "Comentarios";    key = "comentarios";                                  color = "DarkYellow" }
        @{ label = "DN";             key = "dn";                                           color = "DarkGray" }
    )

    $visibleFields = @()
    foreach ($pf in $profileFields) {
        $val = if ($f.ContainsKey($pf.key) -and $f[$pf.key]) { $f[$pf.key] } `
               elseif ($pf.ContainsKey('fallback') -and $f.ContainsKey($pf.fallback) -and $f[$pf.fallback]) { $f[$pf.fallback] } `
               else { $null }
        if ($val) { $visibleFields += @{ label = $pf.label; value = $val; color = $pf.color } }
    }

    $useColumns = $script:columns -ge 120
    $scrollPos = 0
    $actionRow = $visibleFields.Count
    if ($useColumns) {
        $colCount = [Math]::Ceiling($visibleFields.Count / 2)
        $maxVisible = $colCount + 6
    } else {
        $maxVisible = 12
    }

    while ($true) {
        ui; header
        Write-Host (".- $displayId" + (" " * ($script:columns - 8 - $displayId.Length)) + ".") -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  DATOS DEL USUARIO" -ForegroundColor Cyan
        Write-Host "|"

        if ($useColumns) {
            $half = [Math]::Ceiling($visibleFields.Count / 2)
            for ($i = 0; $i -lt $half; $i++) {
                $left = $visibleFields[$i]
                $rightIdx = $i + $half
                $right = if ($rightIdx -lt $visibleFields.Count) { $visibleFields[$rightIdx] } else { $null }
                $valLeft = if ($left.value.Length -gt 25) { $left.value.Substring(0, 24) + "~" } else { $left.value }
                Write-Host ("|  " + $left.label.PadRight(16) + ": ") -NoNewline
                Write-Host $valLeft.PadRight(26) -ForegroundColor $left.color -NoNewline
                if ($right) {
                    $valRight = if ($right.value.Length -gt 25) { $right.value.Substring(0, 24) + "~" } else { $right.value }
                    Write-Host ($right.label.PadRight(16) + ": ") -NoNewline
                    Write-Host $valRight -ForegroundColor $right.color
                } else { Write-Host "" }
            }
        } else {
            $end = [Math]::Min($scrollPos + $maxVisible - 1, $visibleFields.Count - 1)
            for ($i = $scrollPos; $i -le $end; $i++) {
                $pf = $visibleFields[$i]
                row $pf.label $pf.value $pf.color
            }
        }

        Write-Host "|"
        Write-Host "|  OPCIONES" -ForegroundColor Cyan
        Write-Host "|  [1] Cambiar contrasena" -ForegroundColor Cyan
        Write-Host "|  [2] Campos raw" -ForegroundColor Cyan
        Write-Host "|  [3] HTML debug" -ForegroundColor Cyan
        Write-Host "|  [4] Editar datos" -ForegroundColor Cyan
        Write-Host "|  [0] Volver" -ForegroundColor Red
        Write-Host "|"
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

        footer @("[1-4] Accion", "[e] Editar", "[c] Pass", "[?] Ayuda", "[0] Volver")

        $k = Get-Key
        if ($k.Key -eq '0' -or $k.Key -eq 'ESCAPE') { return }
        if ($k.Key -eq '1') { screen-password; continue }
        if ($k.Key -eq '2') { screen-raw-fields; continue }
        if ($k.Key -eq '3') { screen-debug-html; continue }
        if ($k.Key -eq '4' -or $k.Key -eq 'E') { screen-edit; continue }
        if ($k.Key -eq 'C') { screen-password; continue }
        if ($k.Key -eq 'J' -or $k.Key -eq 'DOWN') {
            if (-not $useColumns -and $scrollPos + $maxVisible -lt $visibleFields.Count) { $scrollPos++ }
            continue
        }
        if ($k.Key -eq 'K' -or $k.Key -eq 'UP') {
            if (-not $useColumns -and $scrollPos -gt 0) { $scrollPos-- }
            continue
        }
        if ($k.Key -eq '?') { Show-Help -Screen "profile"; continue }
    }
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
        Write-Log "Preparando guardado..." "INFO"

        # Step 1: fetch modify form fresh
        $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
        $script:token = Extract-Token $r.Content
        if (-not $script:token) { throw "No se pudo extraer token" }

        $esInt = ($script:ramaLdap -eq "ius")
        $fetchBody = @{
            accion = 'modificacion'; botonPulsado = 'pantalla1'
            datoAuxiliar = $dn; tokenParametro = $script:token
            filtroAtributo = 'identificador'; filtroTipoBusqueda = 'conteniendo'; filtroValor = $uid
            marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
            marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
            marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
            numUsuariosAntiguo = '25'; numUsuarios = '25'
        }
        if ($esInt) { $fetchBody['seleccionarInternos'] = 'on' }
        else { $fetchBody['seleccionarSirhus'] = 'on' }

        $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $fetchBody
        $modifyHtml = $r2.Content
        $script:token = Extract-Token $modifyHtml
        if (-not $script:token) { Write-Log "Token no encontrado, usando anterior" "WARN" }

        # Step 2: extract ALL fields from fresh modify form
        $formFields = Extract-FormFields $modifyHtml
        $allInputs = [regex]::Matches($modifyHtml, '\bname\s*=\s*["'']([^"'']*?)["''][^>]*?\bvalue\s*=\s*["'']([^"'']*?)["'']')
        foreach ($m in $allInputs) {
            $n = $m.Groups[1].Value; $v = $m.Groups[2].Value
            if (-not $formFields.ContainsKey($n)) { $formFields[$n] = $v }
        }

        # Step 3: handle _modificacion suffix — create base-name entries
        $suffixKeys = @()
        foreach ($k in $formFields.Keys) {
            if ($k -match '^(.+)_modificacion$') { $suffixKeys += $k }
        }
        foreach ($sk in $suffixKeys) {
            $base = $sk -replace '_modificacion$', ''
            if (-not $formFields.ContainsKey($base)) {
                $formFields[$base] = $formFields[$sk]
            }
        }

        # Step 4: build POST body = all form fields + new values
        $body = @{}
        foreach ($kv in $formFields.GetEnumerator()) { $body[$kv.Key] = $kv.Value }
        $body['tokenParametro'] = $script:token
        $body['botonPulsado'] = 'confirmarModificacion'

        # Override with new values
        foreach ($ef in $editableFields) {
            $submitKey = if ($ef.type -eq 'select') { $ef.key + '_submit' } else { $ef.key }
            if ($newValues.ContainsKey($submitKey)) { $body[$ef.key] = $newValues[$submitKey] }
        }

        # Ensure key fields
        if (-not $body.ContainsKey('datoAuxiliar')) { $body['datoAuxiliar'] = $dn }
        if (-not $body.ContainsKey('accion')) { $body['accion'] = 'modificacion' }

        Write-Log ("Enviando cambios (" + $body.Count + " campos)...") "INFO"
        $r3 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body

        if ($r3.Content -match 'actualiz.+correctamente|mensaje_ok|Modificaci.n guardada|correctamente') {
            Write-Log "Datos actualizados correctamente" "OK"
            Get-UserProfile -UID $uid
        } else {
            $debugFile = Join-Path $script:DEBUG_DIR ("edit_" + $uid.Replace('.','_') + ".html")
            $r3.Content | Out-File -FilePath $debugFile -Encoding UTF8
            Write-Log "Posible error. HTML guardado en $debugFile" "WARN"
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

function Fetch-Servlet {
    param([string]$ServletName, [string]$Label)
    Write-Log "Obteniendo $Label..." "INFO"
    $r = Invoke-WebRequest -Uri "$script:BASE.$ServletName" -UseBasicParsing -WebSession $script:webSession
    $html = $r.Content
    $debugFile = Join-Path $script:DEBUG_DIR ("$ServletName.html")
    $html | Out-File -FilePath $debugFile -Encoding UTF8
    Write-Log ("Respuesta: " + $html.Length + " bytes, guardado en $debugFile") "INFO"
    return $html
}

function screen-listas {
    ui; header
    Write-Host (".- LISTAS" + (" " * ($script:columns - 10)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host "|  Accediendo al modulo de Listas..." -ForegroundColor Yellow
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
    
    try {
        $html = Fetch-Servlet -ServletName "ListasMain" -Label "Listas"
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
        pause; return
    }

    # Extract page title or heading
    $title = "-"
    $tM = [regex]::Match($html, '<h[1-3][^>]*>(.*?)</h[1-3]>')
    if ($tM.Success) { $title = ($tM.Groups[1].Value -replace '<[^>]+>', '').Trim() }

    ui; header
    panel "LISTAS ($title)" {
        # Extract any table/result rows
        $tabla = [regex]::Match($html, '(?s)<table[^>]*>.*?</table>')
        if ($tabla.Success) {
            Write-Host "|  (tabla encontrada, " + $tabla.Length + " bytes)"
        }
        # Show some text content
        $textContent = $html -replace '<[^>]+>', ' ' -replace '\s+', ' ' -replace '&nbsp;', ' '
        $lines = $textContent -split '\.' | Where-Object { $_.Trim().Length -gt 10 } | Select-Object -First 15
        foreach ($ln in $lines) {
            $t = $ln.Trim()
            if ($t) { Write-Host ("|  " + $t.Substring(0, [Math]::Min(70, $t.Length))) -ForegroundColor DarkYellow }
        }
    }
    Write-Host ("  HTML guardado: $script:DEBUG_DIR\ListasMain.html") -ForegroundColor DarkGray
    pause
}

function screen-sirhus {
    while ($true) {
        ui; header
        panel "SIRHUS" {
            Write-Host "|"
            Write-Host "|  1. Altas (nuevo usuario externo)" -ForegroundColor Cyan
            Write-Host "|  2. Bajas" -ForegroundColor Cyan
            Write-Host "|  3. Traslados" -ForegroundColor Cyan
            Write-Host "|  4. Consulta Estado Sirhus" -ForegroundColor Cyan
            Write-Host "|"
            Write-Host "|  0. Volver" -ForegroundColor Red
            Write-Host "|"
        }
        footer @("1-4 opciones", "0 volver")
        Write-Host ""
        $opt = prompt "Opcion: " "0"
        if ($opt -eq "0") { return }
        elseif ($opt -eq "1") { screen-sirhus-altas }
        elseif ($opt -eq "2") { screen-sirhus-bajas }
        elseif ($opt -eq "3") { screen-sirhus-generic "SirhusTraslados" "TRASLADOS" }
        elseif ($opt -eq "4") { screen-sirhus-consulta-estado }
        else { Write-Log "Opcion no valida" "WARN"; pause }
    }
}

function Parse-SirhusResults {
    param([string]$Html)
    $users = @()

    # Try div-based rows first (fila_par/fila_impar)
    $divRows = [regex]::Matches($Html, '(?s)<div\s+class="fila_(?:par|impar)"[^>]*>.*?</div>')
    if ($divRows.Count -gt 0) {
        foreach ($row in $divRows) {
            $rowHtml = $row.Value
            $dnM = [regex]::Match($rowHtml, 'name="dn"\s*value="([^"]+)"')
            if (-not $dnM.Success) { continue }
            $dn = $dnM.Groups[1].Value
            $uid = ''
            $u = [regex]::Match($dn, 'uid=([^,]+)')
            if ($u.Success) { $uid = $u.Groups[1].Value }
            $spans20 = [regex]::Matches($rowHtml, '<span\s+class="campo"[^>]*style="width:20%"[^>]*>(.*?)</span>')
            $nombre = if ($spans20.Count -ge 1) { ($spans20[0].Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }
            $span30 = [regex]::Match($rowHtml, '<span\s+class="campo"[^>]*style="width:30%"[^>]*>(.*?)</span>')
            $centro = if ($span30.Success) { ($span30.Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }
            $users += @{ dn = $dn; uid = $uid; nombre = $nombre; centro = $centro }
        }
        return $users
    }

    # Fallback: table-based rows (<tr>/<td>)
    [regex]::Matches($Html, '(?s)<tr[^>]*>.*?</tr>') | ForEach-Object {
        $row = $_.Value
        if ($row -match '<th') { return }
        $dnM = [regex]::Match($row, 'name="dn"\s*value="([^"]+)"')
        if (-not $dnM.Success) { return }
        $dn = $dnM.Groups[1].Value
        $u = [regex]::Match($dn, 'uid=([^,]+)')
        $uid = if ($u.Success) { $u.Groups[1].Value } else { '' }
        $cells = [regex]::Matches($row, '<td[^>]*>(.*?)</td>')
        $nombre = if ($cells.Count -ge 1) { ($cells[0].Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim() } else { '' }
        $centro = if ($cells.Count -ge 3) { ($cells[2].Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ').Trim() } else { '' }
        $users += @{ dn = $dn; uid = $uid; nombre = $nombre; centro = $centro }
    }
    return $users
}

function Show-SirhusList {
    param([array]$Users, [string]$Title = "SIRHUS ALTAS")
    if (-not $script:sirhusSelected) { $script:sirhusSelected = @{} }
    $pageSize = 5; $cursor = 0; $page = 0
    while ($true) {
        $total = $Users.Count
        if ($total -eq 0) { return $false }
        $pages = [int][Math]::Max(1, [Math]::Ceiling($total / $pageSize))

        if ($cursor -ge $total) { $cursor = $total - 1 }
        $page = [int][Math]::Floor($cursor / $pageSize)

        ui; header
        Write-Host (".- $Title ($total usuarios)" + (" " * ($script:columns - 15 - $Title.Length)) + ".") -ForegroundColor Cyan
        Write-Host "|" -NoNewline
        $hdr = "    {0,-22} {1,-28} {2,-20}" -f "NOMBRE", "IDENTIFICADOR", "CENTRO DIRECTIVO"
        Write-Host $hdr.PadRight($script:columns - 3) -NoNewline; Write-Host "|" -ForegroundColor DarkGray

        $start = [int]($page * $pageSize); $end = [int][Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $u = $Users[$i]
            $n = $u.nombre
            if ($n.Length -gt 22) { $n = $n.Substring(0, 20) + ".." }
            $id = $u.uid
            if ($id.Length -gt 28) { $id = $id.Substring(0, 26) + ".." }
            $ct = $u.centro
            if ($ct.Length -gt 20) { $ct = $ct.Substring(0, 18) + ".." }
            $sel = if ($script:sirhusSelected.ContainsKey($i)) { "*" } else { " " }
            $isCur = ($i -eq $cursor)
            if ($isCur) { Write-Host "|" -NoNewline; Write-Host "[$sel]" -NoNewline -BackgroundColor DarkCyan }
            else { Write-Host "| [$sel]" -NoNewline }
            Write-Host (" " + "{0,2}" -f ($i+1)) -NoNewline
            if ($isCur) { Write-Host (" {0,-22}" -f $n) -NoNewline -ForegroundColor White -BackgroundColor DarkCyan }
            else { Write-Host (" {0,-22}" -f $n) -NoNewline -ForegroundColor White }
            if ($isCur) { Write-Host ("{0,-28}" -f $id) -NoNewline -ForegroundColor DarkYellow -BackgroundColor DarkCyan }
            else { Write-Host ("{0,-28}" -f $id) -NoNewline -ForegroundColor DarkYellow }
            if ($isCur) { Write-Host ("{0,-20}" -f $ct) -NoNewline -ForegroundColor DarkGray -BackgroundColor DarkCyan }
            else { Write-Host ("{0,-20}" -f $ct) -NoNewline -ForegroundColor DarkGray }
            Write-Host "|"
        }
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

        Write-Host ("Pagina $($page+1)/$pages  ") -ForegroundColor DarkGray -NoNewline
        if ($start -gt 0) { Write-Host "[a]nterior " -ForegroundColor Cyan -NoNewline }
        if ($end -lt $total - 1) { Write-Host "[s]iguiente " -ForegroundColor Cyan -NoNewline }
        Write-Host ""
        Write-Host "  [^][v] navegar  [Espacio] toggle  [t] todos" -ForegroundColor Cyan
        Write-Host "  [v]alidar  [b]uscar  [0] volver" -ForegroundColor Green

        $key = [System.Console]::ReadKey($true)
        $vk = [int]$key.Key
        $ch = $key.KeyChar

        if ($vk -eq 38 -and $cursor -gt 0) { $cursor--; continue }       # Up
        if ($vk -eq 40 -and $cursor -lt $total - 1) { $cursor++; continue } # Down
        if ($vk -eq 33) { $cursor = [Math]::Max(0, $cursor - $pageSize); continue }  # PageUp
        if ($vk -eq 34) { $cursor = [Math]::Min($total - 1, $cursor + $pageSize); continue } # PageDown
        if ($vk -eq 36) { $cursor = 0; continue }  # Home
        if ($vk -eq 35) { $cursor = $total - 1; continue }  # End

        if ($vk -eq 32 -or $ch -eq ' ') {  # Space
            if ($script:sirhusSelected.ContainsKey($cursor)) { $script:sirhusSelected.Remove($cursor) }
            else { $script:sirhusSelected[$cursor] = $true }
            continue
        }

        if ($ch -eq 'v' -or $ch -eq 'V') {
            if ($script:sirhusSelected.Count -eq 0) { Write-Log "Nada seleccionado" "WARN"; pause; continue }
            return $true
        }
        if ($ch -eq 'b' -or $ch -eq 'B') {
            $query = prompt "  Buscar (nombre contiene): " ""
            if (-not $query) { continue }
            return @{ Action = "search"; Value = $query; Field = "nombre"; Type = "conteniendo" }
        }
        if ($ch -eq 't' -or $ch -eq 'T') {
            if ($script:sirhusSelected.Count -eq $total) { $script:sirhusSelected.Clear() }
            else { 0..($total-1) | ForEach-Object { $script:sirhusSelected[$_] = $true } }
            continue
        }
        if ($ch -eq '0' -or $vk -eq 27) { return $false }  # 0 or Escape
    }
}

function screen-sirhus-altas {
    Write-Log "Cargando Sirhus - Altas..." "INFO"
    $html = $null; $script:token = $null
    # Try GET first; fallback to POST with accion=consulta (SirhusAltas often returns 0 on GET)
    try { $html = Fetch-Servlet -ServletName "SirhusAltas" -Label "SirhusAltas" } catch { }
    if ([string]::IsNullOrWhiteSpace($html)) {
        Write-Log "GET devolvio vacio, intentando POST accion=consulta..." "WARN"
        $body = @{ accion = 'consulta'; botonPulsado = ''; filtroAtributo = ''; filtroTipoBusqueda = ''; filtroValor = '' }
        try {
            $r = Invoke-WebRequest -Uri "$script:BASE.SirhusAltas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
            $html = $r.Content
            Write-Log ("Respuesta POST: " + $html.Length + " bytes") "INFO"
            $debugFile = Join-Path $script:DEBUG_DIR "SirhusAltas.html"
            $html | Out-File -FilePath $debugFile -Encoding UTF8
        } catch { Write-Log ("Error en POST: " + $_.Exception.Message) "ERROR"; pause; return }
    }
    if ([string]::IsNullOrWhiteSpace($html)) { Write-Log "No se pudo cargar SirhusAltas" "ERROR"; pause; return }
    $script:token = Extract-Token $html

    $ff = Extract-FormFields $html
    $script:sirhusFiltroAtributo = if ($ff.ContainsKey('filtroAtributo')) { $ff['filtroAtributo'] } else { '' }
    $script:sirhusFiltroTipoBusqueda = if ($ff.ContainsKey('filtroTipoBusqueda')) { $ff['filtroTipoBusqueda'] } else { '' }
    $script:sirhusFiltroValor = if ($ff.ContainsKey('filtroValor')) { $ff['filtroValor'] } else { '' }

    $users = Parse-SirhusResults $html
    Write-Log ("Usuarios pendientes: " + $users.Count) "INFO"
    if ($users.Count -eq 0) { Write-Log "Sin usuarios pendientes" "WARN"; pause; return }

    $script:sirhusSelected = @{}
    while ($true) {
        $result = Show-SirhusList -Users $users -Title "SIRHUS ALTAS"
        if ($result -eq $false) { $script:sirhusSelected = @{}; return }
        elseif ($result -is [hashtable] -and $result.Action -eq "search") {
            $script:sirhusFiltroAtributo = $result.Field
            $script:sirhusFiltroTipoBusqueda = $result.Type
            $script:sirhusFiltroValor = $result.Value
            Write-Log "Buscando '$($result.Value)' por $($result.Field)..." "INFO"
            $body = @{
                accion = 'consulta'; botonPulsado = ''; tokenParametro = $script:token
                filtroAtributo = $script:sirhusFiltroAtributo
                filtroTipoBusqueda = $script:sirhusFiltroTipoBusqueda
                filtroValor = $script:sirhusFiltroValor
            }
            try {
                $r = Invoke-WebRequest -Uri "$script:BASE.SirhusAltas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
                $script:token = Extract-Token $r.Content
                $resultHtml = $r.Content
            } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR"; pause; continue }
            $debugFile = Join-Path $script:DEBUG_DIR "SirhusAltas_resultados.html"
            $resultHtml | Out-File -FilePath $debugFile -Encoding UTF8
            $users = Parse-SirhusResults $resultHtml
            Write-Log ("Resultados: " + $users.Count) "INFO"
            if ($users.Count -eq 0) { Write-Log "Sin resultados" "WARN"; pause }
            $script:sirhusSelected = @{}
        }
        elseif ($result -eq $true) {
            $indices = $script:sirhusSelected.Keys | Sort-Object
            Sirhus-Validar -Users $users -Indices $indices -Tipo "parcial" `
                -FiltroAtributo $script:sirhusFiltroAtributo `
                -FiltroTipoBusqueda $script:sirhusFiltroTipoBusqueda `
                -FiltroValor $script:sirhusFiltroValor
            $script:sirhusSelected = @{}
            # Re-fetch users list after validation
            try {
                $html = $null
                try { $html = Fetch-Servlet -ServletName "SirhusAltas" -Label "SirhusAltas" } catch { }
                if ([string]::IsNullOrWhiteSpace($html)) {
                    $body = @{ accion = 'consulta'; botonPulsado = ''; filtroAtributo = ''; filtroTipoBusqueda = ''; filtroValor = '' }
                    $r = Invoke-WebRequest -Uri "$script:BASE.SirhusAltas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
                    $html = $r.Content
                }
                $script:token = Extract-Token $html
                $ff = Extract-FormFields $html
                $script:sirhusFiltroAtributo = if ($ff.ContainsKey('filtroAtributo')) { $ff['filtroAtributo'] } else { '' }
                $script:sirhusFiltroTipoBusqueda = if ($ff.ContainsKey('filtroTipoBusqueda')) { $ff['filtroTipoBusqueda'] } else { '' }
                $script:sirhusFiltroValor = if ($ff.ContainsKey('filtroValor')) { $ff['filtroValor'] } else { '' }
                $users = Parse-SirhusResults $html
                Write-Log ("Usuarios pendientes tras validar: " + $users.Count) "INFO"
                if ($users.Count -eq 0) { Write-Log "No quedan usuarios pendientes" "OK"; pause; return }
            } catch { Write-Log "Error al recargar lista" "WARN" }
        }
    }
}

function Sirhus-Validar {
    param([array]$Users, [int[]]$Indices, [string]$Tipo = "parcial",
          [string]$FiltroAtributo = "", [string]$FiltroTipoBusqueda = "", [string]$FiltroValor = "")

    $selectedUsers = if ($Tipo -eq "total") { $Users } else { $Indices | ForEach-Object { $Users[$_] } }

    Write-Log "Validando $($Indices.Count) seleccionados de $($Users.Count) totales" "INFO"
    foreach ($i in $Indices) { Write-Log "  indice=$i uid=$($Users[$i].uid)" "INFO" }

    # Build POST body — same as browser validacionParcial()
    $selectedSet = @{}; foreach ($idx in $Indices) { $selectedSet[$idx] = $true }
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('accion=validacionParcial')
    $parts.Add('botonPulsado=')
    $parts.Add('posSeleccion=')
    $parts.Add(('tokenParametro=' + [System.Net.WebUtility]::UrlEncode($script:token)))
    $parts.Add('tipoActualizacion=')
    if ($FiltroAtributo) { $parts.Add(('filtroAtributo=' + [System.Net.WebUtility]::UrlEncode($FiltroAtributo))) }
    if ($FiltroTipoBusqueda) { $parts.Add(('filtroTipoBusqueda=' + [System.Net.WebUtility]::UrlEncode($FiltroTipoBusqueda))) }
    if ($FiltroValor) { $parts.Add(('filtroValor=' + [System.Net.WebUtility]::UrlEncode($FiltroValor))) }
    for ($i = 0; $i -lt $Users.Count; $i++) {
        $selVal = if ($selectedSet.ContainsKey($i)) { "SI" } else { "NO" }
        if ($selectedSet.ContainsKey($i)) { $parts.Add('checkbox=on') }
        $parts.Add(('usuarioSeleccionado=' + $selVal))
        $parts.Add(('dn=' + [System.Net.WebUtility]::UrlEncode($Users[$i].dn)))
        $parts.Add('servidorCorreo=Centralizado')
        $parts.Add('servidorWebmail=Centralizado')
    }
    $bodyString = $parts -join '&'

    # Log body for debugging
    $bodyDebug = Join-Path $script:DEBUG_DIR "SirhusAltas_body.txt"
    $bodyString | Out-File -FilePath $bodyDebug -Encoding UTF8

    try {
        $r = Invoke-WebRequest -Uri "$script:BASE.SirhusAltas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $bodyString -ContentType "application/x-www-form-urlencoded"
        $resp = $r.Content
        $debugFile = Join-Path $script:DEBUG_DIR "SirhusAltas_validar.html"
        $resp | Out-File -FilePath $debugFile -Encoding UTF8
        Write-Log "Respuesta guardada en $debugFile" "INFO"

        if ($resp -match 'actualiz.+correctamente|correcto|ok|mensaje_ok|Se han validado|validado') {
            Write-Log "Validacion completada correctamente" "OK"
        } else {
            Write-Log "Verificar resultado, revisa el HTML guardado" "WARN"
        }
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
        try {
            if ($_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $resp = $reader.ReadToEnd(); $reader.Close()
                $debugFile = Join-Path $script:DEBUG_DIR "SirhusAltas_validar.html"
                $resp | Out-File -FilePath $debugFile -Encoding UTF8
                Write-Log "Body de error guardado en $debugFile" "WARN"
            }
        } catch { }
    }
}

function Load-SirhusList {
    param([string]$ServletName, [string]$Label)
    Write-Log "Cargando $Label..." "INFO"
    $html = $null
    try { $html = Fetch-Servlet -ServletName $ServletName -Label $Label } catch { }
    if ([string]::IsNullOrWhiteSpace($html)) {
        Write-Log "GET devolvio vacio, intentando POST accion=consulta..." "WARN"
        $body = @{ accion = 'consulta'; botonPulsado = ''; filtroAtributo = ''; filtroTipoBusqueda = ''; filtroValor = '' }
        try {
            $r = Invoke-WebRequest -Uri "$script:BASE.$ServletName" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
            $html = $r.Content
            Write-Log ("Respuesta POST: " + $html.Length + " bytes") "INFO"
            $debugFile = Join-Path $script:DEBUG_DIR "${ServletName}.html"
            $html | Out-File -FilePath $debugFile -Encoding UTF8
        } catch { Write-Log ("Error en POST: " + $_.Exception.Message) "ERROR"; return $null }
    }
    return $html
}

function screen-sirhus-generic {
    param([string]$ServletName, [string]$Label)
    $html = Load-SirhusList -ServletName $ServletName -Label $Label
    if (-not $html) { pause; return }

    $script:token = Extract-Token $html

    while ($true) {
        $q = prompt "  Buscar (nombre contiene): " ""
        if (-not $q) { Write-Log "Cancelado" "WARN"; pause; return }
        $f = "nombre"; $t = "conteniendo"
        if ($q -match '^\d{7,8}$') { $f = "dni"; $t = "igual" }

        Write-Log "Buscando '$q' por $f..." "INFO"
        $body = @{
            accion = 'consulta'; botonPulsado = ''; tokenParametro = $script:token
            filtroAtributo = $f; filtroTipoBusqueda = $t; filtroValor = $q
        }
        try {
            $r = Invoke-WebRequest -Uri "$script:BASE.$ServletName" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
            $script:token = Extract-Token $r.Content
            $resultHtml = $r.Content
        } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR"; pause; return }

        $debugFile = Join-Path $script:DEBUG_DIR "${ServletName}_resultados.html"
        $resultHtml | Out-File -FilePath $debugFile -Encoding UTF8

        $users = Parse-SirhusResults $resultHtml
        Write-Log ("Usuarios encontrados: " + $users.Count) "INFO"

        if ($users.Count -eq 0) { Write-Log "Sin resultados" "WARN"; pause; return }

        $page = 0; $pageSize = 20

        while ($true) {
            ui; header
            $total = $users.Count
            $pages = [Math]::Max(1, [Math]::Ceiling($total / $pageSize))
            Write-Host (".- SIRHUS $Label ($total usuarios)" + (" " * ($script:columns - 25)) + ".") -ForegroundColor Cyan
            Write-Host "|" -NoNewline
            $hdr = "{0,3} {1,-22} {2,-28} {3,-20}" -f "#", "NOMBRE", "IDENTIFICADOR", "CENTRO DIRECTIVO"
            Write-Host $hdr.PadRight($script:columns - 3) -NoNewline; Write-Host "|" -ForegroundColor DarkGray

            $start = $page * $pageSize; $end = [Math]::Min($start + $pageSize - 1, $total - 1)
            for ($i = $start; $i -le $end; $i++) {
                $u = $users[$i]
                $n = $u.nombre
                if ($n.Length -gt 22) { $n = $n.Substring(0, 20) + ".." }
                $id = $u.uid
                if ($id.Length -gt 28) { $id = $id.Substring(0, 26) + ".." }
                $ct = $u.centro
                if ($ct.Length -gt 20) { $ct = $ct.Substring(0, 18) + ".." }
                Write-Host ("| " + "{0,2}" -f ($i+1)) -NoNewline
                Write-Host "    " -NoNewline
                Write-Host ("{0,-22}" -f $n) -ForegroundColor White -NoNewline
                Write-Host ("{0,-28}" -f $id) -ForegroundColor DarkYellow -NoNewline
                Write-Host ("{0,-20}" -f $ct) -ForegroundColor DarkGray -NoNewline
                Write-Host "|"
            }
            Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

            Write-Host ("Pagina $($page+1)/$pages") -ForegroundColor DarkGray -NoNewline
            if ($start -gt 0) { Write-Host "  [a]nterior" -ForegroundColor Cyan -NoNewline }
            if ($end -lt $total - 1) { Write-Host "  [s]iguiente" -ForegroundColor Cyan -NoNewline }
            Write-Host ""
            Write-Host ""
            Write-Host "  Opciones:" -ForegroundColor Cyan
            Write-Host "  [0] Volver" -ForegroundColor Red
            $input = prompt "  Accion: " "0"

            if ($input -eq "0" -or $input -eq "q") { return }
            elseif ($input -eq "s" -and $end -lt $total - 1) { $page++ }
            elseif ($input -eq "a" -and $page -gt 0) { $page-- }
        }
    }
}

function screen-sirhus-bajas {
    Write-Log "Cargando Sirhus - Bajas..." "INFO"
    $html = Load-SirhusList -ServletName "SirhusBajas" -Label "BAJAS"
    if (-not $html) { pause; return }
    $script:token = Extract-Token $html

    $ff = Extract-FormFields $html
    $script:sirhusFiltroAtributo = if ($ff.ContainsKey('filtroAtributo')) { $ff['filtroAtributo'] } else { '' }
    $script:sirhusFiltroTipoBusqueda = if ($ff.ContainsKey('filtroTipoBusqueda')) { $ff['filtroTipoBusqueda'] } else { '' }
    $script:sirhusFiltroValor = if ($ff.ContainsKey('filtroValor')) { $ff['filtroValor'] } else { '' }

    $users = Parse-SirhusBajasResults $html
    Write-Log ("Usuarios en Bajas: " + $users.Count) "INFO"
    if ($users.Count -eq 0) { Write-Log "Sin usuarios en Bajas" "WARN"; pause; return }

    $script:sirhusSelected = @{}
    while ($true) {
        $result = Show-SirhusBajasList -Users $users
        if ($result -eq $false) { $script:sirhusSelected = @{}; return }
        elseif ($result -is [hashtable] -and $result.Action -eq "search") {
            $script:sirhusFiltroAtributo = $result.Field
            $script:sirhusFiltroTipoBusqueda = $result.Type
            $script:sirhusFiltroValor = $result.Value
            Write-Log "Buscando '$($result.Value)' por $($result.Field)..." "INFO"
            $body = @{
                accion = 'consulta'; botonPulsado = ''; tokenParametro = $script:token
                filtroAtributo = $script:sirhusFiltroAtributo
                filtroTipoBusqueda = $script:sirhusFiltroTipoBusqueda
                filtroValor = $script:sirhusFiltroValor
            }
            try {
                $r = Invoke-WebRequest -Uri "$script:BASE.SirhusBajas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
                $script:token = Extract-Token $r.Content
                $resultHtml = $r.Content
            } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR"; pause; continue }
            $debugFile = Join-Path $script:DEBUG_DIR "SirhusBajas_resultados.html"
            $resultHtml | Out-File -FilePath $debugFile -Encoding UTF8
            $users = Parse-SirhusBajasResults $resultHtml
            Write-Log ("Resultados: " + $users.Count) "INFO"
            if ($users.Count -eq 0) { Write-Log "Sin resultados" "WARN"; pause }
            $script:sirhusSelected = @{}
        }
        elseif ($result -eq $true) {
            $indices = $script:sirhusSelected.Keys | Sort-Object
            $script:sirhusSelected = @{}
            if ($indices.Count -eq 0) { continue }
            $su = $users[$indices[0]]
            Write-Log "Cambiando contrasena para $($su.uid)..." "INFO"
            # Use the same password logic as cambiar_password_correo.ps1
            $month = Get-Date -Format "MM"
            $year = Get-Date -Format "yy"
            $pwd = "Justicia.$month$year"
            Write-Log "Nueva contrasena: $pwd" "INFO"

            $body = @{
                accion = 'cambioPassword'
                botonPulsado = ''
                posSeleccion = ''
                tokenParametro = $script:token
                tipoActualizacion = ''
                dn = $su.dn
                pwd_sirhusBajas = $pwd
                pwd2_sirhusBajas = $pwd
                usuarioWindows = 'NO'
            }
            try {
                $r = Invoke-WebRequest -Uri "$script:BASE.SirhusBajas" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
                $resp = $r.Content
                $debugFile = Join-Path $script:DEBUG_DIR "SirhusBajas_cambiarpass.html"
                $resp | Out-File -FilePath $debugFile -Encoding UTF8
                if ($resp -match 'actualiz.+correctamente|correcto|ok|mensaje_ok') {
                    Write-Log "Contrasena cambiada correctamente" "OK"
                } else {
                    Write-Log "Verificar resultado en $debugFile" "WARN"
                }
            } catch {
                Write-Log ("Error: " + $_.Exception.Message) "ERROR"
                try {
                    if ($_.Exception.Response) {
                        $stream = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $resp = $reader.ReadToEnd(); $reader.Close()
                        $debugFile = Join-Path $script:DEBUG_DIR "SirhusBajas_cambiarpass.html"
                        $resp | Out-File -FilePath $debugFile -Encoding UTF8
                    }
                } catch { }
            }
        }
    }
}

function Show-SirhusBajasList {
    param([array]$Users)
    if (-not $script:sirhusSelected) { $script:sirhusSelected = @{} }
    $pageSize = 5; $cursor = 0; $page = 0
    while ($true) {
        $total = $Users.Count
        if ($total -eq 0) { return $false }
        $pages = [int][Math]::Max(1, [Math]::Ceiling($total / $pageSize))

        if ($cursor -ge $total) { $cursor = $total - 1 }
        $page = [int][Math]::Floor($cursor / $pageSize)

        ui; header
        Write-Host (".- SIRHUS BAJAS ($total usuarios)" + (" " * ($script:columns - 24)) + ".") -ForegroundColor Cyan
        Write-Host "|" -NoNewline
        $hdr = "    {0,-28} {1,-22} {2,-18}" -f "NOMBRE", "IDENTIFICADOR", "FECHA BAJA"
        Write-Host $hdr.PadRight($script:columns - 3) -NoNewline; Write-Host "|" -ForegroundColor DarkGray

        $start = [int]($page * $pageSize); $end = [int][Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $u = $Users[$i]
            $n = $u.nombre
            if ($n.Length -gt 28) { $n = $n.Substring(0, 26) + ".." }
            $id = $u.uid
            if ($id.Length -gt 22) { $id = $id.Substring(0, 20) + ".." }
            $fb = if ($u.fechaBaja) { $u.fechaBaja } else { "" }
            if ($fb.Length -gt 18) { $fb = $fb.Substring(0, 16) + ".." }
            $sel = if ($script:sirhusSelected.ContainsKey($i)) { "*" } else { " " }
            $isCur = ($i -eq $cursor)
            if ($isCur) { Write-Host "|" -NoNewline; Write-Host "[$sel]" -NoNewline -BackgroundColor DarkCyan }
            else { Write-Host "| [$sel]" -NoNewline }
            Write-Host (" " + "{0,2}" -f ($i+1)) -NoNewline
            if ($isCur) { Write-Host (" {0,-28}" -f $n) -NoNewline -ForegroundColor White -BackgroundColor DarkCyan }
            else { Write-Host (" {0,-28}" -f $n) -NoNewline -ForegroundColor White }
            if ($isCur) { Write-Host ("{0,-22}" -f $id) -NoNewline -ForegroundColor DarkYellow -BackgroundColor DarkCyan }
            else { Write-Host ("{0,-22}" -f $id) -NoNewline -ForegroundColor DarkYellow }
            if ($isCur) { Write-Host ("{0,-18}" -f $fb) -NoNewline -ForegroundColor DarkGray -BackgroundColor DarkCyan }
            else { Write-Host ("{0,-18}" -f $fb) -NoNewline -ForegroundColor DarkGray }
            Write-Host "|"
        }
        Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

        Write-Host ("Pagina $($page+1)/$pages  ") -ForegroundColor DarkGray -NoNewline
        if ($start -gt 0) { Write-Host "[a]nterior " -ForegroundColor Cyan -NoNewline }
        if ($end -lt $total - 1) { Write-Host "[s]iguiente " -ForegroundColor Cyan -NoNewline }
        Write-Host ""
        Write-Host "  [^][v] navegar  [Espacio] toggle  [t] todos" -ForegroundColor Cyan
        Write-Host "  [c]ontrasena  [b]uscar  [0] volver" -ForegroundColor Green

        $key = [System.Console]::ReadKey($true)
        $vk = [int]$key.Key
        $ch = $key.KeyChar

        if ($vk -eq 38 -and $cursor -gt 0) { $cursor--; continue }
        if ($vk -eq 40 -and $cursor -lt $total - 1) { $cursor++; continue }
        if ($vk -eq 33) { $cursor = [Math]::Max(0, $cursor - $pageSize); continue }
        if ($vk -eq 34) { $cursor = [Math]::Min($total - 1, $cursor + $pageSize); continue }
        if ($vk -eq 36) { $cursor = 0; continue }
        if ($vk -eq 35) { $cursor = $total - 1; continue }

        if ($vk -eq 32 -or $ch -eq ' ') {
            if ($script:sirhusSelected.ContainsKey($cursor)) { $script:sirhusSelected.Remove($cursor) }
            else { $script:sirhusSelected[$cursor] = $true }
            continue
        }

        if ($ch -eq 'c' -or $ch -eq 'C') {
            if ($script:sirhusSelected.Count -eq 0) { Write-Log "Nada seleccionado" "WARN"; pause; continue }
            return $true
        }
        if ($ch -eq 'b' -or $ch -eq 'B') {
            $query = prompt "  Buscar (nombre contiene): " ""
            if (-not $query) { continue }
            return @{ Action = "search"; Value = $query; Field = "nombre"; Type = "conteniendo" }
        }
        if ($ch -eq 't' -or $ch -eq 'T') {
            if ($script:sirhusSelected.Count -eq $total) { $script:sirhusSelected.Clear() }
            else { 0..($total-1) | ForEach-Object { $script:sirhusSelected[$_] = $true } }
            continue
        }
        if ($ch -eq '0' -or $vk -eq 27) { return $false }
    }
}

function Parse-SirhusBajasResults {
    param([string]$Html)
    $users = @()

    # Match all row divs (fila_par/fila_impar) and detalle divs (fila_detalle)
    $rowDivs = [regex]::Matches($Html, '(?s)<div\s+class="fila_(?:par|impar)"[^>]*id="fila_(\d+)"[^>]*>.*?</div>')
    $detalleDivs = [regex]::Matches($Html, '(?s)<div\s+class="fila_detalle"[^>]*id="capa_password_(\d+)"[^>]*>.*?</div>')

    Write-Log ("Bajas HTML: $($rowDivs.Count) rows, $($detalleDivs.Count) detalles") "INFO"

    # Build detalle lookup by index
    $detalleMap = @{}
    foreach ($dd in $detalleDivs) {
        $detalleMap[$dd.Groups[1].Value] = $dd.Value
    }

    foreach ($row in $rowDivs) {
        $idx = $row.Groups[1].Value
        $rowHtml = $row.Value

        # Extract nombre (first span width:20%)
        $nM = [regex]::Match($rowHtml, '<span\s+class="campo"[^>]*style="width:20%"[^>]*>(.*?)</span>')
        $nombre = if ($nM.Success) { ($nM.Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }

        # Extract uid/identificador (second span width:20%)
        $spans20 = [regex]::Matches($rowHtml, '<span\s+class="campo"[^>]*style="width:20%"[^>]*>(.*?)</span>')
        $uid = if ($spans20.Count -ge 2) { ($spans20[1].Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }

        # Extract centro (span width:40%)
        $cM = [regex]::Match($rowHtml, '<span\s+class="campo"[^>]*style="width:40%[^>]*>(.*?)</span>')
        $centro = if ($cM.Success) { ($cM.Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }

        # Extract fecha_baja (first span width:10%)
        $fM = [regex]::Match($rowHtml, '<span\s+class="campo"[^>]*style="width:10%[^>]*>(.*?)</span>')
        $fechaBaja = if ($fM.Success) { ($fM.Groups[1].Value -replace '<[^>]+>', '').Trim() } else { '' }

        # Extract dn from corresponding detalle div
        $dn = ''
        if ($detalleMap.ContainsKey($idx)) {
            $dM = [regex]::Match($detalleMap[$idx], 'name="dn"\s*value="([^"]+)"')
            if ($dM.Success) { $dn = $dM.Groups[1].Value }
        }

        $users += @{ dn = $dn; uid = $uid; nombre = $nombre; centro = $centro; fechaBaja = $fechaBaja }
    }

    Write-Log ("Parse-SirhusBajasResults: $($users.Count) usuarios parseados") "INFO"
    return $users
}

function screen-sirhus-consulta-estado {
    Write-Log "Consultando estado Sirhus..." "INFO"
    try {
        $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
        $script:token = Extract-Token $r.Content
        if (-not $script:token) { throw "No se pudo extraer token" }
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"; pause; return
    }

    while ($true) {
        ui; header
        Write-Host (".- CONSULTA ESTADO SIRHUS" + (" " * ($script:columns - 25)) + ".") -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  Introduce DNI (8 digitos sin letra):" -ForegroundColor Yellow
        Write-Host "|  0 = Volver" -ForegroundColor Red
        Write-Host "|"
        $dni = prompt "  DNI: " ""
        if ($dni -eq "0" -or -not $dni) { return }

        if ($dni -notmatch '^\d{7,8}$') {
            Write-Log "DNI invalido (deben ser 7-8 digitos)" "WARN"; pause; continue
        }

        Write-Log "Consultando estado para DNI $dni..." "INFO"
        try {
            $body = @{
                accion = 'consultaEstado'; botonPulsado = 'pantalla2'; datoAuxiliar = ''
                tokenParametro = $script:token
                dni = $dni
                marcarSirhus = 'SI'; marcarInternos = 'NO'; marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
                numUsuariosAntiguo = '25'; numUsuarios = '25'
                seleccionarSirhus = 'on'
            }
            $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
            $html = $r2.Content
        } catch {
            Write-Log ("Error: " + $_.Exception.Message) "ERROR"; pause; continue
        }

        $debugFile = Join-Path $script:DEBUG_DIR "ConsultaEstadoSirhus.html"
        $html | Out-File -FilePath $debugFile -Encoding UTF8

        # Extract fields from form_field_label / form_field_value divs
        $data = @{}
        $pairs = [regex]::Matches($html, '(?s)<div\s+class="form_field_label">(.*?)</div>\s*<div\s+class="form_field_value">(.*?)</div>')
        foreach ($m in $pairs) {
            $label = $m.Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '\s+', ' ' -replace '^\s+|\s+$', '' -replace ':$', ''
            $value = $m.Groups[2].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '\s+', ' ' -replace '^\s+|\s+$', ''
            if ($label -match 'Nombre') { $data['NOMBRE'] = $value }
            elseif ($label -match 'D\.?N\.?I') { $data['DNI'] = $value }
            elseif ($label -match '^Estado') { $data['ESTADO'] = $value }
            elseif ($label -match 'Correo') { $data['CORREO'] = $value }
            elseif ($label -match 'Situaci') { $data['SITUACION'] = $value }
        }

        ui; header
        Write-Host (".- CONSULTA SIRHUS (DNI $dni)" + (" " * ($script:columns - 24)) + ".") -ForegroundColor Cyan
        Write-Host "|"
        if ($data.Count -gt 0) {
            $order = @("NOMBRE", "DNI", "ESTADO", "CORREO", "SITUACION")
            foreach ($k in $order) {
                if ($data.ContainsKey($k)) {
                    Write-Host ("|  $k : ") -NoNewline -ForegroundColor Cyan
                    Write-Host $data[$k] -ForegroundColor White
                }
            }
        } else {
            Write-Host "|  (sin datos estructurados)" -ForegroundColor DarkGray
            Write-Host "|  HTML: $debugFile" -ForegroundColor DarkGray
        }
        Write-Host "|"
        Write-Host "  [Enter] otra consulta  [0] volver" -ForegroundColor Cyan
        $k = prompt "  > " "0"
        if ($k -eq "0") { return }
    }
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
# CREAR USUARIO
# ============================================================

function screen-crear-usuario {
    $tipoOpt = ""
    while ($tipoOpt -eq "" -or $tipoOpt -notmatch '^[0-3]$') {
        ui; header
        panel "CREAR USUARIO" {
            Write-Host "|  Selecciona el tipo de usuario:" -ForegroundColor White
            Write-Host "|"
            Write-Host "|  1. Interno (ius)" -ForegroundColor Cyan
            Write-Host "|  2. Generico (jus)" -ForegroundColor Cyan
            Write-Host "|  3. Externo" -ForegroundColor Cyan
            Write-Host "|"
            Write-Host ("|  Rama actual: $script:ramaLdap") -ForegroundColor Green
            Write-Host "|"
        }
        footer @("1-3 tipo", "0 cancelar")
        $tipoOpt = prompt "Tipo: " "0"
        if ($tipoOpt -eq "" -or $tipoOpt -eq "0") { Write-Log "Cancelado" "WARN"; return }
    }

    $tipoMap = @{ "1" = "interno"; "2" = "generico"; "3" = "externo" }
    $branchMap = @{ "1" = "ius"; "2" = "jus"; "3" = "jus" }
    $empleadoTipo = $tipoMap[$tipoOpt]
    $targetBranch = $branchMap[$tipoOpt]
    $esInt = ($empleadoTipo -eq "interno")

    if ($script:ramaLdap -ne $targetBranch) {
        Write-Log "Cambiando a rama $targetBranch..." "INFO"
        Connect-Directorio -Branch $targetBranch
        if (-not $script:authenticated) { Write-Log "Error al cambiar de rama" "ERROR"; pause; return }
    }

    ui; header
    panel "CREAR USUARIO - Datos basicos" {
        Write-Host ("|  Tipo: $empleadoTipo  |  Rama: $targetBranch") -ForegroundColor Yellow
        Write-Host "|"
    }

    $nombre = prompt "Nombre: "
    if (-not $nombre) { Write-Log "Nombre requerido" "WARN"; pause; return }

    if ($esInt) {
        $apellido1 = prompt "Primer apellido: "
        $apellido2 = prompt "Segundo apellido: "
        $dni = prompt "DNI: "
    } else {
        $apellido1 = prompt "Primer apellido (opcional): "
        if (-not $apellido1) { $apellido1 = "" }
        $apellido2 = prompt "Segundo apellido (opcional): "
        if (-not $apellido2) { $apellido2 = "" }
        $dni = prompt "DNI (opcional): "
        if (-not $dni) { $dni = "" }
    }

    $autoUid = ""
    if ($esInt -and $apellido1) {
        $autoUid = ($nombre -replace '\s', '').ToLower() + "." + ($apellido1 -replace '\s', '').ToLower()
    }

    ui; header
    panel "CREAR USUARIO - Identificador" {
        if ($autoUid) { Write-Host ("|  UID sugerido: $autoUid") -ForegroundColor DarkGray }
        Write-Host "|"
    }

    if ($esInt) {
        $sug = $autoUid
        $uidIn = prompt "UID [$sug]: " $sug
        $uid = if ($uidIn) { $uidIn } else { $sug }
    } else {
        $uid = prompt "UID: "
        if (-not $uid) { Write-Log "UID requerido" "WARN"; pause; return }
    }

    $month = Get-Date -Format "MM"; $year = Get-Date -Format "yy"
    $defaultPass = "Justicia.$month$year"
    $pass = prompt "Password [$defaultPass]: " $defaultPass

    $cuota = if ($esInt) { "1024" } else { "250" }
    $uidManager = ""; $centroDirectivo = ""; $centroDestino = ""

    if ($empleadoTipo -eq "generico") {
        ui; header
        panel "CREAR USUARIO - Opciones generico" {
            Write-Host ("|  UID: $uid") -ForegroundColor Yellow
            Write-Host "|"
        }
        $uidManager = prompt "Gestor (email): "
        $centroDirectivo = prompt "Centro directivo [A0]: " "A0"
        if (-not $centroDirectivo) { $centroDirectivo = "A0" }
        $centroDestino = prompt "Centro destino [A0]: " "A0"
        if (-not $centroDestino) { $centroDestino = "A0" }
        $cuotaIn = prompt "Cuota (MB) [$cuota]: " $cuota
        if ($cuotaIn) { $cuota = $cuotaIn }
    } else {
        $cuotaIn = prompt "Cuota (MB) [$cuota]: " $cuota
        if ($cuotaIn) { $cuota = $cuotaIn }
    }

    ui; header
    panel "CREAR USUARIO - RESUMEN" {
        Write-Host ("|  Tipo:     $empleadoTipo") -ForegroundColor Yellow
        Write-Host ("|  Nombre:   $nombre") -ForegroundColor Green
        Write-Host ("|  Apellidos: $apellido1 $apellido2") -ForegroundColor Green
        Write-Host ("|  DNI:      $dni") -ForegroundColor Green
        Write-Host ("|  UID:      $uid") -ForegroundColor Green
        Write-Host ("|  Rama:     $targetBranch") -ForegroundColor Green
        Write-Host ("|  Password: $pass") -ForegroundColor Green
        Write-Host ("|  Cuota:    $cuota MB") -ForegroundColor Green
        if ($uidManager) { Write-Host ("|  Gestor:   $uidManager") -ForegroundColor Green }
        if ($centroDirectivo) { Write-Host ("|  Centro:   $centroDirectivo / $centroDestino") -ForegroundColor Green }
        Write-Host "|"
    }
    footer @("s para crear", "Enter para cancelar")
    $confirm = prompt "s/N: " "n"
    if ($confirm -ne 's') { Write-Log "Cancelado" "WARN"; return }

    try {
        Write-Log "Paso 1/3: Inicializando formulario..." "INFO"
        $initBody = @{
            accion = 'nuevo'; botonPulsado = 'pantalla1'
            tokenParametro = $script:token
            filtroAtributo = 'identificador'; filtroTipoBusqueda = 'empezando'; filtroValor = ''
            marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
            marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
            marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
            numUsuariosAntiguo = '25'; numUsuarios = '25'
        }
        $r1 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $initBody
        $script:token = Extract-Token $r1.Content
        if (-not $script:token) { throw "No se pudo extraer token tras pantalla1" }

        Write-Log "Paso 2/3: Enviando datos basicos..." "INFO"
        $basicBody = @{
            accion = 'nuevo'; botonPulsado = 'pantalla2'
            tokenParametro = $script:token
            empleadoNombre_sa = $nombre; empleadoApellido1_sa = $apellido1; empleadoApellido2_sa = $apellido2
            empleadoUidType = 'conCorreo'; empleadoTipo = $empleadoTipo
            empleadoNombre = $nombre; empleadoApellido1 = $apellido1; empleadoApellido2 = $apellido2
            empleadoDni = $dni
        }
        $r2 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $basicBody
        $p2Html = $r2.Content
        $script:token = Extract-Token $p2Html
        if (-not $script:token) { throw "No se pudo extraer token tras pantalla2" }

        $debugStep2 = Join-Path $script:DEBUG_DIR "crear_p2_$uid.html"
        $p2Html | Out-File -FilePath $debugStep2 -Encoding UTF8
        Write-Log ("Pantalla2: " + $p2Html.Length + " bytes") "INFO"

        Write-Log "Paso 3/3: Extrayendo campos y enviando..." "INFO"
        $formFields = Extract-FormFields $p2Html
        $allInputs = [regex]::Matches($p2Html, '\bname\s*=\s*["'']([^"'']*?)["''][^>]*?\bvalue\s*=\s*["'']([^"'']*?)["'']')
        foreach ($m in $allInputs) {
            $n = $m.Groups[1].Value; $v = $m.Groups[2].Value
            if (-not $formFields.ContainsKey($n)) { $formFields[$n] = $v }
        }

        $body = @{}
        foreach ($kv in $formFields.GetEnumerator()) { $body[$kv.Key] = $kv.Value }
        $body['tokenParametro'] = $script:token
        $body['botonPulsado'] = 'pantalla3'
        $body['accion'] = 'nuevo'

        $body['empleadoNombre'] = $nombre
        $body['empleadoNombre2'] = $nombre
        $body['empleadoApellido1'] = $apellido1
        $body['empleadoApellido2'] = $apellido2
        $body['empleadoDni'] = $dni
        $body['empleadoTipo'] = $empleadoTipo
        $body['empleadoUidType'] = 'conCorreo'
        $body['dominioCorreoSeleccionado'] = 'juntadeandalucia.es'
        $body['pwd_nuevo'] = $pass
        $body['pwd2_nuevo'] = $pass
        $body['empleadoServidorCorreo'] = 'Centralizado'
        $body['empleadoServidorWebmail'] = 'Centralizado'
        $body['empleadoCuota'] = $cuota
        $body['FJCuota'] = '10240'
        $body['provincia'] = '99'
        $body['JAreserva'] = 'SI'
        $body['caducidadNO'] = 'NO'

        if ($esInt) {
            $body['identificador_radio'] = 'select'
            $body['identificador_select'] = $uid
            $body['empleadoExtension_select'] = '.ius'
            $body['empleadoExtension'] = ''
            $body['JAcloudTipoUsuario'] = 'NA'
        } else {
            $body['identificador_text'] = $uid
            $body['empleadoExtension'] = '.jus'
            $body['JAcloud'] = 'NO'
            $body['consigna'] = '0'
            if ($uidManager) { $body['uidManager'] = $uidManager }
            if ($centroDirectivo) { $body['centroDirectivo'] = $centroDirectivo }
            if ($centroDestino) { $body['centroDestino'] = $centroDestino }
            $body['puestoTrabajoNuevo'] = ''
        }

        Write-Log ("Enviando creacion (" + $body.Count + " campos)...") "INFO"
        $r3 = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body

        $resultHtml = $r3.Content
        $debugFile = Join-Path $script:DEBUG_DIR "crear_result_$uid.html"
        $resultHtml | Out-File -FilePath $debugFile -Encoding UTF8

        if ($resultHtml -match 'correctamente|actualiz.+correcta|Usuario.*creado|Alta.*correcta|mensaje_ok') {
            Write-Log "Usuario $uid creado correctamente" "OK"
            try { Get-UserProfile -UID $uid; screen-profile } catch { pause }
        } else {
            Write-Log "Posible error. HTML guardado en $debugFile" "WARN"
            pause
        }
    } catch {
        $debugFile = Join-Path $script:DEBUG_DIR "crear_error_$uid.html"
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
            "2" { screen-crear-usuario }
            "3" { if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-password }
            "4" { screen-listas }
            "5" { screen-sirhus }
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
