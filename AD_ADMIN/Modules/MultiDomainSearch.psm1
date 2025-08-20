#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para búsqueda de usuarios en múltiples dominios
.DESCRIPTION
    Proporciona funciones para buscar usuarios en todos los dominios del bosque con interfaz interactiva
#>

Import-Module "$PSScriptRoot\DomainStructureManager.psm1" -Force
Import-Module "$PSScriptRoot\UserSearch.psm1" -Force
Import-Module "$PSScriptRoot\PasswordManager.psm1" -Force

function Get-SafePropertyValue {
    <#
    .SYNOPSIS
        Obtiene el valor de una propiedad de AD de manera segura, manejando colecciones
    #>
    param([object]$Property)
    
    try {
        if ($null -eq $Property -or $Property -eq "") {
            return ""
        }
        
        # Si es una colección, tomar el primer elemento
        if ($Property -is [Microsoft.ActiveDirectory.Management.ADPropertyValueCollection]) {
            if ($Property.Count -gt 0) {
                return $Property[0].ToString()
            } else {
                return ""
            }
        }
        
        # Si es un array, tomar el primer elemento
        if ($Property -is [Array] -and $Property.Count -gt 0) {
            return $Property[0].ToString()
        }
        
        # Para cualquier otro tipo, convertir a string de manera segura
        if ($Property.GetType().Name -eq "String") {
            return $Property
        }
        
        return $Property.ToString()
    } catch {
        # En caso de error, devolver string vacío
        return ""
    }
}

