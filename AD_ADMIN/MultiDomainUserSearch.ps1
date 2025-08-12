#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Herramienta avanzada de busqueda de usuarios en multiples dominios
.DESCRIPTION
    Permite buscar usuarios en dominios especificos o en todos los dominios del bosque
.PARAMETER Domain
    Dominio especifico donde buscar (opcional)
.PARAMETER SearchAllDomains
    Buscar en todos los dominios del bosque
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [switch]$SearchAllDomains,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_MultiDomainSearch"
)

$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor Gray
    
    if ($LogPath) {
        try {
            if (-not (Test-Path $LogPath)) {
                New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
            }
            $LogFile = Join-Path $LogPath "MultiDomainSearch_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
        } catch {
            # Ignore logging errors
        }
    }
}

function Get-StandardPassword {
    <#
    .SYNOPSIS
        Genera la contraseña estándar basada en la fecha actual
    .DESCRIPTION
        Formato: Justicia + MM + AA (ejemplo: Justicia0825 para agosto 2025)
    #>
    [CmdletBinding()]
    param()
    
    $CurrentDate = Get-Date
    $Month = $CurrentDate.ToString("MM")
    $Year = $CurrentDate.ToString("yy")
    
    $StandardPassword = "Justicia$Month$Year"
    
    return $StandardPassword
}

function Get-ForestDomains {
    Write-Log "Obteniendo dominios del bosque..."
    $Domains = @()
    
    try {
        $Forest = Get-ADForest -ErrorAction Stop
        Write-Log "Bosque: $($Forest.Name)"
        
        foreach ($DomainName in $Forest.Domains) {
            try {
                $DomainObj = Get-ADDomain -Identity $DomainName -ErrorAction Stop
                $Domains += [PSCustomObject]@{
                    Name = $DomainObj.DNSRoot
                    NetBIOSName = $DomainObj.NetBIOSName
                    DistinguishedName = $DomainObj.DistinguishedName
                    DomainMode = $DomainObj.DomainMode
                    Forest = $Forest.Name
                    Available = $true
                }
                Write-Log "Dominio disponible: $($DomainObj.DNSRoot)"
            } catch {
                $Domains += [PSCustomObject]@{
                    Name = $DomainName
                    NetBIOSName = "Desconocido"
                    DistinguishedName = "Desconocido"
                    DomainMode = "Desconocido"
                    Forest = $Forest.Name
                    Available = $false
                }
                Write-Log "Dominio no accesible: $DomainName - $($_.Exception.Message)" "WARNING"
            }
        }
    } catch {
        Write-Log "Error obteniendo bosque: $($_.Exception.Message)" "ERROR"
        
        # Fallback al dominio actual
        try {
            $CurrentDomain = Get-ADDomain -Current LocalComputer
            $Domains += [PSCustomObject]@{
                Name = $CurrentDomain.DNSRoot
                NetBIOSName = $CurrentDomain.NetBIOSName
                DistinguishedName = $CurrentDomain.DistinguishedName
                DomainMode = $CurrentDomain.DomainMode
                Forest = "Local"
                Available = $true
            }
            Write-Log "Usando dominio local: $($CurrentDomain.DNSRoot)"
        } catch {
            Write-Log "Error obteniendo dominio local: $($_.Exception.Message)" "ERROR"
        }
    }
    
    return $Domains
}

function Show-DomainSelection {
    param([array]$Domains)
    
    Write-Host "`n=== SELECCION DE DOMINIOS ===" -ForegroundColor Cyan
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
    
    $Selection = Read-Host "Seleccione dominios (numeros separados por coma, 'A' para todos, 'Q' para salir)"
    
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
                Write-Host "Advertencia: El dominio $($SelectedDomain.Name) no esta disponible" -ForegroundColor Yellow
            }
        }
    }
    
    return $SelectedDomains
}

