param([switch]$WhatIf)

# ============================================================
# LAZYTEMIS - Terminal Temis
# ============================================================

$script:VERSION = "2.0"
$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "lazytemis.log"
$script:DEBUG_DIR = Join-Path $script:SCRIPT_DIR "debug"
$null = New-Item -ItemType Directory -Path $script:DEBUG_DIR -Force
$script:ESC_URL = "https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio"
$script:TEMIS_URL = "http://temis.justicia.junta-andalucia.es/Temis"
$script:webSession = $null
$script:cert = $null
$script:lastResultData = @()
$script:lastProfileFields = $null
$script:authenticated = $false
$script:columns = 80

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
    Write-Host ("|  LAZYTEMIS v$script:VERSION") -ForegroundColor Yellow -NoNewline
    $rest = $w - 24 - $conn.Length
    if ($rest -gt 0) { Write-Host (" " * $rest) -NoNewline } else { Write-Host "" -NoNewline }
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host ("|  " + (" " * 18)) -NoNewline
    Write-Host $conn -ForegroundColor $cc -NoNewline
    Write-Host (" " * ($w - 24 - $conn.Length)) -NoNewline; Write-Host "|" -ForegroundColor DarkGray
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
    Write-Host ("|  " + $Label.PadRight(16) + ": ") -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

# ============================================================
# AUTH
# ============================================================

function Get-Certificate {
    $certs = Get-ChildItem Cert:\CurrentUser\My | Where-Object {
        $_.Subject -match '\d{8}[A-Z]' -and $_.NotAfter -gt (Get-Date)
    } | Sort-Object NotAfter -Descending
    $cert = $certs | Select-Object -First 1
    if (-not $cert) {
        $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.NotAfter -gt (Get-Date) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    }
    if (-not $cert) { $cert = Get-ChildItem Cert:\CurrentUser\My | Select-Object -First 1 }
    if (-not $cert) { throw "No se encontro ningun certificado digital en el almacen" }
    return $cert
}

function Test-Url {
    param([string]$Url)
    try { $req = [System.Net.WebRequest]::Create($Url); $req.Method = "HEAD"; $req.Timeout = 5000; $req.GetResponse().Dispose(); return $true }
    catch { return $false }
}

function Connect-Temis {
    if (-not (Test-Url "$script:ESC_URL/Inicio.do")) { throw "No se puede acceder a Escritorio Judicial. Verifica VPN." }
    $script:cert = Get-Certificate
    Write-Log "Autenticando con certificado..." "INFO"
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/Inicio.do" -UseBasicParsing -SessionVariable script:webSession -Certificate $script:cert
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/AccesoCertificado.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/CallAuthenticationServlet" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST
    $r = Invoke-WebRequest -Uri "$script:ESC_URL/Lanzadera.do?id=2" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -MaximumRedirection 10
    $script:authenticated = $true
    Write-Log ("Temis: " + $r.BaseResponse.ResponseUri.AbsoluteUri) "OK"
}

# ============================================================
# SEARCH
# ============================================================

