#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para búsqueda y gestión de usuarios plantilla para copiar perfiles
.DESCRIPTION
    Proporciona funciones para encontrar usuarios con descripciones similares
    y permitir selección interactiva cuando no hay coincidencias exactas
#>

Import-Module "$PSScriptRoot\DomainStructureManager.psm1" -Force

function Find-TemplateUserByDescription {
    <#
    .SYNOPSIS
        Busca usuarios con la misma descripción para usar como plantilla
    .PARAMETER Description
        Descripción a buscar (ej: "Tramitador", "Auxilio", "LAJ", "Letrado de la Administración de justicia", "Juez")
    .PARAMETER TargetOffice
        Oficina de destino para filtrar usuarios relevantes
    .PARAMETER Domain
        Dominio donde buscar usuarios plantilla
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetOffice,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    Write-Host "Buscando usuario plantilla con descripción: '$Description'" -ForegroundColor Yellow
    Write-Host "Oficina destino: $TargetOffice" -ForegroundColor Gray
    Write-Host "Dominio: $Domain" -ForegroundColor Gray
    
    try {
        # Buscar usuarios con la descripción exacta
        $ExactMatches = Get-ADUser -Filter "Description -eq '$Description'" -Server $Domain -Properties @(
            'Description', 'Office', 'Department', 'Title', 'DisplayName',
            'MemberOf', 'DistinguishedName', 'Enabled'
        ) | Where-Object { $_.Enabled -eq $true }
        
        if ($ExactMatches) {
            Write-Host "Encontrados $($ExactMatches.Count) usuarios con descripción exacta" -ForegroundColor Green
            
            # Filtrar por oficina si es posible
            $OfficeMatches = $ExactMatches | Where-Object { 
                $_.Office -and ($_.Office -like "*$TargetOffice*" -or $TargetOffice -like "*$($_.Office)*")
            }
            
            if ($OfficeMatches) {
                Write-Host "Encontrado usuario con oficina coincidente: $($OfficeMatches[0].DisplayName)" -ForegroundColor Green
                # Agregar información del dominio
                $SelectedUser = $OfficeMatches[0]
                $SelectedUser | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                return $SelectedUser
            } else {
                Write-Host "Usando primer usuario con descripción exacta: $($ExactMatches[0].DisplayName)" -ForegroundColor Green
                # Agregar información del dominio
                $SelectedUser = $ExactMatches[0]
                $SelectedUser | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                return $SelectedUser
            }
        }
        
        # Si no hay coincidencias exactas, buscar similares
        Write-Host "No se encontraron usuarios con descripción exacta" -ForegroundColor Yellow
        
        $SimilarMatches = Find-SimilarDescriptionUsers -Description $Description -Domain $Domain
        
        if ($SimilarMatches.Count -gt 0) {
            Write-Host "Encontrados usuarios con descripciones similares" -ForegroundColor Yellow
            
            # Filtrar por oficina si es posible
            $OfficeMatches = $SimilarMatches | Where-Object { 
                $_.Office -and ($_.Office -like "*$TargetOffice*" -or $TargetOffice -like "*$($_.Office)*")
            }
            
            if ($OfficeMatches) {
                Write-Host "Usuario similar con oficina coincidente: $($OfficeMatches[0].DisplayName)" -ForegroundColor Green
                return $OfficeMatches[0]
            } else {
                Write-Host "Usuario similar encontrado: $($SimilarMatches[0].DisplayName)" -ForegroundColor Green
                return $SimilarMatches[0]
            }
        }
        
        Write-Host "No se encontraron usuarios plantilla apropiados" -ForegroundColor Red
        return $null
        
    } catch {
        Write-Error "Error buscando usuario plantilla: $($_.Exception.Message)"
        return $null
    }
}

function Find-SimilarDescriptionUsers {
    <#
    .SYNOPSIS
        Busca usuarios con descripciones similares usando palabras clave
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    # Mapeo de descripciones similares
    $DescriptionMappings = @{
        "Tramitador" = @("Tramitador", "Tramitadora", "Gestión procesal", "Procesal")
        "Auxilio" = @("Auxilio", "Auxilio judicial", "Auxiliar", "Auxiliar judicial")
        "LAJ" = @("LAJ", "Letrado de la administración", "Letrado", "Administración de Justicia")
        "Letrado de la Administración de justicia" = @("LAJ", "Letrado", "Letrado de la administración", "Administración de Justicia")
        "Juez" = @("Juez", "Jueza", "Magistrado", "Magistrada")
    }
    
    $SimilarUsers = @()
    
    # Buscar por cada palabra clave relacionada
    $Keywords = $DescriptionMappings[$Description]
    if (-not $Keywords) {
        $Keywords = @($Description)
    }
    
    foreach ($Keyword in $Keywords) {
        try {
            $Users = Get-ADUser -Filter "Description -like '*$Keyword*'" -Server $Domain -Properties @(
                'Description', 'Office', 'Department', 'Title', 'DisplayName',
                'MemberOf', 'DistinguishedName', 'Enabled'
            ) | Where-Object { $_.Enabled -eq $true }
            
            foreach ($User in $Users) {
                # Agregar información del dominio
                $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                $SimilarUsers += $User
            }
            
        } catch {
            Write-Warning "Error buscando con palabra clave '$Keyword': $($_.Exception.Message)"
        }
    }
    
    # Remover duplicados
    $UniqueUsers = $SimilarUsers | Sort-Object SamAccountName -Unique
    
    return $UniqueUsers
}

