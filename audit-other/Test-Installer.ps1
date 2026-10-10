param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'instalar.ps1'),[ref]$t,[ref]$e)
$assignment=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$functions'},$true)
$text=$assignment.Right.Expression.Value
if ($text -match 'raw\.githubusercontent|\birm\b|scriptblock\]::Create') { throw 'FAIL: installed shortcuts evaluate mutable remote code' }
$text=$text.Replace('__CAU_ROOT__',$Repo.Replace("'","''"))
$defs=[System.Management.Automation.Language.Parser]::ParseInput($text,[ref]$t,[ref]$e)
if ($e.Count) { throw 'FAIL: generated shortcut syntax' }
# Only local definitions/CAUInstallRoot assignment; do not install or reload a profile.
. ([scriptblock]::Create($text))
$fixtureRoot=Join-Path $PSScriptRoot 'installer-fixture'
try {
    foreach ($pair in @(@('Temis','cambiar_password_temis.ps1'),@('Directorio correo','cambiar_password_correo.ps1'),@('lazydirectory','lazydirectory.ps1'))) {
        $dir=Join-Path $fixtureRoot $pair[0]
        $null=New-Item $dir -ItemType Directory -Force
        # Match the real target parameter types; a string-only stub hid SecureString corruption.
        $passwordType = if ($pair[0] -eq 'Directorio correo') { 'Security.SecureString' } else { 'string' }
        $fixture = 'param([string]$TemisUser,[string]$TargetUser,[' + $passwordType + ']$NewPassword,[switch]$PersistCredentials,[switch]$WhatIf,[switch]$Interno,[switch]$ShowBrowser); [pscustomobject]@{TemisUser=$TemisUser;TargetUser=$TargetUser;NewPassword=$NewPassword;PersistCredentials=[bool]$PersistCredentials;WhatIf=[bool]$WhatIf;Interno=[bool]$Interno}'
        $fixture | Set-Content (Join-Path $dir $pair[1]) -Encoding UTF8
    }
    $global:CAUInstallRoot=$fixtureRoot
    $r=temis -TemisUser 'OFFLINE' -WhatIf
    if (-not $r.WhatIf -or $r.TemisUser -ne 'OFFLINE') { throw 'FAIL: temis WhatIf forwarding' }
    $r=ldap -correo 'OFFLINE' -Interno -WhatIf
    if (-not $r.WhatIf -or -not $r.Interno -or $r.TargetUser -ne 'OFFLINE') { throw 'FAIL: ldap parameters forwarding' }
    $password = ConvertTo-SecureString 'SYNTHETIC-NOT-A-CREDENTIAL' -AsPlainText -Force
    $r=ldap -correo 'OFFLINE' -NewPassword $password -Interno -WhatIf
    if (-not [object]::ReferenceEquals($r.NewPassword,$password)) { throw 'FAIL: ldap shortcut must preserve SecureString identity' }
    $r=lazydirectory -WhatIf
    if (-not $r.WhatIf) { throw 'FAIL: lazydirectory WhatIf forwarding' }
    $r=ldap -correo 'OFFLINE' -NewPassword $password -WhatIf -PersistCredentials
    if (-not $r.PersistCredentials) { throw 'FAIL: ldap PersistCredentials forwarding' }
    $r=lazydirectory -WhatIf -PersistCredentials
    if (-not $r.PersistCredentials) { throw 'FAIL: lazydirectory PersistCredentials forwarding' }
    $profileTarget=Join-Path $fixtureRoot 'profile-fixture.ps1'
    $content='function temis {} function ldap {} function lazydirectory {}'
    Set-Content -Path $profileTarget -Value $content -Encoding UTF8
    $PROFILE=$profileTarget
    $functions=$text
    $migration=$ast.Find({param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Extent.Text -match '\$content' -and $n.Extent.Text -match 'Add-Content'},$true)
    & ([scriptblock]::Create($migration.Extent.Text))
    if (-not (Get-Content $profileTarget -Raw).Contains($text.Trim())) { throw 'FAIL: existing shortcuts must migrate to local definitions' }
    Write-Output 'PASS: installer local shortcuts, switch forwarding and sandbox profile migration; real profile untouched'
} finally { Remove-Item $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue }
