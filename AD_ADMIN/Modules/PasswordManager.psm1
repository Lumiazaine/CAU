# #Requires -Modules ActiveDirectory  # Comentado para desarrollo

<#
.SYNOPSIS
    Modulo para la gestion de contraseñas de usuarios en Active Directory
.DESCRIPTION
    Genera contraseñas temporales aleatorias con CSPRNG y establece contraseñas sin registrar valores.
#>

# Variable para detectar disponibilidad de ActiveDirectory
$script:ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)

# Funciones wrapper para simulación cuando AD no está disponible
function Get-ADUserSafe {
    [CmdletBinding()]
    param($Identity)
    if (-not $script:ADAvailable) { throw 'ActiveDirectory no disponible; no se fabrican usuarios.' }
    Get-ADUser -Identity $Identity -ErrorAction Stop
}

function Set-ADAccountPasswordSafe {
    param($Identity, $NewPassword, [switch]$Reset)
    if (-not $script:ADAvailable) { throw 'ActiveDirectory no disponible; reset bloqueado.' }
    Set-ADAccountPassword -Identity $Identity -NewPassword $NewPassword -Reset:$Reset -ErrorAction Stop
    return $true
}

function Set-ADUserSafe {
    param($Identity, $ChangePasswordAtLogon)
    if (-not $script:ADAvailable) { throw 'ActiveDirectory no disponible; actualización bloqueada.' }
    Set-ADUser -Identity $Identity -ChangePasswordAtLogon $ChangePasswordAtLogon -ErrorAction Stop
    return $true
}

function Get-StandardPassword {
    <# Contraseña temporal única de 24 caracteres; nunca basada en fecha. #>
    [CmdletBinding()]
    param()
    # 64 caracteres: byte % 64 no introduce sesgo porque 256 es múltiplo de 64.
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 24
    try {
        do {
            $rng.GetBytes($bytes)
            $password = -join @($bytes | ForEach-Object { $alphabet[[int]$_ % 64] })
        } until ($password -cmatch '[A-Z]' -and $password -cmatch '[a-z]' -and $password -cmatch '[0-9]' -and $password -cmatch '[!@]')
        Write-Verbose 'Contraseña temporal generada (valor omitido).'
        return $password
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
        $rng.Dispose()
    }
}

function Set-UserStandardPassword {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory=$true)][string]$Identity, [switch]$ForceChange = $true)
    if (-not $PSCmdlet.ShouldProcess($Identity, 'Establecer contraseña standard')) { return $false }
    $password = Get-StandardPassword
    return Set-UserCustomPassword -Identity $Identity -Password $password -ForceChange:$ForceChange -Confirm:$false
}

function Set-UserCustomPassword {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)][string]$Identity,
        [Parameter(Mandatory=$true)][string]$Password,
        [switch]$ForceChange = $true
    )
    if (-not $PSCmdlet.ShouldProcess($Identity, 'Establecer contraseña personalizada')) { return $false }
    try {
        $user = Get-ADUserSafe -Identity $Identity -ErrorAction Stop
        if (-not $user) { throw 'Usuario no encontrado.' }
        $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        if (-not (Set-ADAccountPasswordSafe -Identity $user.SamAccountName -NewPassword $securePassword -Reset)) { throw 'Reset de contraseña fallido.' }
        if (-not (Set-ADUserSafe -Identity $user.SamAccountName -ChangePasswordAtLogon ([bool]$ForceChange))) { throw 'Configuración de cambio de contraseña fallida.' }
        Write-Verbose 'Contraseña actualizada; valor omitido.'
        return $true
    } catch {
        # No incluir valores ni excepciones que puedan contener secretos.
        Write-Error 'No se pudo establecer la contraseña; operación no confirmada.'
        return $false
    }
}

