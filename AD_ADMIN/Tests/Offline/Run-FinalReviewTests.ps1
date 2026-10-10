#requires -version 5.1
param([string]$ResultPath,[string]$Case='*')
$ErrorActionPreference='Stop'
$PSModuleAutoLoadingPreference='None'
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
$Root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$t=$null;$e=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$t,[ref]$e)
if ($e.Count) { throw 'Parser entrypoint failed' }
foreach ($name in @('Find-ExistingUserForTransfer')) {
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:Results=@()
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Test-Case($name,[scriptblock]$action) {
    if ($name -notlike $Case) { return }
    try { & $action; $script:Results+=[pscustomobject]@{Name=$name;Passed=$true;Error=$null} }
    catch { $script:Results+=[pscustomobject]@{Name=$name;Passed=$false;Error=$_.Exception.Message} }
}
function Write-Log { param($Message,$Level) }
function Read-Host { throw 'No interaction in offline review' }
$script:Data=[pscustomobject]@{AD='';Email='fixture@example.invalid';Telefono='';Nombre='';Apellidos=''}
$script:User=[pscustomobject]@{SamAccountName='fixture';ObjectGUID=[guid]'11111111-1111-1111-1111-111111111111';DistinguishedName='CN=Fixture,DC=source,DC=invalid';DisplayName='Synthetic Fixture';mail='fixture@example.invalid';Office='Fixture';Description='Fixture';telephoneNumber=''}
Test-Case 'Discovery-DomainReadFailureBlocksPartialCandidate' {
    function Get-ADForest { [CmdletBinding()]param() [pscustomobject]@{Domains=@('source.invalid','denied.invalid')} }
    function Get-ADDomain { [CmdletBinding()]param($Identity) [pscustomobject]@{DNSRoot=$Identity} }
    function Get-ADUser { [CmdletBinding()]param($Identity,$Filter,$Server,$Properties)
        if ($Server -eq 'denied.invalid') { Write-Error 'Synthetic access denied'; return }
        $script:User
    }
    foreach ($criterion in @('AD','Email','Telefono','Nombre')) {
        $data=[pscustomobject]@{AD='';Email='';Telefono='';Nombre='';Apellidos=''}
        $data.$criterion='fixture'
        if ($criterion -eq 'Nombre') { $data.Apellidos='Synthetic' }
        $r=Find-ExistingUserForTransfer -UserData $data -Interactive:$false
        Assert ($null -eq $r) ('Partial forest query must not select candidate for mutation: '+$criterion)
    }
}
Test-Case 'Discovery-DomainMetadataFailureBlocksPartialCandidate' {
    function Get-ADForest { [CmdletBinding()]param() [pscustomobject]@{Domains=@('source.invalid','denied.invalid')} }
    function Get-ADDomain { [CmdletBinding()]param($Identity) if ($Identity -eq 'denied.invalid') { throw 'Synthetic domain denied' }; [pscustomobject]@{DNSRoot=$Identity} }
    function Get-ADUser { [CmdletBinding()]param($Identity,$Filter,$Server,$Properties) $script:User | Select-Object * }
    Assert ($null -eq (Find-ExistingUserForTransfer -UserData $script:Data -Interactive:$false)) 'Unavailable domain metadata must block discovery'
}
Test-Case 'Discovery-ForestFailureNeverUsesGuessedDomains' {
    function Get-ADForest { [CmdletBinding()]param() throw 'Synthetic forest denied' }
    function Get-ADDomain { [CmdletBinding()]param($Identity) [pscustomobject]@{DNSRoot=$Identity} }
    function Get-ADUser { [CmdletBinding()]param($Identity,$Filter,$Server,$Properties) $script:User | Select-Object * }
    Assert ($null -eq (Find-ExistingUserForTransfer -UserData $script:Data -Interactive:$false)) 'Failed forest lookup must block discovery instead of guessed domains'
}
Test-Case 'Discovery-DuplicateCandidatesBlockNonInteractive' {
    function Get-ADForest { [CmdletBinding()]param() [pscustomobject]@{Domains=@('source.invalid','other.invalid')} }
    function Get-ADDomain { [CmdletBinding()]param($Identity) [pscustomobject]@{DNSRoot=$Identity} }
    function Get-ADUser { [CmdletBinding()]param($Identity,$Filter,$Server,$Properties) $script:User | Select-Object * }
    $r=Find-ExistingUserForTransfer -UserData $script:Data -Interactive:$false
    Assert ($null -eq $r) 'Ambiguous users must not select first candidate automatically'
}
Test-Case 'Discovery-UniqueVerifiedCandidateStillWorks' {
    function Get-ADForest { [CmdletBinding()]param() [pscustomobject]@{Domains=@('source.invalid')} }
    function Get-ADDomain { [CmdletBinding()]param($Identity) [pscustomobject]@{DNSRoot=$Identity} }
    function Get-ADUser { [CmdletBinding()]param($Identity,$Filter,$Server,$Properties) $script:User | Select-Object * }
    $r=Find-ExistingUserForTransfer -UserData $script:Data -Interactive:$false
    Assert ($r.SamAccountName -ceq 'fixture' -and $r.SourceDomain -ceq 'source.invalid') 'Unique verified fixture should resolve unchanged'
}
$summary=[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();Mode='Reviewed AST fragments; synthetic AD fixtures; AD autoload disabled';Tests=$script:Results;Passed=@($script:Results|Where-Object Passed).Count;Failed=@($script:Results|Where-Object {-not $_.Passed}).Count}
if ($ResultPath) { $summary|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ResultPath -Encoding UTF8 }
$summary|ConvertTo-Json -Depth 6
if ($summary.Failed) { exit 1 }
