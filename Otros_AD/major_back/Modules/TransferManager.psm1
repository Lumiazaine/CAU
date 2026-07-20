#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para la gestión de traslados de usuarios entre ubicaciones/dominios
.DESCRIPTION
    Maneja traslados de usuarios, búsqueda por email, detección de provincia,
    copia de perfiles y gestión de grupos según el destino
#>

# Importar módulos dependientes con manejo de errores
try {
    Import-Module "$PSScriptRoot\PasswordManager.psm1" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "No se pudo cargar PasswordManager: $($_.Exception.Message)"
}

try {
    Import-Module "$PSScriptRoot\DomainStructureManager.psm1" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "No se pudo cargar DomainStructureManager: $($_.Exception.Message)"
}

try {
    Import-Module "$PSScriptRoot\UserTemplateManager.psm1" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "No se pudo cargar UserTemplateManager: $($_.Exception.Message)"
}

function Start-UserTransferProcess {
    <#
    .SYNOPSIS
        Inicia el proceso de traslado de usuario basado en CSV
    .PARAMETER UserData
        Datos del usuario del CSV (debe incluir email)
    .PARAMETER WhatIf
        Modo de simulación sin realizar cambios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    Write-Host "=== PROCESANDO TRASLADO DE USUARIO ===" -ForegroundColor Cyan
    Write-Host "Email: $($UserData.Email)" -ForegroundColor White
    Write-Host "Destino: $($UserData.Oficina)" -ForegroundColor Yellow
    
    # 1. Buscar usuario existente por email o campo AD
    $ExistingUser = Find-UserForTransfer -Email $UserData.Email -ADField $UserData.AD
    if (-not $ExistingUser) {
        $SearchCriteria = if (![string]::IsNullOrWhiteSpace($UserData.AD)) { "campo AD: $($UserData.AD)" } else { "email: $($UserData.Email)" }
        Write-Host "ERROR: Usuario no encontrado con $SearchCriteria" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Usuario encontrado: $($ExistingUser.DisplayName) en $($ExistingUser.SourceDomain)" -ForegroundColor Green
    
    # 2. Determinar provincia origen y destino
    $SourceProvince = Get-ProvinceFromDomain -Domain $ExistingUser.SourceDomain
    $TargetProvince = Get-ProvinceFromOffice -Office $UserData.Oficina
    
    Write-Host "Provincia origen: $SourceProvince" -ForegroundColor Gray
    Write-Host "Provincia destino: $TargetProvince" -ForegroundColor Gray
    
    # 3. Determinar tipo de traslado
    $IsSameProvince = ($SourceProvince -eq $TargetProvince)
    $CanMoveUser = Test-UserMoveCapability -SourceDomain $ExistingUser.SourceDomain -TargetOffice $UserData.Oficina
    
    if ($IsSameProvince -and $CanMoveUser) {
        Write-Host "TRASLADO TIPO: Movimiento dentro del mismo dominio" -ForegroundColor Green
        return Start-SameDomainTransfer -ExistingUser $ExistingUser -UserData $UserData -WhatIf:$WhatIf
    } else {
        Write-Host "TRASLADO TIPO: Creación de nueva cuenta (copia de perfil)" -ForegroundColor Yellow
        return Start-CrossDomainTransfer -ExistingUser $ExistingUser -UserData $UserData -WhatIf:$WhatIf
    }
}

function Find-UserForTransfer {
    <#
    .SYNOPSIS
        Busca un usuario para traslado por email o campo AD
    .PARAMETER Email
        Dirección de email del usuario (opcional)
    .PARAMETER ADField
        Campo AD que contiene el SamAccountName del usuario (opcional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Email,
        
        [Parameter(Mandatory=$false)]
        [string]$ADField
    )
    
    # Priorizar búsqueda por campo AD si está presente
    if (![string]::IsNullOrWhiteSpace($ADField)) {
        Write-Host "Buscando usuario por campo AD: $ADField" -ForegroundColor Yellow
        return Find-UserByADField -ADField $ADField
    }
    
    # Si no hay campo AD, buscar por email
    if (![string]::IsNullOrWhiteSpace($Email)) {
        Write-Host "Buscando usuario por email: $Email" -ForegroundColor Yellow
        return Find-UserByEmail -Email $Email
    }
    
    Write-Warning "No se proporcionó email ni campo AD para buscar el usuario"
    return $null
}

function Find-UserByADField {
    <#
    .SYNOPSIS
        Busca un usuario por su SamAccountName en todos los dominios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ADField
    )
    
    $AllDomains = Get-AllAvailableDomains
    
    foreach ($Domain in $AllDomains) {
        try {
            Write-Verbose "Buscando usuario '$ADField' en dominio: $($Domain.Name)"
            
            $User = Get-ADUser -Identity $ADField -Server $Domain.Name -Properties @(
                'DisplayName', 'mail', 'proxyAddresses', 'Description', 'Office', 
                'Department', 'Title', 'telephoneNumber', 'MemberOf', 'Enabled'
            ) -ErrorAction SilentlyContinue
            
            if ($User) {
                # Agregar información del dominio
                $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain.Name -Force
                $User | Add-Member -NotePropertyName "SourceDomainNetBIOS" -NotePropertyValue $Domain.NetBIOSName -Force
                
                Write-Host "Usuario encontrado en $($Domain.Name): $($User.DisplayName) ($($User.SamAccountName))" -ForegroundColor Green
                return $User
            }
        } catch {
            Write-Verbose "Usuario '$ADField' no encontrado en dominio $($Domain.Name)"
        }
    }
    
    return $null
}

