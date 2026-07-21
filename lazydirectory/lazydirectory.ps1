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
    [regex]::Matches($Html, '<input[^>]*name="([^"]*)"[^>]*value="([^"]*)"[^>]*>') | ForEach-Object { $fields[$_.Groups[1].Value] = $_.Groups[2].Value }
    [regex]::Matches($Html, '<select[^>]*name="([^"]*)"[^>]*>(.*?)</select>') | ForEach-Object {
        $n = $_.Groups[1].Value; $s = [regex]::Match($_.Groups[2].Value, '<option[^>]*value="([^"]*)"[^>]*selected[^>]*>')
        if ($s.Success) { $fields[$n] = $s.Groups[1].Value }
    }
    [regex]::Matches($Html, '<textarea[^>]*name="([^"]*)"[^>]*>(.*?)</textarea>') | ForEach-Object {
        $fields[$_.Groups[1].Value] = $_.Groups[2].Value -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]+>', ''
    }
    return $fields
}

function Extract-DisplayData {
    param([string]$Html)
    $data = @{}
    $labelMap = @{
        'Nombre:' = 'cn'; 'Identificador:' = 'uid'; 'Correo electr.nico:' = 'mail'
        'Descripci.n:' = 'description'; 'Apellido1:' = 'sn'; 'Apellido2:' = 'empleadoApellido2_sa'
        'Tel.fono:' = 'telephoneNumber'; 'M.vil:' = 'mobile'; 'Fax:' = 'facsimileTelephoneNumber'
        'Direcci.n:' = 'postalAddress'; 'C.P.:' = 'postalCode'; 'Ciudad:' = 'l'
        'Provincia:' = 'st'; 'Cargo:' = 'title'; 'Depto:' = 'departmentNumber'
        'Organismo:' = 'o'; 'C.entro Gestor:' = 'centroGestor'; 'C.entro Destino:' = 'centroDestino'
        'Edificio:' = 'edificio'; 'Servicio:' = 'servicio'; 'Puesto:' = 'puestoTrabajo'
        'UID Number:' = 'uidNumber'; 'GID Number:' = 'gidNumber'
        'Home Directory:' = 'homeDirectory'; 'Login Shell:' = 'loginShell'
        'Tipo de usuario:' = 'tipoUsuario'; '.ltimo cambio de contrase.a:' = 'ultimoCambioPassword'
    }
    foreach ($label in $labelMap.Keys) {
        $pattern = [regex]::Escape($label) + '\s*(.*?)(?=<br|<BR|</td|</div|<input|<select|<textarea|$)'
        $m = [regex]::Match($Html, $pattern)
        if ($m.Success) {
            $val = $m.Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '\s+', ' '
            $val = $val.Trim()
            if ($val) { $data[$labelMap[$label]] = $val }
        }
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

    Write-Log "Cargando perfil de $UID..." "INFO"

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession
    $script:token = Extract-Token $r.Content
    if (-not $script:token) { throw "No se pudo extraer token" }

    $body = @{
        accion = 'consulta'; botonPulsado = ''; datoAuxiliar = ''
        tokenParametro = $script:token
        filtroAtributo = 'identificador'
        filtroTipoBusqueda = 'exacto'
        filtroValor = $UID
        marcarSirhus = $(if ($esInt) { 'NO' } else { 'SI' })
        marcarInternos = $(if ($esInt) { 'SI' } else { 'NO' })
        marcarExternos = 'NO'; marcarGenericos = 'NO'; marcarNA = 'NO'
        numUsuariosAntiguo = '25'; numUsuarios = '25'
    }
    if ($esInt) { $body['seleccionarInternos'] = 'on' }
    else { $body['seleccionarSirhus'] = 'on' }

    $r = Invoke-WebRequest -Uri "$script:BASE.UsuariosMain" -UseBasicParsing -WebSession $script:webSession -Method POST -Body $body
    $script:token = Extract-Token $r.Content

    $html = $r.Content
    $debugFile = Join-Path $script:DEBUG_DIR ("profile_" + $UID.Replace('.','_') + ".html")
    $html | Out-File -FilePath $debugFile -Encoding UTF8
    Write-Log ("HTML guardado en " + $debugFile) "INFO"

    $fields = Extract-FormFields $html

    # _modificacion suffix (Directorio modify form naming convention)
    $allInputs = [regex]::Matches($html, 'name="([^"]*)"\s*value="([^"]*)"')
    foreach ($m in $allInputs) {
        $n = $m.Groups[1].Value; $v = $m.Groups[2].Value
        if (-not $fields.ContainsKey($n)) { $fields[$n] = $v }
        if ($n -match '^(.+)_modificacion$') {
            $base = $Matches[1]
            if (-not $fields.ContainsKey($base)) { $fields[$base] = $v }
        }
    }

    # Display data as fallback
    $display = Extract-DisplayData $html
    foreach ($kv in $display.GetEnumerator()) {
        if (-not $fields.ContainsKey($kv.Key) -or [string]::IsNullOrEmpty($fields[$kv.Key])) {
            $fields[$kv.Key] = $kv.Value
        }
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
        Write-Host "|  1. Conectar a Directorio" -ForegroundColor Cyan
        Write-Host "|  2. Buscar usuario" -ForegroundColor Cyan
        Write-Host "|  3. Ver perfil" -ForegroundColor Cyan
        Write-Host "|  4. Cambiar contrasena" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Salir" -ForegroundColor Red
        Write-Host "|"
        if (-not $script:authenticated) {
            Write-Host "|  >> Conecta primero (opcion 1)" -ForegroundColor Yellow
        } else {
            Write-Host ("|  >> Rama: $script:ramaLdap") -ForegroundColor Green
            if ($script:lastProfileFields -and $script:lastProfileFields['uid']) {
                Write-Host ("|     Usuario: $($script:lastProfileFields['uid'])") -ForegroundColor DarkGray
            }
        }
        Write-Host "|"
    }
    footer @("1-4 opciones", "0/q salir", "s <uid> busqueda rapida")
    Write-Host ""
    Write-Host "Opcion: " -ForegroundColor Yellow -NoNewline
    return Read-Host
}

function screen-connect {
    ui
    header
    panel "CONEXION AL DIRECTORIO" {
        Write-Host "|"
        Write-Host "|  Conectando como administrador..." -ForegroundColor White
        Write-Host "|"
        Write-Host "|  La rama LDAP se detectara automaticamente" -ForegroundColor Cyan
        Write-Host "|  al buscar un usuario:" -ForegroundColor Cyan
        Write-Host "|  - usuario.ius   -> Internos (ius)" -ForegroundColor Cyan
        Write-Host "|  - usuario       -> Sirhus (jus)" -ForegroundColor Cyan
        Write-Host "|"
    }
    footer @("Enter conectar", "0 volver")
    Write-Host ""

    try {
        Connect-Directorio -Branch "jus"
        Write-Log "Conectado (rama por defecto: jus)" "OK"
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
    pause
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
        "1" = "identificador"; "2" = "dni"; "3" = "mail"
        "4" = "cn"; "5" = "tipoUsuario"; "6" = "edificio"; "7" = "servicio"
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
    $typeMap = @{"1" = "empezando"; "2" = "exacto"; "3" = "terminando"; "4" = "conteniendo"}
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

    if ($users.Count -eq 1 -and $users[0].fields) {
        $script:lastProfileFields = $users[0].fields
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
    Write-Host (".- PERFIL LDAP: $displayId" + (" " * ($script:columns - 20 - $displayId.Length)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host "|  DATOS PERSONALES" -ForegroundColor Cyan
    row "UID"         $(if ($f['uid']) { $f['uid'] } else { $f['identificador'] }) "Green"
    row "DN"          $f['dn']
    row "Nombre"      $f['cn']
    row "Apellido1"   $f['sn']
    row "Apellido2"   $f['empleadoApellido2_sa']
    row "Email"       $f['mail'] "DarkYellow"
    row "Descripcion" $f['description']
    Write-Host "|"
    Write-Host "|  CONTACTO" -ForegroundColor Cyan
    row "Telefono"    $f['telephoneNumber']
    row "Movil"       $f['mobile']
    row "Fax"         $f['facsimileTelephoneNumber']
    row "Direccion"   $f['postalAddress']
    row "CP"          $f['postalCode']
    row "Ciudad"      $f['l']
    row "Provincia"   $f['st']
    Write-Host "|"
    Write-Host "|  PUESTO" -ForegroundColor Cyan
    row "Cargo"       $f['title']
    row "Depto"       $f['departmentNumber']
    row "Organismo"   $f['o']
    row "Centro Gestor" $f['centroGestor']
    row "Centro Destino" $f['centroDestino']
    row "Edificio"    $f['edificio']
    row "Servicio"    $f['servicio']
    row "Puesto"      $f['puestoTrabajo']
    Write-Host "|"
    Write-Host "|  CUENTA" -ForegroundColor Cyan
    row "UID Number"  $f['uidNumber']
    row "GID Number"  $f['gidNumber']
    row "Home Dir"    $f['homeDirectory']
    row "Login Shell" $f['loginShell']
    row "Tipo User"   $(if ($f['tipoUsuario']) { $f['tipoUsuario'] } else { $f['employeeType'] })
    row "Ultimo Pass" $f['ultimoCambioPassword']
    row "Cuota Buzon" $f['cuotaBuzonMax']
    row "Cuota FJ"    $f['cuotaFJMax']
    if ($f['buzonExternosDeshabilitado']) { row "Buzon Ext" $f['buzonExternosDeshabilitado'] }
    Write-Host "|"
    Write-Host "|  OPCIONES" -ForegroundColor Cyan
    Write-Host "|  1. Cambiar contrasena" -ForegroundColor Cyan
    Write-Host "|  2. Ver campos raw (todos)" -ForegroundColor Cyan
    Write-Host "|  0. Volver al menu" -ForegroundColor Red
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

    Write-Host ""
    $opt = prompt "Opcion: " "0"
    if ($opt -eq "1") { screen-password }
    elseif ($opt -eq "2") { screen-raw-fields }
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
    $running = $true
    while ($running) {
        $opt = screen-main
        if (-not $script:authenticated -and $opt -ne "1" -and $opt -ne "0" -and $opt -ne "q") {
            Write-Log "Conectando automaticamente..." "INFO"
            try { Connect-Directorio -Branch "jus" } catch {
                Write-Log ("Error de conexion: " + $_.Exception.Message) "ERROR"
                pause; continue
            }
        }
        switch -Wildcard ($opt) {
            "1" { screen-connect }
            "2" { screen-search }
            "3" { if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-profile }
            "4" { if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-password }
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