function Search-UsersInAllDomains {
    <#
    .SYNOPSIS
        Busca usuarios en todos los dominios disponibles
    .PARAMETER SearchTerm
        Término de búsqueda (busca en nombre, apellido, usuario, email, descripción)
    .PARAMETER SelectedDomains
        Array de dominios donde buscar (opcional, si no se especifica busca en todos)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchTerm,
        
        [Parameter(Mandatory=$false)]
        [array]$SelectedDomains
    )
    
    # Si no se especificaron dominios, obtener todos los disponibles
    if (-not $SelectedDomains) {
        $SelectedDomains = Get-AllAvailableDomains | Where-Object { $_.Available }
    }
    
    $AllUsers = @()
    $TotalDomains = $SelectedDomains.Count
    $CompletedDomains = 0
    
    Write-Host "`nBuscando '$SearchTerm' en $TotalDomains dominios..." -ForegroundColor Yellow
    
    foreach ($Domain in $SelectedDomains) {
        $CompletedDomains++
        
        Write-Host "`n[$CompletedDomains/$TotalDomains] Buscando en: $($Domain.Name)" -ForegroundColor Cyan
        Write-Progress -Activity "Búsqueda Multi-Dominio" -Status "Dominio: $($Domain.Name)" -PercentComplete (($CompletedDomains / $TotalDomains) * 100)
        
        try {
            # Crear criterios de búsqueda para UserSearch
            $SearchCriteria = @{
                "nombre" = $SearchTerm
                "apellidos" = $SearchTerm
                "samaccountname" = $SearchTerm
                "email" = $SearchTerm
                "descripcion" = $SearchTerm
            }
            
            # Construir filtro LDAP manualmente para multi-criterio
            $Filter = "GivenName -like '*$SearchTerm*' -or Surname -like '*$SearchTerm*' -or SamAccountName -like '*$SearchTerm*' -or DisplayName -like '*$SearchTerm*' -or mail -like '*$SearchTerm*' -or Description -like '*$SearchTerm*'"
            
            $Users = Get-ADUser -Filter $Filter -Server $Domain.Name -Properties @(
                'DisplayName', 'mail', 'telephoneNumber', 'mobile', 'Office', 
                'Description', 'Enabled', 'LastLogonDate', 'Created', 'Modified',
                'Department', 'Title', 'Manager', 'EmployeeID', 'LockedOut'
            ) -ErrorAction Stop
            
            if ($Users) {
                # Asegurar que $Users es un array
                $UserArray = @($Users)
                $UserCount = $UserArray.Count
                
                foreach ($User in $Users) {
                    # Añadir metadatos del dominio
                    $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain.Name -Force
                    $User | Add-Member -NotePropertyName "SourceDomainNetBIOS" -NotePropertyValue $Domain.NetBIOSName -Force
                    $User | Add-Member -NotePropertyName "ForestName" -NotePropertyValue $Domain.Forest -Force
                    
                    # Determinar estado del usuario
                    $UserStatus = "ACTIVO"
                    if (-not $User.Enabled) {
                        $UserStatus = "DESHABILITADO"
                    } elseif ($User.LockedOut) {
                        $UserStatus = "BLOQUEADO"
                    }
                    $User | Add-Member -NotePropertyName "UserStatus" -NotePropertyValue $UserStatus -Force
                    
                    $AllUsers += $User
                }
                
                Write-Host "  Encontrados: $UserCount usuarios" -ForegroundColor Green
            } else {
                Write-Host "  Sin resultados" -ForegroundColor Gray
            }
            
        } catch {
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Progress -Activity "Búsqueda Multi-Dominio" -Completed
    return $AllUsers
}

function Show-MultiDomainSearchResults {
    <#
    .SYNOPSIS
        Muestra los resultados de búsqueda multi-dominio con interfaz interactiva
    .PARAMETER Users
        Array de usuarios encontrados
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Users
    )
    
    # Asegurar que $Users es un array y obtener el conteo de manera segura
    $UserArray = @($Users)
    $UserCount = $UserArray.Count
    
    if ($UserCount -eq 0) {
        Write-Host "`nNo se encontraron usuarios con los criterios especificados." -ForegroundColor Red
        return $null
    }
    
    # Ordenar usuarios por dominio y nombre
    $SortedUsers = $UserArray | Sort-Object SourceDomain, DisplayName
    
    Write-Host "`n=== RESULTADOS DE BÚSQUEDA ($UserCount usuarios) ===" -ForegroundColor Green
    Write-Host ("=" * 100) -ForegroundColor Green
    
    for ($i = 0; $i -lt $UserCount; $i++) {
        $User = $SortedUsers[$i]
        $StatusColor = switch ($User.UserStatus) {
            "ACTIVO" { "Green" }
            "DESHABILITADO" { "Red" }
            "BLOQUEADO" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host "[$($i+1)] [$($User.UserStatus)] $(Get-SafePropertyValue $User.DisplayName)" -ForegroundColor White
        Write-Host "     Usuario: $(Get-SafePropertyValue $User.SamAccountName)" -ForegroundColor Gray
        Write-Host "     Dominio: $($User.SourceDomain) ($($User.SourceDomainNetBIOS))" -ForegroundColor Magenta
        Write-Host "     Email: $(Get-SafePropertyValue $User.mail)" -ForegroundColor Gray
        Write-Host "     Teléfono: $(Get-SafePropertyValue $User.telephoneNumber)" -ForegroundColor Gray
        Write-Host "     Oficina: $(Get-SafePropertyValue $User.Office)" -ForegroundColor Gray
        Write-Host "     Departamento: $(Get-SafePropertyValue $User.Department)" -ForegroundColor Gray
        Write-Host "     Título: $(Get-SafePropertyValue $User.Title)" -ForegroundColor Gray
        Write-Host "     Último acceso: $(Get-SafePropertyValue $User.LastLogonDate)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host ("=" * 100) -ForegroundColor Green
    
    $Selection = Read-Host "Seleccione un usuario (1-$UserCount) o Enter para nueva búsqueda"
    
    if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $UserCount) {
        return $SortedUsers[$Selection - 1]
    }
    
    return $null
}

function Show-MultiDomainUserActions {
    <#
    .SYNOPSIS
        Muestra las acciones disponibles para un usuario multi-dominio
    .PARAMETER User
        Usuario seleccionado con metadatos de dominio
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    do {
        Write-Host "`n=== GESTIÓN DEL USUARIO ===" -ForegroundColor Cyan
        Write-Host "Usuario: $(Get-SafePropertyValue $User.DisplayName) ($(Get-SafePropertyValue $User.SamAccountName))" -ForegroundColor White
        Write-Host "Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
        Write-Host "Estado: [$($User.UserStatus)]" -ForegroundColor $(
            switch ($User.UserStatus) {
                "ACTIVO" { "Green" }
                "DESHABILITADO" { "Red" }
                "BLOQUEADO" { "Yellow" }
                default { "Gray" }
            }
        )
        
        Write-Host "`nAcciones disponibles:" -ForegroundColor Yellow
        Write-Host "1. Ver información completa"
        Write-Host "2. Habilitar usuario"
        Write-Host "3. Deshabilitar usuario"
        Write-Host "4. Desbloquear usuario"
        Write-Host "5. Ver grupos del usuario"
        Write-Host "6. Cambiar contraseña (estándar)"
        Write-Host "7. Cambiar contraseña (personalizada)"
        Write-Host "8. Ver historial de inicios de sesión"
        Write-Host "Q. Volver a resultados"
        
        $Option = Read-Host "`nSeleccione una opción"
        
        switch ($Option.ToUpper()) {
            "1" { Show-MultiDomainUserCompleteInfo -User $User }
            "2" { Enable-MultiDomainUser -User $User }
            "3" { Disable-MultiDomainUser -User $User }
            "4" { Unlock-MultiDomainUser -User $User }
            "5" { Show-MultiDomainUserGroups -User $User }
            "6" { Set-MultiDomainUserStandardPassword -User $User }
            "7" { Set-MultiDomainUserCustomPassword -User $User }
            "8" { Show-MultiDomainUserLogonHistory -User $User }
            "Q" { return }
            default { 
                Write-Host "Opción inválida." -ForegroundColor Red 
                Start-Sleep -Seconds 1
            }
        }
        
        if ($Option.ToUpper() -ne "Q" -and $Option.ToUpper() -ne "1") {
            Write-Host "`nPresione Enter para continuar..." -ForegroundColor Gray
            Read-Host
        }
        
    } while ($true)
}

function Show-MultiDomainUserCompleteInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    Write-Host "`n=== INFORMACIÓN COMPLETA DEL USUARIO ===" -ForegroundColor Cyan
    Write-Host "Nombre completo: $(Get-SafePropertyValue $User.DisplayName)" -ForegroundColor White
    Write-Host "Usuario (SAM): $(Get-SafePropertyValue $User.SamAccountName)" -ForegroundColor White
    Write-Host "Dominio: $($User.SourceDomain) ($($User.SourceDomainNetBIOS))" -ForegroundColor Magenta
    Write-Host "Bosque: $($User.ForestName)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Contacto:" -ForegroundColor Yellow
    Write-Host "  Email: $(Get-SafePropertyValue $User.mail)" -ForegroundColor Gray
    Write-Host "  Teléfono: $(Get-SafePropertyValue $User.telephoneNumber)" -ForegroundColor Gray
    Write-Host "  Móvil: $(Get-SafePropertyValue $User.mobile)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Organización:" -ForegroundColor Yellow
    Write-Host "  Oficina: $(Get-SafePropertyValue $User.Office)" -ForegroundColor Gray
    Write-Host "  Departamento: $(Get-SafePropertyValue $User.Department)" -ForegroundColor Gray
    Write-Host "  Título: $(Get-SafePropertyValue $User.Title)" -ForegroundColor Gray
    Write-Host "  Manager: $(Get-SafePropertyValue $User.Manager)" -ForegroundColor Gray
    Write-Host "  Employee ID: $(Get-SafePropertyValue $User.EmployeeID)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Estado de cuenta:" -ForegroundColor Yellow
    Write-Host "  Estado: [$($User.UserStatus)]" -ForegroundColor $(
        switch ($User.UserStatus) {
            "ACTIVO" { "Green" }
            "DESHABILITADO" { "Red" }
            "BLOQUEADO" { "Yellow" }
            default { "Gray" }
        }
    )
    Write-Host "  Último acceso: $(Get-SafePropertyValue $User.LastLogonDate)" -ForegroundColor Gray
    Write-Host "  Fecha de creación: $(Get-SafePropertyValue $User.Created)" -ForegroundColor Gray
    Write-Host "  Última modificación: $(Get-SafePropertyValue $User.Modified)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Otros:" -ForegroundColor Yellow
    Write-Host "  Descripción: $(Get-SafePropertyValue $User.Description)" -ForegroundColor Gray
    Write-Host "  DN: $(Get-SafePropertyValue $User.DistinguishedName)" -ForegroundColor Gray
}

