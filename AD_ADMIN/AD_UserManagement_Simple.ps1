#Requires -Version 5.1

<#
.SYNOPSIS
    Script principal para la gestion de altas de usuarios en Active Directory - Version Simple
.DESCRIPTION
    Sistema modular para gestionar altas normalizadas, traslados y compaginadas
    Version simplificada que maneja mejor las dependencias de modulos
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CSVFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\AD_UserManagement"
)

$ErrorActionPreference = "Continue"

# Configurar logging antes de importar modulos
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $LogPath)) {
    try {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    } catch {
        $LogPath = $env:TEMP
    }
}

$LogFile = Join-Path $LogPath "AD_UserManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    Write-Host $LogEntry
    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    } catch {
        # Ignorar errores de logging
    }
}

function Get-DomainFromOffice {
    <#
    .SYNOPSIS
        Determina el dominio correcto basado en la oficina del usuario
    #>
    param([string]$Office)
    
    if ([string]::IsNullOrWhiteSpace($Office)) {
        return "justicia.junta-andalucia.es"  # Dominio por defecto
    }
    
    $Office = $Office.ToLower()
    
    # Mapeo de ubicaciones a dominios
    $DomainMap = @{
        "almeria" = "almeria.justicia.junta-andalucia.es"
        "cadiz" = "cadiz.justicia.junta-andalucia.es"
        "cordoba" = "cordoba.justicia.junta-andalucia.es"
        "granada" = "granada.justicia.junta-andalucia.es"
        "huelva" = "huelva.justicia.junta-andalucia.es"
        "jaen" = "jaen.justicia.junta-andalucia.es"
        "malaga" = "malaga.justicia.junta-andalucia.es"
        "sevilla" = "sevilla.justicia.junta-andalucia.es"
        "formacion" = "formacion.justicia.junta-andalucia.es"
        "vdi" = "vdi.justicia.junta-andalucia.es"
    }
    
    # Buscar coincidencia en el nombre de la oficina
    foreach ($Location in $DomainMap.Keys) {
        if ($Office -like "*$Location*") {
            Write-Log "Oficina '$Office' mapeada a dominio: $($DomainMap[$Location])" "INFO"
            return $DomainMap[$Location]
        }
    }
    
    # Si no encuentra coincidencia, usar dominio por defecto
    Write-Log "No se pudo mapear oficina '$Office' a dominio especifico. Usando dominio por defecto." "WARNING"
    return "justicia.junta-andalucia.es"
}