function Search-User {
    param([string]$Query = "", [string]$SearchField = "usuario", [string]$Cargo = "")

    $null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert

    $body = @{
        usuario = ''; accion = 'buscar_dos'; nombre = ''; apellidos = ''
        dni = ''; codigoDocumento = ''; cargo = $Cargo; codigoUsuario = ''
        codigosUsuarios = ''; codigoMunicipio = ''; mayor = ''; noResultados = ''
        partidoJudicial = ''; organismo = ''; busquedaAbierta = 'false'
        busquedaSegundaAbierta = 'true'; codigoPartidoJudicial = ''
        codigoMunicipioPart = ''; codigoOrganismo = ''; otro = ''; mostrar = ''
        organismoHijo = ''; listadoOrganismoHijo = ''; codigoOrganismoPadre = ''
        activos = ''; formulario = ''; valorEstado = ''; ocultoDni = ''
        ocultoOtro = ''; codigoEstado = ''; codigoProvincia = ''; provincia = ''
        codigoInformePartidoJudicial = ''; informePartidoJudicial = ''
        codigoInformeMunicipio = ''; informeMunicipio = ''
        codigoInformeTipoOrganismo = ''; informeTipoOrganismo = ''
        codigoInformeOrganismo = ''; informeOrganismo = ''
    }

    switch ($SearchField) {
        "usuario"   { $body['usuario'] = $Query; if ($Query -match '^\d{8}[A-Z]$') { $body['dni'] = $Query; $body['codigoDocumento'] = 'D' } }
        "dni"       { $body['dni'] = $Query; $body['codigoDocumento'] = 'D'; $body['usuario'] = $Query.Substring(0, [Math]::Min(8, $Query.Length)) }
        "nombre"    { $body['nombre'] = $Query }
        "apellidos" { $body['apellidos'] = $Query }
    }

    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $body
    $html = $result.Content

    # Extraer todos los usuarios de la tabla de resultados
    $users = @()
    $rowPattern = '(?s)<tr[^>]*class="texto[12]"[^>]*>(.*?)</tr>'
    $rowMatches = [regex]::Matches($html, $rowPattern)
    if ($rowMatches.Count -gt 0) {
        foreach ($rm in $rowMatches) {
            $rowHtml = $rm.Groups[1].Value
            $codMatch = [regex]::Match($rowHtml, 'name="codigoUsuario"\s*value="(\d+)"')
            if (-not $codMatch.Success) { continue }
            $cells = [regex]::Matches($rowHtml, '<td[^>]*>(.*?)</td>')
            $cellVals = @()
            foreach ($c in $cells) {
                $v = $c.Groups[1].Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '\s+', ' '; $cellVals += $v.Trim()
            }
            $users += @{
                codigo   = $codMatch.Groups[1].Value
                nombre   = if ($cellVals.Count -gt 0) { $cellVals[0] } else { '' }
                ape1     = if ($cellVals.Count -gt 1) { $cellVals[1] } else { '' }
                ape2     = if ($cellVals.Count -gt 2) { $cellVals[2] } else { '' }
                dni      = if ($cellVals.Count -gt 4) { $cellVals[4] } else { '' }
                cargo    = if ($cellVals.Count -gt 5) { $cellVals[5] } else { '' }
                org      = if ($cellVals.Count -gt 6) { $cellVals[6] } else { '' }
            }
        }
    }

    # Si no hay tabla, puede ser resultado unico con formulario
    if ($users.Count -eq 0) {
        $codMatch = [regex]::Match($html, 'name="codigoUsuario"\s*value="(\d+)"')
        if ($codMatch.Success) {
            $fields = Extract-ProfileFields -Html $html
            if ($fields.Count -gt 0) {
                $users += @{
                    codigo   = $codMatch.Groups[1].Value
                    nombre   = $fields['nombre']
                    ape1     = $fields['apellido1']
                    ape2     = $fields['apellido2']
                    dni      = $fields['dni']
                    cargo    = $fields['cargo']
                    org      = $fields['organismo']
                }
                $script:lastProfileFields = $fields
            }
        }
    }

    $script:lastResultData = $users
    return $users
}

function Get-UserProfile {
    param([string]$CodigoUsuario)
    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        codigoUsuario = $CodigoUsuario; accion = 'modificarDos'
    }
    $fields = Extract-ProfileFields -Html $result.Content
    $script:lastProfileFields = $fields
    return $fields
}

function Extract-ProfileFields {
    param([string]$Html)
    $fields = @{}
    [regex]::Matches($Html, '<input[^>]*name="([^"]*)"[^>]*value="([^"]*)"[^>]*>') | ForEach-Object { $fields[$_.Groups[1].Value] = [System.Web.HttpUtility]::HtmlDecode($_.Groups[2].Value) }
    [regex]::Matches($Html, '<textarea[^>]*name="([^"]*)"[^>]*>(.*?)</textarea>') | ForEach-Object { $fields[$_.Groups[1].Value] = $_.Groups[2].Value -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]+>', '' }
    [regex]::Matches($Html, '<select[^>]*name="([^"]*)"[^>]*>(.*?)</select>') | ForEach-Object {
        $n = $_.Groups[1].Value; $s = [regex]::Match($_.Groups[2].Value, '<option[^>]*value="([^"]*)"[^>]*selected[^>]*>')
        if ($s.Success) { $fields[$n] = $s.Groups[1].Value }
    }
    return $fields
}