function Enable-MultiDomainUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    try {
        Enable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
        Write-Host "Usuario habilitado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
        $User.UserStatus = "ACTIVO"
    } catch {
        Write-Host "Error habilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-MultiDomainUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    $Confirm = Read-Host "ATENCIÓN: ¿Está seguro de deshabilitar '$($User.DisplayName)' en $($User.SourceDomain)? (SI/NO)"
    if ($Confirm -eq "SI") {
        try {
            Disable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
            Write-Host "Usuario deshabilitado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
            $User.UserStatus = "DESHABILITADO"
        } catch {
            Write-Host "Error deshabilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Operación cancelada." -ForegroundColor Yellow
    }
}

function Unlock-MultiDomainUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    try {
        Unlock-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
        Write-Host "Usuario desbloqueado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
        if ($User.UserStatus -eq "BLOQUEADO") {
            $User.UserStatus = "ACTIVO"
        }
    } catch {
        Write-Host "Error desbloqueando usuario: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-MultiDomainUserGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    try {
        $Groups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName -Server $User.SourceDomain | Sort-Object Name
        
        Write-Host "`n=== GRUPOS DEL USUARIO ($($Groups.Count)) ===" -ForegroundColor Cyan
        Write-Host "Usuario: $($User.SamAccountName) en $($User.SourceDomain)" -ForegroundColor White
        Write-Host ""
        
        foreach ($Group in $Groups) {
            Write-Host "- $($Group.Name)" -ForegroundColor White
            Write-Host "  Tipo: $($Group.GroupCategory) / $($Group.GroupScope)" -ForegroundColor Gray
            Write-Host "  DN: $($Group.DistinguishedName)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
    } catch {
        Write-Host "Error obteniendo grupos: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-MultiDomainUserStandardPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    try {
        $StandardPassword = Get-StandardPassword
        $SecurePassword = ConvertTo-SecureString $StandardPassword -AsPlainText -Force
        Set-ADAccountPassword -Identity $User.SamAccountName -Server $User.SourceDomain -NewPassword $SecurePassword -Reset -ErrorAction Stop
        Set-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -ChangePasswordAtLogon $true
        
        Write-Host "Contraseña cambiada a: $StandardPassword (cambio obligatorio en próximo inicio)" -ForegroundColor Green
    } catch {
        Write-Host "Error cambiando contraseña: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-MultiDomainUserCustomPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    Write-Host "`nCambio de contraseña para: $(Get-SafePropertyValue $User.DisplayName)" -ForegroundColor Cyan
    Write-Host "Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
    Write-Host "(Dejar en blanco para usar contraseña estándar: $(Get-StandardPassword))" -ForegroundColor Yellow
    
    $NewPassword = Read-Host "Ingrese la nueva contraseña (o Enter para estándar)" -AsSecureString
    $NewPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    
    # Si está en blanco, usar contraseña estándar
    if ([string]::IsNullOrWhiteSpace($NewPasswordText)) {
        $NewPasswordText = Get-StandardPassword
        Write-Host "Usando contraseña estándar: $NewPasswordText" -ForegroundColor Green
    }
    
    $ForceChange = Read-Host "¿Forzar cambio en el próximo inicio de sesión? (S/N)"
    
    try {
        $SecurePassword = ConvertTo-SecureString $NewPasswordText -AsPlainText -Force
        Set-ADAccountPassword -Identity $User.SamAccountName -Server $User.SourceDomain -NewPassword $SecurePassword -Reset -ErrorAction Stop
        
        if ($ForceChange -match '^[SsYy]') {
            Set-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -ChangePasswordAtLogon $true
            Write-Host "Contraseña cambiada exitosamente. Usuario debe cambiar en el próximo inicio." -ForegroundColor Green
        } else {
            Write-Host "Contraseña cambiada exitosamente." -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error cambiando contraseña: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-MultiDomainUserLogonHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    Write-Host "`n=== HISTORIAL DE INICIOS DE SESIÓN ===" -ForegroundColor Cyan
    Write-Host "Usuario: $($User.SamAccountName) en $($User.SourceDomain)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Obtener información adicional del usuario
        $UserDetail = Get-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -Properties LastLogonDate, LastBadPasswordAttempt, BadPwdCount, AccountLockoutTime -ErrorAction Stop
        
        Write-Host "Último inicio de sesión exitoso: $(Get-SafePropertyValue $UserDetail.LastLogonDate)" -ForegroundColor Green
        Write-Host "Último intento fallido: $(Get-SafePropertyValue $UserDetail.LastBadPasswordAttempt)" -ForegroundColor Yellow
        Write-Host "Intentos fallidos consecutivos: $(Get-SafePropertyValue $UserDetail.BadPwdCount)" -ForegroundColor $(if ($UserDetail.BadPwdCount -gt 0) { "Yellow" } else { "Green" })
        
        if ($UserDetail.AccountLockoutTime) {
            Write-Host "Fecha de bloqueo: $(Get-SafePropertyValue $UserDetail.AccountLockoutTime)" -ForegroundColor Red
        } else {
            Write-Host "Cuenta no bloqueada" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error obteniendo historial: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Start-MultiDomainUserSearch {
    <#
    .SYNOPSIS
        Inicia la herramienta de búsqueda multi-dominio con interfaz interactiva
    .PARAMETER Domain
        Dominio específico donde buscar (opcional)
    .PARAMETER SearchAllDomains
        Buscar en todos los dominios del bosque
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Domain,
        
        [Parameter(Mandatory=$false)]
        [switch]$SearchAllDomains
    )
    
    Write-Host "=== HERRAMIENTA DE BÚSQUEDA MULTI-DOMINIO ===" -ForegroundColor Cyan
    Write-Host "Obteniendo información de dominios..." -ForegroundColor Yellow
    
    $AvailableDomains = Get-AllAvailableDomains
    
    if ($AvailableDomains.Count -eq 0) {
        Write-Host "No se pudieron obtener dominios disponibles." -ForegroundColor Red
        return
    }
    
    # Si se especificó un dominio, usarlo
    if ($Domain) {
        $SelectedDomains = $AvailableDomains | Where-Object { $_.Name -like "*$Domain*" -and $_.Available }
        if (-not $SelectedDomains) {
            Write-Host "Dominio '$Domain' no encontrado o no accesible." -ForegroundColor Red
            return
        }
    }
    # Si se especificó buscar en todos
    elseif ($SearchAllDomains) {
        $SelectedDomains = $AvailableDomains | Where-Object { $_.Available }
    }
    # Modo interactivo
    else {
        $SelectedDomains = Show-DomainSelection -Domains $AvailableDomains
        if (-not $SelectedDomains) {
            Write-Host "Saliendo..." -ForegroundColor Yellow
            return
        }
    }
    
    do {
        Write-Host "`n=== BÚSQUEDA DE USUARIOS ===" -ForegroundColor Cyan
        Write-Host "Dominios seleccionados: $($SelectedDomains.Name -join ', ')" -ForegroundColor Green
        
        $SearchTerm = Read-Host "`nIngrese término de búsqueda (nombre, apellido, usuario, email, descripción)"
        
        if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
            Write-Host "Término de búsqueda vacío. Intente de nuevo." -ForegroundColor Red
            continue
        }
        
        $Users = Search-UsersInAllDomains -SearchTerm $SearchTerm -SelectedDomains $SelectedDomains
        $SelectedUser = Show-MultiDomainSearchResults -Users $Users
        
        if ($SelectedUser) {
            Show-MultiDomainUserActions -User $SelectedUser
        }
        
        $Continue = Read-Host "`n¿Desea realizar otra búsqueda? (S/N)"
        
    } while ($Continue -match '^[SsYy]')
    
    Write-Host "Gracias por usar la herramienta multi-dominio." -ForegroundColor Green
}

function Show-DomainSelection {
    <#
    .SYNOPSIS
        Muestra la selección interactiva de dominios
    .PARAMETER Domains
        Array de dominios disponibles
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Domains
    )
    
    Write-Host "`n=== SELECCIÓN DE DOMINIOS ===" -ForegroundColor Cyan
    Write-Host "Dominios disponibles:" -ForegroundColor Green
    
    for ($i = 0; $i -lt $Domains.Count; $i++) {
        $Domain = $Domains[$i]
        $Status = if ($Domain.Available) { "[DISPONIBLE]" } else { "[NO ACCESIBLE]" }
        $Color = if ($Domain.Available) { "Green" } else { "Red" }
        
        Write-Host "[$($i+1)] $Status $($Domain.Name)" -ForegroundColor $Color
        Write-Host "     NetBIOS: $($Domain.NetBIOSName)" -ForegroundColor Gray
        Write-Host "     Bosque: $($Domain.Forest)" -ForegroundColor Gray
        if ($Domain.Available) {
            Write-Host "     Modo: $($Domain.DomainMode)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "A. Buscar en TODOS los dominios disponibles" -ForegroundColor Yellow
    Write-Host "Q. Salir" -ForegroundColor Red
    Write-Host ""
    
    $Selection = Read-Host "Seleccione dominios (números separados por coma, 'A' para todos, 'Q' para salir)"
    
    if ($Selection -match '^[Qq]') {
        return $null
    }
    
    if ($Selection -match '^[Aa]') {
        return $Domains | Where-Object { $_.Available }
    }
    
    $SelectedDomains = @()
    $Numbers = $Selection -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($Num in $Numbers) {
        if ([int]::TryParse($Num, [ref]$null) -and $Num -ge 1 -and $Num -le $Domains.Count) {
            $SelectedDomain = $Domains[$Num - 1]
            if ($SelectedDomain.Available) {
                $SelectedDomains += $SelectedDomain
            } else {
                Write-Host "Advertencia: El dominio $($SelectedDomain.Name) no está disponible" -ForegroundColor Yellow
            }
        }
    }
    
    return $SelectedDomains
}

Export-ModuleMember -Function @(
    'Search-UsersInAllDomains',
    'Show-MultiDomainSearchResults', 
    'Show-MultiDomainUserActions',
    'Start-MultiDomainUserSearch',
    'Get-SafePropertyValue'
)