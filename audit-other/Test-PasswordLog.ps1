param([string]$Repo=(Split-Path $PSScriptRoot -Parent),[ValidateSet('correo','temis','lazydirectory','lazytemis')][string]$Case='correo')
$ErrorActionPreference='Stop'
$map=@{correo='Directorio correo/cambiar_password_correo.ps1';temis='Temis/cambiar_password_temis.ps1';lazydirectory='lazydirectory/lazydirectory.ps1';lazytemis='lazytemis/lazytemis.ps1'}
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $map[$Case]),[ref]$t,[ref]$e)
if($e.Count){throw 'FAIL: syntax'}
$script:messages=@()
function Write-Log {param([string]$Message,[string]$Level);$script:messages+=$Message}
$NewPassword='OFFLINE_SECRET_SENTINEL'
# Execute only individual, reviewed log calls containing a password variable.
# No password-changing function/entrypoint, disk logger or web request runs.
$calls=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Write-Log' -and $n.Extent.Text -match '\$NewPassword\b'},$true)
foreach($call in $calls){& ([scriptblock]::Create($call.Extent.Text))}
if(($script:messages -join ';').Contains($NewPassword)){throw "FAIL: $Case writes destination password to log"}
Write-Output "PASS: $Case password not interpolated into log calls"