function Search-UsersInDomains {
    param([array]$Domains, [string]$SearchTerm)
    
    $AllUsers = @()
    $TotalDomains = $Domains.Count
    $CompletedDomains = 0
    
    Write-Host "`nBuscando '$SearchTerm' en $TotalDomains dominios..." -ForegroundColor Yellow
    
    foreach ($Domain in $Domains) {
        $CompletedDomains++
        
        Write-Host "`n[$CompletedDomains/$TotalDomains] Buscando en: $($Domain.Name)" -ForegroundColor Cyan
        Write-Progress -Activity "Busqueda Multi-Dominio" -Status "Dominio: $($Domain.Name)" -PercentComplete (($CompletedDomains / $TotalDomains) * 100)
        
        try {
            $Filter = "GivenName -like '*$SearchTerm*' -or Surname -like '*$SearchTerm*' -or SamAccountName -like '*$SearchTerm*' -or DisplayName -like '*$SearchTerm*' -or mail -like '*$SearchTerm*' -or Description -like '*$SearchTerm*'"
            
            $Users = Get-ADUser -Filter $Filter -Server $Domain.Name -Properties @(
                'DisplayName', 'mail', 'telephoneNumber', 'mobile', 'Office', 
                'Description', 'Enabled', 'LastLogonDate', 'Created', 'Modified',
                'Department', 'Title', 'Manager', 'EmployeeID', 'LockedOut'
            ) -ErrorAction Stop
            
            if ($Users) {
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
                
                Write-Host "  Encontrados: $($Users.Count) usuarios" -ForegroundColor Green
                Write-Log "Dominio $($Domain.Name): $($Users.Count) usuarios encontrados"
            } else {
                Write-Host "  Sin resultados" -ForegroundColor Gray
                Write-Log "Dominio $($Domain.Name): Sin resultados"
            }
            
        } catch {
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Error en dominio $($Domain.Name): $($_.Exception.Message)" "ERROR"
        }
    }
    
    Write-Progress -Activity "Busqueda Multi-Dominio" -Completed
    return $AllUsers
}

function Show-SearchResults {
    param([array]$Users)
    
    if ($Users.Count -eq 0) {
        Write-Host "`nNo se encontraron usuarios con los criterios especificados." -ForegroundColor Red
        return $null
    }
    
    # Ordenar usuarios por dominio y nombre
    $SortedUsers = $Users | Sort-Object SourceDomain, DisplayName
    
    Write-Host "`n=== RESULTADOS DE BUSQUEDA ($($Users.Count) usuarios) ===" -ForegroundColor Green
    Write-Host ("=" * 100) -ForegroundColor Green
    
    for ($i = 0; $i -lt $SortedUsers.Count; $i++) {
        $User = $SortedUsers[$i]
        $StatusColor = switch ($User.UserStatus) {
            "ACTIVO" { "Green" }
            "DESHABILITADO" { "Red" }
            "BLOQUEADO" { "Yellow" }
            default { "Gray" }
        }
        
        Write-Host "[$($i+1)] [$($User.UserStatus)] $($User.DisplayName)" -ForegroundColor White
        Write-Host "     Usuario: $($User.SamAccountName)" -ForegroundColor Gray
        Write-Host "     Dominio: $($User.SourceDomain) ($($User.SourceDomainNetBIOS))" -ForegroundColor Magenta
        Write-Host "     Email: $($User.mail)" -ForegroundColor Gray
        Write-Host "     Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
        Write-Host "     Oficina: $($User.Office)" -ForegroundColor Gray
        Write-Host "     Departamento: $($User.Department)" -ForegroundColor Gray
        Write-Host "     Titulo: $($User.Title)" -ForegroundColor Gray
        Write-Host "     Ultimo acceso: $($User.LastLogonDate)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host ("=" * 100) -ForegroundColor Green
    
    $Selection = Read-Host "Seleccione un usuario (1-$($Users.Count)) o Enter para nueva busqueda"
    
    if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $Users.Count) {
        return $SortedUsers[$Selection - 1]
    }
    
    return $null
}

function Show-UserActions {
    param([PSCustomObject]$User)
    
    do {
        Write-Host "`n=== GESTION DEL USUARIO ===" -ForegroundColor Cyan
        Write-Host "Usuario: $($User.DisplayName) ($($User.SamAccountName))" -ForegroundColor White
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
        Write-Host "1. Ver informacion completa"
        Write-Host "2. Habilitar usuario"
        Write-Host "3. Deshabilitar usuario"
        Write-Host "4. Desbloquear usuario"
        Write-Host "5. Ver grupos del usuario"
        Write-Host "6. Cambiar contraseña"
        Write-Host "7. Ver historial de inicios de sesion"
        Write-Host "Q. Volver a resultados"
        
        $Option = Read-Host "`nSeleccione una opcion"
        
        switch ($Option.ToUpper()) {
            "1" { Show-CompleteUserInfo -User $User }
            "2" { Enable-UserInDomain -User $User }
            "3" { Disable-UserInDomain -User $User }
            "4" { Unlock-UserInDomain -User $User }
            "5" { Show-UserGroups -User $User }
            "6" { Change-UserPassword -User $User }
            "7" { Show-UserLogonHistory -User $User }
            "Q" { return }
            default { 
                Write-Host "Opcion invalida." -ForegroundColor Red 
                Start-Sleep -Seconds 1
            }
        }
        
        if ($Option.ToUpper() -ne "Q" -and $Option.ToUpper() -ne "1") {
            Write-Host "`nPresione Enter para continuar..." -ForegroundColor Gray
            Read-Host
        }
        
    } while ($true)
}