function Select-TemplateUserInteractive {
    <#
    .SYNOPSIS
        Permite selección interactiva de usuario plantilla cuando no hay coincidencias automáticas
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetOffice,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    Write-Host "`n=== SELECCIÓN INTERACTIVA DE USUARIO PLANTILLA ===" -ForegroundColor Cyan
    Write-Host "No se encontró usuario plantilla automáticamente." -ForegroundColor Yellow
    Write-Host "Oficina destino: $TargetOffice" -ForegroundColor White
    Write-Host "Dominio: $Domain" -ForegroundColor White
    
    try {
        # Obtener usuarios con diferentes descripciones que podrían ser plantillas
        $PotentialTemplates = Get-PotentialTemplateUsers -TargetOffice $TargetOffice -Domain $Domain
        
        if ($PotentialTemplates.Count -eq 0) {
            Write-Host "No se encontraron usuarios potenciales como plantilla." -ForegroundColor Red
            return $null
        }
        
        # Mostrar opciones
        Write-Host "`nUsuarios disponibles con DESCRIPCIONES DIFERENTES:" -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        
        for ($i = 0; $i -lt $PotentialTemplates.Count; $i++) {
            $User = $PotentialTemplates[$i]
            Write-Host "[$($i+1)] $($User.DisplayName)" -ForegroundColor White
            Write-Host "     Descripción: $($User.Description)" -ForegroundColor Cyan
            Write-Host "     Oficina: $($User.Office)" -ForegroundColor Gray
            Write-Host "     Título: $($User.Title)" -ForegroundColor Gray
            Write-Host "     Departamento: $($User.Department)" -ForegroundColor Gray
            Write-Host "     Grupos: $($User.MemberOf.Count) grupos" -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-Host "0. Cancelar operación" -ForegroundColor Red
        Write-Host ""
        
        # Solicitar selección
        do {
            $Selection = Read-Host "Seleccione un usuario plantilla (1-$($PotentialTemplates.Count), 0 para cancelar)"
            
            if ($Selection -eq "0") {
                Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
                return $null
            }
            
            if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $PotentialTemplates.Count) {
                $SelectedUser = $PotentialTemplates[$Selection - 1]
                
                Write-Host "`nUsuario plantilla seleccionado:" -ForegroundColor Green
                Write-Host "  Nombre: $($SelectedUser.DisplayName)" -ForegroundColor White
                Write-Host "  Descripción: $($SelectedUser.Description)" -ForegroundColor Cyan
                Write-Host "  Oficina: $($SelectedUser.Office)" -ForegroundColor Gray
                
                $Confirm = Read-Host "`n¿Confirma la selección? (S/N)"
                if ($Confirm -match '^[SsYy]') {
                    return $SelectedUser
                }
            } else {
                Write-Host "Selección inválida. Intente de nuevo." -ForegroundColor Red
            }
            
        } while ($true)
        
    } catch {
        Write-Error "Error en selección interactiva: $($_.Exception.Message)"
        return $null
    }
}