function List-By-Organismo {
    param([string]$Organismo = "", [string]$PartidoJudicial = "")
    $null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert
    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        accion = 'buscar_dos'; busquedaSegundaAbierta = 'true'; mostrar = 'SI'
        codigoPartidoJudicial = $PartidoJudicial; codigoOrganismo = $Organismo
        codigoMunicipioPart = ''; codigoUsuario = ''; codigosUsuarios = ''
        usuario = ''; nombre = ''; apellidos = ''; codigoMunicipio = ''
        mayor = ''; noResultados = ''; partidoJudicial = ''; organismo = ''
        cargo = ''; busquedaAbierta = 'false'; codigoDocumento = ''; dni = ''
        otro = ''; organismoHijo = ''; listadoOrganismoHijo = ''; codigoOrganismoPadre = ''
        activos = ''; formulario = ''; valorEstado = ''; ocultoDni = ''
        ocultoOtro = ''; codigoEstado = ''; codigoCargo = ''; codigoProvincia = ''
        provincia = ''; codigoInformePartidoJudicial = ''; informePartidoJudicial = ''
        codigoInformeMunicipio = ''; informeMunicipio = ''
        codigoInformeTipoOrganismo = ''; informeTipoOrganismo = ''
        codigoInformeOrganismo = ''; informeOrganismo = ''
    }
    return Search-User -Query "" -SearchField "usuario"
}

# ============================================================
# PASSWORD
# ============================================================

function Set-UserPassword {
    param([string]$CodigoUsuario, [string]$NewPassword, [switch]$WhatIf)
    $modResult = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        codigoUsuario = $CodigoUsuario; accion = 'modificarDos'
    }
    $formFields = Extract-ProfileFields -Html $modResult.Content
    if ($formFields.Count -eq 0) { throw "No se pudieron extraer los campos del formulario" }
    if ($WhatIf) { Write-Log "WHATIF - Se anularia la contrasena en Temis y se estableceria: $NewPassword" "INFO"; return }
    $formFields['accion'] = 'anular'; $formFields['usuario'] = $formFields['dni']
    $formFields['cambiarIdPassword'] = '3'
    $formFields['pwd_modificacion'] = $NewPassword; $formFields['pwd2_modificacion'] = $NewPassword
    $null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioGuardarModificar.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $formFields
    Write-Log "Contrasena anulada en Temis" "OK"
    $dni = $formFields['usuario'] -replace '[A-Z]$', ''
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/RealizarModificarPassword.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        usuario = $dni; password = ''; nuevaPassword = $NewPassword; nuevaPassword2 = $NewPassword; aceptar2 = 'Aceptar'
    }
    Write-Log "Contrasena establecida en Escritorio Judicial" "OK"
}

# ============================================================
# SCREENS
# ============================================================

function screen-main {
    ui
    header
    panel "MENU PRINCIPAL" {
        Write-Host "|"
        Write-Host "|  1. Conectar a Temis" -ForegroundColor Cyan
        Write-Host "|  2. Buscar usuario" -ForegroundColor Cyan
        Write-Host "|  3. Ver perfil" -ForegroundColor Cyan
        Write-Host "|  4. Cambiar contrasena" -ForegroundColor Cyan
        Write-Host "|  5. Listar por organismo" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Salir" -ForegroundColor Red
        Write-Host "|"
        if (-not $script:authenticated) {
            Write-Host "|  >> Conecta primero (opcion 1)" -ForegroundColor Yellow
        } elseif ($script:lastProfileFields) {
            Write-Host ("|  >> Usuario: $($script:lastProfileFields['usuario']) ($($script:lastProfileFields['dni']))") -ForegroundColor Green
            Write-Host ("|     $($script:lastProfileFields['nombre']) $($script:lastProfileFields['apellido1']) $($script:lastProfileFields['apellido2'])") -ForegroundColor DarkGray
        }
        Write-Host "|"
    }
    footer @("1-5 opciones", "0/q salir", "s <dni> busqueda rapida")
    Write-Host ""
    Write-Host "Opcion: " -ForegroundColor Yellow -NoNewline
    return Read-Host
}