function Show-CompleteUserInfo {
    param([PSCustomObject]$User)
    
    Write-Host "`n=== INFORMACION COMPLETA DEL USUARIO ===" -ForegroundColor Cyan
    Write-Host "Nombre completo: $($User.DisplayName)" -ForegroundColor White
    Write-Host "Usuario (SAM): $($User.SamAccountName)" -ForegroundColor White
    Write-Host "Dominio: $($User.SourceDomain) ($($User.SourceDomainNetBIOS))" -ForegroundColor Magenta
    Write-Host "Bosque: $($User.ForestName)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Contacto:" -ForegroundColor Yellow
    Write-Host "  Email: $($User.mail)" -ForegroundColor Gray
    Write-Host "  Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
    Write-Host "  Movil: $($User.mobile)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Organizacion:" -ForegroundColor Yellow
    Write-Host "  Oficina: $($User.Office)" -ForegroundColor Gray
    Write-Host "  Departamento: $($User.Department)" -ForegroundColor Gray
    Write-Host "  Titulo: $($User.Title)" -ForegroundColor Gray
    Write-Host "  Manager: $($User.Manager)" -ForegroundColor Gray
    Write-Host "  Employee ID: $($User.EmployeeID)" -ForegroundColor Gray
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
    Write-Host "  Ultimo acceso: $($User.LastLogonDate)" -ForegroundColor Gray
    Write-Host "  Fecha de creacion: $($User.Created)" -ForegroundColor Gray
    Write-Host "  Ultima modificacion: $($User.Modified)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Otros:" -ForegroundColor Yellow
    Write-Host "  Descripcion: $($User.Description)" -ForegroundColor Gray
    Write-Host "  DN: $($User.DistinguishedName)" -ForegroundColor Gray
}

function Enable-UserInDomain {
    param([PSCustomObject]$User)
    
    try {
        Enable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
        Write-Host "Usuario habilitado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
        $User.UserStatus = "ACTIVO"
        Write-Log "Usuario $($User.SamAccountName) habilitado en $($User.SourceDomain)"
    } catch {
        Write-Host "Error habilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error habilitando $($User.SamAccountName): $($_.Exception.Message)" "ERROR"
    }
}

function Disable-UserInDomain {
    param([PSCustomObject]$User)
    
    $Confirm = Read-Host "ATENCION: Esta seguro de deshabilitar '$($User.DisplayName)' en $($User.SourceDomain)? (SI/NO)"
    if ($Confirm -eq "SI") {
        try {
            Disable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
            Write-Host "Usuario deshabilitado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
            $User.UserStatus = "DESHABILITADO"
            Write-Log "Usuario $($User.SamAccountName) deshabilitado en $($User.SourceDomain)"
        } catch {
            Write-Host "Error deshabilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Error deshabilitando $($User.SamAccountName): $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
    }
}

function Unlock-UserInDomain {
    param([PSCustomObject]$User)
    
    try {
        Unlock-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain -ErrorAction Stop
        Write-Host "Usuario desbloqueado exitosamente en $($User.SourceDomain)" -ForegroundColor Green
        if ($User.UserStatus -eq "BLOQUEADO") {
            $User.UserStatus = "ACTIVO"
        }
        Write-Log "Usuario $($User.SamAccountName) desbloqueado en $($User.SourceDomain)"
    } catch {
        Write-Host "Error desbloqueando usuario: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error desbloqueando $($User.SamAccountName): $($_.Exception.Message)" "ERROR"
    }
}

function Show-UserGroups {
    param([PSCustomObject]$User)
    
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

function Change-UserPassword {
    param([PSCustomObject]$User)
    
    Write-Host "`nCambio de contraseña para: $($User.DisplayName)" -ForegroundColor Cyan
    Write-Host "Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
    Write-Host "(Dejar en blanco para usar contraseña estándar: $(Get-StandardPassword))" -ForegroundColor Yellow
    
    $NewPassword = Read-Host "Ingrese la nueva contraseña (o Enter para estándar)" -AsSecureString
    $NewPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    
    # Si está en blanco, usar contraseña estándar
    if ([string]::IsNullOrWhiteSpace($NewPasswordText)) {
        $NewPasswordText = Get-StandardPassword
        Write-Host "Usando contraseña estándar: $NewPasswordText" -ForegroundColor Green
    }
    
    $ConfirmPassword = Read-Host "Confirme la contraseña" -AsSecureString
    $ConfirmPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfirmPassword))
    
    # Si la confirmación está en blanco y se usó estándar, usar la estándar también
    if ([string]::IsNullOrWhiteSpace($ConfirmPasswordText) -and $NewPasswordText -eq (Get-StandardPassword)) {
        $ConfirmPasswordText = Get-StandardPassword
    }
    
    if ($NewPasswordText -ne $ConfirmPasswordText) {
        Write-Host "Las contraseñas no coinciden." -ForegroundColor Red
        return
    }
    
    $ForceChange = Read-Host "Forzar cambio en el próximo inicio de sesión? (S/N)"
    
    try {
        $SecurePassword = ConvertTo-SecureString $NewPasswordText -AsPlainText -Force
        Set-ADAccountPassword -Identity $User.SamAccountName -Server $User.SourceDomain -NewPassword $SecurePassword -Reset -ErrorAction Stop
        
        if ($ForceChange -match '^[SsYy]') {
            Set-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -ChangePasswordAtLogon $true
            Write-Host "Contraseña cambiada exitosamente. Usuario debe cambiar en el próximo inicio." -ForegroundColor Green
        } else {
            Write-Host "Contraseña cambiada exitosamente." -ForegroundColor Green
        }
        
        Write-Log "Contraseña cambiada para $($User.SamAccountName) en $($User.SourceDomain)"
    } catch {
        Write-Host "Error cambiando contraseña: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error cambiando contraseña $($User.SamAccountName): $($_.Exception.Message)" "ERROR"
    }
}

