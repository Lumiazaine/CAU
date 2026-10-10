#Requires -Version 5.1
# servidor_helpdesk.ps1 — Servidor HTTP que expone incidencias Help-Desk vía COM Remedy
# Uso: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "servidor_helpdesk.ps1"
# Dashboard accede en: http://localhost:8080

[CmdletBinding()]
param(
    [ValidateRange(1024,65535)][int]$Port = 8080,
    [Security.SecureString]$AccessToken
)

$script:port = $Port
$script:dashboardRoot = $PSScriptRoot
# Explicit user-supplied ephemeral bearer; never persist, print or accept in URLs.
if ($null -eq $AccessToken) { $AccessToken = Read-Host 'Token local (43-128 caracteres aleatorios base64url; conservar en gestor)' -AsSecureString }
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    if ($plain -cnotmatch '^[A-Za-z0-9_-]{43,128}$') { throw 'Token invalido: use 43-128 caracteres aleatorios base64url de su gestor.' }
    $script:tokenHash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($plain))
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $sha.Dispose(); $plain = $null; $AccessToken = $null
}
$script:server = "10.241.130.25"
$script:form = "101_INCIDENCIAS"
$script:qual = "'4' = `"Help-Desk`" AND '7' != `"Cerrada`""
$script:cacheRefreshSec = 120

$script:cache = @{entries=$null; time=$null; status='starting'}
$script:lock = New-Object System.Threading.Mutex $false

function Write-Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg"
}

function Get-HelpdeskEntries {
    Write-Log "Ejecutando Query()..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $ar = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Remedy.User")
        $f = $ar.OpenForm(0, $script:server, $script:form, 2, 0)
        $r = $f.Query($script:qual)
        $count = $r.Count
        Write-Log "Query devolvio $count entradas"
        $result = @()
        for ($i = 1; $i -le $count; $i++) {
            $e = $r.Item($i)
            $result += @{ id = $e.entryId; desc = $e.Description }
        }
        $sw.Stop()
        Write-Log "Completado: $count entradas en $($sw.Elapsed.TotalSeconds.ToString('F1'))s ($([Math]::Round($count/$sw.Elapsed.TotalSeconds)) entradas/s)"
        return ,$result
    } catch {
        Write-Log "ERROR en Query: $($_.Exception.Message)"
        return $null
    }
}

function Get-TicketDetail($entryId) {
    try {
        $ar = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Remedy.User")
        $lf = $ar.LoadForm(0, $script:server, $script:form, $entryId, 3, 0)
        $detail = @{
            id = $entryId
            estado = $(try { $lf.GetFieldById(7).Value } catch { '' })
            nivel = $(try { $lf.GetFieldById(1010000147).Value } catch { '' })
            grupo = $(try { $lf.GetFieldById(4).Value } catch { '' })
            asignado = $(try { $lf.GetFieldById(5).Value } catch { '' })
            provincia = $(try { $lf.GetFieldById(1010000163).Value } catch { '' })
            localidad = $(try { $lf.GetFieldById(1010000164).Value } catch { '' })
            telefono = $(try { $lf.GetFieldById(1010000167).Value } catch { '' })
            nombre = $(try { $lf.GetFieldById(1010000169).Value } catch { '' })
            dni = $(try { $lf.GetFieldById(1010000170).Value } catch { '' })
            clase = $(try { $lf.GetFieldById(1010000173).Value } catch { '' })
            tipo = $(try { $lf.GetFieldById(1010000174).Value } catch { '' })
            subtipo = $(try { $lf.GetFieldById(1010000175).Value } catch { '' })
            descripcion = $(try { $lf.GetFieldById(1010000177).Value } catch { '' })
            prioridad = $(try { $lf.GetFieldById(1010000179).Value } catch { '' })
            origen = $(try { $lf.GetFieldById(1010000199).Value } catch { '' })
            tipoSolicitud = $(try { $lf.GetFieldById(1010000229).Value } catch { '' })
            tipoInc = $(try { $lf.GetFieldById(1010000262).Value } catch { '' })
            diario = $(try { $lf.GetFieldById(1010000274).Value } catch { '' })
        }
        $lf.Close()
        return $detail
    } catch {
        Write-Log "ERROR LoadForm ${entryId}: $($_.Exception.Message)"
        return $null
    }
}

function Refresh-Cache {
    $lock.WaitOne() | Out-Null
    try {
        Write-Log "Refrescando cache..."
        $script:cache = @{entries=$null; time=$null; status='loading'}
        $entries = Get-HelpdeskEntries
        if ($null -ne $entries) {
            $script:cache = @{entries=$entries; time=Get-Date; status='ready'}
            Write-Log "Cache listo: $($entries.Count) entradas"
        } else {
            $script:cache = @{entries=$entries; time=$null; status='error'}
            Write-Log "Cache fallo: sin entradas"
        }
    } finally {
        $lock.ReleaseMutex()
    }
}