function Find-OrganizationalUnit {
    <#
    .SYNOPSIS
        Busca la UO correcta basada en el nombre de la oficina con precision mejorada
    #>
    param(
        [string]$Office,
        [string]$Domain
    )
    
    if ([string]::IsNullOrWhiteSpace($Office)) {
        Write-Log "Oficina no especificada - usando UO por defecto" "WARNING"
        return $null
    }
    
    try {
        Write-Log "Buscando UO para oficina: '$Office' en dominio: $Domain" "INFO"
        
        # Obtener todas las UOs del dominio
        $AllOUs = Get-ADOrganizationalUnit -Filter * -Server $Domain -Properties Name, DistinguishedName
        
        # Normalizar nombre de oficina
        $NormalizedOffice = $Office.ToLower() -replace '[^a-z0-9\s]', ' ' -replace '\s+', ' '
        Write-Log "Oficina normalizada: '$NormalizedOffice'" "INFO"
        
        # PASO 1: Buscar coincidencia exacta (incluyendo numeros)
        foreach ($OU in $AllOUs) {
            $NormalizedOUName = $OU.Name.ToLower() -replace '[^a-z0-9\s]', ' ' -replace '\s+', ' '
            
            if ($NormalizedOUName -eq $NormalizedOffice) {
                Write-Log "Coincidencia EXACTA encontrada: '$($OU.Name)'" "INFO"
                Write-Log "DN: $($OU.DistinguishedName)" "INFO"
                return $OU.DistinguishedName
            }
        }
        
        # PASO 2: Buscar coincidencia por numero especifico si existe
        $OfficeNumber = ""
        if ($Office -match '\bn[oº°]\s*(\d+)') {
            $OfficeNumber = $Matches[1]
            Write-Log "Numero detectado en oficina: '$OfficeNumber'" "INFO"
            
            foreach ($OU in $AllOUs) {
                $OUName = $OU.Name.ToLower()
                # Verificar que contenga el numero especifico
                if ($OUName -match '\bn[oº°]\s*' + $OfficeNumber + '\b') {
                    # Verificar que tambien contenga palabras clave principales
                    $KeyWords = @('juzgado', 'primera', 'instancia', 'penal', 'civil', 'mixto', 'familia', 'mercantil', 'contencioso', 'social')
                    $MatchedKeyWords = 0
                    
                    foreach ($KeyWord in $KeyWords) {
                        if ($NormalizedOffice -like "*$KeyWord*" -and $OUName -like "*$KeyWord*") {
                            $MatchedKeyWords++
                        }
                    }
                    
                    if ($MatchedKeyWords -ge 2) {  # Al menos 2 palabras clave coinciden
                        Write-Log "Coincidencia por NUMERO ESPECIFICO encontrada: '$($OU.Name)'" "INFO"
                        Write-Log "Numero: $OfficeNumber, Palabras clave coincidentes: $MatchedKeyWords" "INFO"
                        Write-Log "DN: $($OU.DistinguishedName)" "INFO"
                        return $OU.DistinguishedName
                    }
                }
            }
        }
        
        # PASO 3: Buscar por coincidencia de palabras clave (sin numero especifico)
        $OfficeWords = $Office -split '\s+' | Where-Object { $_.Length -gt 3 -and $_ -notmatch '^\d+$' }  # Excluir numeros solos
        
        $BestMatch = $null
        $BestScore = 0
        
        foreach ($OU in $AllOUs) {
            $Score = 0
            $OUName = $OU.Name.ToLower()
            
            # Puntuar coincidencias de palabras (excluyendo numeros)
            foreach ($Word in $OfficeWords) {
                $CleanWord = $Word.ToLower() -replace '[^a-z]', ''
                if ($CleanWord.Length -gt 3 -and $OUName -like "*$CleanWord*") {
                    $Score += $CleanWord.Length
                }
            }
            
            # Penalizar si tiene numero diferente
            if ($OfficeNumber -and $OUName -match '\bn[oº°]\s*(\d+)') {
                $OUNumber = $Matches[1]
                if ($OUNumber -ne $OfficeNumber) {
                    $Score = $Score * 0.5  # Reducir puntuacion a la mitad
                    Write-Log "Penalizando UO '$($OU.Name)' por numero diferente ($OUNumber vs $OfficeNumber)" "INFO"
                }
            }
            
            if ($Score -gt $BestScore) {
                $BestScore = $Score
                $BestMatch = $OU
            }
        }
        
        if ($BestMatch -and $BestScore -gt 10) {  # Umbral minimo de puntuacion
            Write-Log "Mejor coincidencia encontrada: '$($BestMatch.Name)' (Puntuacion: $BestScore)" "WARNING"
            Write-Log "ADVERTENCIA: Esta UO puede no ser exacta. Verifique manualmente." "WARNING"
            Write-Log "DN: $($BestMatch.DistinguishedName)" "INFO"
            return $BestMatch.DistinguishedName
        } else {
            Write-Log "No se encontro UO especifica para '$Office' - usando UO por defecto" "WARNING"
            
            # Mostrar UOs disponibles para ayuda
            Write-Log "UOs disponibles que contienen 'juzgado':" "INFO"
            $JuzgadoOUs = $AllOUs | Where-Object { $_.Name -like "*juzgado*" } | Select-Object -First 5
            foreach ($JOU in $JuzgadoOUs) {
                Write-Log "  - $($JOU.Name)" "INFO"
            }
            
            # Buscar UO "Users" como fallback
            $DefaultOU = Get-ADOrganizationalUnit -Filter "Name -eq 'Users'" -Server $Domain -ErrorAction SilentlyContinue
            if ($DefaultOU) {
                return $DefaultOU.DistinguishedName
            }
            
            # Si no hay UO Users, usar el contenedor Users por defecto
            $DomainDN = (Get-ADDomain -Server $Domain).DistinguishedName
            return "CN=Users,$DomainDN"
        }
        
    } catch {
        Write-Log "Error buscando UO: $($_.Exception.Message)" "ERROR"
        # Fallback al contenedor Users
        try {
            $DomainDN = (Get-ADDomain -Server $Domain).DistinguishedName
            return "CN=Users,$DomainDN"
        } catch {
            return $null
        }
    }
}

