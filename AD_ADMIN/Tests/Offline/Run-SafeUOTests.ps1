#requires -version 5.1
param([string]$ResultPath, [string]$Case = '*', [switch]$ModulesOnly)
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Security
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $Root 'Modules/UOManager.psm1') -Force -DisableNameChecking
$script:Results = @()
function Assert-Equal($Actual, $Expected) { if ($Actual -cne $Expected) { throw "Esperado '$Expected', obtenido '$Actual'" } }
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch { if ($_.Exception.Message -match $Pattern) { return }; throw }
    throw "Se esperaba rechazo: $Pattern"
}
function Test-Case([string]$Name, [scriptblock]$Action) {
    if ($Name -notlike $Case) { return }
    if ($ModulesOnly -and ($Name -like 'ruta principal*' -or $Name -like 'alta normalizada*' -or $Name -like 'entrypoint*')) { return }
    try { & $Action; $script:Results += [pscustomobject]@{Name=$Name;Passed=$true;Error=$null}; Write-Host "PASS $Name" }
    catch { $script:Results += [pscustomobject]@{Name=$Name;Passed=$false;Error=$_.Exception.Message}; Write-Host "FAIL $Name : $($_.Exception.Message)" }
}
$alias = [pscustomobject]@{
    Alias='sección 1 del tribunal de instrucción de sevilla'; Locality='sevilla'
    SourceType='INSTRUCCION'; SourceNumber='1'; TargetType='INSTRUCCION'; TargetNumber='1'
    TargetName='juzgado de instrucción 1 sevilla'
}
$mixed = [pscustomobject]@{Name=$alias.TargetName;DistinguishedName='OU=Mixto 1,OU=Fixture,DC=example,DC=invalid'}
Test-Case 'alias explícito devuelve el objeto y DN legacy sin alterarlo' {
    $resolved = Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed) -Aliases @($alias)
    Assert-Equal $resolved.DistinguishedName $mixed.DistinguishedName
    Assert-Equal $resolved.Name $mixed.Name
}
Test-Case 'sin alias no hay equivalencia normativa entre materias' {
    $incompatible=[pscustomobject]@{Name='juzgado de primera instancia e instrucción 1 sevilla';DistinguishedName='OU=Mixto 1,OU=Fixture,DC=example,DC=invalid'}
    Assert-Equal (Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($incompatible)) $null
}
Test-Case 'alias no puede mentir sobre localidad tipo o número' {
    foreach ($field in @('Locality','SourceType','SourceNumber','TargetType','TargetNumber')) {
        $bad = $alias | Select-Object *
        $bad.$field = if ($field -like '*Number') { '2' } elseif ($field -like '*Type') { 'PRIMERA_INSTANCIA' } else { 'utrera' }
        Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed) -Aliases @($bad) } 'alias.*(inválido|ámbito)'
    }
}
Test-Case 'alias incompleto se rechaza incluso si no coincide' {
    Assert-Throws { Resolve-UOName -Name 'otro' -OrganizationalUnits @($mixed) -Aliases @([pscustomobject]@{Alias='otro';TargetName=$mixed.Name}) } 'alias.*inválido'
}
Test-Case 'normalización no cambia los límites ni el tipo de órgano' {
    $r = Resolve-UOName -Name '  SECCIÓN   1 DEL TRIBUNAL DE INSTRUCCIÓN DE SEVILLA ' -OrganizationalUnits @($mixed) -Aliases @($alias)
    Assert-Equal $r.DistinguishedName $mixed.DistinguishedName
    foreach ($name in @('sección 11 del tribunal de instrucción de sevilla','sección 1 del tribunal de instrucción de utrera','sección 1 del tribunal de primera instancia de sevilla','juzgado de primera instancia e instrucción 1 sevilla','juzgado de primera instancia 1 sevilla')) {
        Assert-Equal (Resolve-UOName -Name $name -OrganizationalUnits @($mixed) -Aliases @($alias)) $null
    }
}
Test-Case 'DN duplicado idéntico no es ambigüedad pero dos DNs sí' {
    Assert-Equal (Resolve-UOName -Name $mixed.Name -OrganizationalUnits @($mixed,$mixed)).DistinguishedName $mixed.DistinguishedName
    $other = [pscustomobject]@{Name=$mixed.Name;DistinguishedName='OU=Mixto 1,OU=Otro,DC=example,DC=invalid'}
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed,$other) -Aliases @($alias) } 'ambigua'
}
Test-Case 'conflicto alias y nombre actual bloquea selección automática' {
    $current = [pscustomobject]@{Name=$alias.Alias;DistinguishedName='OU=Actual,DC=example,DC=invalid'}
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed,$current) -Aliases @($alias) } 'ambigua'
}
Test-Case 'aliases contradictorios se rechazan antes de resolver' {
    $other = $alias | Select-Object *
    $other.TargetName='juzgado de instrucción Nº 1 de sevilla'
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed) -Aliases @($alias,$other) } 'alias.*(ambiguo|contradictorio)'
}
Test-Case 'Get-UOByName usa el resolver seguro y no la clave fuzzy de provincia' {
    $module = Get-Module UOManager
    & $module { param($ou) Clear-UOCache; $script:ADAvailable=$false; $script:UOCache['sevilla']=[pscustomobject]@{Name='sevilla';DistinguishedName='DC=example,DC=invalid'}; $script:UOCache['fixture']=$ou } $mixed
    Set-UOAliases -Aliases @($alias)
    Assert-Equal (Get-UOByName -Name $alias.Alias -UseCache:$false).DistinguishedName $mixed.DistinguishedName
    Assert-Equal (Get-UOByName -Name 'juzgado de instrucción 11 sevilla' -UseCache:$false) $null
}
Test-Case 'consulta no disponible no fabrica DNs' {
    $module = Get-Module UOManager
    & $module { $script:ADAvailable=$false }
    Assert-Throws { & $module { Get-ADOrganizationalUnitSafe -Filter '*' } } 'ActiveDirectory.*(disponible|inicializado)'
}
Test-Case 'ruta principal usa aliases y rechaza nombres duplicados' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw $errors[0].Message }
    foreach ($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Parent -is [Management.Automation.Language.NamedBlockAst]},$true)) {
        if ($fn.Name -ne 'Write-Log') { . ([scriptblock]::Create($fn.Extent.Text)) }
    }
    function Write-Log { param($Message,$Level) }
    function Get-ADOrganizationalUnit { param($Filter,$Server,$Properties) $script:FixtureOUs }
    function Read-Host { throw 'Interacción no permitida en tests offline' }
    $script:FixtureOUs=@($mixed)
    $script:ConfiguredUOAliases=@($alias)
    Assert-Equal (Find-OrganizationalUnit -Office $alias.Alias -Domain 'example.invalid') $mixed.DistinguishedName
    $script:FixtureOUs=@($mixed,[pscustomobject]@{Name=$mixed.Name;DistinguishedName='OU=Duplicate,DC=example,DC=invalid'})
    Assert-Equal (Find-OrganizationalUnit -Office $mixed.Name -Domain 'example.invalid') $null
}
Test-Case 'alta normalizada bloqueada no intenta crear sin UO' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    $switch = $ast.FindAll({param($n) $n -is [Management.Automation.Language.SwitchStatementAst] -and $n.Condition.Extent.Text -eq '$User.TipoAlta.ToUpper()'},$true)[0]
    $clause = @($switch.Clauses | Where-Object { $_.Item1.Extent.Text -eq '"NORMALIZADA"' })[0].Item2.Extent.Text
    $body=[scriptblock]::Create($clause.Substring(1,$clause.Length-2))
    function Write-Log { param($Message,$Level) $script:CapturedLogs += [string]$Message }
    function Get-DomainFromOffice { 'example.invalid' }
    function New-SamAccountName { [CmdletBinding()] param($GivenName,$Surname,$Domain) 'fixtureuser' }
    function Find-OrganizationalUnit { $null }
    function New-ADUser { $script:WriteAttempts++; throw 'AD write bloqueado por harness' }
    function Get-ADUser { $null }
    $User=[pscustomobject]@{Nombre='Fixture';Apellidos='Sintética';Oficina='sin resolver';TipoAlta='NORMALIZADA';Email='fixture@example.invalid';Descripcion='fixture'}
    $Global:WhatIfMode=$false; $script:WriteAttempts=0; $script:CapturedLogs=@(); $ErrorCount=0; $ProcessedCount=0; $ProcessingResults=@()
    foreach ($record in @($User)) { . $body }
    if (($script:CapturedLogs -join ';') -notmatch 'UO de destino no resuelta') { throw ($script:CapturedLogs -join ';') }
    Assert-Equal $script:WriteAttempts 0
    Assert-Equal $ProcessedCount 0
    Assert-Equal $ErrorCount 1
}
Test-Case 'PasswordManager permite WhatIf común sin parámetro duplicado' {
    Import-Module (Join-Path $Root 'Modules/PasswordManager.psm1') -Force -DisableNameChecking
    Assert-Equal (Get-Command Set-UserCustomPassword).Parameters.ContainsKey('WhatIf') $true
}
Test-Case 'PasswordManager no filtra contraseña en verbose' {
    $records = @(Get-StandardPassword -Verbose 4>&1)
    $secret = @($records | Where-Object { $_ -is [string] })[0]
    foreach ($item in @($records | Where-Object { $_ -is [Management.Automation.VerboseRecord] })) {
        if ($item.Message.Contains($secret)) { throw 'Contraseña en stream verbose' }
    }
}
Test-Case 'inicialización sin AD falla antes de abrir conexiones' {
    $module=Get-Module UOManager
    & $module {
        function Get-Module { param([switch]$ListAvailable,$Name) $null }
        function Initialize-ADConnectionPool { $script:PoolAttempts++; throw 'Conexión prohibida' }
        $script:PoolAttempts=0
        $result=Initialize-UOManager -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($script:PoolAttempts -ne 0) { throw 'Intentó abrir LDAP sin módulo AD' }
        if ($result -ne $false) { throw 'Inicialización sin AD no puede informar éxito' }
        try { Get-ADDomainSafe -Identity 'example.invalid' | Out-Null } catch { return }
        throw 'Se fabricó un dominio sin AD'
    }
}
Test-Case 'PasswordManager no informa éxito sin AD ni tras reset fallido' {
    Import-Module (Join-Path $Root 'Modules/PasswordManager.psm1') -Force -DisableNameChecking
    $module=Get-Module PasswordManager
    & $module { $script:ADAvailable=$false }
    Assert-Throws { & $module { Get-ADUserSafe -Identity fixture -ErrorAction Stop } } 'ActiveDirectory.*disponible'
    Assert-Equal (Set-UserCustomPassword -Identity 'fixture' -Password 'FixtureSecret!123' -Confirm:$false -ErrorAction SilentlyContinue) $false
}
Test-Case 'PasswordManager propaga un reset fallido sin falso éxito' {
    $module=Get-Module PasswordManager
    $result = & $module {
        function Get-ADUserSafe { param($Identity,$ErrorAction) [pscustomobject]@{SamAccountName='fixture'} }
        function Set-ADAccountPasswordSafe { param($Identity,$NewPassword,[switch]$Reset) $false }
        Set-UserCustomPassword -Identity 'fixture' -Password 'FixtureSecret!123' -Confirm:$false -ErrorAction SilentlyContinue
    }
    Assert-Equal $result $false
}
Test-Case 'PasswordManager WhatIf no ejecuta resets' {
    $module=Get-Module PasswordManager
    & $module {
        function Get-ADUserSafe { param($Identity,$ErrorAction) [pscustomobject]@{SamAccountName='fixture'} }
        function Set-ADAccountPasswordSafe { param($Identity,$NewPassword,[switch]$Reset) throw 'Reset no permitido' }
    }
    Assert-Equal (Set-UserCustomPassword -Identity 'fixture' -Password 'FixtureSecret!123' -WhatIf -ErrorAction Stop) $false
}
Test-Case 'SamAccountName conserva un apellido único completo' {
    Import-Module (Join-Path $Root 'Modules/SamAccountNameGenerator.psm1') -Force -DisableNameChecking
    $module=Get-Module SamAccountNameGenerator
    & $module {
        function Test-SamAccountNameUniqueness { param($SamAccountName,$Domain) $true }
        $result=New-SamAccountName -GivenName 'Fixture' -Surname 'Sintetica' -Domain 'example.invalid'
        if ($result -cne 'fsintetica') { throw "Apellido truncado: $result" }
    }
}
Test-Case 'unicidad no se afirma si un dominio no se puede consultar' {
    $module=Get-Module SamAccountNameGenerator
    & $module {
        function Get-ADForest { [CmdletBinding()] param() [pscustomobject]@{Domains=@('example.invalid')} }
        function Get-ADDomain { [CmdletBinding()] param($Identity) [pscustomobject]@{DNSRoot='example.invalid'} }
        function Get-ADUser { [CmdletBinding()] param($Filter,$Server) throw 'Consulta denegada fixture' }
        try { Test-SamAccountNameUniqueness -SamAccountName fixture -Domain example.invalid | Out-Null } catch { return }
        throw 'Unicidad sin verificación completa'
    }
}
Test-Case 'nomenclatura nueva conserva tipo número localidad frente a otros órganos' {
    $instruction=[pscustomobject]@{Name='Juzgado de Instruccion Nº 1 de Sevilla';DistinguishedName='OU=Instruccion 1,OU=SEVILLA -XX- Fixture,DC=example,DC=invalid'}
    $first=[pscustomobject]@{Name='Juzgado de Primera Instancia Nº 1 de Sevilla';DistinguishedName='OU=Civil 1,OU=Fixture,DC=example,DC=invalid'}
    $incompatible=[pscustomobject]@{Name='juzgado de primera instancia e instrucción 1 sevilla';DistinguishedName='OU=Mixto 1,DC=example,DC=invalid'}
    Assert-Equal (Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($incompatible,$instruction,$first)).DistinguishedName $instruction.DistinguishedName
    Assert-Equal (Resolve-UOName -Name 'Sección de Instrucción del Tribunal de Instancia de Sevilla plaza 1' -OrganizationalUnits @($instruction)).DistinguishedName $instruction.DistinguishedName
}
Test-Case 'municipio de ancestro OU no se sustituye por provincia DC' {
    $localMixed=[pscustomobject]@{Name='Juzgado de Primera Instancia e Instruccion Nº 1';DistinguishedName='OU=Mixto 1,OU=UTRERA -XX- Fixture,DC=sevilla,DC=example,DC=invalid'}
    Assert-Equal (Resolve-UOName -Name 'sección 1 del tribunal de primera instancia e instrucción de utrera' -OrganizationalUnits @($localMixed)).DistinguishedName $localMixed.DistinguishedName
    Assert-Equal (Resolve-UOName -Name 'sección 1 del tribunal de primera instancia e instrucción de sevilla' -OrganizationalUnits @($localMixed)) $null
}
Test-Case 'canonical también bloquea dos DNs con misma identidad' {
    $a=[pscustomobject]@{Name='Juzgado de Instruccion Nº 1 de Sevilla';DistinguishedName='OU=A,DC=example,DC=invalid'}
    $b=[pscustomobject]@{Name='Juzgado de Instruccion 1 Sevilla';DistinguishedName='OU=B,DC=example,DC=invalid'}
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($a,$b) } 'ambigua'
}
Test-Case 'entrypoint helpers de traslado respetan WhatIf antes de consultar AD' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    foreach ($name in @('Execute-UserTransfer','Execute-CrossDomainTransfer')) {
        $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)[0]
        . ([scriptblock]::Create($fn.Extent.Text))
        if (-not (Get-Command $name).Parameters.ContainsKey('WhatIf')) { throw "$name no declara ShouldProcess/WhatIf" }
        $script:ADReadAttempts=0
        function Get-ADUser { $script:ADReadAttempts++; throw 'Consulta no permitida bajo WhatIf' }
        function Write-Log { param($Message,$Level) }
        $Global:WhatIfMode=$false
        $result=& $name -ExistingUser ([pscustomobject]@{SamAccountName='fixture'}) -TargetDomain example.invalid -TargetOU 'OU=Fixture,DC=example,DC=invalid' -UserData ([pscustomobject]@{}) -WhatIf -ErrorAction Stop
        Assert-Equal $result $false
        Assert-Equal $script:ADReadAttempts 0
    }
}
Test-Case 'entrypoint no imprime valores de contraseñas en logs' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    $leaks=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Write-Log' -and $n.Extent.Text -match '\$(StandardPassword|UserPassword|Month|Year)\b'},$true))
    if ($leaks.Count) { throw "Logs con secretos en líneas $($leaks.Extent.StartLineNumber -join ',')" }
}
Test-Case 'PS51 fuentes unicode modificadas declaran UTF8 BOM' {
    $files=@('Modules/UOManager.psm1','Modules/PasswordManager.psm1','Modules/SamAccountNameGenerator.psm1')
    if (-not $ModulesOnly) { $files+='AD_UserManagement.ps1' }
    foreach ($file in $files) {
        $bytes=[IO.File]::ReadAllBytes((Join-Path $Root $file))
        if ($bytes.Length -lt 3 -or $bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) { throw "Falta UTF8 BOM para PS5.1: $file" }
    }
}
Test-Case 'contenedor no oculta fallo de lectura ni elige Users ambiguo' {
    $module=Get-Module UOManager
    & $module {
        param($ou)
        $script:ADAvailable=$true; $script:ContainerCache=@{}
        function Get-ADOrganizationalUnitSafe { param($Filter,$SearchBase,$SearchScope,$Properties) if ($SearchScope -eq 'OneLevel') { throw 'Lectura denegada fixture' }; $ou }
        try { Get-UOContainer -UOName $ou.Name | Out-Null } catch { return }
        throw 'Error de lectura oculto con fallback al padre'
    } $mixed
    & $module {
        param($ou)
        $script:ADAvailable=$true; $script:ContainerCache=@{}
        function Get-ADOrganizationalUnitSafe {
            param($Filter,$SearchBase,$SearchScope,$Properties)
            if ($SearchScope -eq 'OneLevel') { return @([pscustomobject]@{DistinguishedName='OU=Users,OU=A,DC=example,DC=invalid'},[pscustomobject]@{DistinguishedName='OU=Users,OU=B,DC=example,DC=invalid'}) }
            $ou
        }
        try { Get-UOContainer -UOName $ou.Name | Out-Null } catch { if ($_.Exception.Message -match 'ambigu') { return }; throw }
        throw 'Users ambiguo aceptado'
    } $mixed
}
Test-Case 'inicialización disponible devuelve un único booleano sin fugas de TryAdd' {
    $module=Get-Module UOManager
    $result=& $module {
        Clear-UOCache
        function Get-Module { param([switch]$ListAvailable,$Name) [pscustomobject]@{Name='ActiveDirectory fixture'} }
        function Initialize-ADConnectionPool { }
        function Get-ADDomainSafe { param($Identity,$ErrorAction) [pscustomobject]@{Name=$Identity;DistinguishedName='DC=example,DC=invalid'} }
        Initialize-UOManager -EnablePerformanceTracking:$false -ErrorAction Stop
    }
    Assert-Equal @($result).Count 1
    Assert-Equal $result $true
}
Test-Case 'alias explícito nunca autoriza cruce de materia' {
    $bad=$alias | Select-Object *
    $bad.TargetType='MIXTO'; $bad.TargetName='juzgado de primera instancia e instrucción 1 sevilla'
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed) -Aliases @($bad) } 'Alias.*(materia|tipo).*incompatible'
}
Test-Case 'alias explícito nunca renumera una plaza de instrucción' {
    $bad=$alias | Select-Object *
    $bad.TargetNumber='2'; $bad.TargetName='juzgado de instrucción 2 sevilla'
    Assert-Throws { Resolve-UOName -Name $alias.Alias -OrganizationalUnits @($mixed) -Aliases @($bad) } 'Alias.*número.*incompatible'
}
Test-Case 'contraseña temporal es aleatoria compleja y no depende del calendario' {
    Import-Module (Join-Path $Root 'Modules/PasswordManager.psm1') -Force -DisableNameChecking
    $seen=@{}
    foreach ($i in 1..128) {
        $password=Get-StandardPassword
        if ($password.Length -lt 24 -or -not (Test-PasswordComplexity $password).IsComplex -or $password -match '^Justicia[0-9]{4}$') {
            throw 'Contraseña temporal predecible o insuficientemente compleja; valor omitido.'
        }
        if ($seen.ContainsKey($password)) { throw 'Generador reutilizó una contraseña; valor omitido.' }
        $seen[$password]=$true
    }
    $source=[IO.File]::ReadAllText((Join-Path $Root 'Modules/PasswordManager.psm1'))
    if ($source -notmatch 'Security.Cryptography.RandomNumberGenerator' -or $source -match '\bGet-Random\b') {
        throw 'Generador debe utilizar CSPRNG, no PRNG general.'
    }
}
Test-Case 'entrypoint reutiliza el generador criptográfico sin claves por fecha' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw $errors[0].Message }
    $assignments=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -match '^\$(StandardPassword|UserPassword)$'},$true))
    if ($assignments.Count -lt 3) { throw 'No se encontraron los tres flujos de contraseña activa.' }
    foreach ($assignment in $assignments) {
        # La eliminación explícita del secreto en finally no es una generación de contraseña.
        if ($assignment.Right.Extent.Text.Trim() -ceq '$null') { continue }
        if ($assignment.Right.Extent.Text.Trim() -cne 'Get-StandardPassword') { throw "Contraseña activa no utiliza CSPRNG en línea $($assignment.Extent.StartLineNumber); valor omitido." }
    }
    if ([IO.File]::ReadAllText((Join-Path $Root 'AD_UserManagement.ps1')) -notmatch "Import-Module .*Modules/PasswordManager.psm1") { throw 'Falta importar el generador de contraseñas.' }
}
Test-Case 'traslado entre dominios bloquea colisión sin borrar usuario destino' {
    Import-Module (Join-Path $Root 'Modules/PasswordManager.psm1') -Force -DisableNameChecking
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Execute-CrossDomainTransfer'},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
    function Write-Log { param($Message,$Level) }
    function Find-TemplateUserInOU { $null }
    function Get-ADUser { [CmdletBinding()] param($Identity,$Filter,$Server,$Properties) [pscustomobject]@{SamAccountName='fixture';Name='Fixture';SourceDomain='source.invalid'} }
    function Remove-ADUser { [CmdletBinding(SupportsShouldProcess)] param($Identity,$Server) $script:CollisionWrites++; throw 'Borrado interceptado.' }
    function New-ADUser { [CmdletBinding()] param($SamAccountName) $script:CollisionWrites++; throw 'Alta interceptada.' }
    $script:CollisionWrites=0; $Global:WhatIfMode=$false
    $r=Execute-CrossDomainTransfer -ExistingUser ([pscustomobject]@{SamAccountName='fixture';SourceDomain='source.invalid'}) -TargetDomain target.invalid -TargetOU 'OU=Fixture,DC=target,DC=invalid' -UserData ([pscustomobject]@{Descripcion='Fixture';Oficina='Fixture';Email='fixture@example.invalid';Telefono=''}) -Confirm:$false
    Assert-Equal $script:CollisionWrites 0
    Assert-Equal $r $false
}
Test-Case 'traslado entre dominios bloquea consulta de colisión fallida' {
    Import-Module (Join-Path $Root 'Modules/PasswordManager.psm1') -Force -DisableNameChecking
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'AD_UserManagement.ps1'),[ref]$tokens,[ref]$errors)
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Execute-CrossDomainTransfer'},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
    function Write-Log { param($Message,$Level) }
    function Find-TemplateUserInOU { $null }
    function Get-ADUser {
        [CmdletBinding()] param($Identity,$Filter,$Server,$Properties)
        if ($Filter) { $script:CollisionReads++; Write-Error 'Consulta fixture denegada'; return }
        [pscustomobject]@{SamAccountName='fixture';Name='Fixture';SourceDomain='source.invalid'}
    }
    function Remove-ADUser { $script:DeniedWrites++; throw 'Borrado interceptado.' }
    function New-ADUser { $script:DeniedWrites++; throw 'Alta interceptada.' }
    $script:DeniedWrites=0; $script:CollisionReads=0; $Global:WhatIfMode=$false
    $r=Execute-CrossDomainTransfer -ExistingUser ([pscustomobject]@{SamAccountName='fixture';SourceDomain='source.invalid'}) -TargetDomain target.invalid -TargetOU 'OU=Fixture,DC=target,DC=invalid' -UserData ([pscustomobject]@{Descripcion='Fixture';Oficina='Fixture';Email='fixture@example.invalid';Telefono=''}) -Confirm:$false
    Assert-Equal $script:CollisionReads 1
    Assert-Equal $script:DeniedWrites 0
    Assert-Equal $r $false
}
Test-Case 'DT1 sección civil y de instrucción conserva MIXTO municipio y plaza' {
    $legacy=[pscustomobject]@{Name='Juzgado de Primera Instancia e Instrucción Nº 1';DistinguishedName='OU=ObservedMixed,OU=UTRERA -XX- Fixture,DC=sevilla,DC=example,DC=invalid'}
    foreach ($name in @('Sección Civil y de Instrucción del Tribunal de Instancia de Utrera plaza 1','Sección Civil y de Instrucción Única del Tribunal de Instancia de Utrera')) {
        Assert-Equal (Resolve-UOName -Name $name -OrganizationalUnits @($legacy)).DistinguishedName $legacy.DistinguishedName
    }
    foreach ($name in @('Sección de Instrucción del Tribunal de Instancia de Utrera plaza 1','Sección Civil y de Instrucción del Tribunal de Instancia de Utrera plaza 2','Sección Civil y de Instrucción del Tribunal de Instancia de Sevilla plaza 1','Sección de Familia del Tribunal de Instancia de Utrera plaza 1')) {
        Assert-Equal (Resolve-UOName -Name $name -OrganizationalUnits @($legacy)) $null
    }
}
Test-Case 'DT1 sección civil equivale solo a PRIMERA_INSTANCIA misma plaza y municipio' {
    $legacy=[pscustomobject]@{Name='Juzgado de Primera Instancia Nº 1 de Sevilla';DistinguishedName='OU=ObservedCivil,DC=example,DC=invalid'}
    $mixed=[pscustomobject]@{Name='Juzgado de Primera Instancia e Instrucción Nº 1 de Sevilla';DistinguishedName='OU=ObservedMixed,DC=example,DC=invalid'}
    $instruction=[pscustomobject]@{Name='Juzgado de Instrucción Nº 1 de Sevilla';DistinguishedName='OU=ObservedInstruction,DC=example,DC=invalid'}
    Assert-Equal (Resolve-UOName -Name 'Sección Civil del Tribunal de Instancia de Sevilla plaza 1' -OrganizationalUnits @($mixed,$instruction,$legacy)).DistinguishedName $legacy.DistinguishedName
    foreach ($name in @('Sección Civil del Tribunal de Instancia de Sevilla plaza 2','Sección Civil del Tribunal de Instancia de Utrera plaza 1','Sección de Familia del Tribunal de Instancia de Sevilla plaza 1')) {
        Assert-Equal (Resolve-UOName -Name $name -OrganizationalUnits @($legacy)) $null
    }
    Assert-Equal (Resolve-UOName -Name 'Sección de Instrucción del Tribunal de Instancia de Sevilla plaza 1' -OrganizationalUnits @($mixed,$instruction,$legacy)).DistinguishedName $instruction.DistinguishedName
}
$summary = [pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();Tests=@($script:Results);Passed=@($script:Results | Where-Object Passed).Count;Failed=@($script:Results | Where-Object { -not $_.Passed }).Count;Mode='OFFLINE; fixtures sintéticas; ningún resultado de AD real'}
if ($ResultPath) { $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding UTF8 }
$summary | ConvertTo-Json -Depth 8
if ($summary.Failed -gt 0) { exit 1 }
