param([string]$Repo=(Split-Path $PSScriptRoot -Parent),[ValidateSet('Contracts','Runtime')][string]$Case='Contracts')
$ErrorActionPreference='Stop'
$script:checks=0
function Assert-Safe { param([bool]$Condition,[string]$Name); $script:checks++; if(-not $Condition){throw "FAIL: $Name"} }
function Get-SourceAst {param([string]$Relative); $t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $Relative),[ref]$t,[ref]$e);Assert-Safe ($e.Count -eq 0) "$Relative syntax";return $a}
function Import-ReviewedFunction {param($Ast,[string]$Name);$f=$Ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true);Assert-Safe ($f.Count -eq 1) "$Name unique definition";. ([scriptblock]::Create($f[0].Extent.Text));Set-Item "Function:script:$Name" (Get-Item "Function:$Name").ScriptBlock}
foreach($rel in @('Temis/cambiar_password_temis.ps1','lazytemis/lazytemis.ps1','Otros_AD/ADaltas.ps1','Otros_AD/AltasAD.ps1')){
 $ast=Get-SourceAst $rel;$src=$ast.Extent.Text
 Assert-Safe ($src -notmatch '(?i)ConvertTo-SecureString\s+[\x22\x27]') "$rel no embedded credential"
 Assert-Safe ($src -notmatch '(?i)\$defaultPass|\$month|\$year') "$rel no calendar default"
 if($rel -like 'Otros_AD/*'){
  Assert-Safe ($src -match '(?is)Parameter\(Mandatory\s*=\s*\$true\).*?\[Security\.SecureString\]\$AccountPassword') "$rel secure account input"
 }else{
  Assert-Safe ($src -match '\[Security\.SecureString\]\$NewPassword') "$rel secure reset input"
 }
}
if($Case -eq 'Runtime'){
 foreach($rel in @('Temis/cambiar_password_temis.ps1','lazytemis/lazytemis.ps1')){
  $ast=Get-SourceAst $rel
  foreach($name in @('Assert-PasswordEndpoint','Invoke-PasswordPost','Get-Certificate')){Import-ReviewedFunction $ast $name}
  $script:calls=0;$script:captured=$null
  function Invoke-WebRequest {param($Uri,$Body,$Method,$MaximumRedirection,$Certificate,$WebSession,[switch]$UseBasicParsing,$ErrorAction);$script:calls++;$script:captured=@{Uri=$Uri;Body=$Body.Clone();MaximumRedirection=$MaximumRedirection};return [pscustomobject]@{Content='synthetic'}}
  function Write-Log {param($Message,$Level);if($Message -match 'OFFLINE_SECRET'){throw 'FAIL: secret output'}}
  $secret=ConvertTo-SecureString ('OFFLINE_'+'SECRET_SENTINEL') -AsPlainText -Force
  $script:TEMIS_URL='http://offline.invalid/Temis';$script:ESC_URL='https://offline.invalid/Escritorio';$script:cert=$null;$script:webSession=$null
  try{Assert-PasswordEndpoint $script:TEMIS_URL;throw 'FAIL: HTTP accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: HTTP accepted') "$rel HTTP rejected"}
  try{Invoke-PasswordPost -Uri 'http://offline.invalid/reset' -Fields @{} -NewPassword $secret;throw 'FAIL: HTTP post accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: HTTP post accepted') "$rel HTTP post rejected"}
  Assert-Safe ($script:calls -eq 0) "$rel no HTTP secret request"
  Invoke-PasswordPost -Uri 'https://offline.invalid/reset' -Fields @{usuario='fixture'} -NewPassword $secret | Out-Null
  Assert-Safe ($script:calls -eq 1) "$rel one HTTPS request"
  Assert-Safe ($script:captured.MaximumRedirection -eq 0) "$rel redirect disabled"
  Assert-Safe ($script:captured.Body.nuevaPassword -eq ('OFFLINE_'+'SECRET_SENTINEL')) "$rel secret bound only in request body"
  $script:captured=$null
  function Invoke-WebRequest {throw ('OFFLINE_'+'SECRET_SENTINEL')}
  try{Invoke-PasswordPost -Uri 'https://offline.invalid/reset' -Fields @{} -NewPassword $secret;throw 'FAIL: request exception missing'}catch{Assert-Safe ($_.Exception.Message -notmatch 'OFFLINE_SECRET') "$rel sanitized request failure"}
  $now=Get-Date;$script:CertificateThumbprint='';$script:fixtureCerts=@()
  function Get-ChildItem {param($Path);return $script:fixtureCerts}
  try{Get-Certificate;throw 'FAIL: empty store accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: empty store accepted') "$rel empty certificate store blocked"}
  $valid=[pscustomobject]@{NotBefore=$now.AddDays(-1);NotAfter=$now.AddDays(1);HasPrivateKey=$true;Subject='synthetic';Thumbprint='AA'}
  $expired=[pscustomobject]@{NotBefore=$now.AddDays(-2);NotAfter=$now.AddDays(-1);HasPrivateKey=$true;Thumbprint='BB'}
  $noKey=[pscustomobject]@{NotBefore=$now.AddDays(-1);NotAfter=$now.AddDays(1);HasPrivateKey=$false;Thumbprint='CC'}
  $script:fixtureCerts=@($expired,$noKey,$valid);Assert-Safe ((Get-Certificate).Thumbprint -eq 'AA') "$rel valid private key certificate only"
  $second=[pscustomobject]@{NotBefore=$now.AddDays(-1);NotAfter=$now.AddDays(1);HasPrivateKey=$true;Thumbprint='DD'}
  $script:fixtureCerts=@($valid,$second)
  try{Get-Certificate;throw 'FAIL: ambiguous store accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: ambiguous store accepted') "$rel ambiguous certificate store blocked"}
  $script:CertificateThumbprint='DD';Assert-Safe ((Get-Certificate).Thumbprint -eq 'DD') "$rel explicit thumbprint selected"
  $script:CertificateThumbprint='BB';try{Get-Certificate;throw 'FAIL: missing thumbprint accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: missing thumbprint accepted') "$rel unavailable thumbprint blocked"}
  if($rel -like 'lazytemis/*'){
   Import-ReviewedFunction $ast 'Set-UserPassword';$script:calls=0
   function Invoke-WebRequest {$script:calls++;throw 'FAIL: WhatIf request'}
   Set-UserPassword -CodigoUsuario 'fixture' -WhatIf
   Assert-Safe ($script:calls -eq 0) 'lazytemis WhatIf no request or prompt'
   try{Set-UserPassword -CodigoUsuario 'fixture' -NewPassword $secret;throw 'FAIL: HTTP reset accepted'}catch{Assert-Safe ($_.Exception.Message -ne 'FAIL: HTTP reset accepted') 'lazytemis HTTP reset blocked'}
   Assert-Safe ($script:calls -eq 0) 'lazytemis HTTP guard before lookup'
   # Full reset function with synthetic profile and capturing web boundary only.
   $script:TEMIS_URL='https://offline.invalid/Temis';$script:ResetWhatIf=$false
   $script:calls=0;$script:requests=@();$script:messages=@();$script:securePrompt=$false
   function Extract-ProfileFields {param($Html);return @{dni='00000000T';usuario='fixture'}}
   function Read-Host {param($Prompt,[switch]$AsSecureString);$script:securePrompt=[bool]$AsSecureString;return ConvertTo-SecureString ('OFFLINE_'+'SECRET_SENTINEL') -AsPlainText -Force}
   function Write-Log {param($Message,$Level);$script:messages+=$Message}
   function Invoke-WebRequest {param($Uri,$Body,$Method,$MaximumRedirection,$Certificate,$WebSession,[switch]$UseBasicParsing,$ErrorAction);$script:calls++;$script:requests+=@{Uri=$Uri;Body=$Body.Clone();Redirect=$MaximumRedirection};return [pscustomobject]@{Content=('OFFLINE_'+'SECRET_SENTINEL')}}
   $output=Set-UserPassword -CodigoUsuario 'fixture' *>&1 | Out-String
   Assert-Safe $script:securePrompt 'lazytemis prompt uses AsSecureString'
   Assert-Safe ($script:calls -eq 3) 'lazytemis lookup and two reset posts'
   Assert-Safe ($script:requests[1].Body.pwd_modificacion -eq ('OFFLINE_'+'SECRET_SENTINEL')) 'lazytemis Temis secret bound'
   Assert-Safe ($script:requests[2].Body.nuevaPassword -eq ('OFFLINE_'+'SECRET_SENTINEL')) 'lazytemis Escritorio secret bound'
   Assert-Safe ($script:requests[1].Body.cambiarIdPassword -eq '3') 'lazytemis original protocol flag preserved'
   Assert-Safe (($script:requests | Where-Object {$_.Redirect -ne 0}).Count -eq 0) 'lazytemis all reset redirects disabled'
   Assert-Safe ($output -notmatch 'OFFLINE_SECRET' -and ($script:messages -join ';') -notmatch 'OFFLINE_SECRET') 'lazytemis response/logs contain no reflected secret'
   $script:requests=@()

  }
  $secret.Dispose()
 }
 foreach($rel in @('Otros_AD/ADaltas.ps1','Otros_AD/AltasAD.ps1')){
  $ast=Get-SourceAst $rel
  $cmd=$ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-ADUser'},$true)
  Assert-Safe ($cmd.Count -eq 1) "$rel one reviewed AD write"
  $script:adCalls=0;$script:adCapture=$null
  function New-ADUser {
   param($Name,$GivenName,$Surname,$SamAccountName,$UserPrincipalName,$Path,[Security.SecureString]$AccountPassword,[bool]$ChangePasswordAtLogon,$OfficePhone,$Description,$EmailAddress,[bool]$Enabled,$ErrorAction)
   $script:adCalls++;$script:adCapture=@{Password=$AccountPassword;ForceChange=$ChangePasswordAtLogon;Action=$ErrorAction;Path=$Path;Email=$EmailAddress}
  }
  $securePassword=ConvertTo-SecureString ('OFFLINE_'+'SECRET_SENTINEL') -AsPlainText -Force
  $fname='Synthetic';$lname='Fixture';$firstLastName='Fixture';$secondLastName='Only';$username='syntheticfixture';$emailaddress='fixture@example.invalid';$OUpath='OU=Synthetic,DC=example,DC=invalid';$dni='fixture';$jtitle='fixture'
  & ([scriptblock]::Create($cmd[0].Extent.Text))
  Assert-Safe ($script:adCalls -eq 1) "$rel AD command correctly bound"
  Assert-Safe ([object]::ReferenceEquals($securePassword,$script:adCapture.Password)) "$rel secure input identity preserved"
  Assert-Safe ($script:adCapture.ForceChange -eq $true) "$rel must change at logon"
  Assert-Safe ($script:adCapture.Action -eq 'Stop') "$rel AD write terminating errors"
  Assert-Safe ($script:adCapture.Path -eq $OUpath) "$rel no OU rewrite"
  # Only the reviewed gate/command; no entrypoint, CSV, AD or network.
  $gate=$cmd[0].Parent
  while($gate -and $gate -isnot [Management.Automation.Language.IfStatementAst]){$gate=$gate.Parent}
  Assert-Safe ($null -ne $gate -and $gate.Extent.Text -match 'ShouldProcess') "$rel mutation inside ShouldProcess"
  $dry=[scriptblock]::Create('[CmdletBinding(SupportsShouldProcess=$true)]param()' + "`n" + $gate.Extent.Text)
  $script:adCalls=0
  & $dry -WhatIf | Out-Null
  Assert-Safe ($script:adCalls -eq 0) "$rel WhatIf no AD writes"
  $securePassword.Dispose();$script:adCapture=$null
 }
 # Installer contains function source in a literal here-string; never execute installer/profile writes.
 $installer=Get-SourceAst 'instalar.ps1'
 $literal=$installer.FindAll({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'function temis \{'},$true)
 Assert-Safe ($literal.Count -eq 1) 'installer reviewed shortcut literal'
 $t=$null;$e=$null;$shortcut=[Management.Automation.Language.Parser]::ParseInput($literal[0].Value,[ref]$t,[ref]$e)
 Assert-Safe ($e.Count -eq 0) 'installer shortcut parser'
 Import-ReviewedFunction $shortcut 'temis'
 $global:CAUInstallRoot='synthetic'
 function Join-Path {param($Path,$ChildPath);return 'Capture-Temis'}
 function Capture-Temis {param($TemisUser,[Security.SecureString]$NewPassword,[switch]$WhatIf,[switch]$ShowBrowser,$TemisEndpoint,$CertificateThumbprint);$script:shortcutCapture=@{Secret=$NewPassword;Dry=[bool]$WhatIf;Endpoint=$TemisEndpoint;Thumbprint=$CertificateThumbprint}}
 $secret=ConvertTo-SecureString ('OFFLINE_'+'SECRET_SENTINEL') -AsPlainText -Force
 temis -TemisUser 'fixture' -NewPassword $secret -WhatIf -TemisEndpoint 'https://offline.invalid/Temis' -CertificateThumbprint 'AA'
 Assert-Safe ([object]::ReferenceEquals($secret,$script:shortcutCapture.Secret)) 'temis shortcut secure identity'
 Assert-Safe ($script:shortcutCapture.Dry) 'temis shortcut WhatIf forwarded'
 Assert-Safe ($script:shortcutCapture.Endpoint -eq 'https://offline.invalid/Temis') 'temis shortcut endpoint forwarded'
 Assert-Safe ($script:shortcutCapture.Thumbprint -eq 'AA') 'temis shortcut certificate forwarded'
 $secret.Dispose();$script:shortcutCapture=$null
 Remove-Item Function:Join-Path
 # Reviewed standalone dry-run statement with hostile boundaries.
 $ast=Get-SourceAst 'Temis/cambiar_password_temis.ps1'
 $gate=$ast.FindAll({param($n)$n -is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text -match '^if \(\$WhatIf\).*No se realizan peticiones'},$true)
 Assert-Safe ($gate.Count -eq 1) 'standalone early dryrun gate exists'
 $WhatIf=$true;$script:calls=0
 function Invoke-WebRequest {$script:calls++;throw 'Unexpected request'}
 function Read-Host {throw 'Unexpected prompt'}
 function Add-Content {throw 'Unexpected disk write'}
 & ([scriptblock]::Create($gate[0].Extent.Text))
 Assert-Safe ($script:calls -eq 0) 'standalone WhatIf no request'
}
[pscustomobject]@{case=$Case;checks=$script:checks;status='PASS';engine=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Compress
