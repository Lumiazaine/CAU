param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
foreach($file in @('Otros_AD/localizador.ps1','Otros_AD/rastreator.ps1')) {
    $t=$null;$e=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $file),[ref]$t,[ref]$e)
    $functions=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)
    foreach($fn in $functions) {. ([scriptblock]::Create($fn.Extent.Text))}
    $assignment=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$Filtro'},$true)
    $command=$ast.Find({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Get-ADUser'},$true)
    function Get-ADUser {param($Filter,$LDAPFilter,$Server,$Properties,$ErrorAction); $script:Captured=$LDAPFilter}
    $Busqueda="O'Neil*)(uid=*)\"+[char]0
    . ([scriptblock]::Create($assignment.Extent.Text))
    . ([scriptblock]::Create($command.Extent.Text))
    $expected="(|(sAMAccountName=*O'Neil\2a\29\28uid=\2a\29\5c\00*)(name=*O'Neil\2a\29\28uid=\2a\29\5c\00*)(displayName=*O'Neil\2a\29\28uid=\2a\29\5c\00*))"
    if ($script:Captured -cne $expected) {throw "FAIL: literal LDAP search must escape special input in $file"}
}
Write-Output 'PASS: both real search handlers escape RFC4515 special input; no AD/GUI'
