#requires -version 5.1
param([string]$ResultPath,[string]$Case='*')
$ErrorActionPreference='Stop'
$PSModuleAutoLoadingPreference='None'
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Security
$Root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw $errors[0].Message }
foreach ($name in @('Execute-UserTransfer','Execute-CrossDomainTransfer')) {
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:Results=@()
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Test-Case([string]$name,[scriptblock]$action) {
    if ($name -notlike $Case) { return }
    try { Reset-Fixture; & $action; $script:Results += [pscustomobject]@{Name=$name;Passed=$true;Error=$null} }
    catch { $script:Results += [pscustomobject]@{Name=$name;Passed=$false;Error=$_.Exception.Message} }
}
function Reset-Fixture {
    $Global:WhatIfMode=$false
    $script:Fault=''; $script:Writes=@(); $script:Logs=@(); $script:Reads=@(); $script:Deleted=$false; $script:Cross=$false
    $script:SourceGuid=[guid]'11111111-1111-1111-1111-111111111111'
    $script:CreatedGuid=[guid]'22222222-2222-2222-2222-222222222222'
    $script:SourceOU='OU=Source,DC=source,DC=invalid'; $script:TargetOU='OU=Target,DC=target,DC=invalid'
    $script:Source=[pscustomobject]@{SamAccountName='fixture';ObjectGUID=$script:SourceGuid;Name='Fixture';DisplayName='Fixture';GivenName='Fixture';Surname='Synthetic';DistinguishedName="CN=Fixture,$script:SourceOU";Office='old';Description='old';mail='old@example.invalid';telephoneNumber='';Enabled=$true;UserPrincipalName='fixture@justicia.junta-andalucia.es';pwdLastSet=123;MemberOf=@('CN=Old,DC=source,DC=invalid')}
    $script:Created=$null
    $script:Existing=[pscustomobject]@{SamAccountName='fixture';ObjectGUID=$script:SourceGuid;DistinguishedName=$script:Source.DistinguishedName;SourceDomain='source.invalid'}
    $script:Data=[pscustomobject]@{Oficina='new';Descripcion='new';Email='fixture@example.invalid';Telefono='123'}
    $script:Template=[pscustomobject]@{SamAccountName='template';MemberOf=@('CN=Desired,DC=target,DC=invalid')}
}
function Write-Log { param($Message,$Level) $script:Logs += [pscustomobject]@{Message=[string]$Message;Level=$Level} }
function Normalize-Text { param($Text) $Text }
function Get-StandardPassword { 'SyntheticOnly-Aa9!NeverLog' }
function Find-TemplateUserInOU { param($Description,$OrganizationalUnit,$Domain) if ($script:Fault -eq 'Template') { return $null }; $script:Template }
function Fail-At([string]$point) { if ($script:Fault -eq $point) { Write-Error 'Provider failure SyntheticOnly-Aa9!NeverLog' } }
function Get-ADUser {
    [CmdletBinding()] param($Identity,$Filter,$Server,$Properties)
    $script:Reads += [string]$Server
    if ($Filter) {
        if ($Filter -match 'ObjectGUID') { Fail-At 'DeleteVerify'; if (-not $script:Deleted) { $script:Source }; return }
        Fail-At 'Collision'; if ($script:Fault -eq 'CollisionFound') { $script:Source }; return
    }
    if ($script:Cross -and $Server -eq 'target.invalid') {
        Fail-At 'DestinationRead'
        if ($script:Fault -eq 'DestinationMissing') { return }
        if ($script:Created) {
            $copy=$script:Created | Select-Object *
            if ($script:Fault -eq 'DestinationGuid') { $copy.ObjectGUID=$script:SourceGuid }
            if ($script:Fault -eq 'DestinationOU') { $copy.DistinguishedName="CN=Fixture,$script:SourceOU" }
            if ($script:Fault -eq 'DestinationGroups') { $copy.MemberOf=@() }
            if ($script:Fault -eq 'DestinationDisabled') { $copy.Enabled=$false }
            return $copy
        }
        return
    }
    Fail-At 'SourceRead'
    if ($script:Deleted) { return }
    $copy=$script:Source | Select-Object *
    if ($script:Fault -eq 'SourceChanged' -and $script:Created) { $copy.Description='concurrent-change' }
    if ($script:Fault -eq 'SourceGuidChanged' -and $script:Created) { $copy.ObjectGUID=$script:CreatedGuid }
    if ($script:Fault -eq 'FinalOU' -and $script:Writes.Count) { $copy.DistinguishedName="CN=Fixture,$script:SourceOU" }
    if ($script:Fault -eq 'FinalPassword' -and $script:Writes.Count) { $copy.pwdLastSet=123 }
    $copy
}
function Get-ADGroup {
    [CmdletBinding()] param($Identity,$Server)
    Fail-At 'GroupRead'
    [pscustomobject]@{Name='Desired';DistinguishedName=[string]$Identity}
}
function Get-ADPrincipalGroupMembership {
    [CmdletBinding()] param($Identity,$Server)
    if ($script:Writes.Count) { Fail-At 'FinalGroups' } else { Fail-At 'CurrentGroups' }
    foreach ($dn in $script:Source.MemberOf) { [pscustomobject]@{Name=if ($dn -like '*Old*') {'Old'} else {'Desired'};DistinguishedName=$dn} }
}
function New-ADUser {
    [CmdletBinding()] param($SamAccountName,$Name,$DisplayName,$GivenName,$Surname,$UserPrincipalName,$EmailAddress,$OfficePhone,$Office,$Description,$AccountPassword,$Enabled,$ChangePasswordAtLogon,$Server,$Path,[switch]$PassThru)
    $script:Writes+='New'; Fail-At 'New'
    $script:Created=[pscustomobject]@{SamAccountName=$SamAccountName;ObjectGUID=$script:CreatedGuid;Name=$Name;DisplayName=$DisplayName;GivenName=$GivenName;Surname=$Surname;UserPrincipalName=$UserPrincipalName;mail=$EmailAddress;telephoneNumber=$OfficePhone;Office=$Office;Description=$Description;Enabled=$Enabled;pwdLastSet=0;DistinguishedName="CN=Fixture,$Path";MemberOf=@()}
    if ($PassThru) { if ($script:Fault -eq 'CreateReceipt') { return }; $script:Created }
}
function Add-ADGroupMember {
    [CmdletBinding()] param($Identity,$Members,$Server)
    $script:Writes+='Add'; Fail-At 'Add'
    $dn=if($Identity -is [string]){$Identity}else{$Identity.DistinguishedName}
    if ($script:Cross) { $script:Created.MemberOf+=@($dn) } else { $script:Source.MemberOf+=@($dn) }
}
function Remove-ADGroupMember {
    [CmdletBinding(SupportsShouldProcess)] param($Identity,$Members,$Server)
    $script:Writes+='RemoveGroup'; Fail-At 'RemoveGroup'
    $dn=if($Identity -is [string]){$Identity}else{$Identity.DistinguishedName}
    $script:Source.MemberOf=@($script:Source.MemberOf | Where-Object {$_ -ne $dn})
}
function Move-ADObject {
    [CmdletBinding()] param($Identity,$TargetPath,$Server)
    $script:Writes+='Move'; Fail-At 'Move'; $script:Source.DistinguishedName="CN=Fixture,$TargetPath"
}
function Set-ADUser {
    [CmdletBinding()] param($Identity,$Office,$Description,$Server,$ChangePasswordAtLogon)
    $point=if($PSBoundParameters.ContainsKey('Office')){'Attributes'}else{'MustChange'}
    $script:Writes+=$point; Fail-At $point
    if ($point -eq 'Attributes') { $script:Source.Office=$Office; $script:Source.Description=$Description } else { $script:Source.pwdLastSet=0 }
}
function Set-ADAccountPassword {
    [CmdletBinding()] param($Identity,$Server,$NewPassword,[switch]$Reset)
    $script:Writes+='Reset'; Fail-At 'Reset'
}
function Remove-ADUser {
    [CmdletBinding(SupportsShouldProcess)] param($Identity,$Server)
    $script:Writes+='Delete'; Fail-At 'Delete'
    Assert ($Server -eq 'source.invalid') 'No borrar destino'
    Assert ([string]$Identity -eq [string]$script:SourceGuid) 'Borrado debe usar GUID de origen, no SAM reutilizable'
    $script:Deleted=$true
}
function Invoke-Transfer([switch]$Cross) {
    $script:Cross=[bool]$Cross
    $domain=if($Cross){'target.invalid'}else{'source.invalid'}
    $command=if($Cross){'Execute-CrossDomainTransfer'}else{'Execute-UserTransfer'}
    $saved=$ErrorActionPreference; $ErrorActionPreference='Continue'
    try { $result=@(& $command -ExistingUser $script:Existing -TargetDomain $domain -TargetOU $script:TargetOU -UserData $script:Data -Confirm:$false 2>$null) }
    finally { $ErrorActionPreference=$saved }
    Assert ($result.Count -eq 1 -and $result[0] -is [bool]) 'Resultado debe ser un unico booleano'
    $result[0]
}
Test-Case 'Same-ResetFailure' {
    $script:Fault='Reset'; $r=Invoke-Transfer
    Assert (-not $r) 'Reset no terminante debe impedir exito'
    Assert (@($script:Logs | Where-Object Level -eq 'ERROR').Count -gt 0) 'Fallo debe quedar auditado'
    Assert (-not (($script:Logs.Message -join ' ') -like '*SyntheticOnly-Aa9!NeverLog*')) 'No registrar secretos del proveedor'
}
Test-Case 'Cross-GroupFailureKeepsBoth' {
    $script:Fault='Add'; $r=Invoke-Transfer -Cross
    Assert (-not $r) 'Copia fallida no puede devolver exito'
    Assert ($script:Writes -notcontains 'Delete') 'Copia fallida no puede intentar borrar origen'
    Assert ($null -ne $script:Created -and -not $script:Deleted) 'Conservar ambas cuentas tras estado parcial'
    Assert (-not (($script:Logs.Message -join ' ') -like '*SyntheticOnly-Aa9!NeverLog*')) 'No registrar secretos del proveedor'
}
foreach ($faultCase in @('CurrentGroups','RemoveGroup','Move','Attributes','Add','MustChange','FinalGroups','FinalOU','FinalPassword','Template','SourceRead','GroupRead')) {
    Test-Case ('Same-FailClosed-'+$faultCase) {
        $script:Fault=$faultCase; $r=Invoke-Transfer
        Assert (-not $r) 'Fallo o estado final incorrecto no puede declarar exito'
        Assert ($script:Writes -notcontains 'Delete') 'Traslado local nunca borra cuentas'
        Assert (@($script:Logs | Where-Object Level -eq 'ERROR').Count -gt 0) 'Error parcial debe auditarse'
        Assert (-not (($script:Logs.Message -join ' ') -like '*SyntheticOnly-Aa9!NeverLog*')) 'Logs de fallo no deben copiar mensajes del proveedor'
        if ($faultCase -in @('Template','CurrentGroups','SourceRead','GroupRead')) { Assert ($script:Writes.Count -eq 0) 'Preflight fallido debe bloquear todas las escrituras' }
        if ($faultCase -in @('Add','Move','Attributes','MustChange')) { Assert ($script:Writes -notcontains 'RemoveGroup') 'No retirar acceso anterior antes de preparar destino' }
    }
}
Test-Case 'Same-SuccessVerified' {
    Assert (Invoke-Transfer) 'Traslado local valido debe devolver true'
    Assert ($script:Source.DistinguishedName -eq "CN=Fixture,$script:TargetOU") 'Debe verificar UO destino'
    Assert ($script:Source.MemberOf -contains $script:Template.MemberOf[0]) 'Debe copiar grupo destino'
    Assert ($script:Source.MemberOf -notcontains 'CN=Old,DC=source,DC=invalid') 'Debe retirar grupo antiguo'
}
foreach ($faultCase in @('Template','SourceRead','GroupRead','Collision','CollisionFound','New','CreateReceipt','DestinationRead','DestinationMissing','DestinationGuid','DestinationOU','DestinationGroups','DestinationDisabled')) {
    Test-Case ('Cross-FailClosed-'+$faultCase) {
        $script:Fault=$faultCase; $r=Invoke-Transfer -Cross
        Assert (-not $r) 'Fallo antes de verificacion no puede declarar exito'
        Assert ($script:Writes -notcontains 'Delete') 'Destino no verificado debe impedir borrado origen'
        Assert (-not $script:Deleted) 'Origen debe conservarse'
        if ($faultCase -in @('Template','SourceRead','GroupRead','Collision','CollisionFound')) { Assert ($script:Writes.Count -eq 0) 'Preflight fallido no puede crear cuenta' }
        Assert (-not (($script:Logs.Message -join ' ') -like '*SyntheticOnly-Aa9!NeverLog*')) 'No copiar errores proveedor a logs'
    }
}
Test-Case 'Cross-DeleteFailureIsNotSuccess' {
    $script:Fault='Delete'; $r=Invoke-Transfer -Cross
    Assert (-not $r -and -not $script:Deleted -and $null -ne $script:Created) 'Fallo de borrado conserva ambos y devuelve false'
    Assert (-not (($script:Logs.Message -join ' ') -like '*SyntheticOnly-Aa9!NeverLog*')) 'No copiar errores proveedor a logs'
}
Test-Case 'Cross-SuccessUsesSourceGuid' {
    Assert (Invoke-Transfer -Cross) 'Destino verificado y borrado confirmado deben devolver true'
    Assert ($script:Deleted -and $null -ne $script:Created) 'Solo origen eliminado'
}
Test-Case 'Cross-DeleteVerificationFailureIsNotSuccess' {
    $script:Fault='DeleteVerify'; Assert (-not (Invoke-Transfer -Cross)) 'Borrado no confirmado no puede declarar exito'
}
Test-Case 'Writes-AuditUnavailableBlocksCrossBeforeCreate' {
    function Write-Log { param($Message,$Level) throw 'Audit offline unavailable' }
    try { Invoke-Transfer -Cross | Out-Null } catch { }
    Assert ($script:Writes.Count -eq 0) 'No crear ni borrar si auditoria no esta disponible'
}
Test-Case 'Writes-AuditUnavailableBlocksSameBeforeWrite' {
    function Write-Log { param($Message,$Level) throw 'Audit offline unavailable' }
    try { Invoke-Transfer | Out-Null } catch { }
    Assert ($script:Writes.Count -eq 0) 'No modificar usuario si auditoria no esta disponible'
}
Test-Case 'Writes-AllEntryWritesRequireStop' {
    $writes=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -match '^(New|Set|Add|Remove|Move|Enable|Disable|Unlock|Rename)-AD|^(New-Item|Add-Content|Export-Csv)$'},$true))
    Assert ($writes.Count -gt 0) 'Inventario de writes vacio'
    foreach ($write in $writes) { Assert ($write.Extent.Text -match '-ErrorAction\s+Stop\b') ('Escritura sin Stop: '+$write.GetCommandName()+' linea '+$write.Extent.StartLineNumber) }
}
Test-Case 'Writes-LogFailureIsTerminatingUnderContinue' {
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-Log'},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
    function Add-Content { [CmdletBinding()] param($Path,$Value,$Encoding) Write-Error 'Synthetic audit IO failure' }
    $saved=$ErrorActionPreference; $ErrorActionPreference='Continue'; $thrown=$false
    try { Write-Log 'Fixture' 'INFO' 2>$null } catch { $thrown=$true } finally { $ErrorActionPreference=$saved }
    Assert $thrown 'No informar log guardado tras error no terminante'
}
foreach ($faultCase in @('SourceChanged','SourceGuidChanged')) {
    Test-Case ('Cross-Concurrent-'+$faultCase) { $script:Fault=$faultCase; Assert (-not (Invoke-Transfer -Cross)) 'Origen cambiado bloquea traslado'; Assert ($script:Writes -notcontains 'Delete') 'Origen cambiado no se borra' }
}
Test-Case 'Cross-WhatIfNoReadsOrWrites' {
    $r=Execute-CrossDomainTransfer -ExistingUser $script:Existing -TargetDomain target.invalid -TargetOU $script:TargetOU -UserData $script:Data -WhatIf
    Assert (-not $r -and $script:Reads.Count -eq 0 -and $script:Writes.Count -eq 0) 'WhatIf debe bloquear antes de lecturas y escrituras'
}
Test-Case 'Same-WhatIfNoReadsOrWrites' {
    $r=Execute-UserTransfer -ExistingUser $script:Existing -TargetDomain source.invalid -TargetOU $script:TargetOU -UserData $script:Data -WhatIf
    Assert (-not $r -and $script:Reads.Count -eq 0 -and $script:Writes.Count -eq 0) 'WhatIf debe bloquear antes de lecturas y escrituras'
}
$writeInventory=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -match '^(New|Set|Add|Remove|Move|Enable|Disable|Unlock|Rename)-AD|^(New-Item|Add-Content|Export-Csv)$'},$true) | ForEach-Object { [pscustomobject]@{Command=$_.GetCommandName();Line=$_.Extent.StartLineNumber;Stop=($_.Extent.Text -match '-ErrorAction\s+Stop\b')} })
$parserResults=@()
foreach ($file in @((Join-Path $Root 'AD_UserManagement.ps1'))+@(Get-ChildItem (Join-Path $Root 'Modules') -Filter '*.psm1' | ForEach-Object FullName)+@(Get-ChildItem $PSScriptRoot -Filter '*.ps1' | ForEach-Object FullName)) {
    $t=$null; $e=$null; [Management.Automation.Language.Parser]::ParseFile($file,[ref]$t,[ref]$e) | Out-Null
    $parserResults+=[pscustomobject]@{File=([IO.Path]::GetFileName($file));Errors=@($e).Count}
}
$summary=[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();Mode='AST REAL; AD AUTOLOAD OFF; TODOS CMDLETS AD SON FIXTURES';Tests=$script:Results;Passed=@($script:Results | Where-Object Passed).Count;Failed=@($script:Results | Where-Object {-not $_.Passed}).Count;WriteInventory=$writeInventory;Parser=$parserResults}
if ($ResultPath) { $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding UTF8 }
$summary | ConvertTo-Json -Depth 8
if ($summary.Failed) { exit 1 }
