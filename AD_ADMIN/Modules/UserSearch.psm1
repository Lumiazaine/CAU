# #Requires -Modules ActiveDirectory  # Comentado para desarrollo

<#
.SYNOPSIS
    Modulo para la busqueda de usuarios en Active Directory
.DESCRIPTION
    Proporciona funciones para buscar usuarios por diversos criterios con seleccion interactiva
#>

Import-Module "$PSScriptRoot\PasswordManager.psm1" -Force

function Find-ADUserByCriteria {
    <#
    .SYNOPSIS
        Busca usuarios en AD por diversos criterios
    .PARAMETER SearchCriteria
        Hashtable con los criterios de busqueda
    .PARAMETER ExactMatch
        Si se debe realizar busqueda exacta o con wildcards
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SearchCriteria,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExactMatch
    )
    
    $FilterParts = @()
    
    foreach ($Key in $SearchCriteria.Keys) {
        $Value = $SearchCriteria[$Key]
        if ([string]::IsNullOrWhiteSpace($Value)) {
            continue
        }
        
        $SearchValue = if ($ExactMatch) { $Value } else { "*$Value*" }
        
        switch ($Key.ToLower()) {
            "nombre" { 
                $FilterParts += "GivenName -like '$SearchValue'"
            }
            "apellidos" { 
                $FilterParts += "Surname -like '$SearchValue'"
            }
            "descripcion" { 
                $FilterParts += "Description -like '$SearchValue'"
            }
            "oficina" { 
                $FilterParts += "Office -like '$SearchValue'"
            }
            "telefono" { 
                $FilterParts += "(telephoneNumber -like '$SearchValue' -or mobile -like '$SearchValue')"
            }
            "email" { 
                $FilterParts += "(mail -like '$SearchValue' -or proxyAddresses -like '*$SearchValue*')"
            }
            "samaccountname" {
                $FilterParts += "SamAccountName -like '$SearchValue'"
            }
            "employeeid" {
                $FilterParts += "EmployeeID -like '$SearchValue'"
            }
        }
    }
    
    if ($FilterParts.Count -eq 0) {
        Write-Warning "No se proporcionaron criterios de busqueda validos"
        return @()
    }
    
    $Filter = $FilterParts -join " -or "
    
    try {
        Write-Verbose "Ejecutando busqueda con filtro: $Filter"
        
        $Users = Get-ADUser -Filter $Filter -Properties @(
            'GivenName', 'Surname', 'DisplayName', 'SamAccountName', 
            'mail', 'telephoneNumber', 'mobile', 'Office', 'Description', 
            'EmployeeID', 'Department', 'Title', 'Manager', 'DistinguishedName',
            'Enabled', 'LastLogonDate', 'Created', 'Modified'
        )
        
        Write-Verbose "Encontrados $($Users.Count) usuarios"
        return $Users
        
    } catch {
        Write-Error "Error en la busqueda de usuarios: $($_.Exception.Message)"
        return @()
    }
}

function Search-UserByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$FirstName,
        
        [Parameter(Mandatory=$false)]
        [string]$LastName,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExactMatch
    )
    
    $SearchCriteria = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($FirstName)) {
        $SearchCriteria["nombre"] = $FirstName
    }
    
    if (-not [string]::IsNullOrWhiteSpace($LastName)) {
        $SearchCriteria["apellidos"] = $LastName
    }
    
    return Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch:$ExactMatch
}

function Search-UserByEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExactMatch
    )
    
    $SearchCriteria = @{
        "email" = $Email
    }
    
    return Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch:$ExactMatch
}

function Search-UserByPhone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Phone,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExactMatch
    )
    
    $SearchCriteria = @{
        "telefono" = $Phone
    }
    
    return Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch:$ExactMatch
}

function Search-UserByOffice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Office,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExactMatch
    )
    
    $SearchCriteria = @{
        "oficina" = $Office
    }
    
    return Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch:$ExactMatch
}

