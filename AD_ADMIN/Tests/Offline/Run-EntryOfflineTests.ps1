#requires -version 5.1
# Harness offline del entrypoint real. Los únicos writes son archivos sintéticos.
param([string]$ResultPath, [string]$ScratchPath)
$ErrorActionPreference='Stop'
$PSModuleAutoLoadingPreference='None'
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Security
if (-not $ScratchPath) { throw 'Indique ScratchPath fuera del repo para fixtures y logs.' }
$ScratchPath=Join-Path $ScratchPath ('run-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $ScratchPath -Force | Out-Null
$Root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$entry=Join-Path $Root 'AD_UserManagement.ps1'
# Desactivar AD autoload + interceptar todos los cmdlets alcanzables por esta ruta.
$Global:CAUAuditWriteAttempts=0
function global:New-ADUser {
    [CmdletBinding()] param($SamAccountName,$Name,$DisplayName,$GivenName,$Surname,$UserPrincipalName,$EmailAddress,$OfficePhone,$Office,$Description,$AccountPassword,$Enabled,$ChangePasswordAtLogon,$Server,$Path,[switch]$PassThru)
    $Global:CAUAuditWriteAttempts++
    if ($Global:CAUAuditCase -eq 'CreationFailure') { Write-Error 'Write AD interceptado: fallo sintético no terminante.'; return }
    $Global:CAUAuditCreated=[pscustomobject]@{ObjectGUID=[guid]'33333333-3333-3333-3333-333333333333';SamAccountName=$SamAccountName;Name=$Name;DisplayName=$DisplayName;GivenName=$GivenName;Surname=$Surname;UserPrincipalName=$UserPrincipalName;mail=$EmailAddress;telephoneNumber=$OfficePhone;Office=$Office;Description=$Description;Enabled=$Enabled;pwdLastSet=0;DistinguishedName="CN=Fixture,$Path";MemberOf=@()}
    if ($PassThru) { $Global:CAUAuditCreated }
}
function global:Remove-ADUser { $Global:CAUAuditWriteAttempts++; throw 'Write AD prohibido en harness' }
function global:Move-ADObject { $Global:CAUAuditWriteAttempts++; throw 'Write AD prohibido en harness' }
function global:Set-ADUser { $Global:CAUAuditWriteAttempts++; throw 'Write AD prohibido en harness' }
function global:Set-ADAccountPassword { $Global:CAUAuditWriteAttempts++; throw 'Write AD prohibido en harness' }
function global:Add-ADGroupMember {
    [CmdletBinding()] param($Identity,$Members,$Server)
    $Global:CAUAuditWriteAttempts++
    if ($Global:CAUAuditCase -eq 'GroupCopyFailure') { Write-Error 'Error de grupo sintético no terminante'; return }
    $Global:CAUAuditCreated.MemberOf+=@($Identity.DistinguishedName)
}
function global:Get-ADGroup { [CmdletBinding()] param($Identity,$Server) [pscustomobject]@{Name='Fixture';DistinguishedName=$Identity} }
function global:Remove-ADGroupMember { $Global:CAUAuditWriteAttempts++; throw 'Write AD prohibido en harness' }
function global:Get-ADUser {
    [CmdletBinding()] param($Filter,$Identity,$Server,$Properties,$SearchBase,$SearchScope)
    if ($SearchBase) { return [pscustomobject]@{SamAccountName='template';Description='fixture';MemberOf=@('CN=FixtureGroup,DC=example,DC=invalid')} }
    if ($Identity) {
        if ($Global:CAUAuditCase -eq 'CreationVerificationFailure') { Write-Error 'Lectura final sintética no terminante'; return }
        return $Global:CAUAuditCreated
    }
    $null
}
function global:Get-ADForest { [CmdletBinding()] param() [pscustomobject]@{Domains=@('example.invalid')} }
function global:Get-ADDomain { [CmdletBinding()] param($Identity) [pscustomobject]@{DNSRoot='example.invalid';DistinguishedName='DC=example,DC=invalid';Name='example'} }
function global:Get-ADOrganizationalUnit { [CmdletBinding()] param($Filter,$Server,$Properties,$SearchBase,$SearchScope) $Global:CAUAuditFixtureOUs }
function global:Read-Host { throw 'Interacción no permitida en harness offline' }
$alias=[pscustomobject]@{Alias='sección 1 del tribunal de instrucción de sevilla';Locality='sevilla';SourceType='INSTRUCCION';SourceNumber='1';TargetType='INSTRUCCION';TargetNumber='1';TargetName='juzgado de instrucción 1 sevilla'}
$Global:CAUAuditFixtureOUs=@([pscustomobject]@{Name=$alias.TargetName;DistinguishedName='OU=Mixto 1,OU=Fixture,DC=example,DC=invalid'})
$aliasPath=Join-Path $ScratchPath 'aliases.json'
@($alias) | ConvertTo-Json | Set-Content -LiteralPath $aliasPath -Encoding UTF8
$results=@()
foreach ($case in @('AliasWhatIf','Unresolved','Ambiguous','CreationFailure','GroupCopyFailure','CreationVerificationFailure','CreationVerified')) {
    try {
        $Global:CAUAuditCase=$case; $Global:CAUAuditCreated=$null
        $csv=Join-Path $ScratchPath ($case+'.csv')
        [pscustomobject]@{TipoAlta='NORMALIZADA';Nombre='Fixture';Apellidos='Sintetica';Email='fixture@example.invalid';Telefono='';Oficina=$alias.Alias;Descripcion='fixture'} | Export-Csv -LiteralPath $csv -Delimiter ';' -NoTypeInformation -Encoding UTF8
        $params=@{CSVFile=$csv;LogDirectory=(Join-Path $ScratchPath 'logs')}
        if ($case -eq 'AliasWhatIf') { $params.WhatIf=$true; $params.UOAliasPath=$aliasPath }
        if ($case -eq 'Unresolved') { $Global:CAUAuditFixtureOUs=@([pscustomobject]@{Name='juzgado de primera instancia e instrucción 1 sevilla';DistinguishedName='OU=Mixto 1,DC=example,DC=invalid'}) }
        if ($case -eq 'Ambiguous') { $params.UOAliasPath=$aliasPath; $Global:CAUAuditFixtureOUs=@([pscustomobject]@{Name=$alias.TargetName;DistinguishedName='OU=A,DC=example,DC=invalid'},[pscustomobject]@{Name=$alias.TargetName;DistinguishedName='OU=B,DC=example,DC=invalid'}) }
        if ($case -in @('CreationFailure','GroupCopyFailure','CreationVerificationFailure','CreationVerified')) { $params.UOAliasPath=$aliasPath; $Global:CAUAuditFixtureOUs=@([pscustomobject]@{Name=$alias.TargetName;DistinguishedName='OU=Fixture,DC=example,DC=invalid'}) }
        $Global:CAUAuditWriteAttempts=0
        try {
            if ($case -in @('CreationFailure','GroupCopyFailure','CreationVerificationFailure','CreationVerified')) { $ErrorActionPreference='Continue' }
            & $entry @params 2>$null
        } finally { $ErrorActionPreference='Stop' }
        $resultFile=@(Get-ChildItem -LiteralPath $ScratchPath -Filter ($case+'_resultados_*.csv'))[-1]
        $rows=@(Import-Csv -LiteralPath $resultFile.FullName -Delimiter ';' -Encoding UTF8)
        if ($rows.Count -ne 1) { throw 'El informe debe contener exactamente un registro sintético' }
        $expectedAttempts=if($case -eq 'CreationFailure'){1}elseif($case -in @('GroupCopyFailure','CreationVerificationFailure','CreationVerified')){2}else{0}
        if ($Global:CAUAuditWriteAttempts -ne $expectedAttempts) { throw "Intentos AD interceptados: $Global:CAUAuditWriteAttempts, esperado $expectedAttempts" }
        if ($case -eq 'AliasWhatIf') {
            if ($rows[0].Estado -ne 'SIMULADO' -or $rows[0].UO_Destino -cne $Global:CAUAuditFixtureOUs[0].DistinguishedName) { throw 'WhatIf no devolvió DN fixture y estado SIMULADO' }
        } elseif ($case -eq 'CreationVerified') {
            if ($rows[0].Estado -ne 'EXITOSO') { throw 'Alta completamente verificada debe declarar EXITOSO' }
        } elseif ($rows[0].Estado -ne 'ERROR') { throw 'Fallo de resolucion, escritura o verificacion debe declarar ERROR' }
        $results += [pscustomobject]@{Name=$case;Passed=$true;WriteAttempts=$Global:CAUAuditWriteAttempts;Error=$null}
    } catch { $results += [pscustomobject]@{Name=$case;Passed=$false;WriteAttempts=$Global:CAUAuditWriteAttempts;Error=$_.Exception.Message} }
}
$summary=[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();Mode='ENTRYPOINT REAL CON CMDLETS AD INTERCEPTADOS; NO AD REAL';Tests=$results;Passed=@($results | Where-Object Passed).Count;Failed=@($results | Where-Object { -not $_.Passed }).Count}
if ($ResultPath) { $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding UTF8 }
$summary | ConvertTo-Json -Depth 8
if ($summary.Failed) { exit 1 }
