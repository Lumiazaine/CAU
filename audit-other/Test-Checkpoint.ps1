param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$null=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Scripts/Checkpoint_checker.ps1'),[ref]$t,[ref]$e)
if ($e.Count) { throw 'FAIL: Checkpoint PS entrypoint contains batch syntax' }
$temp=Join-Path $PSScriptRoot 'checkpoint-fixture.ps1'
try {
    @'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
$global:LASTEXITCODE=0
$Arguments -join '|'
'@ | Set-Content -Path $temp -Encoding UTF8
    $out=@(& (Join-Path $Repo 'Scripts/Checkpoint_checker.ps1') -VpnCommand $temp -ListOnly)
    if ($out.Count -ne 1 -or $out[0] -ne 'list') { throw 'FAIL: ListOnly must not start or connect VPN' }
    $out=@(& (Join-Path $Repo 'Scripts/Checkpoint_checker.ps1') -VpnCommand $temp -SiteName 'offline.invalid')
    if (($out -join ';') -ne 'list;start;connectgui|-s|offline.invalid') { throw 'FAIL: VPN command sequence' }
    $failed=$false
    try { & (Join-Path $Repo 'Scripts/Checkpoint_checker.ps1') -VpnCommand "$temp.missing" -ListOnly } catch { $failed=$true }
    if (-not $failed) { throw 'FAIL: missing client must fail' }
    Write-Output 'PASS: checkpoint offline fake command; no VPN calls'
} finally { Remove-Item $temp -ErrorAction SilentlyContinue }
