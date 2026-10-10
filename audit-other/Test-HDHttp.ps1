param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
Import-Module Microsoft.PowerShell.Utility
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
if ($e.Count) { throw 'FAIL: production source parser' }
$source=$ast.Extent.Text
# Ephemeral loopback port and synthetic token; never acquire Remedy or credentials.
$socket=New-Object System.Net.Sockets.TcpListener ([Net.IPAddress]::Loopback),0
$socket.Start(); $port=$socket.LocalEndpoint.Port; $socket.Stop()
$source=$source.Replace('$script:cacheRefreshSec = 120','$script:cacheRefreshSec = 1')
$source=$source.Replace('$script:dashboardRoot = $PSScriptRoot',('$script:dashboardRoot = '''+(Join-Path $Repo 'Proyecto_HD').Replace("'","''")+''''))
$queryFunctions=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-HelpdeskEntries'},$true))
if ($queryFunctions.Count -ne 2) {throw 'FAIL: both COM query boundaries must be stubbed'}
foreach($fn in $queryFunctions) {
    $source=$source.Replace($fn.Extent.Text,'function Get-HelpdeskEntries { return ,@() }')
}
$token='OFFLINE-fixture-token-abcdefghijklmnopqrstuvwxyz-0123456789'
$secureToken=ConvertTo-SecureString $token -AsPlainText -Force
$headers=@{Authorization='Bearer '+$token}
$hostPs=[PowerShell]::Create()
$null=$hostPs.AddScript($source).AddParameter('Port',$port).AddParameter('AccessToken',$secureToken)
try {
    $task=$hostPs.BeginInvoke()
    $url="http://localhost:$port/api/helpdesk"
    $ready=$false
    for($i=0;$i -lt 20;$i++) {
        if ($task.IsCompleted) { throw 'FAIL: isolated HTTP host exited early' }
        try { $r=Invoke-WebRequest $url -Headers $headers -UseBasicParsing -TimeoutSec 2; $ready=$true; break } catch {Start-Sleep -Milliseconds 100}
    }
    if (-not $ready) {throw 'FAIL: isolated HTTP listener did not start'}
    $data=$r.Content | ConvertFrom-Json
    if ($r.StatusCode -ne 200 -or -not $data.ok -or $data.count -ne 0 -or $null -eq $data.data) {throw 'FAIL: HTTP empty cache response'}
    if ($r.Headers['Access-Control-Allow-Origin'] -or $r.Headers['Cache-Control'] -ne 'no-store') {throw 'FAIL: HTTP response security headers'}
    $rejected=$false
    try { $null=Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3 } catch { $rejected=([int]$_.Exception.Response.StatusCode -eq 401) }
    if (-not $rejected) {throw 'FAIL: anonymous real HTTP request not rejected'}
    $page=Invoke-WebRequest "http://localhost:$port/" -UseBasicParsing -TimeoutSec 3
    if ($page.StatusCode -ne 200 -or $page.Content -notmatch 'hdConnectBtn') {throw 'FAIL: public dashboard unavailable'}
    # Request arrives after the real 5s polling timeout, not before it.
    Start-Sleep -Seconds 6
    $r=Invoke-WebRequest $url -Headers $headers -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -ne 200) {throw 'FAIL: late HTTP request lost'}
    if ($hostPs.Streams.Error.Count) {throw 'FAIL: HTTP host emitted errors'}
    Write-Output 'PASS: real loopback authenticated HTTP200, anonymous HTTP401, public dashboard and late request after 6s; real worker, no corporate calls'
} finally {
    $hostPs.Stop();$hostPs.Dispose()
    $probe=New-Object Net.Sockets.TcpClient
    try {
        $closed=$false
        try { $probe.Connect('127.0.0.1',$port) } catch { $closed=$true }
        if (-not $closed) {throw 'FAIL: staged HTTP listener remains open after cleanup'}
    } finally { $probe.Dispose() }
}
