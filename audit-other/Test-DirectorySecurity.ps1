param([string]$Repo=(Split-Path $PSScriptRoot -Parent),[string]$Case='legacy-disabled')
$ErrorActionPreference='Stop'
function Load-Fn($File,$Name){
 $t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $File),[ref]$t,[ref]$e)
 if($e.Count){throw 'FAIL: production parser'}
 $f=$a.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true)
 if(-not $f){throw "FAIL: missing $Name"}
 . ([scriptblock]::Create($f.Extent.Text.Replace("function $Name","function script:$Name")))
}
function Write-Log {param($Message,$Level)}
$fixture=Join-Path $PSScriptRoot 'credential-fixture'
$null=New-Item -ItemType Directory -Force $fixture
try {
 switch($Case){
  'legacy-disabled' {
   $script:ENV_FILE=Join-Path $fixture '.env'
   @('ADMIN_USER=FIXTURE','ADMIN_PASS=SYNTHETIC-NOT-A-CREDENTIAL') | Set-Content $script:ENV_FILE
   foreach($file in @('Directorio correo/cambiar_password_correo.ps1','lazydirectory/lazydirectory.ps1')) {
    Load-Fn $file 'Get-Credentials'
    function Get-DirectoryCredential {return $null}
    if($null -ne (Get-Credentials)){throw 'FAIL: legacy plaintext credential auto-loaded'}
   }
  }
  'dpapi-roundtrip' {
   $module=Join-Path $Repo 'Common/DirectorySecurity.psm1'
   if(-not (Test-Path $module)){throw 'FAIL: protected credential store missing'}
   Import-Module $module -Force
   $path=Join-Path $fixture 'credential.xml'
   $password=ConvertTo-SecureString 'SYNTHETIC-NOT-A-CREDENTIAL' -AsPlainText -Force
   $credential=New-Object Management.Automation.PSCredential 'FIXTURE',$password
   Save-DirectoryCredential -Credential $credential -Path $path
   $stored=[IO.File]::ReadAllText($path)
   if($stored.Contains('SYNTHETIC-NOT-A-CREDENTIAL') -or $stored.Contains('ADMIN_PASS=')){throw 'FAIL: plaintext persistence'}
   $restored=Get-DirectoryCredential -Path $path
   if($restored.UserName -ne 'FIXTURE' -or $restored.GetNetworkCredential().Password -ne 'SYNTHETIC-NOT-A-CREDENTIAL'){throw 'FAIL: DPAPI roundtrip'}
   $acl=Get-Acl $path
   if(-not $acl.AreAccessRulesProtected){throw 'FAIL: inherited credential permissions'}
  }
  'random-password' {
   $module=Join-Path $Repo 'Common/DirectorySecurity.psm1'
   if(-not (Test-Path $module)){throw 'FAIL: CSPRNG password generator missing'}
   Import-Module $module -Force
   $seen=@{}
   for($i=0;$i -lt 100;$i++) {
    $p=New-DirectoryPassword
    if($p -isnot [Security.SecureString]){throw 'FAIL: generator not SecureString'}
    $plain=(New-Object Management.Automation.PSCredential 'FIXTURE',$p).GetNetworkCredential().Password
    if($plain.Length -lt 40 -or $seen.ContainsKey($plain)){throw 'FAIL: weak/duplicate default'}
    $seen[$plain]=$true
   }
  }
  'masked-ui' {
   $source=[IO.File]::ReadAllText((Join-Path $Repo 'lazydirectory/lazydirectory.ps1'))
   if($source -match 'Justicia\.\$month\$year|Password por defecto:|cambiar a ''\$pass''|Password: \$pass|\$pass = prompt'){throw 'FAIL: predictable/visible password UI'}
   if($source -match '\| Out-File -FilePath'){throw 'FAIL: raw authenticated response persisted'}
  }
  default {throw 'unknown test'}
 }
 Write-Output "PASS: $Case"
} finally {Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