function Test-HelpdeskToken([string]$Header) {
    if ($null -eq $script:tokenHash -or $Header -cnotmatch '^Bearer ([A-Za-z0-9_-]{43,128})$') { return $false }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $candidate = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Matches[1])) }
    finally { $sha.Dispose() }
    $difference = 0
    for ($i = 0; $i -lt $candidate.Length; $i++) { $difference = $difference -bor ($candidate[$i] -bxor $script:tokenHash[$i]) }
    return ($difference -eq 0)
}

function Get-HelpdeskRequestStatus($Request, [switch]$PublicPage) {
    $origin = "http://localhost:$script:port"
    if ($Request.Headers['Host'] -cne "localhost:$script:port") { return 403 }
    if ($Request.Url.Query) { return 400 }
    if ($Request.Headers['Origin'] -and $Request.Headers['Origin'] -cne $origin) { return 403 }
    if ($Request.Headers['Sec-Fetch-Site'] -in @('cross-site','same-site')) { return 403 }
    if ($Request.HttpMethod -cne 'GET') { return 405 }
    if (-not $PublicPage -and -not (Test-HelpdeskToken $Request.Headers['Authorization'])) { return 401 }
    return 200
}

function Handle-Request($ctx) {
    $req = $ctx.Request
    $resp = $ctx.Response
    $path = $req.Url.AbsolutePath.TrimEnd('/')

    $body = ""
    $contentType = 'application/json; charset=utf-8'
    $staticFiles = @{'/dashboard_incidencias.html'='dashboard_incidencias.html'; '/chart.umd.min.js'='chart.umd.min.js'; '/predictor_data.js'='predictor_data.js'; '/wiki_knowledge.js'='wiki_knowledge.js'; '/ods_data.js'='ods_data.js'}
    if ($path -eq '') { $path = '/dashboard_incidencias.html' }
    $publicPage = $path -in @('/dashboard_incidencias.html','/chart.umd.min.js')
    $code = Get-HelpdeskRequestStatus $req -PublicPage:$publicPage

    try {
        if ($code -ne 200) {
            $body = @{ok=$false; msg='Peticion rechazada'} | ConvertTo-Json
        } elseif ($staticFiles.ContainsKey($path)) {
            # Whitelist only; no repository browsing, credentials, arbitrary paths or data without auth.
            $body = [IO.File]::ReadAllText((Join-Path $script:dashboardRoot $staticFiles[$path]), [Text.Encoding]::UTF8)
            $contentType = if ($path.EndsWith('.html')) { 'text/html; charset=utf-8' } else { 'application/javascript; charset=utf-8' }
        } elseif ($path -eq "/api/helpdesk/status") {
            $c = $script:cache
            $body = @{
                status = $c.status
                count = if ($c.entries) { $c.entries.Count } else { 0 }
                updated = if ($c.time) { $c.time.ToString("yyyy-MM-dd HH:mm:ss") } else { $null }
                query = $script:qual
            } | ConvertTo-Json
        } elseif ($path -eq "/api/helpdesk") {
            $c = $script:cache
            if ($c.status -eq 'ready' -and $null -ne $c.entries) {
                $body = @{ok=$true; count=$c.entries.Count; data=$c.entries; updated=$c.time.ToString("yyyy-MM-dd HH:mm:ss")} | ConvertTo-Json -Depth 3 -Compress
            } elseif ($c.status -eq 'loading') {
                $body = @{ok=$false; status='loading'; msg='Cargando datos desde Remedy (~25s)...'} | ConvertTo-Json
                $code = 503
            } else {
                $body = @{ok=$false; status=$c.status; msg='Servidor iniciando...'} | ConvertTo-Json
                $code = 503
            }
        } elseif ($path -match "^/api/helpdesk/(IN\d+)$") {
            $entryId = $matches[1]
            Write-Log "Cargando detalle: $entryId"
            $detail = Get-TicketDetail $entryId
            if ($detail) {
                $body = @{ok=$true; data=$detail} | ConvertTo-Json -Depth 3 -Compress
            } else {
                $body = @{ok=$false; msg="Error cargando $entryId"} | ConvertTo-Json
                $code = 500
            }
        } else {
            $body = @{ok=$false; msg="Ruta no encontrada: $path"} | ConvertTo-Json
            $code = 404
        }
    } catch {
        $body = @{ok=$false; msg=$_.Exception.Message} | ConvertTo-Json
        $code = 500
    }

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp.StatusCode = $code
    $resp.Headers.Add('Cache-Control', 'no-store')
    $resp.Headers.Add('X-Content-Type-Options', 'nosniff')
    $resp.Headers.Add('Referrer-Policy', 'no-referrer')
    $policy = if ($contentType.StartsWith('text/html')) { "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'" } else { "default-src 'none'; frame-ancestors 'none'" }
    $resp.Headers.Add('Content-Security-Policy', $policy)
    $resp.ContentType = $contentType
    $resp.ContentLength64 = $buffer.Length
    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
    $resp.OutputStream.Close()
}

