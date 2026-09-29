param([switch]$WhatIf)

$script:VERSION = "2.0"
$script:SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LOG_FILE = Join-Path $script:SCRIPT_DIR "lazyagentportal.log"
$script:AGENT_PORTAL_URL = "https://hppcgroup.cccdm-rcja.juntadeandalucia.es/agentportal/#login"
$script:WS_URL = "wss://hppcgroup.cccdm-rcja.juntadeandalucia.es/agentportal/ws/"
$script:OPENSCAPE_EXE = "C:\Program Files (x86)\Unify\OpenScape Desktop Client\Client\Unify.OpenScape.exe"
$script:OPENSCAPE_PROCESS = "Unify.OpenScape"
$script:OPENSCAPE_EXT = "34955066036"
$script:openscapeRunning = $false
$script:columns = 80
$script:ws = $null
$script:wsConnected = $false
$script:wsStream = $null
$script:tcp = $null
$script:wsBuffer = $null
$script:requestId = 0
$script:agentInfo = @{}
$script:teamAgents = @()
$script:queueStats = $null
$script:cachedCreds = $null
$script:ENV_FILE = Join-Path $env:USERPROFILE ".env_agentportal"
$script:lastError = $null

function ui {
    $script:columns = [Math]::Max(80, [Console]::WindowWidth)
}
function bar { param([string]$c = "DarkGray"); Write-Host ("-" * $script:columns) -ForegroundColor $c }
function empty { Write-Host (" " * $script:columns) -ForegroundColor DarkGray }