function Get-UserDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -Properties @(
            'GivenName', 'Surname', 'DisplayName', 'SamAccountName', 
            'mail', 'telephoneNumber', 'mobile', 'Office', 'Description', 
            'EmployeeID', 'Department', 'Title', 'Manager', 'DistinguishedName',
            'Enabled', 'LastLogonDate', 'Created', 'Modified', 'MemberOf',
            'HomeDirectory', 'HomeDrive', 'ProfilePath', 'ScriptPath'
        )
        
        $Groups = Get-ADPrincipalGroupMembership -Identity $Identity | Select-Object Name, DistinguishedName
        
        $UserDetails = [PSCustomObject]@{
            User = $User
            Groups = $Groups
            GroupCount = $Groups.Count
        }
        
        return $UserDetails
        
    } catch {
        Write-Error "Error obteniendo detalles del usuario $Identity`: $($_.Exception.Message)"
        return $null
    }
}

function Format-UserSearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Users
    )
    
    if ($Users.Count -eq 0) {
        Write-Host "No se encontraron usuarios con los criterios especificados." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nResultados de busqueda ($($Users.Count) usuarios encontrados):" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Green
    
    foreach ($User in $Users) {
        Write-Host "Nombre completo: $($User.DisplayName)" -ForegroundColor White
        Write-Host "SamAccountName: $($User.SamAccountName)" -ForegroundColor Gray
        Write-Host "Email: $($User.mail)" -ForegroundColor Gray
        Write-Host "Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
        Write-Host "Oficina: $($User.Office)" -ForegroundColor Gray
        Write-Host "Descripcion: $($User.Description)" -ForegroundColor Gray
        Write-Host "Estado: $(if ($User.Enabled) {'Activo'} else {'Inactivo'})" -ForegroundColor $(if ($User.Enabled) {'Green'} else {'Red'})
        Write-Host "Ultimo acceso: $($User.LastLogonDate)" -ForegroundColor Gray
        Write-Host ("=" * 80) -ForegroundColor Gray
    }
}

function Start-InteractiveUserSearch {
    [CmdletBinding()]
    param()
    
    Write-Host "=== BUSQUEDA INTERACTIVA DE USUARIOS ===" -ForegroundColor Cyan
    Write-Host "Proporcione al menos uno de los siguientes criterios de busqueda:" -ForegroundColor Yellow
    Write-Host "(Puede dejar campos vacios presionando Enter)" -ForegroundColor Gray
    Write-Host ""
    
    $SearchCriteria = @{}
    
    $Nombre = Read-Host "Nombre"
    if (-not [string]::IsNullOrWhiteSpace($Nombre)) {
        $SearchCriteria["nombre"] = $Nombre
    }
    
    $Apellidos = Read-Host "Apellidos"
    if (-not [string]::IsNullOrWhiteSpace($Apellidos)) {
        $SearchCriteria["apellidos"] = $Apellidos
    }
    
    $Email = Read-Host "Correo electronico"
    if (-not [string]::IsNullOrWhiteSpace($Email)) {
        $SearchCriteria["email"] = $Email
    }
    
    $Telefono = Read-Host "Numero de telefono"
    if (-not [string]::IsNullOrWhiteSpace($Telefono)) {
        $SearchCriteria["telefono"] = $Telefono
    }
    
    $Oficina = Read-Host "Oficina"
    if (-not [string]::IsNullOrWhiteSpace($Oficina)) {
        $SearchCriteria["oficina"] = $Oficina
    }
    
    $Descripcion = Read-Host "Descripcion"
    if (-not [string]::IsNullOrWhiteSpace($Descripcion)) {
        $SearchCriteria["descripcion"] = $Descripcion
    }
    
    if ($SearchCriteria.Count -eq 0) {
        Write-Host "No se proporcionaron criterios de busqueda. Operacion cancelada." -ForegroundColor Red
        return
    }
    
    Write-Host "`nBuscando usuarios..." -ForegroundColor Yellow
    $Users = Find-ADUserByCriteria -SearchCriteria $SearchCriteria
    
    if ($Users.Count -eq 0) {
        Show-NoUsersFoundOptions -SearchCriteria $SearchCriteria
    } else {
        Show-UserSelectionMenu -Users $Users
    }
}