function Show-UserLogonHistory {
    param([PSCustomObject]$User)
    
    Write-Host "`n=== HISTORIAL DE INICIOS DE SESION ===" -ForegroundColor Cyan
    Write-Host "Usuario: $($User.SamAccountName) en $($User.SourceDomain)" -ForegroundColor White
    Write-Host ""
    
    try {
        # Obtener información adicional del usuario
        $UserDetail = Get-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -Properties LastLogonDate, LastBadPasswordAttempt, BadPwdCount, AccountLockoutTime -ErrorAction Stop
        
        Write-Host "Ultimo inicio de sesion exitoso: $($UserDetail.LastLogonDate)" -ForegroundColor Green
        Write-Host "Ultimo intento fallido: $($UserDetail.LastBadPasswordAttempt)" -ForegroundColor Yellow
        Write-Host "Intentos fallidos consecutivos: $($UserDetail.BadPwdCount)" -ForegroundColor $(if ($UserDetail.BadPwdCount -gt 0) { "Yellow" } else { "Green" })
        
        if ($UserDetail.AccountLockoutTime) {
            Write-Host "Fecha de bloqueo: $($UserDetail.AccountLockoutTime)" -ForegroundColor Red
        } else {
            Write-Host "Cuenta no bloqueada" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Error obteniendo historial: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Script principal
try {
    Write-Host "=== HERRAMIENTA DE BUSQUEDA MULTI-DOMINIO ===" -ForegroundColor Cyan
    Write-Host "Obteniendo informacion de dominios..." -ForegroundColor Yellow
    
    $AvailableDomains = Get-ForestDomains
    
    if ($AvailableDomains.Count -eq 0) {
        Write-Host "No se pudieron obtener dominios disponibles." -ForegroundColor Red
        exit 1
    }
    
    # Si se especifico un dominio, usarlo
    if ($Domain) {
        $SelectedDomains = $AvailableDomains | Where-Object { $_.Name -like "*$Domain*" -and $_.Available }
        if (-not $SelectedDomains) {
            Write-Host "Dominio '$Domain' no encontrado o no accesible." -ForegroundColor Red
            exit 1
        }
    }
    # Si se especifico buscar en todos
    elseif ($SearchAllDomains) {
        $SelectedDomains = $AvailableDomains | Where-Object { $_.Available }
    }
    # Modo interactivo
    else {
        $SelectedDomains = Show-DomainSelection -Domains $AvailableDomains
        if (-not $SelectedDomains) {
            Write-Host "Saliendo..." -ForegroundColor Yellow
            exit 0
        }
    }
    
    do {
        Write-Host "`n=== BUSQUEDA DE USUARIOS ===" -ForegroundColor Cyan
        Write-Host "Dominios seleccionados: $($SelectedDomains.Name -join ', ')" -ForegroundColor Green
        
        $SearchTerm = Read-Host "`nIngrese termino de busqueda (nombre, apellido, usuario, email, descripcion)"
        
        if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
            Write-Host "Termino de busqueda vacio. Intente de nuevo." -ForegroundColor Red
            continue
        }
        
        $Users = Search-UsersInDomains -Domains $SelectedDomains -SearchTerm $SearchTerm
        $SelectedUser = Show-SearchResults -Users $Users
        
        if ($SelectedUser) {
            Show-UserActions -User $SelectedUser
        }
        
        $Continue = Read-Host "`nDesea realizar otra busqueda? (S/N)"
        
    } while ($Continue -match '^[SsYy]')
    
    Write-Host "Gracias por usar la herramienta multi-dominio." -ForegroundColor Green
    
} catch {
    Write-Host "Error critico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Error critico: $($_.Exception.Message)" "ERROR"
    exit 1
}