function header {
    Clear-Host
    $w = $script:columns
    $osc = if ($script:openscapeRunning) { "OPENSCAPE OK" } else { "OPENSCAPE DETENIDO" }
    $oc = if ($script:openscapeRunning) { "Green" } else { "Red" }
    $conn = if ($script:wsConnected) { "WSCON OK" } else { "WSCON NO" }
    $cc = if ($script:wsConnected) { "Green" } else { "Red" }
    Write-Host ("." + ("-" * ($w - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + (" " * ($w - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("|  LAZYAGENTPORTAL v$script:VERSION") -ForegroundColor Yellow -NoNewline
    $rest = $w - 39
    if ($rest -gt 0) { Write-Host (" " * $rest) -NoNewline } else { Write-Host "" -NoNewline }
    Write-Host "|" -ForegroundColor DarkGray
    Write-Host ("|  " + (" " * 2)) -NoNewline
    Write-Host $osc -ForegroundColor $oc -NoNewline
    Write-Host (" " * 5) -NoNewline
    Write-Host $conn -ForegroundColor $cc -NoNewline
    if ($script:wsConnected -and $script:agentInfo.userRoutingState) {
        $name = if ($script:agentInfo.userRoutingState.userName) { $script:agentInfo.userRoutingState.userName } else { $script:agentInfo.userRoutingState.tenant }
        $rs = Get-StateName $script:agentInfo.userRoutingState.routingState
        Write-Host (" " + $name + " [" + $rs + "]") -NoNewline -ForegroundColor Green
        $nlen = $name.Length + $rs.Length + 4
        $rest2 = $w - 27 - $osc.Length - $conn.Length - $nlen
        if ($rest2 -gt 0) { Write-Host (" " * $rest2) -NoNewline } else { Write-Host "" -NoNewline }
    } else {
        Write-Host (" " * ($w - 27 - $osc.Length - $conn.Length)) -NoNewline
    }
    Write-Host "|" -ForegroundColor DarkGray
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

function Get-StateName {
    param([string]$RoutingState)
    switch ($RoutingState) {
        "0" { return "EN_COLA" }
        "1" { return "OCUPADO" }
        "2" { return "REGISTRADO" }
        "3" { return "DESCONECTADO" }
        default { return "DESCONOCIDO" }
    }
}

function Get-PresenceName {
    param([string]$PresenceState)
    switch ($PresenceState) {
        "1" { return "Disponible" }
        "2" { return "En pausa" }
        "3" { return "Ocupado" }
        "4" { return "Ausente" }
        default { return "Desconocido" }
    }
}

# ============================================================
# OPENSCAPE MANAGEMENT
# ============================================================

function Test-OpenScape {
    $proc = Get-Process -Name $script:OPENSCAPE_PROCESS -ErrorAction SilentlyContinue
    $script:openscapeRunning = ($null -ne $proc)
    if ($script:openscapeRunning) {
        Write-Log "OpenScape detectado (PID: $($proc.Id))" "OK"
    } else {
        Write-Log "OpenScape no detectado" "WARN"
    }
    return $script:openscapeRunning
}

function Start-OpenScape {
    if ($script:openscapeRunning) {
        Write-Log "OpenScape ya ejecutandose" "INFO"
        return $true
    }
    if (-not (Test-Path $script:OPENSCAPE_EXE)) {
        Write-Log "No encontrado: $($script:OPENSCAPE_EXE)" "ERROR"
        return $false
    }
    try {
        Write-Log "Iniciando OpenScape..." "INFO"
        if ($WhatIf) { Write-Log "WHATIF - Se iniciaria OpenScape" "INFO"; return $true }
        Start-Process -FilePath $script:OPENSCAPE_EXE
        $timeout = 15
        for ($i = 0; $i -lt $timeout; $i++) {
            Start-Sleep -Seconds 1
            if (Test-OpenScape) { Write-Log "OpenScape iniciado" "OK"; return $true }
        }
        Write-Log "Timeout iniciando OpenScape" "WARN"
        return (Test-OpenScape)
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
        return $false
    }
}

function Stop-OpenScape {
    if (-not $script:openscapeRunning) { return }
    try {
        Write-Log "Deteniendo OpenScape..." "INFO"
        if ($WhatIf) { Write-Log "WHATIF - Se detendria OpenScape" "INFO"; return }
        $proc = Get-Process -Name $script:OPENSCAPE_PROCESS -ErrorAction SilentlyContinue
        if ($proc) { $proc.Kill(); Write-Log "OpenScape detenido" "OK" }
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
}

# ============================================================
# WEBSOCKET AGENT PORTAL CONNECTION
# ============================================================

function New-RequestId {
    return [System.Threading.Interlocked]::Increment([ref]$script:requestId)
}

function Send-WSFrame {
    param([string]$Realm, [string]$Type, $Data, [int]$RequestId)
    $msg = @{ type = "1"; data = @{ realm = $Realm; type = $Type; data = $Data; requestId = $RequestId } } | ConvertTo-Json -Compress
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
        $len = $bytes.Length
        $frame = New-Object System.Collections.Generic.List[byte]
        $frame.Add(0x81)
        if ($len -le 125) {
            $frame.Add([byte](0x80 -bor $len))
        } elseif ($len -le 65535) {
            $frame.Add(0x80 -bor 126)
            $frame.Add([byte](($len -shr 8) -band 0xFF)); $frame.Add([byte]($len -band 0xFF))
        } else {
            $frame.Add(0x80 -bor 127)
            $l = [BitConverter]::GetBytes([long]$len)
            7..0 | ForEach-Object { $frame.Add($l[$_]) }
        }
        $maskArr = [byte[]]::new(4)
        for ($mi = 0; $mi -lt 4; $mi++) { $maskArr[$mi] = [byte](Get-Random -Maximum 256); $frame.Add($maskArr[$mi]) }
        for ($i = 0; $i -lt $len; $i++) { $frame.Add([byte]($bytes[$i] -bxor $maskArr[$i % 4])) }
        $script:wsStream.Write($frame.ToArray(), 0, $frame.Count)
        $script:wsStream.Flush()
        Write-Log "WS>> realm=$Realm type=$Type reqId=$RequestId" "OK"
    } catch {
        $ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
        Write-Log ("WS send error: " + $ex.Message) "ERROR"
        $script:wsConnected = $false
    }
}

function Read-WSFrames {
    param([int]$Count = 1, [int]$TimeoutMs = 5000)
    $messages = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $headerBuf = New-Object byte[] 2
    try {
        while ($messages.Count -lt $Count) {
            $remaining = $TimeoutMs - $sw.ElapsedMilliseconds
            if ($remaining -le 0) { break }
            if ((Read-WSStreamBytes -Buffer $headerBuf -Offset 0 -Count 2 -TimeoutMs $remaining) -lt 2) { break }
            $b0 = $headerBuf[0]; $b1 = $headerBuf[1]
            $opcode = $b0 -band 0x0F
            $rsv1 = ($b0 -band 0x40) -ne 0
            $masked = ($b1 -band 0x80) -ne 0
            $len = $b1 -band 0x7F
            Write-Log "WS frame: b0=$b0 b1=$b1 opcode=$opcode rsv1=$rsv1 masked=$masked len=$len" "DEBUG"
            if ($len -eq 126) {
                $extBuf = New-Object byte[] 2
                if ((Read-WSStreamBytes -Buffer $extBuf -Offset 0 -Count 2) -lt 2) { break }
                $len = ($extBuf[0] -shl 8) -bor $extBuf[1]
                Write-Log "WS ext len 16: $len" "DEBUG"
            } elseif ($len -eq 127) {
                $extBuf = New-Object byte[] 8
                if ((Read-WSStreamBytes -Buffer $extBuf -Offset 0 -Count 8) -lt 8) { break }
                $len = 0
                for ($j = 0; $j -lt 8; $j++) { $len = ($len -shl 8) -bor $extBuf[$j] }
                if ($len -gt [int]::MaxValue) { break }
                $len = [int]$len
                Write-Log "WS ext len 64: $len" "DEBUG"
            }
            $maskKey = $null
            if ($masked) {
                $mkBuf = New-Object byte[] 4
                if ((Read-WSStreamBytes -Buffer $mkBuf -Offset 0 -Count 4) -lt 4) { break }
                $maskKey = $mkBuf
            }
            $payload = New-Object byte[] $len
            $totalRead = 0
            while ($totalRead -lt $len) {
                $r = Read-WSStreamBytes -Buffer $payload -Offset $totalRead -Count ($len - $totalRead)
                if ($r -eq 0) { break }
                $totalRead += $r
            }
            if ($totalRead -lt $len) { break }
            if ($maskKey) { for ($i = 0; $i -lt $len; $i++) { $payload[$i] = $payload[$i] -bxor $maskKey[$i % 4] } }
            if ($opcode -eq 8) { Write-Log "WS cerrado por servidor" "WARN"; $script:wsConnected = $false; break }
            if ($opcode -eq 9) { Send-WSPong; continue }
            if ($opcode -eq 10) { continue }
            if ($opcode -eq 1) {
                $text = [System.Text.Encoding]::UTF8.GetString($payload, 0, [Math]::Min($payload.Length, 200))
                Write-Log "WS text frame ($($payload.Length) bytes): $text" "DEBUG"
                $messages += [System.Text.Encoding]::UTF8.GetString($payload, 0, $payload.Length)
            }
        }
    } catch {
        $ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
        Write-Log ("Read-WSFrames error: " + $ex.Message) "WARN"
        $script:wsConnected = $false
    }
    return $messages
}

function Read-WSStreamBytes {
    param([byte[]]$Buffer, [int]$Offset, [int]$Count, [int]$TimeoutMs = 5000)
    $read = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($read -lt $Count) {
        $remaining = $TimeoutMs - $sw.ElapsedMilliseconds
        if ($remaining -le 0) { break }
        if ($script:wsBuffer -and $script:wsBuffer.Count -gt 0) {
            $Buffer[$Offset + $read] = $script:wsBuffer.Dequeue()
            $read++
        } else {
            $rt = $script:wsStream.ReadAsync($Buffer, $Offset + $read, $Count - $read)
            if (-not $rt.Wait([Math]::Max(1, [int]$remaining))) { break }
            $n = $rt.Result
            if ($n -eq 0) { break }
            $read += $n
        }
    }
    return $read
}

function Send-WSPong {
    $frame = @(0x8A, 0x80, 0, 0, 0, 0)
    try { $script:wsStream.Write($frame, 0, $frame.Length); $script:wsStream.Flush() } catch {}
}

function Close-WSConnection {
    try { if ($script:wsStream) { $script:wsStream.Close() } } catch {}
    try { if ($script:tcp) { $script:tcp.Close() } } catch {}
    $script:wsConnected = $false
    $script:wsStream = $null
    $script:tcp = $null
    $script:wsBuffer = $null
}

function Get-Credentials {
    if ($script:cachedCreds) { return $script:cachedCreds }
    if (Test-Path $script:ENV_FILE) {
        $lines = Get-Content $script:ENV_FILE -Encoding UTF8
        $creds = @{}
        foreach ($line in $lines) {
            if ($line -match '^([^=]+)=(.*)$') { $creds[$matches[1].Trim()] = $matches[2].Trim() }
        }
        if ($creds['USERNAME']) { $script:cachedCreds = $creds; return $creds }
    }
    return $null
}

function Save-Credentials {
    param([string]$Username, [string]$Password)
    $script:cachedCreds = @{ USERNAME = $Username; PASSWORD = $Password }
    @("USERNAME=$Username", "PASSWORD=$Password") | Set-Content -Path $script:ENV_FILE -Encoding UTF8
}

function Connect-AgentPortalWS {
    param([string]$Username, [string]$Password)
    if ($script:wsConnected) { Write-Log "Ya conectado" "WARN"; return $true }
    try {
        Write-Log "Conectando WebSocket a $($script:WS_URL)..." "INFO"
        if ($WhatIf) { Write-Log "WHATIF - Conectaria WebSocket" "INFO"; return $true }

        # TCP raw + SslStream (ClientWebSocket rechaza 'Connection: upgrade, keep-alive')
        $uri = [System.Uri]$script:WS_URL
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.ConnectAsync($uri.Host, $uri.Port).Wait(15000)
        $script:tcp = $tcp
        $netStream = $tcp.GetStream()

        # Delegate SSL via DynamicMethod IL
        $dmArgs = @([object], [System.Security.Cryptography.X509Certificates.X509Certificate], [System.Security.Cryptography.X509Certificates.X509Chain], [System.Net.Security.SslPolicyErrors])
        $dm = New-Object System.Reflection.Emit.DynamicMethod("ValidateCert", [bool], $dmArgs)
        $il = $dm.GetILGenerator()
        $il.Emit([System.Reflection.Emit.OpCodes]::Ldc_I4_1)
        $il.Emit([System.Reflection.Emit.OpCodes]::Ret)
        $sslCallback = $dm.CreateDelegate([System.Net.Security.RemoteCertificateValidationCallback])

        $ssl = New-Object System.Net.Security.SslStream($netStream, $true, $sslCallback)
        $ssl.AuthenticateAsClient($uri.Host)
        Write-Log "TLS establecido" "OK"

        # HTTP Upgrade: WebSocket handshake manual (headers identicos al navegador)
        $key = [Convert]::ToBase64String([byte[]](1..16 | ForEach-Object { Get-Random -Max 256 }))
        $upgrade = "GET $($uri.PathAndQuery) HTTP/1.1`r`n" +
                   "Host: $($uri.Host)`r`n" +
                   "Origin: https://$($uri.Host)`r`n" +
                   "Upgrade: websocket`r`n" +
                   "Connection: Upgrade`r`n" +
                   "Pragma: no-cache`r`n" +
                   "Cache-Control: no-cache`r`n" +
                   "Sec-WebSocket-Key: $key`r`n" +
                   "Sec-WebSocket-Version: 13`r`n" +
                   "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36`r`n" +
                   "Accept-Language: es-ES,es;q=0.9`r`n" +
                   "Accept-Encoding: gzip, deflate, br, zstd`r`n`r`n"
        $upgradeBytes = [System.Text.Encoding]::ASCII.GetBytes($upgrade)
        $ssl.Write($upgradeBytes, 0, $upgradeBytes.Length); $ssl.Flush()
        Write-Log "Upgrade request enviado" "OK"

        # Leer respuesta HTTP 101 con timeout async, preservando bytes sobrantes del primer frame WS
        $respList = New-Object System.Collections.Generic.List[byte]
        $buf = New-Object byte[] 4096; $done = $false; $leftover = $null
        $respSw = [System.Diagnostics.Stopwatch]::StartNew()
        $respTimeout = 10000
        while (-not $done -and $respSw.ElapsedMilliseconds -lt $respTimeout) {
            $readTask = $ssl.ReadAsync($buf, 0, $buf.Length)
            $remaining = $respTimeout - $respSw.ElapsedMilliseconds
            if ($remaining -le 0) { break }
            if (-not $readTask.Wait([Math]::Max(1, $remaining))) {
                Write-Log "Timeout leyendo respuesta HTTP ($remaining ms)" "WARN"
                break
            }
            $read = $readTask.Result
            if ($read -eq 0) { break }
            for ($i = 0; $i -lt $read; $i++) {
                $respList.Add($buf[$i])
                $c = $respList.Count
                if ($c -ge 4 -and $respList[$c-4] -eq 13 -and $respList[$c-3] -eq 10 -and $respList[$c-2] -eq 13 -and $respList[$c-1] -eq 10) {
                    $done = $true
                    if ($i + 1 -lt $read) { $leftover = @($buf[($i+1)..($read-1)]) }
                    break
                }
            }
        }
        $respText = [System.Text.Encoding]::ASCII.GetString($respList.ToArray())
        if ($respText -notmatch '101') {
            Write-Log ("Upgrade fallo: " + ($respText -split "`r`n")[0]) "ERROR"
            $tcp.Close(); return $false
        }
        Write-Log "WebSocket upgrade OK (101)" "OK"

        # WebSocket manual: stream SSL raw, bytes sobrantes en buffer
        $script:wsStream = $ssl
        $script:ws = "MANUAL"
        $script:wsBuffer = New-Object System.Collections.Generic.Queue[byte]
        if ($leftover) {
            Write-Log "Leftover: $($leftover.Count) bytes -> wsBuffer" "INFO"
            foreach ($b in $leftover) { $script:wsBuffer.Enqueue($b) }
        } else {
            Write-Log "No leftover, wsBuffer vacio" "INFO"
        }

        # Paso 1: Version
        $rid = New-RequestId; Send-WSFrame -Realm "0" -Type "65" -Data @{} -RequestId $rid
        # Paso 2: Config (enviar antes de leer por si el servidor bachea respuestas)
        $rid = New-RequestId; Send-WSFrame -Realm "9" -Type "62" -Data @{} -RequestId $rid
        $respMsgs = Read-WSFrames -Count 2 -TimeoutMs 5000
        Write-Log "Version/Config responses: $([string]::Join(' | ', $respMsgs))" "INFO"

        # Paso 3: Login
        $rid = New-RequestId
        Send-WSFrame -Realm "0" -Type "0" -Data @{
            locale = "es"; language = "es"; timezone = "Europe/Madrid"
            tenant = $Username; username = $Username; password = $Password
        } -RequestId $rid

        $response = Read-WSFrames -Count 1 -TimeoutMs 10000
        Write-Log "Login response: $response" "INFO"

        if ($response -match '"error":0') {
            Write-Log "Login correcto" "OK"
            $script:wsConnected = $true
            Save-Credentials -Username $Username -Password $Password
            # Post-login: settings + estado agente
            foreach ($s in @(@{type="517";value="PreferredDeviceLogonOption=0"}, @{type="513";value="AgentLogonMode="})) {
                $rid = New-RequestId; Send-WSFrame -Realm "0" -Type "13" -Data $s -RequestId $rid
            }
            $rid = New-RequestId; Send-WSFrame -Realm "0" -Type "47" -Data @{} -RequestId $rid
            $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
            foreach ($m in $msgs) {
                if ($m -match '"type":"47"') { try { $script:agentInfo = ($m | ConvertFrom-Json).data.result.data } catch {} }
            }
        } elseif ($response -match '"error":5') {
            # El servidor acepta el login incluso con error 5 (sesion duplicada).
            # El error 5 es informativo para la UI; el WebSocket sigue activo y la sesion funciona.
            Write-Log "Sesion ya activa (error 5) - continuando, el servidor ya acepto el login" "WARN"
            $script:wsConnected = $true
            Save-Credentials -Username $Username -Password $Password
            foreach ($s in @(@{type="517";value="PreferredDeviceLogonOption=0"}, @{type="513";value="AgentLogonMode="})) {
                $rid = New-RequestId; Send-WSFrame -Realm "0" -Type "13" -Data $s -RequestId $rid
            }
            $rid = New-RequestId; Send-WSFrame -Realm "0" -Type "47" -Data @{} -RequestId $rid
            $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
            foreach ($m in $msgs) {
                if ($m -match '"type":"47"') { try { $script:agentInfo = ($m | ConvertFrom-Json).data.result.data } catch {} }
            }
        } else {
            Write-Log "Respuesta inesperada, continuando..." "WARN"
            $script:wsConnected = $true
            Save-Credentials -Username $Username -Password $Password
        }
        return $true
    } catch {
        $ex = $_.Exception
        while ($ex.InnerException) { $ex = $ex.InnerException }
        $script:lastError = $ex.Message
        Write-Log ("Error conexion: " + $ex.Message) "ERROR"
        Close-WSConnection
        return $false
    }
}

function Set-AgentState {
    <#
    .SYNOPSIS
    Cambia el estado del agente. Estados: ENCOLA=0, REGISTRADO=1, PAUSA=2, DESCONECTADO=3
    Basado en protocolo real del HAR: realm 1 types 4/5/6, realm 2 type 1
    #>
    param([int]$State)
    if (-not $script:wsConnected) { Write-Log "No conectado" "ERROR"; return $false }
    try {
        switch ($State) {
            0 { # EN_COLA
                $rid = New-RequestId; Send-WSFrame -Realm "1" -Type "4" -Data @{} -RequestId $rid
                $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
                Write-Log "Estado -> EN_COLA" "OK"
            }
            1 { # REGISTRADO / Disponible
                $rid = New-RequestId; Send-WSFrame -Realm "1" -Type "5" -Data @{} -RequestId $rid
                $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
                Write-Log "Estado -> REGISTRADO" "OK"
            }
            2 { # PAUSA
                $rid = New-RequestId; Send-WSFrame -Realm "1" -Type "6" -Data @{} -RequestId $rid
                $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
                Write-Log "Estado -> PAUSA" "OK"
            }
            3 { # DESCONECTAR
                $rid = New-RequestId; Send-WSFrame -Realm "2" -Type "1" -Data @{} -RequestId $rid
                $msgs = Read-WSFrames -Count 2 -TimeoutMs 5000
                Write-Log "Estado -> DESCONECTADO" "OK"
            }
        }
        # Parse push notification for state update
        foreach ($m in $msgs) {
            if ($m -match '"type":"15"') {
                try { $data = $m | ConvertFrom-Json; $script:agentInfo = @{userRoutingState = $data.data.data} } catch {}
            }
        }
        Refresh-AgentState | Out-Null
        return $true
    } catch {
        $ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
        $script:lastError = "Error estado: " + $ex.Message
        Write-Log $script:lastError "ERROR"
        return $false
    }
}

function Send-AgentLogon {
    <#
    .SYNOPSIS
    Conecta el agente a la cola (logon). Equivalente a realm 2, type 0 del HAR.
    #>
    param([string]$Extension)
    if (-not $script:wsConnected) { Write-Log "No conectado" "ERROR"; return $false }
    try {
        $rid = New-RequestId
        Send-WSFrame -Realm "2" -Type "0" -Data @{extension = $Extension; autoLogon = $true} -RequestId $rid
        $msgs = Read-WSFrames -Count 3 -TimeoutMs 5000
        Write-Log "Logon enviado para extension $Extension" "OK"
        return $true
    } catch {
        Write-Log ("Error en logon: " + $_.Exception.Message) "ERROR"
        return $false
    }
}

function Refresh-AgentState {
    if (-not $script:wsConnected) { return $null }
    try {
        $rid = New-RequestId
        Send-WSFrame -Realm "0" -Type "47" -Data @{} -RequestId $rid
        $msgs = Read-WSFrames -Count 3 -TimeoutMs 5000
        foreach ($m in $msgs) {
            if ($m -match '"type":"47"') {
                try { $data = $m | ConvertFrom-Json; $script:agentInfo = $data.data.result.data } catch {}
            }
        }
        # Query team agents (realm 3, type 57 = team bar)
        $rid = New-RequestId
        Send-WSFrame -Realm "3" -Type "57" -Data @{tabId = "0"; opening = $true} -RequestId $rid
        $msgs2 = Read-WSFrames -Count 2 -TimeoutMs 5000
        foreach ($m in $msgs2) {
            if ($m -match '"type":"23"') {
                try { $data = $m | ConvertFrom-Json; $script:teamAgents = $data.data.data.agents } catch {}
            }
        }
    } catch {}
    return $script:agentInfo
}

# ============================================================
# BROWSER MANAGEMENT
# ============================================================

function Open-AgentPortal {
    try {
        Write-Log "Abriendo Agent Portal..." "INFO"
        if ($WhatIf) { Write-Log "WHATIF - Abriria: $($script:AGENT_PORTAL_URL)" "INFO"; return }
        Start-Process $script:AGENT_PORTAL_URL
    } catch {
        Write-Log ("Error: " + $_.Exception.Message) "ERROR"
    }
}

function Open-PortalSection {
    param([string]$Section)
    $url = "https://hppcgroup.cccdm-rcja.juntadeandalucia.es/agentportal/#/$Section"
    try { Start-Process $url } catch { Write-Log ("Error: " + $_.Exception.Message) "ERROR" }
}

# ============================================================
# SCREENS
# ============================================================

function screen-main {
    ui
    # Main loop: dashboard + key actions
    while ($true) {
        if ($script:wsConnected) {
            Refresh-AgentState | Out-Null
        }
        header
        $w = $script:columns

        # Error persistente (se muestra hasta nueva accion)
        if ($script:lastError) {
            Write-Host ("|  ERROR: " + $script:lastError).PadRight($w-1) -ForegroundColor Red -NoNewline
            Write-Host "|" -ForegroundColor DarkGray
            Write-Host ""
        }

        # Panel: MI ESTADO
        if ($script:agentInfo.userRoutingState) {
            $name = if ($script:agentInfo.userRoutingState.userName) { $script:agentInfo.userRoutingState.userName } else { "Agente $($script:agentInfo.userRoutingState.tenant)" }
            $rs = Get-StateName $script:agentInfo.userRoutingState.routingState
            $ps = Get-PresenceName "$($script:agentInfo.userRoutingState.presenceState)"
            $rc = switch ($script:agentInfo.userRoutingState.routingState) { "0" { "Green" } "1" { "Cyan" } "2" { "Yellow" } "3" { "Red" } default { "White" } }
            Write-Host (".- " + (" " * ($w - 6)) + ".") -ForegroundColor Cyan
            Write-Host ("|  $name").PadRight($w-1) -NoNewline; Write-Host "|" -ForegroundColor DarkGray
            Write-Host ("|  " + $rs + " / " + $ps).PadRight($w-1) -ForegroundColor $rc -NoNewline; Write-Host "|" -ForegroundColor DarkGray
            Write-Host ("|  Ext: " + $script:agentInfo.userRoutingState.extension).PadRight($w-1) -ForegroundColor DarkGray -NoNewline; Write-Host "|" -ForegroundColor DarkGray
            Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor Cyan
        } elseif ($script:wsConnected) {
            Write-Host (".- " + (" " * ($w - 6)) + ".") -ForegroundColor Cyan
            Write-Host ("|  CONECTADO - esperando datos del agente...").PadRight($w-1) -ForegroundColor Yellow -NoNewline; Write-Host "|" -ForegroundColor DarkGray
            Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor Cyan
        } else {
            Write-Host (".- " + (" " * ($w - 6)) + ".") -ForegroundColor DarkGray
            Write-Host ("|  SIN CONEXION (pulsa C)").PadRight($w-1) -ForegroundColor Yellow -NoNewline; Write-Host "|" -ForegroundColor DarkGray
            Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor DarkGray
        }

        # Panel: EQUIPO
        if ($script:teamAgents -and $script:teamAgents.Count -gt 0) {
            Write-Host ""
            $n = [Math]::Min(12, $script:teamAgents.Count)
            Write-Host (".- EQUIPO ($n)" + (" " * ($w - 13 - "$n".Length)) + ".") -ForegroundColor Cyan
            for ($i = 0; $i -lt $n; $i++) {
                $a = $script:teamAgents[$i]
                $ars = Get-StateName $a.routingState
                $aps = Get-PresenceName $a.presenceState
                $aname = if ($a.userName) { $a.userName.PadRight(20).Substring(0,20) } else { $a.extension.PadRight(20).Substring(0,20) }
                $ac = switch ($a.routingState) { "0" { "Green" } "1" { "Cyan" } "2" { "Yellow" } "3" { "Red" } default { "White" } }
                Write-Host ("|  " + $aname) -NoNewline
                $line = "  " + $ars.PadRight(14) + $aps
                Write-Host $line -ForegroundColor $ac
            }
            Write-Host ("'" + ("-" * ($w - 2)) + "'") -ForegroundColor Cyan
        }

        # Footer con teclas rapidas
        Write-Host ""
        $keys = @("O=OpenScape", "C=Conexion", "R=Refresh", "Q=Colas", "B=Navegador")
        $keys += @("1=EnCola", "2=Registrado", "3=Pausa", "4=Desconectar", "L=Logon")
        $keys += @("0=Salir")
        $kText = ($keys -join " | ")
        Write-Host ("  " + $kText) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Tecla: " -ForegroundColor Yellow -NoNewline

        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Escape) { return "exit" }
        $k = $key.KeyChar.ToString().ToUpper()
        Write-Host $k -ForegroundColor Cyan
        Write-Host ""

        switch ($k) {
            "O" {
                $script:lastError = $null
                if ($script:openscapeRunning) { Stop-OpenScape } else { Start-OpenScape }
            }
            "C" {
                $script:lastError = $null
                if ($script:wsConnected) { Close-WSConnection; Start-Sleep -Milliseconds 200 }
                else {
                    $creds = Get-Credentials
                    if (-not $creds) {
                        ui; header
                        panel "CREDENCIALES" { Write-Host "|  Usuario: 1472" -ForegroundColor DarkGray; Write-Host "|  Pass: 1472" -ForegroundColor DarkGray }
                        $u = prompt "Usuario: " "1472"; $p = prompt "Pass: " "1472"
                        if (Connect-AgentPortalWS -Username $u -Password $p) { Refresh-AgentState | Out-Null }
                    } else {
                        $ok = $false
                        for ($attempt = 1; $attempt -le 2; $attempt++) {
                            if (Connect-AgentPortalWS -Username $creds['USERNAME'] -Password $creds['PASSWORD']) {
                                Refresh-AgentState | Out-Null; $ok = $true; break
                            }
                            if ($script:lastError -notmatch "Sesion ya activa") { break }
                        }
                        if (-not $ok) { Write-Log "No se pudo conectar. Cierra el navegador y pulsa C." "ERROR" }
                    }
                }
            }
            "R" { $script:lastError = $null; Refresh-AgentState | Out-Null }
            "Q" { screen-queues }
            "B" { Open-AgentPortal }
            "1" { $script:lastError = $null; if ($script:wsConnected) { Set-AgentState -State 0 } else { Write-Log "No conectado" "WARN" } }
            "2" { $script:lastError = $null; if ($script:wsConnected) { Set-AgentState -State 1 } else { Write-Log "No conectado" "WARN" } }
            "3" { $script:lastError = $null; if ($script:wsConnected) { Set-AgentState -State 2 } else { Write-Log "No conectado" "WARN" } }
            "4" { $script:lastError = $null; if ($script:wsConnected) { Set-AgentState -State 3 } else { Write-Log "No conectado" "WARN" } }
            "L" {
                $script:lastError = $null
                if ($script:wsConnected) { Send-AgentLogon -Extension $script:OPENSCAPE_EXT }
                else { Write-Log "No conectado" "WARN" }
            }
            "0" { return "exit" }
            default { Write-Log "Tecla no valida" "WARN" }
        }
        Write-Host ""
        if ($k -eq "O" -or $k -eq "C" -or $k -eq "R" -or $k -eq "1" -or $k -eq "2" -or $k -eq "3" -or $k -eq "4" -or $k -eq "L") {
            Start-Sleep -Milliseconds 300
        }
    }
}

function screen-openscape {
    ui; header
    panel "GESTION DE OPENSCAPE" {
        Write-Host "|  1. Verificar estado" -ForegroundColor Cyan
        Write-Host "|  2. Iniciar OpenScape" -ForegroundColor Cyan
        Write-Host "|  3. Detener OpenScape" -ForegroundColor Red
        Write-Host "|  0. Volver" -ForegroundColor Red
    }
    $opt = prompt "Opcion: " "0"
    switch ($opt) {
        "1" { Test-OpenScape; pause }
        "2" { Start-OpenScape; pause }
        "3" { Stop-OpenScape; pause }
    }
}

function screen-ws-connect {
    ui; header
    if ($script:wsConnected) {
        panel "CONEXION WEBSOCKET" {
            Write-Host "|  Estado: CONECTADO" -ForegroundColor Green
            Write-Host "|  1. Desconectar" -ForegroundColor Red
            Write-Host "|  0. Volver" -ForegroundColor Red
        }
        $opt = prompt "Opcion: " "0"
        if ($opt -eq "1") { Close-WSConnection; pause }
        return
    }
    $creds = Get-Credentials
    if (-not $creds) {
        panel "CONECTAR AGENT PORTAL" {
            Write-Host "|  Introduce tus credenciales de Agent Portal." -ForegroundColor DarkGray
            Write-Host "|  (Abonado se deja por defecto, NO se toca)" -ForegroundColor Yellow
            Write-Host "|"
        }
        $usr = prompt "Usuario: " "1472"
        $pass = prompt "Contrasena: " "1472"
    } else {
        $usr = $creds['USERNAME']; $pass = $creds['PASSWORD']
        Write-Log "Usando credenciales guardadas" "INFO"
    }
    if (Connect-AgentPortalWS -Username $usr -Password $pass) {
        Write-Log "Conectado a Agent Portal" "OK"
    }
    pause
}

function screen-team-status {
    ui;     header
    if (-not $script:wsConnected) {
        panel "SIN CONEXION" { Write-Host "|  Conecta primero (opcion 2)" -ForegroundColor Yellow }
        pause; return
    }
    Write-Log "Actualizando estado..." "INFO"
    Refresh-AgentState
    if ($script:agentInfo.userRoutingState) {
        $name = if ($script:agentInfo.userRoutingState.userName) { $script:agentInfo.userRoutingState.userName } else { $script:agentInfo.userRoutingState.tenant }
        $rs = Get-StateName $script:agentInfo.userRoutingState.routingState
        $ps = Get-PresenceName "$($script:agentInfo.userRoutingState.presenceState)"
        panel "MI ESTADO" {
            row "Agente" $name "Green"
            row "Extension" $script:agentInfo.userRoutingState.extension
            row "Routing" $rs "Green"
            row "Presencia" $ps
            if ($script:agentInfo.userMediaStates) {
                foreach ($m in $script:agentInfo.userMediaStates) {
                    $mt = switch ($m.media) { "1" { "Voz" } "2" { "Email" } "3" { "Callback" } "4" { "WebChat" } "5" { "OpenMedia" } default { "Media$($m.media)" } }
                    $ms = if ($m.state -eq "0") { "Off" } else { "On" }
                    row $mt $ms
                }
            }
        }
    } else {
        panel "MI ESTADO" { Write-Host "|  Sin datos" -ForegroundColor Yellow }
    }
    if ($script:teamAgents -and $script:teamAgents.Count -gt 0) {
        panel "EQUIPO ($($script:teamAgents.Count) agentes)" {
            foreach ($a in $script:teamAgents) {
                $ars = Get-StateName $a.routingState
                $aps = Get-PresenceName $a.presenceState
                $aname = if ($a.userName) { $a.userName } else { $a.extension }
                $ac = switch ($a.routingState) { "0" { "Green" } "1" { "Cyan" } "2" { "Yellow" } "3" { "Red" } default { "White" } }
                Write-Host ("|  " + $aname.PadRight(20)) -NoNewline
                Write-Host $ars.PadRight(14) -ForegroundColor $ac -NoNewline
                Write-Host $aps -ForegroundColor $ac
            }
        }
    }
    Write-Host ""
    Write-Host "  1. Refrescar" -ForegroundColor Cyan
    Write-Host "  2. Cambiar estado" -ForegroundColor Cyan
    Write-Host "  0. Volver" -ForegroundColor Red
    $opt = prompt "Opcion: " "0"
    if ($opt -eq "1") { screen-team-status }
    if ($opt -eq "2") { screen-change-state }
}

function screen-change-state {
    ui; header
    if (-not $script:wsConnected) {
        panel "SIN CONEXION" { Write-Host "|  Conecta primero (opcion 2)" -ForegroundColor Yellow }
        pause; return
    }
    Refresh-AgentState
    $name = if ($script:agentInfo.userRoutingState.userName) { $script:agentInfo.userRoutingState.userName } else { "Agente" }
    $curr = if ($script:agentInfo.userRoutingState) { Get-StateName $script:agentInfo.userRoutingState.routingState } else { "DESCONOCIDO" }
    panel "CAMBIAR ESTADO - $name" {
        Write-Host "|  Estado actual: " -NoNewline; Write-Host $curr -ForegroundColor Green
        Write-Host "|"
        Write-Host "|  1. EN COLA (Disponible para llamadas)" -ForegroundColor Cyan
        Write-Host "|  2. REGISTRADO (Disponible, sin cola)" -ForegroundColor Cyan
        Write-Host "|  3. PAUSA / AUSENTE" -ForegroundColor Yellow
        Write-Host "|  4. DESCONECTAR" -ForegroundColor Red
        Write-Host "|  5. LOGON (conectar a cola)" -ForegroundColor Cyan
        Write-Host "|"
        Write-Host "|  0. Volver" -ForegroundColor Red
    }
    $opt = prompt "Opcion: " "0"
    switch ($opt) {
        "1" { if (Set-AgentState -State 0) { Write-Log "Estado cambiado a EN COLA" "OK" } else { Write-Log "Error" "ERROR" }; pause }
        "2" { if (Set-AgentState -State 1) { Write-Log "Estado cambiado a REGISTRADO" "OK" } else { Write-Log "Error" "ERROR" }; pause }
        "3" { if (Set-AgentState -State 2) { Write-Log "Estado cambiado a PAUSA" "OK" } else { Write-Log "Error" "ERROR" }; pause }
        "4" { if (Set-AgentState -State 3) { Write-Log "Estado cambiado a DESCONECTADO" "OK" } else { Write-Log "Error" "ERROR" }; pause }
        "5" {
            $ext = prompt "Extension: " $script:OPENSCAPE_EXT
            if (Send-AgentLogon -Extension $ext) { Write-Log "Logon enviado" "OK" } else { Write-Log "Error" "ERROR" }
            pause
        }
    }
}

function screen-queues {
    ui; header
    if (-not $script:wsConnected) {
        panel "SIN CONEXION" { Write-Host "|  Conecta primero (opcion 2)" -ForegroundColor Yellow }
        pause; return
    }
    Write-Log "Solicitando estado de colas..." "INFO"
    Refresh-AgentState
    if ($script:queueStats) {
        panel "COLAS DE ESPERA" {
            row "Llamadas" "$($script:queueStats.totalTelephonyContactsWaiting)" "Cyan"
            row "Callbacks" "$($script:queueStats.totalCallbackContactsWaiting)" "Cyan"
            row "WebChats" "$($script:queueStats.totalWebChatContactsWaiting)" "Cyan"
            row "Emails" "$($script:queueStats.totalEmailContactsWaiting)" "Cyan"
        }
    } else {
        panel "COLAS DE ESPERA" {
            Write-Host "|  Los datos de colas se reciben via eventos push." -ForegroundColor DarkGray
            Write-Host "|  Abre el portal web para ver datos en tiempo real." -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  1. Abrir seccion de colas en navegador" -ForegroundColor Cyan
        $opt = prompt "Opcion: " "0"
        if ($opt -eq "1") { Open-PortalSection -Section "home/active-contacts"; pause }
        return
    }
    pause
}

function screen-quick-links {
    ui; header
    panel "ACCESOS DIRECTOS DEL PORTAL" {
        Write-Host "|  1. Dashboard (contactos activos)" -ForegroundColor Cyan
        Write-Host "|  2. Agentes" -ForegroundColor Cyan
        Write-Host "|  3. Colas de espera" -ForegroundColor Cyan
        Write-Host "|  4. Speed bar (marcacion rapida)" -ForegroundColor Cyan
        Write-Host "|  5. Team bar (equipo)" -ForegroundColor Cyan
        Write-Host "|  6. Chat agents" -ForegroundColor Cyan
        Write-Host "|  7. Ajustes" -ForegroundColor Cyan
        Write-Host "|  0. Volver" -ForegroundColor Red
    }
    $opt = prompt "Opcion: " "0"
    switch ($opt) {
        "1" { Open-PortalSection "home/active-contacts" }
        "2" { Open-PortalSection "home/active-contacts" }
        "3" { Open-PortalSection "home/active-contacts" }
        "4" { Open-PortalSection "speed-bar" }
        "5" { Open-PortalSection "team-bar" }
        "6" { Open-PortalSection "chat-agents" }
        "7" { Open-PortalSection "home/active-contacts" }
    }
    pause
}

# ============================================================
# MAIN
# ============================================================

try {
    Test-OpenScape
    $creds = Get-Credentials
    if ($creds) {
        Write-Log "Credenciales encontradas, conectando automaticamente..." "INFO"
        Connect-AgentPortalWS -Username $creds['USERNAME'] -Password $creds['PASSWORD'] | Out-Null
    }
    $running = $true
    while ($running) {
        $result = screen-main
        if ($result -eq "exit") { $running = $false }
    }
} finally {
    Close-WSConnection
    ui; header
    Write-Host ("." + ("-" * ($script:columns - 2)) + ".") -ForegroundColor DarkGray
    Write-Host ("|" + (" " * ($script:columns - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("|  LAZYAGENTPORTAL finalizado" + (" " * ($script:columns - 30)) + "|") -ForegroundColor Yellow
    Write-Host ("|" + (" " * ($script:columns - 2)) + "|") -ForegroundColor DarkGray
    Write-Host ("'" + ("-" * ($script:columns - 2)) + "'") -ForegroundColor DarkGray
    Write-Host ""
}
