param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
Import-Module Microsoft.PowerShell.Utility
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/scrape_wiki.ps1'),[ref]$t,[ref]$e)
$sessionParam=@($ast.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -eq 'WebSession'})
if ($sessionParam.Count -ne 1 -or $sessionParam[0].StaticType -ne [Microsoft.PowerShell.Commands.WebRequestSession]) {throw 'FAIL: wiki scraper must accept supplied authenticated session, not embedded cookies'}
$cookieCalls=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'newCookie'},$true)
if ($cookieCalls.Count) {throw 'FAIL: embedded session cookies remain'}
$WebSession=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$sessionAssign=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$Global:session'},$true)
. ([scriptblock]::Create($sessionAssign.Extent.Text))
if (-not [object]::ReferenceEquals($Global:session,$WebSession)) {throw 'FAIL: supplied wiki session was discarded'}
Write-Output 'PASS: wiki retains caller session with no embedded cookies; no HTTP'