function Find-TemplateUserInOU {
    <#
    .SYNOPSIS
        Busca usuario plantilla con descripcion similar dentro de una UO especifica
    #>
    param(
        [string]$Description,
        [string]$OrganizationalUnit,
        [string]$Domain,
        [switch]$Interactive = $false
    )
    
    if ([string]::IsNullOrWhiteSpace($Description) -or [string]::IsNullOrWhiteSpace($OrganizationalUnit)) {
        Write-Log "Descripcion o UO no especificada para busqueda de plantilla" "WARNING"
        return $null
    }
    
    try {
        Write-Log "Buscando usuario plantilla en UO: $OrganizationalUnit" "INFO"
        Write-Log "Descripcion objetivo: '$Description'" "INFO"
        
        # Obtener todos los usuarios de la UO con descripcion
        $UsersInOU = Get-ADUser -SearchBase $OrganizationalUnit -SearchScope Subtree -Filter "Description -like '*'" -Server $Domain -Properties Description, MemberOf -ErrorAction Stop
        
        if (-not $UsersInOU) {
            Write-Log "No se encontraron usuarios con descripcion en la UO especificada" "WARNING"
            return $null
        }
        
        Write-Log "Encontrados $($UsersInOU.Count) usuarios con descripcion en la UO" "INFO"
        
        # Normalizar la descripcion objetivo para comparacion
        $NormalizedTarget = Normalize-JobDescription -Description $Description
        
        # Buscar coincidencia exacta primero
        foreach ($User in $UsersInOU) {
            if ([string]::IsNullOrWhiteSpace($User.Description)) { continue }
            
            $NormalizedUserDesc = Normalize-JobDescription -Description $User.Description
            
            if ($NormalizedUserDesc -eq $NormalizedTarget) {
                Write-Log "Coincidencia exacta encontrada: $($User.SamAccountName) - '$($User.Description)'" "INFO"
                return $User
            }
        }
        
        # Si no hay coincidencia exacta, buscar coincidencia parcial
        $PartialMatches = @()
        foreach ($User in $UsersInOU) {
            if ([string]::IsNullOrWhiteSpace($User.Description)) { continue }
            
            $NormalizedUserDesc = Normalize-JobDescription -Description $User.Description
            
            # Buscar palabras clave comunes
            $TargetWords = $NormalizedTarget -split '\s+' | Where-Object { $_.Length -gt 3 }
            $UserWords = $NormalizedUserDesc -split '\s+' | Where-Object { $_.Length -gt 3 }
            
            $CommonWords = $TargetWords | Where-Object { $UserWords -contains $_ }
            
            if ($CommonWords.Count -gt 0) {
                $PartialMatches += [PSCustomObject]@{
                    User = $User
                    Score = $CommonWords.Count
                    CommonWords = $CommonWords -join ', '
                }
            }
        }
        
        if ($PartialMatches.Count -gt 0) {
            # Ordenar por puntuacion (mas coincidencias primero)
            $PartialMatches = $PartialMatches | Sort-Object Score -Descending
            $BestMatch = $PartialMatches[0]
            
            Write-Log "Coincidencia parcial encontrada: $($BestMatch.User.SamAccountName) - '$($BestMatch.User.Description)' (Palabras comunes: $($BestMatch.CommonWords))" "INFO"
            return $BestMatch.User
        }
        
        # Si no hay coincidencias y es interactivo, mostrar opciones
        if ($Interactive) {
            return Show-DescriptionOptions -UsersInOU $UsersInOU -TargetDescription $Description
        } else {
            Write-Log "No se encontraron coincidencias para '$Description' en la UO" "WARNING"
            
            # Mostrar las descripciones disponibles para referencia
            $UniqueDescriptions = $UsersInOU | Where-Object { ![string]::IsNullOrWhiteSpace($_.Description) } | 
                                             Select-Object -ExpandProperty Description | 
                                             Sort-Object -Unique
            
            Write-Log "Descripciones disponibles en la UO:" "INFO"
            foreach ($Desc in $UniqueDescriptions) {
                Write-Log "  - $Desc" "INFO"
            }
            
            return $null
        }
        
    } catch {
        Write-Log "Error buscando usuario plantilla en UO: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Normalize-JobDescription {
    <#
    .SYNOPSIS
        Normaliza descripciones de trabajo para comparacion
    #>
    param([string]$Description)
    
    if ([string]::IsNullOrWhiteSpace($Description)) {
        return ""
    }
    
    # Convertir a minusculas y limpiar
    $Normalized = $Description.ToLower().Trim()
    
    # Mapeo de terminos equivalentes
    $JobMappings = @{
        'tramitador' = 'tramitacion'
        'tramitadora' = 'tramitacion'
        'tramitacion procesal' = 'tramitacion'
        'tramitacion y gestion procesal' = 'tramitacion'
        'auxilio judicial' = 'auxilio'
        'auxilio' = 'auxilio'
        'letrado' = 'letrado'
        'letrada' = 'letrado'
        'letrado de la administracion de justicia' = 'letrado'
        'laj' = 'letrado'
        'juez' = 'juez'
        'jueza' = 'juez'
        'magistrado' = 'magistrado'
        'magistrada' = 'magistrado'
        'secretario judicial' = 'secretario'
        'secretaria judicial' = 'secretario'
    }
    
    # Aplicar mapeos
    foreach ($Key in $JobMappings.Keys) {
        if ($Normalized -like "*$Key*") {
            $Normalized = $JobMappings[$Key]
            break
        }
    }
    
    return $Normalized
}

function Show-DescriptionOptions {
    <#
    .SYNOPSIS
        Muestra opciones de descripcion para seleccion interactiva
    #>
    param(
        [array]$UsersInOU,
        [string]$TargetDescription
    )
    
    $UniqueDescriptions = $UsersInOU | Where-Object { ![string]::IsNullOrWhiteSpace($_.Description) } | 
                                     Group-Object Description | 
                                     Sort-Object Name
    
    if ($UniqueDescriptions.Count -eq 0) {
        Write-Log "No hay descripciones disponibles para seleccionar" "WARNING"
        return $null
    }
    
    Write-Host "`nNo se encontro coincidencia exacta para: '$TargetDescription'" -ForegroundColor Yellow
    Write-Host "Descripciones disponibles en la UO:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $UniqueDescriptions.Count; $i++) {
        $Desc = $UniqueDescriptions[$i]
        Write-Host "[$($i+1)] $($Desc.Name) ($($Desc.Count) usuarios)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "[0] No usar plantilla (crear usuario sin grupos adicionales)" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione una descripcion (0-$($UniqueDescriptions.Count))"
        
        if ($Selection -eq "0") {
            Write-Log "Usuario eligio no usar plantilla" "INFO"
            return $null
        }
        
        if ([int]::TryParse($Selection, [ref]$null) -and $Selection -ge 1 -and $Selection -le $UniqueDescriptions.Count) {
            $SelectedDesc = $UniqueDescriptions[$Selection - 1]
            $SelectedUser = $UsersInOU | Where-Object { $_.Description -eq $SelectedDesc.Name } | Select-Object -First 1
            
            Write-Log "Usuario selecciono: '$($SelectedDesc.Name)'" "INFO"
            Write-Log "Usuario plantilla: $($SelectedUser.SamAccountName)" "INFO"
            
            return $SelectedUser
        }
        
        Write-Host "Seleccion invalida. Intente de nuevo." -ForegroundColor Red
        
    } while ($true)
}