function Show-NoUsersFoundOptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SearchCriteria
    )
    
    Write-Host "`nNo se encontraron usuarios con los criterios especificados." -ForegroundColor Red
    Write-Host "Criterios utilizados:" -ForegroundColor Yellow
    
    foreach ($Key in $SearchCriteria.Keys) {
        Write-Host "  $Key`: $($SearchCriteria[$Key])" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Desea realizar una nueva busqueda con criterios adicionales? (S/N)" -ForegroundColor Yellow
    $Response = Read-Host
    
    if ($Response -match '^[SsYy]') {
        Start-InteractiveUserSearch
    }
}

function Show-UserSelectionMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Users
    )
    
    Write-Host "`n=== USUARIOS ENCONTRADOS ($($Users.Count)) ===" -ForegroundColor Green
    
    for ($i = 0; $i -lt $Users.Count; $i++) {
        $User = $Users[$i]
        $Status = Get-UserStatusIcon -User $User
        
        Write-Host "[$($i+1)] $Status $($User.DisplayName)" -ForegroundColor White
        Write-Host "     Usuario: $($User.SamAccountName)" -ForegroundColor Gray
        Write-Host "     Email: $($User.mail)" -ForegroundColor Gray
        Write-Host "     Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
        Write-Host "     Oficina: $($User.Office)" -ForegroundColor Gray
        Write-Host "     Descripcion: $($User.Description)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Seleccione un usuario (1-$($Users.Count)) o 'Q' para salir:" -ForegroundColor Yellow
    $Selection = Read-Host
    
    if ($Selection -match '^[Qq]') {
        return
    }
    
    if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $Users.Count) {
        $SelectedUser = $Users[$Selection - 1]
        Show-UserManagementMenu -User $SelectedUser
    } else {
        Write-Host "Seleccion invalida. Intente de nuevo." -ForegroundColor Red
        Show-UserSelectionMenu -Users $Users
    }
}

function Get-UserStatusIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    try {
        $UserFull = Get-ADUser -Identity $User.SamAccountName -Properties Enabled, LockedOut -ErrorAction Stop
        
        if (-not $UserFull.Enabled) {
            return "[DESHABILITADO]"
        } elseif ($UserFull.LockedOut) {
            return "[BLOQUEADO]"
        } else {
            return "[ACTIVO]"
        }
    } catch {
        return "[DESCONOCIDO]"
    }
}