function screen-search {
    ui
    header
    panel "BUSQUEDA DE USUARIOS" {
        Write-Host "|"
        Write-Host "|  1. Por usuario / DNI" -ForegroundColor Cyan
        Write-Host "|  2. Por nombre" -ForegroundColor Cyan
        Write-Host "|  3. Por apellidos" -ForegroundColor Cyan
        Write-Host "|  4. Por cargo" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Volver" -ForegroundColor Red
        Write-Host "|"
    }
    footer @("1-4 criterio", "0 volver")
    Write-Host ""
    $opt = prompt "Criterio: "

    if ($opt -eq "0") { return $null }

    $searchField = "usuario"; $query = ""; $cargo = ""
    switch ($opt) {
        "1" { $searchField = "usuario"; $query = prompt "DNI o usuario: " }
        "2" { $searchField = "nombre"; $query = prompt "Nombre: " }
        "3" { $searchField = "apellidos"; $query = prompt "Apellidos: " }
        "4" { $cargo = prompt "Cargo (ej. Auxilio Judicial): " }
        default { return $null }
    }
    if (-not $query -and -not $cargo) { return $null }

    Write-Log "Buscando..." "INFO"
    $users = Search-User -Query $query -SearchField $searchField -Cargo $cargo

    if ($users.Count -eq 0) {
        Write-Log "No se encontraron usuarios" "WARN"
        pause; return $null
    }

    # Mostrar resultados y seleccionar
    $sel = screen-results -Users $users -Title "RESULTADOS"
    if ($sel -ge 0) {
        $cod = $users[$sel].codigo
        Write-Log "Cargando perfil de codigoUsuario=$cod..." "INFO"
        Get-UserProfile -CodigoUsuario $cod
        screen-profile
    }
    return $null
}