function Test-PasswordComplexity {
    <#
    .SYNOPSIS
        Verifica si una contraseña cumple con los requisitos de complejidad
    .PARAMETER Password
        Contraseña a verificar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Password
    )
    
    $Requirements = @{
        MinLength = $Password.Length -ge 8
        HasUpper = $Password -cmatch '[A-Z]'
        HasLower = $Password -cmatch '[a-z]'
        HasNumber = $Password -cmatch '\d'
        HasSpecial = $Password -cmatch '[!@#$%^&*(),.?":{}|<>]'
    }
    
    $IsComplex = $Requirements.Values -contains $false -eq $false
    
    return @{
        IsComplex = $IsComplex
        Requirements = $Requirements
        Score = ($Requirements.Values | Where-Object { $_ }).Count
    }
}

function Show-PasswordComplexity {
    <#
    .SYNOPSIS
        Muestra los requisitos de complejidad de contraseña
    .PARAMETER Password
        Contraseña a analizar (opcional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Password
    )
    
    Write-Host "Requisitos de complejidad de contraseña:" -ForegroundColor Cyan
    Write-Host "• Minimo 8 caracteres" -ForegroundColor Gray
    Write-Host "• Al menos una letra mayuscula" -ForegroundColor Gray
    Write-Host "• Al menos una letra minuscula" -ForegroundColor Gray
    Write-Host "• Al menos un numero" -ForegroundColor Gray
    Write-Host "• Al menos un caracter especial" -ForegroundColor Gray
    
    if (-not [string]::IsNullOrEmpty($Password)) {
        $Analysis = Test-PasswordComplexity -Password $Password
        
        Write-Host "`nAnalisis de la contraseña:" -ForegroundColor Yellow
        Write-Host "Longitud minima: $(if ($Analysis.Requirements.MinLength) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.MinLength) {'Green'} else {'Red'})
        Write-Host "Mayusculas: $(if ($Analysis.Requirements.HasUpper) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasUpper) {'Green'} else {'Red'})
        Write-Host "Minusculas: $(if ($Analysis.Requirements.HasLower) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasLower) {'Green'} else {'Red'})
        Write-Host "Numeros: $(if ($Analysis.Requirements.HasNumber) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasNumber) {'Green'} else {'Red'})
        Write-Host "Caracteres especiales: $(if ($Analysis.Requirements.HasSpecial) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasSpecial) {'Green'} else {'Red'})
        Write-Host "Puntuacion: $($Analysis.Score)/5" -ForegroundColor $(if ($Analysis.IsComplex) {'Green'} else {'Yellow'})
    }
}

function Get-PasswordExpirationDate {
    <#
    .SYNOPSIS
        Obtiene la fecha de expiracion de la contraseña de un usuario
    .PARAMETER Identity
        Identificador del usuario
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -Properties PasswordLastSet, PasswordNeverExpires, msDS-UserPasswordExpiryTimeComputed -ErrorAction Stop
        
        if ($User.PasswordNeverExpires) {
            return @{
                ExpirationDate = $null
                NeverExpires = $true
                DaysUntilExpiration = $null
                Status = "Nunca expira"
            }
        }
        
        if ($User.'msDS-UserPasswordExpiryTimeComputed' -and $User.'msDS-UserPasswordExpiryTimeComputed' -ne 9223372036854775807) {
            $ExpirationDate = [DateTime]::FromFileTime($User.'msDS-UserPasswordExpiryTimeComputed')
            $DaysUntilExpiration = ($ExpirationDate - (Get-Date)).Days
            
            $Status = if ($DaysUntilExpiration -lt 0) {
                "Expirada"
            } elseif ($DaysUntilExpiration -le 7) {
                "Expira pronto"
            } else {
                "Activa"
            }
            
            return @{
                ExpirationDate = $ExpirationDate
                NeverExpires = $false
                DaysUntilExpiration = $DaysUntilExpiration
                Status = $Status
            }
        }
        
        return @{
            ExpirationDate = $null
            NeverExpires = $false
            DaysUntilExpiration = $null
            Status = "No determinado"
        }
        
    } catch {
        Write-Error "Error obteniendo informacion de contraseña para $Identity`: $($_.Exception.Message)"
        return $null
    }
}

Export-ModuleMember -Function @(
    'Get-StandardPassword',
    'Set-UserStandardPassword',
    'Set-UserCustomPassword',
    'Test-PasswordComplexity',
    'Show-PasswordComplexity',
    'Get-PasswordExpirationDate'
)