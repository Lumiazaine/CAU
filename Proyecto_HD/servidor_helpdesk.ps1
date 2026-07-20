#Requires -Version 5.1
# servidor_helpdesk.ps1 — Servidor HTTP que expone incidencias Help-Desk vía COM Remedy
# Uso: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "servidor_helpdesk.ps1"
# Dashboard accede en: http://localhost:8080

$script:port = 8080
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
        return $result
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
            estado = (try { $lf.GetFieldById(7).Value } catch { '' })
            nivel = (try { $lf.GetFieldById(1010000147).Value } catch { '' })
            grupo = (try { $lf.GetFieldById(4).Value } catch { '' })
            asignado = (try { $lf.GetFieldById(5).Value } catch { '' })
            provincia = (try { $lf.GetFieldById(1010000163).Value } catch { '' })
            localidad = (try { $lf.GetFieldById(1010000164).Value } catch { '' })
            telefono = (try { $lf.GetFieldById(1010000167).Value } catch { '' })
            nombre = (try { $lf.GetFieldById(1010000169).Value } catch { '' })
            dni = (try { $lf.GetFieldById(1010000170).Value } catch { '' })
            clase = (try { $lf.GetFieldById(1010000173).Value } catch { '' })
            tipo = (try { $lf.GetFieldById(1010000174).Value } catch { '' })
            subtipo = (try { $lf.GetFieldById(1010000175).Value } catch { '' })
            descripcion = (try { $lf.GetFieldById(1010000177).Value } catch { '' })
            prioridad = (try { $lf.GetFieldById(1010000179).Value } catch { '' })
            origen = (try { $lf.GetFieldById(1010000199).Value } catch { '' })
            tipoSolicitud = (try { $lf.GetFieldById(1010000229).Value } catch { '' })
            tipoInc = (try { $lf.GetFieldById(1010000262).Value } catch { '' })
            diario = (try { $lf.GetFieldById(1010000274).Value } catch { '' })
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
        if ($entries -ne $null -and $entries.Count -gt 0) {
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

function Handle-Request($ctx) {
    $req = $ctx.Request
    $resp = $ctx.Response
    $path = $req.Url.AbsolutePath.TrimEnd('/')

    $body = ""
    $code = 200

    try {
        if ($path -eq "/api/helpdesk/status") {
            $c = $script:cache
            $body = @{
                status = $c.status
                count = if ($c.entries) { $c.entries.Count } else { 0 }
                updated = if ($c.time) { $c.time.ToString("yyyy-MM-dd HH:mm:ss") } else { $null }
                query = $script:qual
            } | ConvertTo-Json
        } elseif ($path -eq "/api/helpdesk") {
            $c = $script:cache
            if ($c.status -eq 'ready' -and $c.entries) {
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
    $resp.Headers.Add("Access-Control-Allow-Origin", "*")
    $resp.ContentType = "application/json; charset=utf-8"
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
$bgRunspace.Open()
$bgPs = [PowerShell]::Create()
$bgPs.Runspace = $bgRunspace
$null = $bgPs.AddScript({
    param($sec, $mutexName)
    function Write-Log($msg) { $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[bg] [$ts] $msg" }
    function Get-HelpdeskEntries {
        Write-Log "Ejecutando Query() de fondo..."
        try {
            $ar = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Remedy.User")
            $f = $ar.OpenForm(0, "10.241.130.25", "101_INCIDENCIAS", 2, 0)
            $r = $f.Query("'4' = `"Help-Desk`" AND '7' != `"Cerrada`"")
            $count = $r.Count
            $result = @()
            for ($i = 1; $i -le $count; $i++) {
                $e = $r.Item($i)
                $result += @{id=$e.entryId; desc=$e.Description}
            }
            Write-Log "Background: $count entradas"
            return $result
        } catch { Write-Log "Background ERROR: $($_.Exception.Message)"; return $null }
    }
    while ($true) {
        Start-Sleep -Seconds $sec
        $m = [System.Threading.Mutex]::OpenExisting($mutexName)
        $m.WaitOne() | Out-Null
        try {
            $e = Get-HelpdeskEntries
            if ($e -ne $null -and $e.Count -gt 0) {
                [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.SessionStateProxy.SetVariable('global:bgCacheEntries', $e)
                Write-Log "Background cache actualizado: $($e.Count) entradas"
            }
        } finally { $m.ReleaseMutex(); $m.Dispose() }
    }
})
$mutexName = "Global\RemedyHD_" + [System.Diagnostics.Process]::GetCurrentProcess().Id
$null = $bgPs.AddParameters(@{$sec=$script:cacheRefreshSec; $mutexName=$mutexName})
$null = $bgPs.BeginInvoke()

# Loop principal: manejar requests HTTP + sincronizar cache background
while ($listener.IsListening) {
    $ar = $listener.BeginGetContext($null, $null)
    if ($ar.AsyncWaitHandle.WaitOne(5000)) {
        try {
            $ctx = $listener.EndGetContext($ar)
            Handle-Request $ctx
        } catch { Write-Log "Request error: $($_.Exception.Message)" }
    }
    # Check for background cache update every 5s
    $bgCache = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.SessionStateProxy.GetVariable('global:bgCacheEntries')
    if ($bgCache -ne $null) {
        $lock.WaitOne() | Out-Null
        try {
            $script:cache = @{entries=$bgCache; time=Get-Date; status='ready'}
            Write-Log "Cache actualizado desde background: $($bgCache.Count) entradas"
            [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.SessionStateProxy.SetVariable('global:bgCacheEntries', $null)
        } finally { $lock.ReleaseMutex() }
    }
}
