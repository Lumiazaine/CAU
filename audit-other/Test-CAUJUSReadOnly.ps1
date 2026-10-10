param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
function Load-Function($file,$name) {
    $t=$null;$e=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $file),[ref]$t,[ref]$e)
    $fn=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    . ([scriptblock]::Create($fn.Extent.Text.Replace("function $name","function script:$name")))
}
function Write-CAULog {param($Message,$Level)}
Load-Function 'Scripts/CAUJUS.ps1' 'Get-CAUSystemInfo'
$Global:CAUSession=@{}
# Real host read-only WMI queries; no environment initialization, logging or menu.
Get-CAUSystemInfo
if (-not $Global:CAUSession.SystemInfo.ComputerName -or -not $Global:CAUSession.SystemInfo.OSVersion -or $Global:CAUSession.SystemInfo.TotalMemory -le 0) {throw 'FAIL: CAUJUS read-only system information'}
foreach($file in @('Scripts/CAUJUS_PowerShell_v3.ps1','Otros_AD/CAUJUS_PowerShell_v3.ps1')) {
    Load-Function $file 'Get-SystemSummary'
    $summary=Get-SystemSummary
    if (-not $summary.OS -or -not $summary.SN -or -not $summary.Build) {throw "FAIL: read-only summary shape in $file"}
}
Write-Output 'PASS: 3 real CAUJUS system-summary functions; host metadata omitted; no repairs or AD'