function Get-PotentialTemplateUsers {
    <#
    .SYNOPSIS
        Obtiene usuarios potenciales para usar como plantilla basado en la oficina destino
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetOffice,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    $PotentialUsers = @()
    
    try {
        # Buscar usuarios habilitados con descripción no vacía
        Write-Host "Buscando usuarios potenciales..." -ForegroundColor Yellow
        
        # Primero intentar buscar por oficina similar
        $OfficeUsers = Get-ADUser -Filter "Office -like '*$TargetOffice*' -and Enabled -eq `$true -and Description -ne `$null" -Server $Domain -Properties @(
            'Description', 'Office', 'Department', 'Title', 'DisplayName',
            'MemberOf', 'DistinguishedName', 'Enabled'
        )
        
        foreach ($User in $OfficeUsers) {
            if (![string]::IsNullOrWhiteSpace($User.Description)) {
                # Agregar información del dominio
                $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                $PotentialUsers += $User
            }
        }
        
        # Si no hay suficientes usuarios por oficina, buscar otros con descripciones relevantes
        if ($PotentialUsers.Count -lt 5) {
            $RelevantDescriptions = @("Tramitador", "Auxilio", "LAJ", "Letrado", "Juez", "Magistrado", "Procesal", "Judicial")
            
            foreach ($Desc in $RelevantDescriptions) {
                $AdditionalUsers = Get-ADUser -Filter "Description -like '*$Desc*' -and Enabled -eq `$true" -Server $Domain -Properties @(
                    'Description', 'Office', 'Department', 'Title', 'DisplayName',
                    'MemberOf', 'DistinguishedName', 'Enabled'
                ) | Where-Object { $_.SamAccountName -notin ($PotentialUsers | Select-Object -ExpandProperty SamAccountName) }
                
                foreach ($User in $AdditionalUsers) {
                    # Agregar información del dominio
                    $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                    $PotentialUsers += $User
                }
                
                # Limitar la lista para evitar demasiadas opciones
                if ($PotentialUsers.Count -ge 15) {
                    break
                }
            }
        }
        
        Write-Host "Encontrados $($PotentialUsers.Count) usuarios potenciales" -ForegroundColor Green
        
        # Ordenar por relevancia (primero los que coinciden con oficina, luego por descripción)
        $SortedUsers = $PotentialUsers | Sort-Object @(
            @{ Expression = { if ($_.Office -like "*$TargetOffice*") { 0 } else { 1 } } },
            @{ Expression = "Description" },
            @{ Expression = "DisplayName" }
        )
        
        return $SortedUsers
        
    } catch {
        Write-Error "Error obteniendo usuarios potenciales: $($_.Exception.Message)"
        return @()
    }
}

function Get-UserTemplateProfile {
    <#
    .SYNOPSIS
        Obtiene el perfil completo de un usuario plantilla para copiar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$TemplateUser
    )
    
    try {
        # Obtener información completa del usuario plantilla
        $CompleteUser = Get-ADUser -Identity $TemplateUser.SamAccountName -Server $TemplateUser.SourceDomain -Properties @(
            'Description', 'Office', 'Department', 'Title', 'Manager',
            'MemberOf', 'DistinguishedName', 'HomeDirectory', 'HomeDrive',
            'ProfilePath', 'ScriptPath'
        )
        
        # Obtener grupos del usuario
        $Groups = Get-ADPrincipalGroupMembership -Identity $TemplateUser.SamAccountName -Server $TemplateUser.SourceDomain
        
        $Profile = [PSCustomObject]@{
            User = $CompleteUser
            Groups = $Groups
            Properties = @{
                Description = $CompleteUser.Description
                Office = $CompleteUser.Office
                Department = $CompleteUser.Department
                Title = $CompleteUser.Title
                Manager = $CompleteUser.Manager
                HomeDirectory = $CompleteUser.HomeDirectory
                HomeDrive = $CompleteUser.HomeDrive
                ProfilePath = $CompleteUser.ProfilePath
                ScriptPath = $CompleteUser.ScriptPath
            }
            TargetOU = ($CompleteUser.DistinguishedName -split ',',2)[1]
        }
        
        return $Profile
        
    } catch {
        Write-Error "Error obteniendo perfil del usuario plantilla: $($_.Exception.Message)"
        return $null
    }
}

function Show-TemplateUserSummary {
    <#
    .SYNOPSIS
        Muestra un resumen del usuario plantilla seleccionado
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$TemplateUser
    )
    
    Write-Host "`n=== RESUMEN DEL USUARIO PLANTILLA ===" -ForegroundColor Cyan
    Write-Host "Nombre: $($TemplateUser.DisplayName)" -ForegroundColor White
    Write-Host "Usuario: $($TemplateUser.SamAccountName)" -ForegroundColor Gray
    Write-Host "Descripción: $($TemplateUser.Description)" -ForegroundColor Yellow
    Write-Host "Oficina: $($TemplateUser.Office)" -ForegroundColor Gray
    Write-Host "Departamento: $($TemplateUser.Department)" -ForegroundColor Gray
    Write-Host "Título: $($TemplateUser.Title)" -ForegroundColor Gray
    Write-Host "Dominio: $($TemplateUser.SourceDomain)" -ForegroundColor Magenta
    
    if ($TemplateUser.MemberOf) {
        Write-Host "Grupos ($($TemplateUser.MemberOf.Count)):" -ForegroundColor Yellow
        foreach ($GroupDN in $TemplateUser.MemberOf) {
            $GroupName = ($GroupDN -split ',')[0] -replace '^CN=', ''
            Write-Host "  - $GroupName" -ForegroundColor Gray
        }
    }
}

Export-ModuleMember -Function @(
    'Find-TemplateUserByDescription',
    'Find-SimilarDescriptionUsers',
    'Select-TemplateUserInteractive',
    'Get-PotentialTemplateUsers',
    'Get-UserTemplateProfile',
    'Show-TemplateUserSummary'
)