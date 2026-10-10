param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Scripts/Meraki.ps1'),[ref]$t,[ref]$e)
$command=$ast.Find({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-ADUser'},$true)
function New-ADUser {
    param($Name,$GivenName,$Surname,$SamAccountName,$UserPrincipalName,$Path,$AccountPassword,$ChangePasswordAtLogon,$OfficePhone,$Description,$EmailAddress,$Enabled)
    $script:Arguments=$PSBoundParameters
}
$fname='Fixture';$firstLastName='One';$secondLastName='Two';$username='fixture';$OUpath='OU=Fixture,DC=offline';$dni='OFFLINE';$jtitle='Fixture';$emailaddress='fixture@offline.invalid'
$securePassword=ConvertTo-SecureString 'OFFLINE-only-fixture' -AsPlainText -Force
. ([scriptblock]::Create($command.Extent.Text))
if ($script:Arguments.Path -ne $OUpath -or -not [object]::ReferenceEquals($script:Arguments.AccountPassword,$securePassword) -or $script:Arguments.Enabled -ne $true) {throw 'FAIL: Meraki creation command loses trailing parameters at inline comment'}
Write-Output 'PASS: real Meraki command binds OU/password/enabled to fixture stub; no AD writes'