Write-Log "============================================"
Write-Log "Servidor HelpDesk Remedy"
Write-Log "============================================"
Write-Log "Servidor: $($script:server)"
Write-Log "Formulario: $($script:form)"
Write-Log "Query: $($script:qual)"
Write-Log ""

# Primer cache load (sincrono, puede tardar ~25s)
Write-Log "Carga inicial de cache desde Remedy..."
Write-Log "(puede tardar hasta 30s dependiendo del numero de incidencias)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Refresh-Cache
$sw.Stop()
Write-Log "Carga inicial: $($sw.Elapsed.TotalSeconds.ToString('F1'))s"
Write-Log ""

# Arrancar servidor HTTP
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$script:port/")
try {
    $listener.Start()
    Write-Log "Servidor HTTP escuchando en http://localhost:$script:port/"
    Write-Log "Endpoints:"
    Write-Log "  GET /api/helpdesk        -> lista de incidencias"
    Write-Log "  GET /api/helpdesk/{id}   -> detalle de una incidencia"
    Write-Log "  GET /api/helpdesk/status -> estado del servidor"
    Write-Log "Cache se refresca cada $($script:cacheRefreshSec)s en background"
    Write-Log "============================================"
    Write-Log ""
} catch {
    Write-Log "ERROR iniciando servidor HTTP en puerto $script:port"
    Write-Log "Prueba ejecutar como Administrador o:"
    Write-Log "  netsh http add urlacl url=http://localhost:8080/ user=BUILTIN\Users"
    throw
}

# Lanzar refresco periodico en runspace separado
$bgRunspace = [RunspaceFactory]::CreateRunspace()
$bgRunspace.ApartmentState = 'STA'
$bgRunspace.Open()
$bgPs = [PowerShell]::Create()
$bgPs.Runspace = $bgRunspace
$bgState = [hashtable]::Synchronized(@{Pending=$false; Entries=$null; Stop=$false})
$null = $bgPs.AddScript({
    param($sec, $state, $server, $form, $qual)
    function Write-Log($msg) { $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[bg] [$ts] $msg" }
    function Get-HelpdeskEntries {
        Write-Log "Ejecutando Query() de fondo..."
        try {
            $ar = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Remedy.User")
            $f = $ar.OpenForm(0, $server, $form, 2, 0)
            $r = $f.Query($qual)
            $count = $r.Count
            $result = @()
            for ($i = 1; $i -le $count; $i++) {
                $e = $r.Item($i)
                $result += @{id=$e.entryId; desc=$e.Description}
            }
            Write-Log "Background: $count entradas"
            return ,$result
        } catch { Write-Log "Background ERROR: $($_.Exception.Message)"; return $null }
    }
    while (-not $state.Stop) {
        Start-Sleep -Seconds $sec
        if ($state.Stop) { break }
        $entries = Get-HelpdeskEntries
        [System.Threading.Monitor]::Enter($state.SyncRoot)
        try {
            $state.Entries = $entries
            $state.Pending = $true
        } finally { [System.Threading.Monitor]::Exit($state.SyncRoot) }
    }
})
$null = $bgPs.AddArgument($script:cacheRefreshSec).AddArgument($bgState).AddArgument($script:server).AddArgument($script:form).AddArgument($script:qual)
$null = $bgPs.BeginInvoke()

# Loop principal: manejar requests HTTP + sincronizar cache background
$pendingRequest = $null
try {
    while ($listener.IsListening) {
        if ($null -eq $pendingRequest) { $pendingRequest = $listener.BeginGetContext($null, $null) }
        if ($pendingRequest.AsyncWaitHandle.WaitOne(5000)) {
            try {
                $ctx = $listener.EndGetContext($pendingRequest)
                Handle-Request $ctx
            } catch { Write-Log "Request error: $($_.Exception.Message)" }
            finally { $pendingRequest.AsyncWaitHandle.Close(); $pendingRequest = $null }
        }
        [System.Threading.Monitor]::Enter($bgState.SyncRoot)
        try {
            if ($bgState.Pending) {
                if ($null -ne $bgState.Entries) {
                    $script:cache = @{entries=$bgState.Entries; time=Get-Date; status='ready'}
                } else {
                    $script:cache = @{entries=$null; time=$null; status='error'}
                }
                $bgState.Pending = $false
            }
        } finally { [System.Threading.Monitor]::Exit($bgState.SyncRoot) }
    }
} finally {
    $bgState.Stop = $true
    $listener.Close()
    if ($pendingRequest) { $pendingRequest.AsyncWaitHandle.Close() }
    $bgPs.Stop()
    $bgPs.Dispose()
    $bgRunspace.Dispose()
    $script:lock.Dispose()
}