function Find-ExistingUserForTransfer {
    <#
    .SYNOPSIS
        Busca usuario existente para traslado por email o campo AD
    #>
    param([PSCustomObject]$UserData)
    
    try {
        # Obtener todos los dominios
        $AllDomains = @()
        try {
            $Forest = Get-ADForest -ErrorAction Stop
            foreach ($DomainName in $Forest.Domains) {
                try {
                    $DomainObj = Get-ADDomain -Identity $DomainName -ErrorAction Stop
                    $AllDomains += $DomainObj.DNSRoot
                } catch {
                    Write-Log "Dominio $DomainName no accesible" "WARNING"
                }
            }
        } catch {
            Write-Log "Error obteniendo dominios del bosque" "WARNING"
            return $null
        }
        
        # Buscar por campo AD si existe
        if (![string]::IsNullOrWhiteSpace($UserData.AD)) {
            Write-Log "Buscando usuario por campo AD: $($UserData.AD)" "INFO"
            
            foreach ($Domain in $AllDomains) {
                try {
                    $User = Get-ADUser -Identity $UserData.AD -Server $Domain -Properties DisplayName, mail, Office, Description -ErrorAction SilentlyContinue
                    if ($User) {
                        Write-Log "Usuario encontrado en $Domain`: $($User.DisplayName) ($($User.SamAccountName))" "INFO"
                        $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                        return $User
                    }
                } catch {
                    # Continuar con el siguiente dominio
                }
            }
        }
        
        # Buscar por email si no se encontró por AD
        if (![string]::IsNullOrWhiteSpace($UserData.Email)) {
            Write-Log "Buscando usuario por email: $($UserData.Email)" "INFO"
            
            foreach ($Domain in $AllDomains) {
                try {
                    $Users = Get-ADUser -Filter "mail -eq '$($UserData.Email)'" -Server $Domain -Properties DisplayName, mail, Office, Description -ErrorAction SilentlyContinue
                    if ($Users) {
                        $User = $Users[0]  # Tomar el primero si hay múltiples
                        Write-Log "Usuario encontrado en $Domain`: $($User.DisplayName) ($($User.SamAccountName))" "INFO"
                        $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                        return $User
                    }
                } catch {
                    # Continuar con el siguiente dominio
                }
            }
        }
        
        Write-Log "No se encontro usuario con email '$($UserData.Email)' o AD '$($UserData.AD)'" "WARNING"
        return $null
        
    } catch {
        Write-Log "Error buscando usuario existente: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Move-UserToNewLocation {
    <#
    .SYNOPSIS
        Mueve usuario a nueva ubicacion
    #>
    param(
        [PSCustomObject]$ExistingUser,
        [string]$TargetDomain,
        [string]$TargetOU,
        [PSCustomObject]$TemplateUser,
        [string]$NewOffice
    )
    
    try {
        Write-Log "Moviendo usuario $($ExistingUser.SamAccountName) a nueva ubicacion" "INFO"
        
        # Si es el mismo dominio, solo mover la UO y actualizar oficina
        if ($ExistingUser.SourceDomain -eq $TargetDomain) {
            Write-Log "Traslado dentro del mismo dominio" "INFO"
            
            # Mover a nueva UO si es diferente
            if ($TargetOU) {
                Move-ADObject -Identity $ExistingUser.DistinguishedName -TargetPath $TargetOU -Server $TargetDomain
                Write-Log "Usuario movido a UO: $TargetOU" "INFO"
            }
            
            # Actualizar oficina
            Set-ADUser -Identity $ExistingUser.SamAccountName -Office $NewOffice -Server $TargetDomain
            Write-Log "Oficina actualizada a: $NewOffice" "INFO"
            
        } else {
            Write-Log "Traslado entre dominios no implementado completamente" "WARNING"
            # Aquí se implementaría traslado entre dominios
            return $false
        }
        
        # Copiar grupos del usuario plantilla si existe
        if ($TemplateUser -and $TemplateUser.MemberOf) {
            Write-Log "Copiando grupos del usuario plantilla..." "INFO"
            
            foreach ($GroupDN in $TemplateUser.MemberOf) {
                try {
                    $Group = Get-ADGroup -Identity $GroupDN -Server $TargetDomain
                    Add-ADGroupMember -Identity $Group -Members $ExistingUser.SamAccountName -Server $TargetDomain
                    Write-Log "Usuario añadido al grupo: $($Group.Name)" "INFO"
                } catch {
                    Write-Log "Error añadiendo usuario al grupo $GroupDN`: $($_.Exception.Message)" "WARNING"
                }
            }
        }
        
        return $true
        
    } catch {
        Write-Log "Error moviendo usuario: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Log "=== INICIANDO PROCESAMIENTO DE USUARIOS ===" "INFO"
Write-Log "Archivo CSV: $CSVFile" "INFO"
Write-Log "Modo WhatIf: $WhatIf" "INFO"

# Verificar que el archivo CSV existe
if (-not (Test-Path $CSVFile)) {
    Write-Log "ERROR: El archivo CSV no existe: $CSVFile" "ERROR"
    throw "El archivo CSV no existe: $CSVFile"
}

# Importar modulos necesarios
Write-Log "Cargando modulos del sistema..." "INFO"

$ModulesLoaded = @()
$ModulesFailed = @()

# Lista de modulos a cargar (usar versiones corregidas si existen)
$ModulesToLoad = @(
    @{ Name = "CSVValidation"; Alternatives = @("CSVValidation_Fixed", "CSVValidation") },
    @{ Name = "SamAccountNameGenerator"; Alternatives = @("SamAccountNameGenerator_Fixed", "SamAccountNameGenerator") },
    @{ Name = "PasswordManager"; Alternatives = @("PasswordManager") },
    @{ Name = "TransferManager"; Alternatives = @("TransferManager") }
)

foreach ($ModuleInfo in $ModulesToLoad) {
    $ModuleLoaded = $false
    $ModuleName = $ModuleInfo.Name
    
    # Intentar cargar alternativas en orden de prioridad
    foreach ($Alternative in $ModuleInfo.Alternatives) {
        $ModulePath = Join-Path "$ScriptPath\Modules" "$Alternative.psm1"
        
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force -ErrorAction Stop
                $ModulesLoaded += $ModuleName
                Write-Log "Modulo cargado: $Alternative (como $ModuleName)" "INFO"
                $ModuleLoaded = $true
                break
            } catch {
                Write-Log "Error cargando modulo $Alternative`: $($_.Exception.Message)" "ERROR"
                continue
            }
        }
    }
    
    if (-not $ModuleLoaded) {
        $ModulesFailed += $ModuleName
        Write-Log "No se pudo cargar ninguna version del modulo $ModuleName" "WARNING"
    }
}

Write-Log "Modulos cargados: $($ModulesLoaded.Count)" "INFO"
Write-Log "Modulos fallidos: $($ModulesFailed.Count)" "INFO"

# Validar CSV si el modulo esta disponible
if ("CSVValidation" -in $ModulesLoaded) {
    Write-Log "Validando archivo CSV..." "INFO"
    
    try {
        $CSVValidation = Test-CSVFile -CSVPath $CSVFile -Delimiter ";"
        
        Write-Log "Filas totales: $($CSVValidation.TotalRows)" "INFO"
        Write-Log "Filas validas: $($CSVValidation.ValidRows)" "INFO"
        Write-Log "Filas con errores: $($CSVValidation.ErrorRows)" "INFO"
        
        if (-not $CSVValidation.IsValid) {
            Write-Log "El archivo CSV contiene errores:" "ERROR"
            foreach ($Error in $CSVValidation.Errors) {
                Write-Log "  ERROR: $Error" "ERROR"
            }
            throw "Errores de validacion en el archivo CSV. Corrija los errores e intente de nuevo."
        }
        
        $Users = $CSVValidation.ValidatedData
        Write-Log "Datos validados: $($Users.Count) registros validos para procesar" "INFO"
        
    } catch {
        Write-Log "Error en validacion CSV: $($_.Exception.Message)" "ERROR"
        Write-Log "Continuando con importacion directa del CSV..." "WARNING"
        
        # Fallback a importacion directa
        $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
        Write-Log "Importados $($Users.Count) registros del CSV (sin validacion)" "INFO"
    }
} else {
    Write-Log "Modulo CSVValidation no disponible - usando importacion directa" "WARNING"
    
    try {
        Write-Log "Intentando importar CSV desde: $CSVFile" "INFO"
        $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
        
        if ($Users.Count -eq 0) {
            Write-Log "ERROR: El archivo CSV esta vacio o no tiene datos validos" "ERROR"
            throw "El archivo CSV esta vacio"
        }
        
        Write-Log "Importados $($Users.Count) registros del CSV" "INFO"
        
        # Mostrar las columnas detectadas
        $Columns = $Users[0].PSObject.Properties.Name
        Write-Log "Columnas detectadas: $($Columns -join ', ')" "INFO"
        
        # Validacion basica del primer registro para verificar formato
        $FirstUser = $Users[0]
        if (-not ($FirstUser.PSObject.Properties.Name -contains "TipoAlta")) {
            Write-Log "ADVERTENCIA: El CSV no contiene la columna 'TipoAlta'. Verifique el formato." "WARNING"
            Write-Log "Columnas disponibles: $($FirstUser.PSObject.Properties.Name -join ', ')" "WARNING"
        }
        
        # Mostrar primer registro para debugging
        Write-Log "Primer registro - Nombre: '$($FirstUser.Nombre)', Apellidos: '$($FirstUser.Apellidos)', TipoAlta: '$($FirstUser.TipoAlta)'" "INFO"
        
    } catch {
        Write-Log "Error importando CSV: $($_.Exception.Message)" "ERROR"
        throw "Error importando el archivo CSV"
    }
}

# Procesar usuarios
$ProcessedCount = 0
$ErrorCount = 0

Write-Log "Iniciando procesamiento de $($Users.Count) usuarios" "INFO"

foreach ($User in $Users) {
    try {
        Write-Log "Procesando usuario: $($User.Nombre) $($User.Apellidos)" "INFO"
        
        # Validacion basica del tipo de alta
        if ([string]::IsNullOrWhiteSpace($User.TipoAlta)) {
            Write-Log "ERROR: Establece el tipo de alta, es obligatorio para seguir con el proceso." "ERROR"
            $ErrorCount++
            continue
        }
        
        switch ($User.TipoAlta.ToUpper()) {
            "NORMALIZADA" {
                Write-Log "Procesando alta normalizada" "INFO"
                
                # Determinar dominio correcto basado en la oficina
                $TargetDomain = Get-DomainFromOffice -Office $User.Oficina
                Write-Log "Dominio destino determinado: $TargetDomain" "INFO"
                
                if ("SamAccountNameGenerator" -in $ModulesLoaded) {
                    # Generar SamAccountName
                    try {
                        $SamAccountName = New-SamAccountName -GivenName $User.Nombre -Surname $User.Apellidos -Domain $TargetDomain -Verbose
                        if ([string]::IsNullOrWhiteSpace($SamAccountName)) {
                            Write-Log "ERROR: No se pudo generar un SamAccountName unico para $($User.Nombre) $($User.Apellidos)" "ERROR"
                            $ErrorCount++
                            continue
                        }
                        Write-Log "SamAccountName generado: $SamAccountName (verificado como unico en todos los dominios)" "INFO"
                    } catch {
                        Write-Log "ERROR: Error generando SamAccountName para $($User.Nombre) $($User.Apellidos): $($_.Exception.Message)" "ERROR"
                        $ErrorCount++
                        continue
                    }
                } else {
                    Write-Log "ERROR: Modulo SamAccountNameGenerator no disponible - no se puede crear usuario" "ERROR"
                    $ErrorCount++
                    continue
                }
                
                # Buscar la UO correcta para ubicar el usuario
                $TargetOU = Find-OrganizationalUnit -Office $User.Oficina -Domain $TargetDomain
                
                # Buscar usuario plantilla dentro de la UO especifica
                $TemplateUser = $null
                if ($TargetOU) {
                    Write-Log "Buscando usuario plantilla con descripcion '$($User.Descripcion)' en UO: $TargetOU" "INFO"
                    
                    # Buscar primero sin interactividad
                    $TemplateUser = Find-TemplateUserInOU -Description $User.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain
                    
                    # Si no se encuentra y no es modo WhatIf, permitir seleccion interactiva
                    if (-not $TemplateUser -and -not $WhatIf) {
                        Write-Log "No se encontro coincidencia automatica. Habilitando seleccion interactiva..." "INFO"
                        $TemplateUser = Find-TemplateUserInOU -Description $User.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain -Interactive
                    }
                } else {
                    Write-Log "No se pudo determinar UO especifica, buscando en todo el dominio como fallback" "WARNING"
                    try {
                        $TemplateUsers = Get-ADUser -Filter "Description -like '*$($User.Descripcion)*'" -Server $TargetDomain -Properties Description, MemberOf -ErrorAction SilentlyContinue
                        if ($TemplateUsers) {
                            $TemplateUser = $TemplateUsers[0]
                            Write-Log "Usuario plantilla encontrado en dominio: $($TemplateUser.SamAccountName) - $($TemplateUser.Description)" "INFO"
                        }
                    } catch {
                        Write-Log "Error buscando usuario plantilla en dominio: $($_.Exception.Message)" "WARNING"
                    }
                }
                
                if ($WhatIf) {
                    Write-Log "SIMULACION: Crearia usuario normalizado en dominio $TargetDomain" "INFO"
                    Write-Log "SIMULACION: UO destino: $TargetOU" "INFO"
                    Write-Log "SIMULACION: UPN seria: $SamAccountName@justicia.junta-andalucia.es" "INFO"
                } else {
                    Write-Log "CREANDO USUARIO REAL en dominio $TargetDomain" "INFO"
                    
                    try {
                        # Generar contraseña usando PasswordManager si está disponible
                        $UserPassword = "Justicia0825"  # Contraseña por defecto
                        if ("PasswordManager" -in $ModulesLoaded) {
                            try {
                                $UserPassword = Get-StandardPassword
                                Write-Log "Contraseña generada: $UserPassword" "INFO"
                            } catch {
                                Write-Log "Error generando contraseña, usando por defecto" "WARNING"
                            }
                        }
                        
                        $SecurePassword = ConvertTo-SecureString $UserPassword -AsPlainText -Force
                        
                        # Parámetros para crear el usuario
                        $UserParams = @{
                            SamAccountName = $SamAccountName
                            Name = "$($User.Nombre) $($User.Apellidos)"
                            DisplayName = "$($User.Nombre) $($User.Apellidos)"
                            GivenName = $User.Nombre
                            Surname = $User.Apellidos
                            UserPrincipalName = "$SamAccountName@justicia.junta-andalucia.es"
                            EmailAddress = $User.Email
                            OfficePhone = $User.Telefono
                            Office = $User.Oficina
                            Description = $User.Descripcion
                            AccountPassword = $SecurePassword
                            Enabled = $true
                            ChangePasswordAtLogon = $true
                            Server = $TargetDomain
                        }
                        
                        # Añadir UO si se encontró
                        if ($TargetOU) {
                            $UserParams.Path = $TargetOU
                        }
                        
                        Write-Log "Creando usuario con parámetros:" "INFO"
                        Write-Log "  SamAccountName: $SamAccountName" "INFO"
                        Write-Log "  UPN: $SamAccountName@justicia.junta-andalucia.es" "INFO"
                        Write-Log "  Dominio: $TargetDomain" "INFO"
                        Write-Log "  UO: $TargetOU" "INFO"
                        
                        # Crear el usuario
                        New-ADUser @UserParams
                        Write-Log "Usuario $SamAccountName creado exitosamente en $TargetDomain" "INFO"
                        
                        # Copiar grupos del usuario plantilla si existe
                        if ($TemplateUser -and $TemplateUser.MemberOf) {
                            Write-Log "Copiando grupos del usuario plantilla..." "INFO"
                            
                            foreach ($GroupDN in $TemplateUser.MemberOf) {
                                try {
                                    $Group = Get-ADGroup -Identity $GroupDN -Server $TargetDomain
                                    Add-ADGroupMember -Identity $Group -Members $SamAccountName -Server $TargetDomain
                                    Write-Log "Usuario añadido al grupo: $($Group.Name)" "INFO"
                                } catch {
                                    Write-Log "Error añadiendo usuario al grupo $GroupDN`: $($_.Exception.Message)" "WARNING"
                                }
                            }
                            
                            Write-Log "Copia de grupos completada" "INFO"
                        }
                        
                    } catch {
                        Write-Log "ERROR: Fallo creando usuario $SamAccountName`: $($_.Exception.Message)" "ERROR"
                        $ErrorCount++
                        continue
                    }
                }
                $ProcessedCount++
            }
            "TRASLADO" {
                Write-Log "Procesando traslado" "INFO"
                
                try {
                    # Buscar usuario existente por email o campo AD
                    $ExistingUser = Find-ExistingUserForTransfer -UserData $User
                    
                    if (-not $ExistingUser) {
                        Write-Log "ERROR: No se encontro usuario existente para traslado" "ERROR"
                        $ErrorCount++
                        continue
                    }
                    
                    Write-Log "Usuario encontrado: $($ExistingUser.DisplayName) en $($ExistingUser.SourceDomain)" "INFO"
                    
                    # Determinar dominio destino
                    $TargetDomain = Get-DomainFromOffice -Office $User.Oficina
                    Write-Log "Dominio destino: $TargetDomain" "INFO"
                    
                    # Buscar UO destino
                    $TargetOU = Find-OrganizationalUnit -Office $User.Oficina -Domain $TargetDomain
                    
                    # Buscar usuario plantilla en la UO destino
                    $TemplateUser = $null
                    if ($TargetOU) {
                        $TemplateUser = Find-TemplateUserInOU -Description $User.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain -Interactive:(-not $WhatIf)
                    }
                    
                    if ($WhatIf) {
                        Write-Log "SIMULACION: Trasladaria usuario de $($ExistingUser.SourceDomain) a $TargetDomain" "INFO"
                        Write-Log "SIMULACION: UO destino: $TargetOU" "INFO"
                        if ($TemplateUser) {
                            Write-Log "SIMULACION: Copiaria grupos de usuario plantilla: $($TemplateUser.SamAccountName)" "INFO"
                        }
                    } else {
                        # Realizar traslado real
                        $TransferResult = Move-UserToNewLocation -ExistingUser $ExistingUser -TargetDomain $TargetDomain -TargetOU $TargetOU -TemplateUser $TemplateUser -NewOffice $User.Oficina
                        
                        if ($TransferResult) {
                            Write-Log "Traslado completado exitosamente" "INFO"
                        } else {
                            Write-Log "ERROR: Fallo en el traslado" "ERROR"
                            $ErrorCount++
                            continue
                        }
                    }
                    
                    $ProcessedCount++
                    
                } catch {
                    Write-Log "Error en proceso de traslado: $($_.Exception.Message)" "ERROR"
                    $ErrorCount++
                }
            }
            "COMPAGINADA" {
                Write-Log "Procesando alta compaginada" "INFO"
                Write-Log "SIMULACION: Procesaria alta compaginada" "INFO"
                $ProcessedCount++
            }
            default {
                Write-Log "Tipo de alta no valido: $($User.TipoAlta)" "ERROR"
                $ErrorCount++
            }
        }
        
    } catch {
        Write-Log "Error procesando usuario $($User.Nombre) $($User.Apellidos): $($_.Exception.Message)" "ERROR"
        $ErrorCount++
    }
    
    # Mostrar progreso
    $TotalProcessed = $ProcessedCount + $ErrorCount
    if ($Users.Count -gt 0) {
        $PercentComplete = [math]::Round(($TotalProcessed / $Users.Count) * 100, 2)
        Write-Progress -Activity "Procesando usuarios" -Status "Procesado: $ProcessedCount, Errores: $ErrorCount" -PercentComplete $PercentComplete
    } else {
        Write-Progress -Activity "Procesando usuarios" -Status "Procesado: $ProcessedCount, Errores: $ErrorCount" -PercentComplete 0
    }
}

Write-Progress -Activity "Procesando usuarios" -Completed

# Resumen final
Write-Log "=== PROCESO COMPLETADO ===" "INFO"
Write-Log "Usuarios procesados exitosamente: $ProcessedCount" "INFO"
Write-Log "Usuarios con errores: $ErrorCount" "INFO"
Write-Log "Total procesados: $($ProcessedCount + $ErrorCount) de $($Users.Count)" "INFO"

if ($ErrorCount -eq 0) {
    Write-Log "Todos los usuarios se procesaron correctamente" "INFO"
} else {
    Write-Log "Se encontraron $ErrorCount errores durante el procesamiento" "WARNING"
}

Write-Log "Log guardado en: $LogFile" "INFO"
Write-Host "`nProceso completado. Revise el log para detalles: $LogFile" -ForegroundColor Green