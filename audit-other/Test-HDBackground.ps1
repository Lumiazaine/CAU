param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
$text=$ast.Extent.Text
$start=$text.IndexOf('$bgRunspace =')
$end=$text.IndexOf('# Loop principal:')
$block=$text.Substring($start,$end-$start)
$fn=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-HelpdeskEntries'},$true) | Select-Object -Last 1
# The only replaced boundary is the external COM query; actual runspace startup/communication executes.
$block=$block.Replace($fn.Extent.Text,'function Get-HelpdeskEntries { return ,@() }')
$script:cacheRefreshSec=1
$script:server='offline.invalid'; $script:form='FIXTURE'; $script:qual='FIXTURE'
$script:lock=New-Object System.Threading.Mutex $false
try {
    . ([scriptblock]::Create($block))
    Start-Sleep -Milliseconds 1500
    if (-not $bgState -or -not $bgState.Pending -or $null -eq $bgState.Entries -or $bgState.Entries.Count -ne 0) {throw 'FAIL: background worker must publish empty cache across runspaces'}
    if ($bgPs.Streams.Error.Count) {throw 'FAIL: background worker emitted errors'}
    Write-Output 'PASS: real background worker publishes zero tickets to foreground; COM fixture only'
} finally {
    if ($bgState) {$bgState.Stop=$true}
    if ($bgPs) {$bgPs.Stop();$bgPs.Dispose()}
    if ($bgRunspace) {$bgRunspace.Dispose()}
    $script:lock.Dispose()
}
