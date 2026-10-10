param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
$fn=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-TicketDetail'},$true)
$table=$fn.Find({param($n) $n -is [System.Management.Automation.Language.HashtableAst]},$true)
# Execute the real field mapping only, never acquire COM or query Remedy.
$lf=New-Object PSObject
$lf | Add-Member ScriptMethod GetFieldById { param($id) if ($id -eq 7) {throw 'synthetic unavailable field'}; [pscustomobject]@{Value="fixture-$id"} }
$entryId='IN000000001'
$detail=& ([scriptblock]::Create($table.Extent.Text))
if ($detail.estado -ne '' -or $detail.dni -ne 'fixture-1010000170' -or $detail.id -ne $entryId) {throw 'FAIL: real detail mapping does not evaluate try/catch as expressions'}
Write-Output 'PASS: all detail fields evaluate on PS5.1; missing field returns empty; no COM'
