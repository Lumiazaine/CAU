param([string]$Repo=(Split-Path $PSScriptRoot -Parent),[string]$Case='uo')
$ErrorActionPreference='Stop'
function Parse-Source($File){$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $File),[ref]$t,[ref]$e);if($e.Count){throw 'FAIL: production parser'};return $a}
function Load-Fn($File,$Name){$a=Parse-Source $File;$f=$a.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true);if(-not $f){throw "FAIL: missing $Name"};. ([scriptblock]::Create($f.Extent.Text.Replace("function $Name","function script:$Name")))}
switch($Case){
 'uo' {
  $a=Parse-Source 'Scripts/UO_Checker.ps1'
  if(-not $a.ParamBlock -or @($a.ParamBlock.Parameters.Name.VariablePath.UserPath) -notcontains 'OutputPath'){throw 'FAIL: UO explicit output missing'}
  function Get-ADOrganizationalUnit {param($Filter,$Server,$ErrorAction);[pscustomobject]@{Name='FIXTURE';DistinguishedName='OU=FIXTURE,DC=offline'}}
  function Get-ADObject {param($SearchBase,$Filter,$Server,$ErrorAction);[pscustomobject]@{Name='SYNTHETIC';DistinguishedName='CN=SYNTHETIC,OU=FIXTURE,DC=offline'}}
  $path=Join-Path $PSScriptRoot 'uo-fixture.csv'
  try {
   & (Join-Path $Repo 'Scripts/UO_Checker.ps1') -Domains @('offline.invalid') -OutputPath $path
   $rows=@(Import-Csv $path -Delimiter ';')
   if($rows.Count -ne 1 -or $rows[0].Dominio -ne 'offline.invalid'){throw 'FAIL: UO CSV content'}
   $failed=$false
   try {& (Join-Path $Repo 'Scripts/UO_Checker.ps1') -Domains @('bad domain') -OutputPath $path}catch{$failed=$true}
   if(-not $failed){throw 'FAIL: invalid domain accepted'}
   $failed=$false
   try {& (Join-Path $Repo 'Scripts/UO_Checker.ps1') -Domains @() -OutputPath $path}catch{$failed=$true}
   if(-not $failed){throw 'FAIL: empty domains accepted'}
  } finally {Remove-Item $path -ErrorAction SilentlyContinue}
 }
 'vdi' {
  Load-Fn 'Otros_AD/vdi.ps1' 'ConvertTo-LdapLiteral'
  $literal=ConvertTo-LdapLiteral "a*()\$([char]0)"
  if($literal -cne 'a\2a\28\29\5c\00'){throw 'FAIL: RFC4515 escaping'}
  $a=Parse-Source 'Otros_AD/vdi.ps1'
  $script:filters=@()
  function Get-ADUser {param($LDAPFilter,$Server);$script:filters+=,$LDAPFilter}
  function Get-ADGroup {param($LDAPFilter,$Server);$script:filters+=,$LDAPFilter}
  $Group=@{DistinguishedName='CN=A*(B)\C'};$UserAlta=@{DistinguishedName='CN=U*(V)\W'};$UserBaja=$UserAlta
  $UserAltaInput="u*)(objectClass=*)";$UserBajaInput=$UserAltaInput;$GCServer='offline.invalid:3268';$Domain='offline.invalid'
  foreach($cmd in $a.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Get-ADUser','Get-ADGroup') -and $n.Extent.Text -notmatch '-Identity'},$true)){
   & ([scriptblock]::Create($cmd.Extent.Text))
  }
  if($script:filters.Count -ne 4){throw 'FAIL: expected four literal LDAP queries'}
  if(@($script:filters | Where-Object {$_ -match '\(objectClass=\*\)|CN=A\*|CN=U\*'}).Count){throw 'FAIL: unescaped LDAP query'}
  # Execute only the real GC assignment; no module import/menu/mutators.
  $gc=$a.Find({param($n)$n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$GCServer'},$true)
  . ([scriptblock]::Create($gc.Extent.Text))
  if($GCServer -ne 'offline.invalid:3268'){throw 'FAIL: GC port interpolation'}
 }
 'launcher' {
  $launcher=[IO.File]::ReadAllText((Join-Path $Repo 'Macro Remedy/ejecutar_v2.bat'))
  $compiler=[IO.File]::ReadAllText((Join-Path $Repo 'Macro Remedy/compilar.bat'))
  if($launcher -notmatch 'CAU_GUI_BETA_v2\.ahk' -or $launcher -match 'CAU_GUI_Refactored'){throw 'FAIL: launcher targets abandoned refactor'}
  if($compiler -notmatch 'CAU_GUI_BETA_v2\.ahk' -or $compiler -match '/icon "Assets\\icon.ico"'){throw 'FAIL: compiler source/missing icon'}
  if($launcher -notmatch 'if not exist' -or $compiler -notmatch 'if not exist'){throw 'FAIL: missing dependency guard'}
 }
 default {throw 'unknown test'}
}
Write-Output "PASS: $Case"