function Find-UserByEmail {
    <#
    .SYNOPSIS
        Busca un usuario por su dirección de email en todos los dominios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email
    )
    
    $AllDomains = Get-AllAvailableDomains
    
    foreach ($Domain in $AllDomains) {
        try {
            Write-Verbose "Buscando en dominio: $($Domain.Name)"
            
            $Users = Get-ADUser -Filter "mail -eq '$Email' -or proxyAddresses -like '*$Email*'" -Server $Domain.Name -Properties @(
                'DisplayName', 'mail', 'proxyAddresses', 'Description', 'Office', 
                'Department', 'Title', 'telephoneNumber', 'MemberOf', 'Enabled'
            ) -ErrorAction SilentlyContinue
            
            if ($Users) {
                foreach ($User in $Users) {
                    # Agregar información del dominio
                    $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain.Name -Force
                    $User | Add-Member -NotePropertyName "SourceDomainNetBIOS" -NotePropertyValue $Domain.NetBIOSName -Force
                    
                    Write-Host "Usuario encontrado en $($Domain.Name): $($User.DisplayName)" -ForegroundColor Green
                    return $User
                }
            }
        } catch {
            Write-Warning "Error buscando en dominio $($Domain.Name): $($_.Exception.Message)"
        }
    }
    
    return $null
}

function Get-ProvinceFromDomain {
    <#
    .SYNOPSIS
        Extrae el nombre de la provincia del dominio
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    # Extraer provincia del nombre de dominio (ej: malaga.justicia.junta-andalucia.es -> malaga)
    if ($Domain -match "^([^.]+)\.") {
        return $matches[1].ToLower()
    }
    
    return "unknown"
}

function Get-ProvinceFromOffice {
    <#
    .SYNOPSIS
        Determina la provincia basada en la oficina de destino
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Office
    )
    
    # Mapear oficinas a provincias (esto se puede expandir)
    $ProvinceMapping = @{
        "almeria" = "almeria"
        "cadiz" = "cadiz"
        "cordoba" = "cordoba"
        "granada" = "granada"
        "huelva" = "huelva"
        "jaen" = "jaen"
        "malaga" = "malaga"
        "sevilla" = "sevilla"
    }
    
    $OfficeNormalized = $Office.ToLower()
    foreach ($Key in $ProvinceMapping.Keys) {
        if ($OfficeNormalized -like "*$Key*") {
            return $ProvinceMapping[$Key]
        }
    }
    
    # Si no coincide, intentar extraer la primera palabra
    if ($Office -match "^(\w+)") {
        return $matches[1].ToLower()
    }
    
    return "unknown"
}

