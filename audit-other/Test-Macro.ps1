param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$path=Join-Path $Repo 'Macro Remedy/verificar_indices.ps1'
$exe=(Get-Process -Id $PID).Path
# Full read-only verifier, in its own process because it uses exit.
$output=& $exe -NoProfile -File $path 2>&1
if ($LASTEXITCODE -ne 0) { throw 'FAIL: real macro index verifier rejected real ARCmds; AHK not executed' }
Write-Output 'PASS: real macro index verifier and 46 real ARCmds; AHK/GUI/macros not executed'