function Show-UserManagementMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    do {
        $UserDetails = Get-UserCompleteDetails -Identity $User.SamAccountName
        if (-not $UserDetails) {
            Write-Host "Error obteniendo detalles del usuario." -ForegroundColor Red
            return
        }
        
        Show-UserDetailedInfo -UserDetails $UserDetails
        
        Write-Host "`n=== OPCIONES DE GESTION ===" -ForegroundColor Cyan
        Write-Host "1. Cambiar contraseña (estandar)" -ForegroundColor White
        Write-Host "2. Habilitar usuario" -ForegroundColor White
        Write-Host "3. Deshabilitar usuario" -ForegroundColor White
        Write-Host "4. Desbloquear usuario" -ForegroundColor White
        Write-Host "5. Ver grupos del usuario" -ForegroundColor White
        Write-Host "6. Cambiar contraseña (personalizada)" -ForegroundColor White
        Write-Host "7. Ver informacion de contraseña" -ForegroundColor White
        Write-Host "Q. Volver al menu de busqueda" -ForegroundColor Yellow
        Write-Host ""
        
        $Option = Read-Host "Seleccione una opcion"
        
        switch ($Option.ToUpper()) {
            "1" { 
                Set-UserStandardPassword -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "2" { 
                Enable-UserAccount -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "3" { 
                Disable-UserAccount -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "4" {
                Unlock-UserAccount -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "5" {
                Show-UserGroups -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "6" {
                Set-UserCustomPasswordInteractive -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "7" {
                Show-UserPasswordInfo -Identity $User.SamAccountName
                Write-Host "Presione Enter para continuar..." -ForegroundColor Gray
                Read-Host
            }
            "Q" { return }
            default { 
                Write-Host "Opcion invalida. Intente de nuevo." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

function Get-UserCompleteDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -Properties @(
            'GivenName', 'Surname', 'DisplayName', 'SamAccountName', 
            'mail', 'telephoneNumber', 'mobile', 'Office', 'Description', 
            'EmployeeID', 'Department', 'Title', 'Manager', 'DistinguishedName',
            'Enabled', 'LastLogonDate', 'Created', 'Modified', 'MemberOf',
            'LockedOut', 'AccountLockoutTime', 'PasswordLastSet', 'PasswordNeverExpires'
        ) -ErrorAction Stop
        
        return $User
    } catch {
        Write-Error "Error obteniendo detalles del usuario $Identity`: $($_.Exception.Message)"
        return $null
    }
}

function Show-UserDetailedInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$UserDetails
    )
    
    Write-Host "`n=== INFORMACION DEL USUARIO ===" -ForegroundColor Cyan
    Write-Host "Nombre completo: $($UserDetails.DisplayName)" -ForegroundColor White
    Write-Host "Usuario (SAM): $($UserDetails.SamAccountName)" -ForegroundColor Gray
    Write-Host "Email: $($UserDetails.mail)" -ForegroundColor Gray
    Write-Host "Telefono: $($UserDetails.telephoneNumber)" -ForegroundColor Gray
    Write-Host "Movil: $($UserDetails.mobile)" -ForegroundColor Gray
    Write-Host "Oficina: $($UserDetails.Office)" -ForegroundColor Gray
    Write-Host "Descripcion: $($UserDetails.Description)" -ForegroundColor Gray
    Write-Host "Departamento: $($UserDetails.Department)" -ForegroundColor Gray
    Write-Host "Titulo: $($UserDetails.Title)" -ForegroundColor Gray
    Write-Host "Employee ID: $($UserDetails.EmployeeID)" -ForegroundColor Gray
    
    Write-Host "`n=== ESTADO DE LA CUENTA ===" -ForegroundColor Yellow
    $EnabledText = if ($UserDetails.Enabled) { "ACTIVA" } else { "DESHABILITADA" }
    $EnabledColor = if ($UserDetails.Enabled) { "Green" } else { "Red" }
    Write-Host "Estado: $EnabledText" -ForegroundColor $EnabledColor
    
    if ($UserDetails.LockedOut) {
        Write-Host "Bloqueo: BLOQUEADA" -ForegroundColor Red
        Write-Host "Fecha de bloqueo: $($UserDetails.AccountLockoutTime)" -ForegroundColor Red
    } else {
        Write-Host "Bloqueo: No bloqueada" -ForegroundColor Green
    }
    
    Write-Host "Ultimo acceso: $($UserDetails.LastLogonDate)" -ForegroundColor Gray
    Write-Host "Fecha de creacion: $($UserDetails.Created)" -ForegroundColor Gray
    Write-Host "Ultima modificacion: $($UserDetails.Modified)" -ForegroundColor Gray
    
    if ($UserDetails.PasswordLastSet) {
        $DaysSincePasswordChange = ((Get-Date) - $UserDetails.PasswordLastSet).Days
        Write-Host "Contraseña cambiada: $($UserDetails.PasswordLastSet) ($DaysSincePasswordChange dias)" -ForegroundColor Gray
    }
}

function Enable-UserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        Enable-ADAccount -Identity $Identity -ErrorAction Stop
        Write-Host "Usuario habilitado exitosamente." -ForegroundColor Green
    } catch {
        Write-Host "Error habilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-UserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $Confirmation = Read-Host "Esta seguro de deshabilitar este usuario? (S/N)"
        if ($Confirmation -match '^[SsYy]') {
            Disable-ADAccount -Identity $Identity -ErrorAction Stop
            Write-Host "Usuario deshabilitado exitosamente." -ForegroundColor Green
        } else {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error deshabilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Unlock-UserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        Unlock-ADAccount -Identity $Identity -ErrorAction Stop
        Write-Host "Usuario desbloqueado exitosamente." -ForegroundColor Green
    } catch {
        Write-Host "Error desbloqueando usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-UserGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $Groups = Get-ADPrincipalGroupMembership -Identity $Identity | Sort-Object Name
        
        Write-Host "`n=== GRUPOS DEL USUARIO ($($Groups.Count)) ===" -ForegroundColor Cyan
        
        foreach ($Group in $Groups) {
            Write-Host "- $($Group.Name)" -ForegroundColor White
            Write-Host "  DN: $($Group.DistinguishedName)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error obteniendo grupos del usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-UserCustomPasswordInteractive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    Write-Host ""
    Show-PasswordComplexity
    Write-Host ""
    
    $Password = Read-Host "Ingrese la nueva contraseña" -AsSecureString
    $PasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    
    if ([string]::IsNullOrWhiteSpace($PasswordPlain)) {
        Write-Host "Contraseña vacia. Operacion cancelada." -ForegroundColor Red
        return
    }
    
    $Complexity = Test-PasswordComplexity -Password $PasswordPlain
    if (-not $Complexity.IsComplex) {
        Write-Host "`nLa contraseña no cumple los requisitos de complejidad." -ForegroundColor Red
        Show-PasswordComplexity -Password $PasswordPlain
        
        $Continue = Read-Host "`nDesea continuar de todos modos? (S/N)"
        if ($Continue -notmatch '^[SsYy]') {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            return
        }
    }
    
    $ForceChange = Read-Host "Forzar cambio en el proximo inicio de sesion? (S/N)"
    $ForceChangeSwitch = $ForceChange -match '^[SsYy]'
    
    Set-UserCustomPassword -Identity $Identity -Password $PasswordPlain -ForceChange:$ForceChangeSwitch
}

function Show-UserPasswordInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    $PasswordInfo = Get-PasswordExpirationDate -Identity $Identity
    
    if ($PasswordInfo) {
        Write-Host "`n=== INFORMACION DE CONTRASEÑA ===" -ForegroundColor Cyan
        Write-Host "Estado: $($PasswordInfo.Status)" -ForegroundColor White
        
        if ($PasswordInfo.ExpirationDate) {
            Write-Host "Fecha de expiracion: $($PasswordInfo.ExpirationDate)" -ForegroundColor Gray
            $Color = if ($PasswordInfo.DaysUntilExpiration -le 7) { "Red" } elseif ($PasswordInfo.DaysUntilExpiration -le 30) { "Yellow" } else { "Green" }
            Write-Host "Dias hasta expiracion: $($PasswordInfo.DaysUntilExpiration)" -ForegroundColor $Color
        }
        
        if ($PasswordInfo.NeverExpires) {
            Write-Host "La contraseña nunca expira" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nContraseña estandar actual: $(Get-StandardPassword)" -ForegroundColor Cyan
}

Export-ModuleMember -Function @(
    'Find-ADUserByCriteria',
    'Search-UserByName',
    'Search-UserByEmail',
    'Search-UserByPhone',
    'Search-UserByOffice',
    'Get-UserDetails',
    'Format-UserSearchResults',
    'Start-InteractiveUserSearch',
    'Enable-UserAccount',
    'Disable-UserAccount',
    'Unlock-UserAccount'
)