function Test-UserMoveCapability {
    <#
    .SYNOPSIS
        Determina si un usuario puede ser movido directamente o requiere copia
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceDomain,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetOffice
    )
    
    $SourceProvince = Get-ProvinceFromDomain -Domain $SourceDomain
    $TargetProvince = Get-ProvinceFromOffice -Office $TargetOffice
    
    # Si es la misma provincia, generalmente se puede mover
    if ($SourceProvince -eq $TargetProvince) {
        return $true
    }
    
    # Para diferentes provincias, normalmente requiere copia
    return $false
}

function Start-SameDomainTransfer {
    <#
    .SYNOPSIS
        Realiza traslado dentro del mismo dominio (movimiento real del usuario)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ExistingUser,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    Write-Host "`n=== TRASLADO DENTRO DEL MISMO DOMINIO ===" -ForegroundColor Cyan
    
    try {
        # 1. Buscar usuario plantilla en destino
        $TemplateUser = Find-TemplateUserByDescription -Description $ExistingUser.Description -TargetOffice $UserData.Oficina -Domain $ExistingUser.SourceDomain
        
        if (-not $TemplateUser) {
            Write-Host "No se encontró usuario plantilla con la misma descripción." -ForegroundColor Yellow
            $TemplateUser = Select-TemplateUserInteractive -TargetOffice $UserData.Oficina -Domain $ExistingUser.SourceDomain
        }
        
        if (-not $TemplateUser) {
            Write-Host "ERROR: No se seleccionó usuario plantilla." -ForegroundColor Red
            return $false
        }
        
        Write-Host "Usuario plantilla seleccionado: $($TemplateUser.DisplayName)" -ForegroundColor Green
        
        # 2. Limpiar membresías actuales del usuario
        Write-Host "Limpiando membresías actuales..." -ForegroundColor Yellow
        if (-not $WhatIf) {
            Remove-UserFromAllGroups -User $ExistingUser
        } else {
            Write-Host "[WHATIF] Se limpiarían las membresías actuales" -ForegroundColor Gray
        }
        
        # 3. Copiar grupos del usuario plantilla
        Write-Host "Copiando grupos del usuario plantilla..." -ForegroundColor Yellow
        if (-not $WhatIf) {
            Copy-UserGroups -SourceUser $TemplateUser -TargetUser $ExistingUser
        } else {
            Write-Host "[WHATIF] Se copiarían los grupos del usuario plantilla" -ForegroundColor Gray
        }
        
        # 4. Actualizar propiedades del usuario
        Write-Host "Actualizando propiedades del usuario..." -ForegroundColor Yellow
        if (-not $WhatIf) {
            Update-UserPropertiesFromCSV -User $ExistingUser -UserData $UserData -TemplateUser $TemplateUser
        } else {
            Write-Host "[WHATIF] Se actualizarían las propiedades del usuario" -ForegroundColor Gray
        }
        
        Write-Host "Traslado dentro del dominio completado exitosamente." -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "ERROR en traslado dentro del dominio: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-CrossDomainTransfer {
    <#
    .SYNOPSIS
        Realiza traslado entre dominios (copia completa del usuario)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ExistingUser,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    Write-Host "`n=== TRASLADO ENTRE DOMINIOS (COPIA) ===" -ForegroundColor Cyan
    
    try {
        # 1. Determinar dominio de destino
        $TargetDomain = Get-TargetDomainForOffice -Office $UserData.Oficina
        if (-not $TargetDomain) {
            Write-Host "ERROR: No se pudo determinar dominio de destino para $($UserData.Oficina)" -ForegroundColor Red
            return $false
        }
        
        Write-Host "Dominio de destino: $($TargetDomain.Name)" -ForegroundColor Green
        
        # 2. Buscar usuario plantilla en destino
        $TemplateUser = Find-TemplateUserByDescription -Description $ExistingUser.Description -TargetOffice $UserData.Oficina -Domain $TargetDomain.Name
        
        if (-not $TemplateUser) {
            Write-Host "No se encontró usuario plantilla con la misma descripción." -ForegroundColor Yellow
            $TemplateUser = Select-TemplateUserInteractive -TargetOffice $UserData.Oficina -Domain $TargetDomain.Name
        }
        
        if (-not $TemplateUser) {
            Write-Host "ERROR: No se seleccionó usuario plantilla." -ForegroundColor Red
            return $false
        }
        
        Write-Host "Usuario plantilla seleccionado: $($TemplateUser.DisplayName)" -ForegroundColor Green
        
        # 3. Crear nuevo usuario copiando del existente y la plantilla
        Write-Host "Creando nuevo usuario..." -ForegroundColor Yellow
        if (-not $WhatIf) {
            $NewUser = New-TransferredUser -SourceUser $ExistingUser -TemplateUser $TemplateUser -UserData $UserData -TargetDomain $TargetDomain.Name
            
            if ($NewUser) {
                Write-Host "Nuevo usuario creado exitosamente: $($NewUser.SamAccountName)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "ERROR: Falló la creación del nuevo usuario." -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "[WHATIF] Se crearía nuevo usuario en dominio $($TargetDomain.Name)" -ForegroundColor Gray
            return $true
        }
        
    } catch {
        Write-Host "ERROR en traslado entre dominios: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-UserFromAllGroups {
    <#
    .SYNOPSIS
        Remueve un usuario de todos sus grupos (excepto grupos primarios)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User
    )
    
    try {
        $Groups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName -Server $User.SourceDomain
        
        foreach ($Group in $Groups) {
            # No remover del grupo primario (Domain Users, etc.)
            if ($Group.Name -notmatch "Domain Users|Users") {
                try {
                    Remove-ADGroupMember -Identity $Group -Members $User.SamAccountName -Server $User.SourceDomain -Confirm:$false
                    Write-Host "  Removido de grupo: $($Group.Name)" -ForegroundColor Gray
                } catch {
                    Write-Warning "No se pudo remover del grupo $($Group.Name): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "Error removiendo grupos: $($_.Exception.Message)"
    }
}

function Copy-UserGroups {
    <#
    .SYNOPSIS
        Copia grupos de un usuario plantilla a un usuario destino
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SourceUser,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$TargetUser
    )
    
    try {
        $SourceGroups = Get-ADPrincipalGroupMembership -Identity $SourceUser.SamAccountName -Server $SourceUser.SourceDomain
        
        foreach ($Group in $SourceGroups) {
            # No copiar grupos primarios del sistema
            if ($Group.Name -notmatch "Domain Users|Users") {
                try {
                    Add-ADGroupMember -Identity $Group -Members $TargetUser.SamAccountName -Server $TargetUser.SourceDomain -Confirm:$false
                    Write-Host "  Agregado a grupo: $($Group.Name)" -ForegroundColor Green
                } catch {
                    Write-Warning "No se pudo agregar al grupo $($Group.Name): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "Error copiando grupos: $($_.Exception.Message)"
    }
}

function Update-UserPropertiesFromCSV {
    <#
    .SYNOPSIS
        Actualiza las propiedades del usuario con datos del CSV y la plantilla
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$TemplateUser
    )
    
    try {
        $UpdateProperties = @{}
        
        # Propiedades del CSV
        if ($UserData.Nombre) { $UpdateProperties.GivenName = $UserData.Nombre }
        if ($UserData.Apellidos) { $UpdateProperties.Surname = $UserData.Apellidos }
        if ($UserData.Email) { $UpdateProperties.mail = $UserData.Email }
        if ($UserData.Telefono) { $UpdateProperties.telephoneNumber = $UserData.Telefono }
        
        # Propiedades de la plantilla
        if ($TemplateUser.Description) { $UpdateProperties.Description = $TemplateUser.Description }
        if ($TemplateUser.Office) { $UpdateProperties.Office = $TemplateUser.Office }
        
        # Generar DisplayName
        if ($UserData.Nombre -and $UserData.Apellidos) {
            $UpdateProperties.DisplayName = "$($UserData.Apellidos), $($UserData.Nombre)"
        }
        
        # Aplicar cambios
        Set-ADUser -Identity $User.SamAccountName -Server $User.SourceDomain @UpdateProperties
        
        Write-Host "Propiedades actualizadas exitosamente." -ForegroundColor Green
        
    } catch {
        Write-Warning "Error actualizando propiedades: $($_.Exception.Message)"
    }
}

function New-TransferredUser {
    <#
    .SYNOPSIS
        Crea un nuevo usuario combinando datos del usuario original, plantilla y CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$SourceUser,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$TemplateUser,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetDomain
    )
    
    try {
        # Generar SamAccountName único
        $NewSamAccountName = Generate-UniqueSamAccountName -Name $UserData.Nombre -Surname $UserData.Apellidos -Domain $TargetDomain
        
        # Obtener contraseña estándar
        $StandardPassword = Get-StandardPassword
        $SecurePassword = ConvertTo-SecureString $StandardPassword -AsPlainText -Force
        
        # Obtener OU de destino de la plantilla
        $TargetOU = ($TemplateUser.DistinguishedName -split ',',2)[1]
        
        # Crear usuario
        $UserParams = @{
            SamAccountName = $NewSamAccountName
            Name = $NewSamAccountName
            GivenName = $UserData.Nombre
            Surname = $UserData.Apellidos
            DisplayName = "$($UserData.Apellidos), $($UserData.Nombre)"
            EmailAddress = $UserData.Email
            OfficePhone = $UserData.Telefono
            Description = $TemplateUser.Description
            Office = $TemplateUser.Office
            Path = $TargetOU
            Server = $TargetDomain
            AccountPassword = $SecurePassword
            Enabled = $true
        }
        
        $NewUser = New-ADUser @UserParams -PassThru
        
        if ($NewUser) {
            Write-Host "Usuario creado: $($NewUser.SamAccountName)" -ForegroundColor Green
            
            # Agregar información de dominio para compatibilidad
            $NewUser | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $TargetDomain -Force
            
            # Copiar grupos de la plantilla
            Copy-UserGroups -SourceUser $TemplateUser -TargetUser $NewUser
            
            return $NewUser
        }
        
    } catch {
        Write-Error "Error creando nuevo usuario: $($_.Exception.Message)"
        return $null
    }
}

function Generate-UniqueSamAccountName {
    <#
    .SYNOPSIS
        Genera un SamAccountName único basado en nombre y apellidos
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Surname,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    # Función auxiliar para limpiar texto
    function Clean-Text {
        param([string]$Text)
        return $Text.ToLower() -replace '[áàäâ]', 'a' -replace '[éèëê]', 'e' -replace '[íìïî]', 'i' -replace '[óòöô]', 'o' -replace '[úùüû]', 'u' -replace '[ñ]', 'n' -replace '[^a-z0-9]', ''
    }
    
    $CleanName = Clean-Text -Text $Name
    $CleanSurname = Clean-Text -Text $Surname
    
    # Intentar diferentes combinaciones
    $Attempts = @(
        "$CleanName.$CleanSurname",
        "$($CleanName.Substring(0, [Math]::Min(3, $CleanName.Length))).$CleanSurname",
        "$CleanName.$($CleanSurname.Substring(0, [Math]::Min(3, $CleanSurname.Length)))",
        "$($CleanName.Substring(0, 1)).$CleanSurname"
    )
    
    foreach ($Attempt in $Attempts) {
        if ($Attempt.Length -le 20) {
            try {
                $ExistingUser = Get-ADUser -Identity $Attempt -Server $Domain -ErrorAction SilentlyContinue
                if (-not $ExistingUser) {
                    return $Attempt
                }
            } catch {
                return $Attempt
            }
        }
    }
    
    # Si todos fallan, agregar número
    for ($i = 2; $i -le 99; $i++) {
        $AttemptWithNumber = "$($Attempts[0])$i"
        if ($AttemptWithNumber.Length -le 20) {
            try {
                $ExistingUser = Get-ADUser -Identity $AttemptWithNumber -Server $Domain -ErrorAction SilentlyContinue
                if (-not $ExistingUser) {
                    return $AttemptWithNumber
                }
            } catch {
                return $AttemptWithNumber
            }
        }
    }
    
    throw "No se pudo generar un SamAccountName único"
}

Export-ModuleMember -Function @(
    'Start-UserTransferProcess',
    'Find-UserByEmail',
    'Get-ProvinceFromDomain',
    'Get-ProvinceFromOffice'
)