param(
    [switch]$WhatIf,
    [switch]$ShowBrowser
)

# ============================================================
# LAZYTEMIS - Terminal Temis (v1)
# App de terminal para gestionar usuarios en Temis
# ============================================================

$script:VERSION = "1.0"
$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "lazytemis.log"
$script:DEBUG_DIR = Join-Path $script:SCRIPT_DIR "debug"
$null = New-Item -ItemType Directory -Path $script:DEBUG_DIR -Force
$script:ESC_URL = "https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio"
$script:TEMIS_URL = "http://temis.justicia.junta-andalucia.es/Temis"
$script:ERROR_COUNT = 0
$script:webSession = $null
$script:cert = $null
$script:lastSearchResult = $null
$script:lastCodigoUsuario = $null
$script:lastProfileHtml = $null
$script:authenticated = $false

# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "HH:mm:ss"
    $prefix = "[$time] [$Level]"
    switch ($Level) {
        "OK"    { Write-Host "$prefix $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "$prefix $Message" -ForegroundColor Red; $script:ERROR_COUNT++ }
        "WARN"  { Write-Host "$prefix $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "$prefix $Message" -ForegroundColor Cyan }
        "HIGHLIGHT" { Write-Host "$prefix $Message" -ForegroundColor Magenta }
        default { Write-Host "$prefix $Message" }
    }
    $logLine = "$(Get-Date -Format 'yyyy-MM-dd') $prefix $Message"
    Add-Content -Path $script:LOG_FILE -Value $logLine -Encoding UTF8
}

function Write-Title {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
}

function Pause-And-Continue {
    Write-Host ""
    Write-Host "Presiona Enter para continuar..." -ForegroundColor DarkGray -NoNewline
    $null = Read-Host
}

# ============================================================
# AUTHENTICACION
# ============================================================

function Get-Certificate {
    $certs = Get-ChildItem Cert:\CurrentUser\My | Where-Object {
        $_.Subject -match '\d{8}[A-Z]' -and $_.NotAfter -gt (Get-Date)
    } | Sort-Object NotAfter -Descending
    $cert = $certs | Select-Object -First 1
    if (-not $cert) {
        $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.NotAfter -gt (Get-Date) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    }
    if (-not $cert) {
        $cert = Get-ChildItem Cert:\CurrentUser\My | Select-Object -First 1
    }
    if (-not $cert) { throw "No se encontro ningun certificado digital en el almacen" }
    return $cert
}

function Test-Url {
    param([string]$Url)
    try {
        $req = [System.Net.WebRequest]::Create($Url)
        $req.Method = "HEAD"
        $req.Timeout = 5000
        $req.GetResponse().Dispose()
        return $true
    } catch { return $false }
}

function Connect-Temis {
    Write-Log "Verificando conectividad..." "INFO"
    if (-not (Test-Url "$script:ESC_URL/Inicio.do") -or -not (Test-Url "$script:TEMIS_URL/UsuarioConsulta.do")) {
        throw "No se puede acceder a los servidores. Verifica conexion VPN."
    }
    Write-Log "Conectividad OK" "OK"

    Write-Log "Obteniendo certificado digital..." "INFO"
    $script:cert = Get-Certificate
    Write-Log ("Certificado: " + $script:cert.Subject) "OK"

    Write-Log "Autenticando en Escritorio Judicial..." "INFO"
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/Inicio.do" -UseBasicParsing -SessionVariable script:webSession -Certificate $script:cert
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/AccesoCertificado.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert
    $null = Invoke-WebRequest -Uri "$script:ESC_URL/CallAuthenticationServlet" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST
    Write-Log "Sesion iniciada en Escritorio" "OK"

    Write-Log "Accediendo a Temis via Lanzadera..." "INFO"
    $r = Invoke-WebRequest -Uri "$script:ESC_URL/Lanzadera.do?id=2" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -MaximumRedirection 10
    Write-Log ("Temis accesible: " + $r.BaseResponse.ResponseUri.AbsoluteUri) "OK"
    $script:authenticated = $true
}

# ============================================================
# BUSQUEDA DE USUARIOS
# ============================================================

function Search-User {
    param(
        [string]$Query = "",
        [string]$SearchField = "usuario",
        [string]$Cargo = ""
    )

    $null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert

    $searchFields = @{
        codigoPartidoJudicial = ''
        codigoMunicipioPart = ''
        codigoOrganismo = ''
        codigoUsuario = ''
        codigosUsuarios = ''
        usuario = ''
        accion = 'buscar_dos'
        nombre = ''
        apellidos = ''
        codigoMunicipio = ''
        mayor = ''
        noResultados = ''
        partidoJudicial = ''
        organismo = ''
        cargo = $Cargo
        busquedaAbierta = 'false'
        busquedaSegundaAbierta = 'true'
        codigoDocumento = ''
        dni = ''
        otro = ''
        mostrar = ''
        organismoHijo = ''
        listadoOrganismoHijo = ''
        codigoOrganismoPadre = ''
    }

    switch ($SearchField) {
        "usuario" { $searchFields['usuario'] = $Query; if ($Query -match '^\d{8}[A-Z]$') { $searchFields['dni'] = $Query; $searchFields['codigoDocumento'] = 'D' } }
        "dni" { $searchFields['dni'] = $Query; $searchFields['codigoDocumento'] = 'D'; $searchFields['usuario'] = $Query.Substring(0, [Math]::Min(8, $Query.Length)) }
        "nombre" { $searchFields['nombre'] = $Query }
        "apellidos" { $searchFields['apellidos'] = $Query }
    }

    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $searchFields
    $script:lastSearchResult = $result.Content

    $users = @()
    $pattern = '<input[^>]*name="codigoUsuario"[^>]*value="(\d+)"[^>]*>'
    $matches = [regex]::Matches($result.Content, $pattern)
    if ($matches.Count -gt 0) {
        # Si hay resultados, extraer info basica de cada uno
        $codigos = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        foreach ($cod in $codigos) {
            $userMatch = [regex]::Match($result.Content, "(?s)<input[^>]*name=\""codigoUsuario\""[^>]*value=\""$cod\""[^>]*>.*?<td[^>]*class=\""[^\""]*texto2[^\""]*\""[^>]*>(.*?)</td>")
            $users += @{
                codigoUsuario = $cod
                display = $cod
            }
        }
        # Si no hay multiples usuarios, el resultado es un solo usuario
        if ($codigos.Count -eq 1) {
            $codigoUsuario = $codigos[0]
            $displayName = ""
            if ($result.Content -match 'name="nombre"\s*value="([^"]*)"') { $displayName = $Matches[1] }
            if ($result.Content -match 'name="apellido1"\s*value="([^"]*)"') { $displayName += " " + $Matches[1] }
            $users[0].display = "$displayName (cod:$codigoUsuario)"
        }
        return $users
    }
    return $users
}

function Get-UserProfile {
    param([string]$CodigoUsuario)
    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        codigoUsuario = $CodigoUsuario
        accion = 'modificarDos'
    }
    $script:lastProfileHtml = $result.Content
    return $result.Content
}

function Extract-ProfileFields {
    param([string]$Html)
    $fields = @{}
    $inputPattern = '<input[^>]*name="([^"]*)"[^>]*value="([^"]*)"[^>]*>'
    $matches = [regex]::Matches($Html, $inputPattern)
    foreach ($m in $matches) {
        $fields[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    $selectPattern = '<select[^>]*name="([^"]*)"[^>]*>(.*?)</select>'
    $smatches = [regex]::Matches($Html, $selectPattern)
    foreach ($m in $smatches) {
        $name = $m.Groups[1].Value
        $selected = [regex]::Match($m.Groups[2].Value, '<option[^>]*value="([^"]*)"[^>]*selected[^>]*>')
        if ($selected.Success) { $fields[$name] = $selected.Groups[1].Value }
    }
    $textareaPattern = '<textarea[^>]*name="([^"]*)"[^>]*>(.*?)</textarea>'
    $tmatches = [regex]::Matches($Html, $textareaPattern)
    foreach ($m in $tmatches) {
        $val = $m.Groups[2].Value -replace '&nbsp;', ' ' -replace '&amp;', '&'
        $fields[$m.Groups[1].Value] = $val
    }
    return $fields
}

function Show-UserProfile {
    param([hashtable]$Fields)
    Clear-Host
    Write-Title "PERFIL DEL USUARIO"

    Write-Host "DATOS PERSONALES" -ForegroundColor Cyan
    Write-Host "  Usuario:       " -NoNewline; Write-Host $Fields['usuario'] -ForegroundColor White
    Write-Host "  Nombre:        " -NoNewline; Write-Host "$($Fields['nombre']) $($Fields['apellido1']) $($Fields['apellido2'])" -ForegroundColor White
    Write-Host "  DNI:           " -NoNewline; Write-Host $Fields['dni'] -ForegroundColor White
    Write-Host "  Sexo:          " -NoNewline; Write-Host $Fields['sexo'] -ForegroundColor White
    Write-Host "  Email:         " -NoNewline; Write-Host $Fields['email'] -ForegroundColor White
    Write-Host "  Telefono:      " -NoNewline; Write-Host $Fields['telefono'] -ForegroundColor White

    Write-Host ""
    Write-Host "PUESTO" -ForegroundColor Cyan
    Write-Host "  Partido Jud:   " -NoNewline; Write-Host $Fields['partidoJudicial'] -ForegroundColor White
    Write-Host "  Organismo:     " -NoNewline; Write-Host $Fields['organismo'] -ForegroundColor White
    Write-Host "  Tipo Org:      " -NoNewline; Write-Host $Fields['tipoOrganismo'] -ForegroundColor White
    Write-Host "  Cargo:         " -NoNewline; Write-Host $Fields['cargo'] -ForegroundColor White
    Write-Host "  Cuerpo:        " -NoNewline; Write-Host $Fields['cuerpo'] -ForegroundColor White
    Write-Host "  Categoria:     " -NoNewline; Write-Host $Fields['categoria'] -ForegroundColor White
    Write-Host "  Caracter:      " -NoNewline; Write-Host $Fields['caracter'] -ForegroundColor White

    Write-Host ""
    Write-Host "UBICACION" -ForegroundColor Cyan
    Write-Host "  Ubicacion:     " -NoNewline; Write-Host $Fields['ubicacion'] -ForegroundColor White
    Write-Host "  Municipio:     " -NoNewline; Write-Host $Fields['municipios'] -ForegroundColor White
    Write-Host "  Fecha Alta:    " -NoNewline; Write-Host $Fields['fechaAlta'] -ForegroundColor White

    Write-Host ""
    Write-Host "OBSERVACIONES" -ForegroundColor Cyan
    Write-Host "  $($Fields['observaciones'])" -ForegroundColor White

    Write-Host ""
    Write-Host "RED" -ForegroundColor Cyan
    Write-Host "  IP VPN IPv4:   " -NoNewline; Write-Host "$($Fields['ipVpn1v4']) / $($Fields['ipVpn2v4'])" -ForegroundColor White
    Write-Host "  IP VPN IPv6:   " -NoNewline; Write-Host "$($Fields['ipVpn1v6']) / $($Fields['ipVpn2v6'])" -ForegroundColor White
}

# ============================================================
# CAMBIO DE CONTRASENA
# ============================================================

function Set-UserPassword {
    param(
        [string]$CodigoUsuario,
        [string]$NewPassword,
        [switch]$WhatIf
    )
    $modResult = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body @{
        codigoUsuario = $CodigoUsuario
        accion = 'modificarDos'
    }

    $formFields = Extract-ProfileFields -Html $modResult.Content
    if ($formFields.Count -eq 0) { throw "No se pudieron extraer los campos del formulario" }

    if ($WhatIf) {
        Write-Log "WHATIF - Se anularia la contrasena en Temis" "INFO"
        Write-Log "WHATIF - Se estableceria nueva contrasena: $NewPassword" "INFO"
        return
    }

    $formFields['accion'] = 'anular'
    $formFields['usuario'] = $formFields['dni']
    $formFields['cambiarIdPassword'] = '3'
    $formFields['pwd_modificacion'] = $NewPassword
    $formFields['pwd2_modificacion'] = $NewPassword

    Write-Log "Anulando contrasena en Temis..." "INFO"
    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioGuardarModificar.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $formFields
    Write-Log "Anulacion completada" "OK"

    Write-Log "Estableciendo contrasena en Escritorio Judicial..." "INFO"
    $dni = $formFields['usuario'] -replace '[A-Z]$', ''
    $escPassFields = @{
        usuario = $dni
        password = ''
        nuevaPassword = $NewPassword
        nuevaPassword2 = $NewPassword
        aceptar2 = 'Aceptar'
    }
    $escResult = Invoke-WebRequest -Uri "$script:ESC_URL/RealizarModificarPassword.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $escPassFields
    Write-Log "Contrasena establecida correctamente" "OK"
}

# ============================================================
# LISTADO / EXPLORACION
# ============================================================

function List-UsersByOrganismo {
    param([string]$Organismo = "", [string]$PartidoJudicial = "")

    $null = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert

    $body = @{
        codigoPartidoJudicial = $PartidoJudicial
        codigoMunicipioPart = ''
        codigoOrganismo = $Organismo
        codigoUsuario = ''
        codigosUsuarios = ''
        usuario = ''
        accion = 'buscar_dos'
        nombre = ''
        apellidos = ''
        codigoMunicipio = ''
        mayor = ''
        noResultados = ''
        partidoJudicial = ''
        organismo = ''
        cargo = ''
        busquedaAbierta = 'false'
        busquedaSegundaAbierta = 'true'
        codigoDocumento = ''
        dni = ''
        otro = ''
        mostrar = 'SI'
        organismoHijo = ''
        listadoOrganismoHijo = ''
        codigoOrganismoPadre = ''
    }

    $result = Invoke-WebRequest -Uri "$script:TEMIS_URL/UsuarioConsulta.do" -UseBasicParsing -WebSession $script:webSession -Certificate $script:cert -Method POST -Body $body
    $script:lastSearchResult = $result.Content

    $users = @()
    $pattern = 'name="codigoUsuario"\s*value="(\d+)"'
    $matches = [regex]::Matches($result.Content, $pattern)
    $seen = @{}
    foreach ($m in $matches) {
        $cod = $m.Groups[1].Value
        if (-not $seen.ContainsKey($cod)) {
            $seen[$cod] = $true
            $nombre = ""
            $ape1 = ""
            if ($result.Content -match "codigoUsuario\s*value=\""$cod\""[^>]*>.*?<td[^>]*class=\""[^\""]*texto[12]\""[^>]*>(.*?)<") {
                $nombre = $matches[1] -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '\s+', ' '
            }
            $users += @{
                codigoUsuario = $cod
                display = "$cod - $nombre"
            }
        }
    }
    return $users
}

# ============================================================
# MENU PRINCIPAL
# ============================================================

function Show-MainMenu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  LAZYTEMIS v$script:VERSION" -ForegroundColor Yellow
    Write-Host "  Terminal Temis - Gestion de Usuarios" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""

    if ($script:authenticated) {
        Write-Host "  Estado: " -NoNewline; Write-Host "CONECTADO" -ForegroundColor Green
        Write-Host "  Cert:   " -NoNewline; Write-Host $script:cert.Subject -ForegroundColor DarkGray
    } else {
        Write-Host "  Estado: " -NoNewline; Write-Host "DESCONECTADO" -ForegroundColor Red
    }
    Write-Host "  Sesion: " -NoNewline
    if ($script:lastCodigoUsuario) {
        Write-Host ("Usuario cargado: $script:lastCodigoUsuario") -ForegroundColor White
    } else {
        Write-Host "Ninguno" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  1. Conectar a Temis" -ForegroundColor Cyan
    Write-Host "  2. Buscar usuario" -ForegroundColor Cyan
    Write-Host "  3. Ver perfil del usuario" -ForegroundColor Cyan
    Write-Host "  4. Cambiar contrasena" -ForegroundColor Cyan
    Write-Host "  5. Listar usuarios por organismo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  0. Salir" -ForegroundColor Red
    Write-Host ""
    Write-Host "  --- Comandos rapidos ---" -ForegroundColor DarkGray
    Write-Host "  s <dni>   Buscar por DNI en cualquier pantalla" -ForegroundColor DarkGray
    Write-Host "  q         Salir" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Selecciona una opcion: " -ForegroundColor Yellow -NoNewline
    $input = Read-Host
    return $input
}

function Show-SearchMenu {
    Clear-Host
    Write-Title "BUSQUEDA DE USUARIOS"

    Write-Host "Criterio de busqueda:" -ForegroundColor Cyan
    Write-Host "  1. Por usuario / DNI"
    Write-Host "  2. Por nombre"
    Write-Host "  3. Por apellidos"
    Write-Host "  4. Por cargo"
    Write-Host ""
    Write-Host "  0. Volver"
    Write-Host ""
    Write-Host "Opcion: " -NoNewline
    $opt = Read-Host

    if ($opt -eq "0") { return }

    $searchField = "usuario"
    $query = ""
    $cargo = ""

    switch ($opt) {
        "1" { $searchField = "usuario"; Write-Host "DNI o usuario: " -NoNewline; $query = Read-Host }
        "2" { $searchField = "nombre"; Write-Host "Nombre: " -NoNewline; $query = Read-Host }
        "3" { $searchField = "apellidos"; Write-Host "Apellidos: " -NoNewline; $query = Read-Host }
        "4" { Write-Host "Cargo (ej. Auxilio Judicial, Tramitacion): " -NoNewline; $cargo = Read-Host }
        default { return }
    }

    if (-not $query -and -not $cargo) { return }

    try {
        Write-Log "Buscando..." "INFO"
        $users = Search-User -Query $query -SearchField $searchField -Cargo $cargo
        Clear-Host
        Write-Title "RESULTADOS DE BUSQUEDA"

        if ($users.Count -eq 0) {
            Write-Host "  No se encontraron usuarios." -ForegroundColor Yellow
        } elseif ($users.Count -eq 1) {
            $script:lastCodigoUsuario = $users[0].codigoUsuario
            Write-Host ("  Usuario encontrado: " + $users[0].display) -ForegroundColor Green
            Write-Log "Cargando perfil del usuario $script:lastCodigoUsuario..." "INFO"
            Get-UserProfile -CodigoUsuario $script:lastCodigoUsuario | Out-Null
            Show-ProfileView
        } else {
            Write-Host "  Usuarios encontrados: $($users.Count)" -ForegroundColor Green
            Write-Host ""
            for ($i = 0; $i -lt $users.Count; $i++) {
                Write-Host ("  $($i+1). " + $users[$i].display) -ForegroundColor White
            }
            Write-Host ""
            Write-Host "Selecciona numero para ver perfil (0 = cancelar): " -NoNewline
            $sel = Read-Host
            if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $users.Count) {
                $script:lastCodigoUsuario = $users[[int]$sel - 1].codigoUsuario
                Write-Log "Cargando perfil..." "INFO"
                Get-UserProfile -CodigoUsuario $script:lastCodigoUsuario | Out-Null
                Show-ProfileView
            }
        }
    } catch {
        Write-Log ("Error en busqueda: " + $_.Exception.Message) "ERROR"
    }
    Pause-And-Continue
}

function Show-ProfileView {
    if (-not $script:lastProfileHtml) {
        Write-Log "No hay perfil cargado" "WARN"
        return
    }
    $fields = Extract-ProfileFields -Html $script:lastProfileHtml
    Show-UserProfile -Fields $fields

    Write-Host ""
    Write-Host "Acciones:" -ForegroundColor Cyan
    Write-Host "  1. Cambiar contrasena de este usuario"
    Write-Host "  0. Volver"
    Write-Host ""
    Write-Host "Opcion: " -NoNewline
    $opt = Read-Host

    if ($opt -eq "1") {
        Show-PasswordChange -CodigoUsuario $script:lastCodigoUsuario -Fields $fields
    }
}

function Show-PasswordChange {
    param([string]$CodigoUsuario, [hashtable]$Fields)

    Clear-Host
    Write-Title "CAMBIAR CONTRASENA"

    $dni = $Fields['dni']
    Write-Host ("Usuario: " + $Fields['usuario'] + " (" + $dni + ")") -ForegroundColor White

    $month = Get-Date -Format "MM"
    $year = Get-Date -Format "yy"
    $defaultPass = "Justicia$month$year"
    Write-Host ""
    Write-Host ("Contrasena por defecto: " + $defaultPass) -ForegroundColor DarkGray
    Write-Host "Nueva contrasena (Enter para usar por defecto): " -NoNewline
    $pass = Read-Host
    if (-not $pass) { $pass = $defaultPass }

    Write-Host ""
    Write-Host "Confirmar cambio de contrasena para $dni a '$pass'?" -ForegroundColor Yellow
    Write-Host "  s = Si, cambiar" -ForegroundColor Green
    Write-Host "  n = No" -ForegroundColor Red
    Write-Host "  w = WhatIf (simular)" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "s/n/w"

    if ($confirm -eq 's' -or $confirm -eq 'S') {
        try {
            Set-UserPassword -CodigoUsuario $CodigoUsuario -NewPassword $pass
            Write-Log "Contrasena cambiada exitosamente" "OK"
        } catch {
            Write-Log ("Error: " + $_.Exception.Message) "ERROR"
        }
    } elseif ($confirm -eq 'w' -or $confirm -eq 'W') {
        Write-Log "Simulando cambio de contrasena..." "INFO"
        Set-UserPassword -CodigoUsuario $CodigoUsuario -NewPassword $pass -WhatIf
        Write-Log "Simulacion completada (sin cambios)" "OK"
    } else {
        Write-Log "Cambio cancelado" "WARN"
    }
    Pause-And-Continue
}

function Show-ListByOrganismo {
    Clear-Host
    Write-Title "LISTAR USUARIOS POR ORGANISMO"

    Write-Host "Introduce criterios (deja vacio para listar todos):"
    Write-Host ""
    Write-Host "Codigo de Partido Judicial: " -NoNewline
    $pj = Read-Host
    Write-Host "Codigo de Organismo: " -NoNewline
    $org = Read-Host

    try {
        Write-Log "Listando usuarios..." "INFO"
        $users = List-UsersByOrganismo -PartidoJudicial $pj -Organismo $org
        Clear-Host
        Write-Title "USUARIOS DEL ORGANISMO"

        if ($users.Count -eq 0) {
            Write-Host "  No se encontraron usuarios." -ForegroundColor Yellow
        } else {
            Write-Host ("  Total: " + $users.Count) -ForegroundColor Green
            Write-Host ""
            $pageSize = 20
            $page = 0
            $totalPages = [Math]::Ceiling($users.Count / $pageSize)
            $showList = $true
            while ($showList) {
                $start = $page * $pageSize
                $end = [Math]::Min($start + $pageSize - 1, $users.Count - 1)
                Clear-Host
                Write-Title "USUARIOS (pagina $($page+1)/$totalPages)"

                for ($i = $start; $i -le $end; $i++) {
                    Write-Host ("  $($i+1). " + $users[$i].display) -ForegroundColor White
                }
                Write-Host ""
                if ($page -gt 0) { Write-Host "  a. Pagina anterior" -ForegroundColor Cyan }
                if ($end -lt $users.Count - 1) { Write-Host "  s. Pagina siguiente" -ForegroundColor Cyan }
                Write-Host "  <numero>. Ver perfil del usuario"
                Write-Host "  0. Volver"
                Write-Host ""
                Write-Host "Opcion: " -NoNewline
                $input = Read-Host
                if ($input -eq "s" -and $end -lt $users.Count - 1) { $page++ }
                elseif ($input -eq "a" -and $page -gt 0) { $page-- }
                elseif ($input -eq "0") { $showList = $false }
                elseif ($input -match '^\d+$') {
                    $idx = [int]$input - 1
                    if ($idx -ge 0 -and $idx -lt $users.Count) {
                        $script:lastCodigoUsuario = $users[$idx].codigoUsuario
                        Write-Log "Cargando perfil..." "INFO"
                        Get-UserProfile -CodigoUsuario $script:lastCodigoUsuario | Out-Null
                        Show-ProfileView
                    }
                }
            }
        }
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
    Pause-And-Continue
}

# ============================================================
# MAIN LOOP
# ============================================================

try {
    $running = $true
    while ($running) {
        $opt = Show-MainMenu

        switch ($opt) {
            "1" {
                try {
                    Connect-Temis
                    Write-Log "Conexion establecida" "OK"
                } catch {
                    Write-Log ("Error de conexion: " + $_.Exception.Message) "ERROR"
                }
                Pause-And-Continue
            }
            "2" {
                if (-not $script:authenticated) { Write-Log "Conecta primero (opcion 1)" "WARN"; Pause-And-Continue; continue }
                Show-SearchMenu
            }
            "3" {
                if (-not $script:authenticated) { Write-Log "Conecta primero (opcion 1)" "WARN"; Pause-And-Continue; continue }
                if (-not $script:lastProfileHtml) { Write-Log "Busca un usuario primero (opcion 2)" "WARN"; Pause-And-Continue; continue }
                Show-ProfileView
            }
            "4" {
                if (-not $script:authenticated) { Write-Log "Conecta primero (opcion 1)" "WARN"; Pause-And-Continue; continue }
                if (-not $script:lastCodigoUsuario) { Write-Log "Busca un usuario primero (opcion 2)" "WARN"; Pause-And-Continue; continue }
                $fields = Extract-ProfileFields -Html $script:lastProfileHtml
                Show-PasswordChange -CodigoUsuario $script:lastCodigoUsuario -Fields $fields
            }
            "5" {
                if (-not $script:authenticated) { Write-Log "Conecta primero (opcion 1)" "WARN"; Pause-And-Continue; continue }
                Show-ListByOrganismo
            }
            "0" { $running = $false }
            "q" { $running = $false }
            default {
                if ($opt -match '^s\s+(\S+)') {
                    if (-not $script:authenticated) { Write-Log "Conecta primero (opcion 1)" "WARN"; Pause-And-Continue; continue }
                    $quickQuery = $Matches[1]
                    try {
                        $users = Search-User -Query $quickQuery -SearchField "usuario"
                        if ($users.Count -eq 1) {
                            $script:lastCodigoUsuario = $users[0].codigoUsuario
                            Write-Log "Usuario encontrado: $script:lastCodigoUsuario" "OK"
                            Get-UserProfile -CodigoUsuario $script:lastCodigoUsuario | Out-Null
                            Show-ProfileView
                        } elseif ($users.Count -gt 1) {
                            Write-Log "Multiples resultados, usa el menu de busqueda" "WARN"
                        } else {
                            Write-Log "Usuario no encontrado" "WARN"
                        }
                    } catch {
                        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
                    }
                    Pause-And-Continue
                } else {
                    Write-Log "Opcion no valida" "WARN"
                    Pause-And-Continue
                }
            }
        }
    }
} finally {
    Write-Log "LAZYTEMIS finalizado" "INFO"
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  Hasta luego!" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
}