function screen-results {
    param([array]$Users, [string]$Title = "RESULTADOS", [switch]$ListMode)
    $page = 0; $pageSize = 15

    while ($true) {
        ui; header
        $total = $Users.Count
        $pages = [Math]::Max(1, [Math]::Ceiling($total / $pageSize))
        Write-Host (".- $Title ($total usuarios)" + (" " * ($script:columns - 25 - $Title.Length)) + ".") -ForegroundColor Cyan
        Write-Host "|" -NoNewline
        $hdr = "{0,3} {1,-5} {2,-33} {3,-13} {4,-20}" -f "#", "COD", "NOMBRE COMPLETO", "DNI", "CARGO"
        Write-Host $hdr.PadRight($script:columns - 3) -NoNewline
        Write-Host "|" -ForegroundColor DarkGray
        $start = $page * $pageSize; $end = [Math]::Min($start + $pageSize - 1, $total - 1)
        for ($i = $start; $i -le $end; $i++) {
            $u = $Users[$i]
            $fullName = "$($u.nombre) $($u.ape1) $($u.ape2)".Trim()
            $line = ("{0,3} {1,-5} {2,-33} {3,-13} {4,-20}" -f ($i+1), $u.codigo, $fullName.Substring(0, [Math]::Min(33, $fullName.Length)), $u.dni, $u.cargo.Substring(0, [Math]::Min(20, $u.cargo.Length)))
            # Truncate if too long
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

    ui; header
    Write-Host (".- PERFIL DE USUARIO: $($f['usuario'])" + (" " * ($script:columns - 28 - $($f['usuario']).Length)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host "|  DATOS PERSONALES" -ForegroundColor Cyan
    row "Usuario"     "$($f['usuario'])  ($($f['dni']))" "Green"
    row "Nombre"      "$($f['nombre']) $($f['apellido1']) $($f['apellido2'])"
    row "Sexo"        $f['sexo']
    row "Email"       $f['email'] "DarkYellow"
    row "Telefono"    $f['telefono']
    Write-Host "|"
    Write-Host "|  PUESTO" -ForegroundColor Cyan
    row "Partido Jud" $f['partidoJudicial']
    row "Organismo"   $f['organismo']
    row "Tipo Org"    $f['tipoOrganismo']
    row "Cargo"       $f['cargo']
    row "Cuerpo"      $f['cuerpo']
    row "Categoria"   $f['categoria']
    row "Caracter"    $f['caracter']
    Write-Host "|"
    Write-Host "|  UBICACION" -ForegroundColor Cyan
    row "Ubicacion"   $f['ubicacion']
    row "Municipio"   $f['municipios']
    row "Fecha Alta"  $f['fechaAlta']
    Write-Host "|"
    Write-Host "|  RED" -ForegroundColor Cyan
    row "VPN IPv4"    "$($f['ipVpn1v4']) / $($f['ipVpn2v4'])"
    row "VPN IPv6"    "$($f['ipVpn1v6']) / $($f['ipVpn2v6'])"
    Write-Host "|"
    Write-Host "|  OBSERVACIONES" -ForegroundColor Cyan
    Write-Host ("|    " + $f['observaciones']) -ForegroundColor White
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "  1. Cambiar contrasena" -ForegroundColor Cyan
    Write-Host "  0. Volver al menu" -ForegroundColor Red
    Write-Host ""
    $opt = prompt "Opcion: " "0"
    if ($opt -eq "1") { screen-password }
}

function screen-password {
    $f = $script:lastProfileFields
    if (-not $f) { return }

    ui; header
    Write-Host (".- CAMBIAR CONTRASENA" + (" " * ($script:columns - 23)) + ".") -ForegroundColor Cyan
    Write-Host "|"
    Write-Host ("|  Usuario: $($f['usuario'])") -ForegroundColor White
    Write-Host ("|  DNI:     $($f['dni'])") -ForegroundColor White
    Write-Host "|"
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray

    $month = Get-Date -Format "MM"; $year = Get-Date -Format "yy"
    $defaultPass = "Justicia$month$year"
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

    $cod = $f['codigoUsuario']
    if (-not $cod) { $cod = $script:lastResultData | Where-Object { $_.dni -eq $f['dni'] } | Select-Object -First 1 -ExpandProperty codigo }
    if (-not $cod) { Write-Log "No se pudo determinar codigoUsuario" "ERROR"; pause; return }

    try {
        if ($confirm -eq 's' -or $confirm -eq 'S') {
            Set-UserPassword -CodigoUsuario $cod -NewPassword $pass
            Write-Log "Contrasena cambiada exitosamente" "OK"
        } elseif ($confirm -eq 'w' -or $confirm -eq 'W') {
            Set-UserPassword -CodigoUsuario $cod -NewPassword $pass -WhatIf
            Write-Log "Simulacion completada" "OK"
        }
    } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR" }
    pause
}

function screen-list-by-org {
    ui; header
    panel "LISTAR POR ORGANISMO" {
        Write-Host "|"
        Write-Host "|  Deja vacio para omitir criterio" -ForegroundColor DarkGray
        Write-Host "|"
    }
    $pj = prompt "Codigo Partido Judicial: "
    $org = prompt "Codigo Organismo: "

    Write-Log "Listando usuarios..." "INFO"
    $users = List-By-Organismo -PartidoJudicial $pj -Organismo $org

    if ($users.Count -eq 0) { Write-Log "No se encontraron usuarios" "WARN"; pause; return }
    $sel = screen-results -Users $users -Title "USUARIOS DEL ORGANISMO"
    if ($sel -ge 0) {
        $cod = $users[$sel].codigo
        Write-Log "Cargando perfil..." "INFO"
        Get-UserProfile -CodigoUsuario $cod
        screen-profile
    }
}

function screen-quick-search {
    param([string]$Query)
    Write-Log "Buscando $Query..." "INFO"
    $users = Search-User -Query $Query -SearchField "usuario"
    if ($users.Count -eq 0) { Write-Log "No encontrado" "WARN"; pause; return }
    if ($users.Count -eq 1) {
        Get-UserProfile -CodigoUsuario $users[0].codigo
        screen-profile
        return
    }
    $sel = screen-results -Users $users -Title "RESULTADOS"
    if ($sel -ge 0) {
        Get-UserProfile -CodigoUsuario $users[$sel].codigo
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
        switch -Wildcard ($opt) {
            "1" {
                try { Connect-Temis; Write-Log "Conectado a Temis" "OK" }
                catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR" }
                pause
            }
            "2" { if (-not $script:authenticated) { Write-Log "Conecta primero" "WARN"; pause; continue }; screen-search }
            "3" { if (-not $script:authenticated) { Write-Log "Conecta primero" "WARN"; pause; continue }; if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-profile }
            "4" { if (-not $script:authenticated) { Write-Log "Conecta primero" "WARN"; pause; continue }; if (-not $script:lastProfileFields) { Write-Log "Busca un usuario primero" "WARN"; pause; continue }; screen-password }
            "5" { if (-not $script:authenticated) { Write-Log "Conecta primero" "WARN"; pause; continue }; screen-list-by-org }
            "0" { $running = $false }
            "q" { $running = $false }
            default {
                if ($opt -match '^s\s+(.+)') {
                    if (-not $script:authenticated) { Write-Log "Conecta primero" "WARN"; pause; continue }
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
    Write-Host ("|  LAZYTEMIS finalizado" + (" " * ($script:columns - 23)) + "|") -ForegroundColor Yellow
    Write-Host ("|" + (" " * ($script:columns - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
    Write-Host ""
}
