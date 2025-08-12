#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Herramienta simplificada de busqueda interactiva de usuarios
.DESCRIPTION
    Version simplificada que funciona sin dependencias complejas
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_UserSearch"
)

$ErrorActionPreference = "Continue"

function Write-SimpleLog {
    param([string]$Message, [string]$Level = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    Write-Host $LogEntry
    if ($LogPath -and (Test-Path $LogPath -IsValid)) {
        try {
            if (-not (Test-Path $LogPath)) {
                New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
            }
            $LogFile = Join-Path $LogPath "SimpleUserSearch_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
        } catch {
            # Ignore logging errors
        }
    }
}

function Get-StandardPassword {
    <#
    .SYNOPSIS
        Genera la contraseña estandar basada en la fecha actual
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

try {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    Write-Host "=== HERRAMIENTA SIMPLE DE BUSQUEDA DE USUARIOS ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-SimpleLog "Iniciando herramienta simplificada"
    
    # Detectar dominios disponibles
    Write-Host "Detectando dominios disponibles..." -ForegroundColor Yellow
    $AvailableDomains = Get-AvailableDomains
    
    Write-Host "Dominios encontrados:" -ForegroundColor Green
    foreach ($Domain in $AvailableDomains) {
        Write-Host "  - $($Domain.Name) ($($Domain.Forest))" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Intentar cargar modulos sin fallar si no funcionan
    Write-Host "Cargando modulos..." -ForegroundColor Yellow
    
    try {
        Import-Module "$ScriptPath\Modules\PasswordManager.psm1" -Force -ErrorAction SilentlyContinue
        $PasswordManagerLoaded = $true
        Write-Host "  PasswordManager: OK" -ForegroundColor Green
    } catch {
        $PasswordManagerLoaded = $false
        Write-Host "  PasswordManager: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    try {
        Import-Module "$ScriptPath\Modules\UserSearch.psm1" -Force -ErrorAction SilentlyContinue
        $UserSearchLoaded = $true
        Write-Host "  UserSearch: OK" -ForegroundColor Green
    } catch {
        $UserSearchLoaded = $false
        Write-Host "  UserSearch: Error - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    
    if ($UserSearchLoaded) {
        Write-Host "Usando modulo UserSearch completo..." -ForegroundColor Green
        Start-InteractiveUserSearch
    } else {
        Write-Host "Usando funcionalidad basica de busqueda..." -ForegroundColor Yellow
        Start-BasicUserSearch
    }
    
} catch {
    Write-Host "Error critico: $($_.Exception.Message)" -ForegroundColor Red
    Write-SimpleLog "Error critico: $($_.Exception.Message)" "ERROR"
}

function Start-BasicUserSearch {
    Write-Host "=== BUSQUEDA BASICA DE USUARIOS ===" -ForegroundColor Cyan
    Write-Host ""
    
    $SearchTerm = Read-Host "Ingrese termino de busqueda (nombre, apellido o usuario)"
    
    if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
        Write-Host "No se ingreso termino de busqueda." -ForegroundColor Red
        return
    }
    
    try {
        Write-Host "Buscando usuarios..." -ForegroundColor Yellow
        
        # Busqueda en todos los dominios
        $AllUsers = @()
        
        foreach ($Domain in $AvailableDomains) {
            try {
                Write-Host "  Buscando en dominio: $($Domain.Name)" -ForegroundColor Cyan
                
                $DomainUsers = Get-ADUser -Filter "GivenName -like '*$SearchTerm*' -or Surname -like '*$SearchTerm*' -or SamAccountName -like '*$SearchTerm*' -or DisplayName -like '*$SearchTerm*'" -Server $Domain.Name -Properties DisplayName, mail, telephoneNumber, Office, Description, Enabled, LastLogonDate -ErrorAction SilentlyContinue
                
                if ($DomainUsers) {
                    # Añadir información del dominio a cada usuario
                    foreach ($User in $DomainUsers) {
                        $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain.Name -Force
                        $AllUsers += $User
                    }
                    Write-Host "    Encontrados: $($DomainUsers.Count) usuarios" -ForegroundColor Green
                } else {
                    Write-Host "    Sin resultados" -ForegroundColor Gray
                }
            } catch {
                Write-Host "    Error accediendo al dominio $($Domain.Name): $($_.Exception.Message)" -ForegroundColor Red
                Write-SimpleLog "Error buscando en dominio $($Domain.Name): $($_.Exception.Message)" "ERROR"
            }
        }
        
        $Users = $AllUsers
        
        if ($Users.Count -eq 0) {
            Write-Host "No se encontraron usuarios con el termino: $SearchTerm" -ForegroundColor Red
            return
        }
        
        Write-Host "`n=== RESULTADOS ($($Users.Count) usuarios) ===" -ForegroundColor Green
        
        for ($i = 0; $i -lt $Users.Count; $i++) {
            $User = $Users[$i]
            $Status = if ($User.Enabled) { "[ACTIVO]" } else { "[INACTIVO]" }
            
            Write-Host "[$($i+1)] $Status $($User.DisplayName)" -ForegroundColor White
            Write-Host "     Usuario: $($User.SamAccountName)" -ForegroundColor Gray
            Write-Host "     Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
            Write-Host "     Email: $($User.mail)" -ForegroundColor Gray
            Write-Host "     Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
            Write-Host "     Oficina: $($User.Office)" -ForegroundColor Gray
            Write-Host ""
        }
        
        $Selection = Read-Host "Seleccione un usuario (1-$($Users.Count)) o Enter para salir"
        
        if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $Users.Count) {
            $SelectedUser = $Users[$Selection - 1]
            Show-BasicUserInfo -User $SelectedUser
        }
        
    } catch {
        Write-Host "Error en busqueda: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-BasicUserInfo {
    param([Microsoft.ActiveDirectory.Management.ADUser]$User)
    
    Write-Host "`n=== INFORMACION DEL USUARIO ===" -ForegroundColor Cyan
    Write-Host "Nombre: $($User.DisplayName)" -ForegroundColor White
    Write-Host "Usuario: $($User.SamAccountName)" -ForegroundColor Gray
    Write-Host "Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
    Write-Host "Email: $($User.mail)" -ForegroundColor Gray
    Write-Host "Telefono: $($User.telephoneNumber)" -ForegroundColor Gray
    Write-Host "Oficina: $($User.Office)" -ForegroundColor Gray
    Write-Host "Estado: $(if ($User.Enabled) {'ACTIVO'} else {'INACTIVO'})" -ForegroundColor $(if ($User.Enabled) {'Green'} else {'Red'})
    Write-Host "Ultimo acceso: $($User.LastLogonDate)" -ForegroundColor Gray
    
    Write-Host "`n=== ACCIONES BASICAS ===" -ForegroundColor Yellow
    Write-Host "1. Habilitar usuario"
    Write-Host "2. Deshabilitar usuario"
    Write-Host "3. Desbloquear usuario"
    Write-Host "4. Cambiar contraseña"
    Write-Host "Q. Salir"
    
    $Option = Read-Host "`nSeleccione una opcion"
    
    switch ($Option.ToUpper()) {
        "1" {
            try {
                Enable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain
                Write-Host "Usuario habilitado exitosamente." -ForegroundColor Green
            } catch {
                Write-Host "Error habilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        "2" {
            $Confirm = Read-Host "Confirmar deshabilitar usuario? (S/N)"
            if ($Confirm -match '^[SsYy]') {
                try {
                    Disable-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain
                    Write-Host "Usuario deshabilitado exitosamente." -ForegroundColor Green
                } catch {
                    Write-Host "Error deshabilitando usuario: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        "3" {
            try {
                Unlock-ADAccount -Identity $User.SamAccountName -Server $User.SourceDomain
                Write-Host "Usuario desbloqueado exitosamente." -ForegroundColor Green
            } catch {
                Write-Host "Error desbloqueando usuario: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        "4" {
            Change-UserPasswordSimple -User $User
        }
    }
}

function Change-UserPasswordSimple {
    param([Microsoft.ActiveDirectory.Management.ADUser]$User)
    
    Write-Host "`nCambio de contraseña para: $($User.DisplayName)" -ForegroundColor Cyan
    Write-Host "Dominio: $($User.SourceDomain)" -ForegroundColor Magenta
    Write-Host "(Dejar en blanco para usar contraseña estándar: $(Get-StandardPassword))" -ForegroundColor Yellow
    
    $NewPassword = Read-Host "Ingrese la nueva contraseña (o Enter para estándar)" -AsSecureString
    $PasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    
    # Si está en blanco, usar contraseña estándar
    if ([string]::IsNullOrWhiteSpace($PasswordPlain)) {
        $PasswordPlain = Get-StandardPassword
        Write-Host "Usando contraseña estándar: $PasswordPlain" -ForegroundColor Green
    }
    
    $ConfirmPassword = Read-Host "Confirme la contraseña" -AsSecureString
    $ConfirmPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfirmPassword))
    
    # Si la confirmación está en blanco y se usó estándar, usar la estándar también
    if ([string]::IsNullOrWhiteSpace($ConfirmPasswordPlain) -and $PasswordPlain -eq (Get-StandardPassword)) {
        $ConfirmPasswordPlain = Get-StandardPassword
    }
    
    if ($PasswordPlain -ne $ConfirmPasswordPlain) {
        Write-Host "Las contraseñas no coinciden." -ForegroundColor Red
        return
    }
    
    $ForceChange = Read-Host "Forzar cambio en el próximo inicio de sesión? (S/N)"
    
    try {
        $SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force
        Set-ADAccountPassword -Identity $User.SamAccountName -Server $User.SourceDomain -NewPassword $SecurePassword -Reset -ErrorAction Stop
        
        if ($ForceChange -match '^[SsYy]') {
            Set-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain -ChangePasswordAtLogon $true
            Write-Host "Contraseña cambiada exitosamente. Usuario debe cambiar en el próximo inicio." -ForegroundColor Green
        } else {
            Write-Host "Contraseña cambiada exitosamente." -ForegroundColor Green
        }
        
        Write-SimpleLog "Contraseña cambiada para $($User.SamAccountName) en $($User.SourceDomain)"
    } catch {
        Write-Host "Error cambiando contraseña: $($_.Exception.Message)" -ForegroundColor Red
        Write-SimpleLog "Error cambiando contraseña $($User.SamAccountName): $($_.Exception.Message)" "ERROR"
    }
}

function Get-AvailableDomains {
    <#
    .SYNOPSIS
        Obtiene todos los dominios disponibles en el bosque
    #>
    [CmdletBinding()]
    param()
    
    $Domains = @()
    
    try {
        # Obtener el bosque actual
        $Forest = Get-ADForest -ErrorAction SilentlyContinue
        
        if ($Forest) {
            Write-SimpleLog "Bosque detectado: $($Forest.Name)"
            
            # Obtener todos los dominios del bosque
            foreach ($DomainName in $Forest.Domains) {
                try {
                    $Domain = Get-ADDomain -Identity $DomainName -ErrorAction SilentlyContinue
                    if ($Domain) {
                        $Domains += [PSCustomObject]@{
                            Name = $Domain.DNSRoot
                            NetBIOSName = $Domain.NetBIOSName
                            Forest = $Forest.Name
                            DistinguishedName = $Domain.DistinguishedName
                        }
                        Write-SimpleLog "Dominio agregado: $($Domain.DNSRoot)"
                    }
                } catch {
                    Write-SimpleLog "Error accediendo al dominio $DomainName`: $($_.Exception.Message)" "WARNING"
                }
            }
        }
    } catch {
        Write-SimpleLog "Error obteniendo informacion del bosque: $($_.Exception.Message)" "WARNING"
    }
    
    # Si no se pudieron obtener dominios del bosque, intentar con el dominio actual
    if ($Domains.Count -eq 0) {
        try {
            $CurrentDomain = Get-ADDomain -Current LocalComputer -ErrorAction SilentlyContinue
            if ($CurrentDomain) {
                $Domains += [PSCustomObject]@{
                    Name = $CurrentDomain.DNSRoot
                    NetBIOSName = $CurrentDomain.NetBIOSName
                    Forest = "Desconocido"
                    DistinguishedName = $CurrentDomain.DistinguishedName
                }
                Write-SimpleLog "Usando dominio actual: $($CurrentDomain.DNSRoot)"
            }
        } catch {
            Write-SimpleLog "Error obteniendo dominio actual: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Si aún no hay dominios, usar el dominio por defecto
    if ($Domains.Count -eq 0) {
        $Domains += [PSCustomObject]@{
            Name = $env:USERDNSDOMAIN
            NetBIOSName = $env:USERDOMAIN
            Forest = "Desconocido"
            DistinguishedName = "Desconocido"
        }
        Write-SimpleLog "Usando dominio del entorno: $env:USERDNSDOMAIN"
    }
    
    return $Domains
}

Write-Host "`nGracias por usar la herramienta de busqueda multi-dominio." -ForegroundColor Green