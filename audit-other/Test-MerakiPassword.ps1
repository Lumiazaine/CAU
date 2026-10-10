param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Scripts/Meraki.ps1'),[ref]$t,[ref]$e)
$secretParam=@($ast.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -eq 'AccountPassword'})
if ($secretParam.Count -ne 1 -or $secretParam[0].StaticType -ne [System.Security.SecureString] -or $secretParam[0].DefaultValue) {throw 'FAIL: Meraki must require explicit SecureString, never an embedded password'}
$AccountPassword=ConvertTo-SecureString 'OFFLINE-only-fixture' -AsPlainText -Force
$assign=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$securePassword'},$true)
. ([scriptblock]::Create($assign.Extent.Text))
if (-not [object]::ReferenceEquals($securePassword,$AccountPassword)) {throw 'FAIL: caller supplied secure password was not preserved'}
Write-Output 'PASS: Meraki requires and preserves explicit SecureString; no AD writes'
