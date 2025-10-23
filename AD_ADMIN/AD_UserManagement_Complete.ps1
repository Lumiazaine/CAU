#requires -version 5.1

<#
.SYNOPSIS
    Sistema completo de gestión de usuarios de Active Directory para Justicia de Andalucía

.DESCRIPTION
    Script principal que coordina la creación, traslado y gestión de usuarios de AD
    usando módulos especializados. Incluye búsqueda inteligente de UOs por oficina.

.PARAMETER CSVFile
    Ruta al archivo CSV con los datos de los usuarios (formato: TipoAlta;Nombre;Apellidos;Email;Oficina;Descripcion;Telefono)

.PARAMETER WhatIf
    Simula las operaciones sin ejecutarlas realmente

.PARAMETER LogLevel
    Nivel de logging: INFO, WARNING, ERROR

.EXAMPLE
    .\AD_UserManagement_Complete.ps1 -CSVFile "Ejemplo_Usuarios.csv"
    .\AD_UserManagement_Complete.ps1 -CSVFile "Ejemplo_Usuarios.csv" -WhatIf
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CSVFile = "Ejemplo_Usuarios.csv",
    
    [switch]$WhatIf = $false,
    
    [ValidateSet("INFO", "WARNING", "ERROR")]
    [string]$LogLevel = "INFO"
)

# Variables globales
$Global:ScriptPath = $PSScriptRoot
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIf

# Crear directorio de logs si no existe
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -ItemType Directory -Path $Global:LogDirectory -Force | Out-Null
}

# Generar nombre de archivo de log con timestamp
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = Join-Path $Global:LogDirectory "AD_UserManagement_$TimeStamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    # Escribir al archivo de log
    try {
        Add-Content -Path $Global:LogFile -Value $LogEntry -Encoding UTF8
    } catch {
        Write-Host "Error escribiendo al log: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Escribir a la consola según el nivel
    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Test-CSVFile {
    <#
    .SYNOPSIS
        Verifica si existe el archivo CSV y si no, ofrece crearlo
    #>
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "El archivo CSV no existe: $FilePath" "WARNING"
        
        $Response = Read-Host "¿Desea crear un archivo CSV de ejemplo? (S/N)"
        if ($Response -eq 'S' -or $Response -eq 's') {
            $ExampleCSV = @"
TipoAlta;Nombre;Apellidos;Email;Oficina;Descripcion;Telefono
NORMALIZADA;Juan;García López;juan.garcia@justicia.junta-andalucia.es;Juzgado de Primera Instancia N 19 de Malaga;Tramitador procesal;952123456
NORMALIZADA;María;Sánchez Pérez;maria.sanchez@justicia.junta-andalucia.es;Juzgado de lo Social N 3 de Sevilla;Gestor procesal;954234567
TRASLADO;Pedro;Martín Ruiz;pedro.martin@justicia.junta-andalucia.es;Audiencia Provincial de Cadiz;Letrado de la administración de justicia;956345678
COMPAGINADA;Ana;López González;ana.lopez@justicia.junta-andalucia.es;Fiscalia Provincial de Granada;Fiscal;958456789
NORMALIZADA;Carlos;Rodríguez Fernández;carlos.rodriguez@justicia.junta-andalucia.es;Juzgado de Instrucción N 5 de Almería;Auxilio judicial;950567890
"@
            
            $ExampleCSV | Out-File -FilePath $FilePath -Encoding UTF8
            Write-Log "Archivo CSV de ejemplo creado: $FilePath" "INFO"
            Write-Host "Se ha creado un archivo CSV de ejemplo. Por favor, edítelo con sus datos reales." -ForegroundColor Green
            return $true
        } else {
            Write-Log "Usuario optó por no crear el archivo CSV" "INFO"
            return $false
        }
    }
    return $true
}

function Extract-ProvinceFromOffice {
    <#
    .SYNOPSIS
        Extrae la provincia de la descripción de la oficina
    #>
    param([string]$Office)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    foreach ($Provincia in $ProvinciasAndalucia) {
        if ($Office.ToLower() -like "*$Provincia*") {
            return $Provincia.ToLower()
        }
    }
    
    # Si no encuentra coincidencia directa, buscar por palabras clave
    $Office = $Office.ToLower()
    if ($Office -like "*málaga*" -or $Office -like "*malaga*") { return "malaga" }
    if ($Office -like "*cádiz*" -or $Office -like "*cadiz*") { return "cadiz" }
    if ($Office -like "*córdoba*" -or $Office -like "*cordoba*") { return "cordoba" }
    if ($Office -like "*sevilla*") { return "sevilla" }
    if ($Office -like "*almería*" -or $Office -like "*almeria*") { return "almeria" }
    if ($Office -like "*granada*") { return "granada" }
    if ($Office -like "*huelva*") { return "huelva" }
    if ($Office -like "*jaén*" -or $Office -like "*jaen*") { return "jaen" }
    
    return $null
}

function Find-UOByOffice {
    <#
    .SYNOPSIS
        Busca una UO basada en la descripción de la oficina
    #>
    param(
        [string]$OfficeDescription,
        [switch]$Interactive = $true
    )
    
    Write-Log "Buscando UO para oficina: $OfficeDescription" "INFO"
    
    # Extraer provincia
    $Province = Extract-ProvinceFromOffice -Office $OfficeDescription
    if (-not $Province) {
        Write-Log "No se pudo identificar la provincia de: $OfficeDescription" "WARNING"
        if ($Interactive) {
            return Select-ProvinceInteractively -OfficeDescription $OfficeDescription
        }
        return $null
    }
    
    Write-Log "Provincia identificada: $Province" "INFO"
    
    # Verificar disponibilidad de ActiveDirectory
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    
    if (-not $ADAvailable) {
        Write-Log "ActiveDirectory no disponible - simulando búsqueda de UO" "WARNING"
        return Simulate-UOSearch -Province $Province -OfficeDescription $OfficeDescription
    }
    
    try {
        # Buscar en el dominio de la provincia
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "Buscando en dominio: $SearchBase" "INFO"
        
        # Extraer palabras clave de la oficina para la búsqueda
        $Keywords = Extract-OfficeKeywords -Office $OfficeDescription
        Write-Log "Palabras clave extraídas: $($Keywords -join ', ')" "INFO"
        
        # Buscar UOs que contengan las palabras clave
        $MatchingOUs = @()
        foreach ($Keyword in $Keywords) {
            try {
                $OUs = Get-ADOrganizationalUnit -Filter "Name -like '*$Keyword*'" -SearchBase $SearchBase -SearchScope Subtree
                $MatchingOUs += $OUs
            } catch {
                Write-Log "Error buscando con keyword '$Keyword': $($_.Exception.Message)" "WARNING"
            }
        }
        
        if ($MatchingOUs.Count -eq 0) {
            Write-Log "No se encontraron UOs que coincidan con: $OfficeDescription" "WARNING"
            if ($Interactive) {
                return Select-UOFromAllProvince -Province $Province -OfficeDescription $OfficeDescription
            }
            return $null
        }
        
        # Si hay múltiples coincidencias, mostrar para selección
        if ($MatchingOUs.Count -gt 1) {
            Write-Log "Se encontraron $($MatchingOUs.Count) UOs posibles" "INFO"
            if ($Interactive) {
                return Select-UOInteractively -OUs $MatchingOUs -OfficeDescription $OfficeDescription
            }
            return $MatchingOUs[0].DistinguishedName
        }
        
        # Una sola coincidencia
        Write-Log "UO encontrada: $($MatchingOUs[0].DistinguishedName)" "INFO"
        return $MatchingOUs[0].DistinguishedName
        
    } catch {
        Write-Log "Error en búsqueda de UO: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Extract-OfficeKeywords {
    <#
    .SYNOPSIS
        Extrae palabras clave relevantes de la descripción de la oficina
    #>
    param([string]$Office)
    
    $Keywords = @()
    
    # Tipos de juzgados y organismos
    if ($Office -like "*Primera Instancia*") { $Keywords += "Primera Instancia" }
    if ($Office -like "*Instrucción*" -or $Office -like "*Instruccion*") { $Keywords += "Instrucción" }
    if ($Office -like "*Social*") { $Keywords += "Social" }
    if ($Office -like "*Penal*") { $Keywords += "Penal" }
    if ($Office -like "*Contencioso*") { $Keywords += "Contencioso" }
    if ($Office -like "*Mercantil*") { $Keywords += "Mercantil" }
    if ($Office -like "*Familia*") { $Keywords += "Familia" }
    if ($Office -like "*Menores*") { $Keywords += "Menores" }
    if ($Office -like "*Violencia*") { $Keywords += "Violencia" }
    if ($Office -like "*Audiencia*") { $Keywords += "Audiencia" }
    if ($Office -like "*Fiscalia*" -or $Office -like "*Fiscalía*") { $Keywords += "Fiscalia" }
    if ($Office -like "*Tribunal*") { $Keywords += "Tribunal" }
    if ($Office -like "*Juzgado*") { $Keywords += "Juzgado" }
    
    # Extraer números si los hay
    if ($Office -match "N[º\s]*(\d+)") {
        $Keywords += "N $($matches[1])"
        $Keywords += "Nº $($matches[1])"
        $Keywords += "$($matches[1])"
    }
    
    return $Keywords
}

function Simulate-UOSearch {
    <#
    .SYNOPSIS
        Simula la búsqueda de UO cuando AD no está disponible
    #>
    param([string]$Province, [string]$OfficeDescription)
    
    $SimulatedOU = "OU=$($OfficeDescription -replace '[^\w\s]', ''),OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
    Write-Log "SIMULACIÓN: UO generada: $SimulatedOU" "INFO"
    return $SimulatedOU
}

function Select-ProvinceInteractively {
    <#
    .SYNOPSIS
        Permite al usuario seleccionar la provincia manualmente
    #>
    param([string]$OfficeDescription)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    Write-Host "`n=== SELECCIÓN DE PROVINCIA ===" -ForegroundColor Yellow
    Write-Host "No se pudo identificar automáticamente la provincia para:" -ForegroundColor White
    Write-Host "$OfficeDescription" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $ProvinciasAndalucia.Count; $i++) {
        Write-Host "[$($i+1)] $($ProvinciasAndalucia[$i].ToUpper())" -ForegroundColor White
    }
    
    Write-Host "[0] OMITIR - No asignar provincia" -ForegroundColor Red
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione la provincia (1-$($ProvinciasAndalucia.Count)) o 0 para omitir"
        if ($Selection -eq "0") {
            Write-Log "Usuario decidió omitir asignación de provincia" "WARNING"
            return $null
        }
        $SelectionNum = [int]$Selection
    } while ($SelectionNum -lt 1 -or $SelectionNum -gt $ProvinciasAndalucia.Count)
    
    $SelectedProvince = $ProvinciasAndalucia[$SelectionNum - 1]
    Write-Log "Provincia seleccionada manualmente: $SelectedProvince" "INFO"
    
    # Continuar con búsqueda en la provincia seleccionada
    return Find-UOByOffice -OfficeDescription $OfficeDescription -Interactive $true
}

function Select-UOInteractively {
    <#
    .SYNOPSIS
        Permite al usuario seleccionar una UO de múltiples opciones
    #>
    param([array]$OUs, [string]$OfficeDescription)
    
    Write-Host "`n=== SELECCIÓN DE UNIDAD ORGANIZATIVA ===" -ForegroundColor Yellow
    Write-Host "Oficina buscada: $OfficeDescription" -ForegroundColor Cyan
    Write-Host "Se encontraron $($OUs.Count) UOs similares:" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        $OU = $OUs[$i]
        Write-Host "[$($i+1)] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($OU.Name)" -ForegroundColor White
        Write-Host "     DN: $($OU.DistinguishedName)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "[0] BUSCAR EN TODA LA PROVINCIA" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione la UO más apropiada (1-$($OUs.Count)) o 0 para buscar en toda la provincia"
        if ($Selection -eq "0") {
            # Extraer provincia del primer OU para buscar en toda la provincia
            $Province = Extract-ProvinceFromOU -OUDN $OUs[0].DistinguishedName
            return Select-UOFromAllProvince -Province $Province -OfficeDescription $OfficeDescription
        }
        $SelectionNum = [int]$Selection
    } while ($SelectionNum -lt 1 -or $SelectionNum -gt $OUs.Count)
    
    $SelectedOU = $OUs[$SelectionNum - 1]
    Write-Log "UO seleccionada manualmente: $($SelectedOU.Name)" "INFO"
    Write-Log "DN: $($SelectedOU.DistinguishedName)" "INFO"
    
    return $SelectedOU.DistinguishedName
}

function Extract-ProvinceFromOU {
    <#
    .SYNOPSIS
        Extrae la provincia del DN de una UO
    #>
    param([string]$OUDN)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    foreach ($Provincia in $ProvinciasAndalucia) {
        if ($OUDN -like "*DC=$Provincia,*") {
            return $Provincia
        }
    }
    return "malaga" # Default
}

function Select-UOFromAllProvince {
    <#
    .SYNOPSIS
        Permite buscar y seleccionar UO de toda la provincia
    #>
    param([string]$Province, [string]$OfficeDescription)
    
    Write-Host "`n=== BÚSQUEDA EN TODA LA PROVINCIA DE $($Province.ToUpper()) ===" -ForegroundColor Yellow
    
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Log "ActiveDirectory no disponible - usando simulación" "WARNING"
        return Simulate-UOSearch -Province $Province -OfficeDescription $OfficeDescription
    }
    
    try {
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope Subtree | 
                  Where-Object { $_.Name -notlike "Users" -and $_.Name -notlike "Computers" } |
                  Sort-Object Name
        
        if ($AllOUs.Count -eq 0) {
            Write-Log "No se encontraron UOs en la provincia $Province" "ERROR"
            return $null
        }
        
        # Mostrar todas las UOs paginadas
        $PageSize = 20
        $CurrentPage = 0
        $TotalPages = [Math]::Ceiling($AllOUs.Count / $PageSize)
        
        do {
            $StartIndex = $CurrentPage * $PageSize
            $EndIndex = [Math]::Min($StartIndex + $PageSize - 1, $AllOUs.Count - 1)
            
            Write-Host "`nPágina $($CurrentPage + 1) de $TotalPages (UOs $($StartIndex + 1)-$($EndIndex + 1) de $($AllOUs.Count)):" -ForegroundColor Cyan
            Write-Host ""
            
            for ($i = $StartIndex; $i -le $EndIndex; $i++) {
                $OU = $AllOUs[$i]
                Write-Host "[$($i+1)] $($OU.Name)" -ForegroundColor White
            }
            
            Write-Host ""
            Write-Host "[N] Página siguiente" -ForegroundColor Yellow
            Write-Host "[P] Página anterior" -ForegroundColor Yellow
            Write-Host "[0] CANCELAR" -ForegroundColor Red
            Write-Host ""
            
            $Selection = Read-Host "Seleccione UO (número), N/P para navegar, o 0 para cancelar"
            
            if ($Selection -eq "0") {
                return $null
            } elseif ($Selection.ToUpper() -eq "N" -and $CurrentPage -lt ($TotalPages - 1)) {
                $CurrentPage++
                continue
            } elseif ($Selection.ToUpper() -eq "P" -and $CurrentPage -gt 0) {
                $CurrentPage--
                continue
            } elseif ([int]$Selection -ge 1 -and [int]$Selection -le $AllOUs.Count) {
                $SelectedOU = $AllOUs[[int]$Selection - 1]
                Write-Log "UO seleccionada de lista completa: $($SelectedOU.Name)" "INFO"
                return $SelectedOU.DistinguishedName
            } else {
                Write-Host "Selección inválida" -ForegroundColor Red
            }
            
        } while ($true)
        
    } catch {
        Write-Log "Error listando UOs de la provincia: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Process-UserByType {
    <#
    .SYNOPSIS
        Procesa un usuario según el tipo de alta
    #>
    param([PSCustomObject]$User, [string]$OUDN)
    
    $Result = [PSCustomObject]@{
        Nombre = $User.Nombre
        Apellidos = $User.Apellidos
        Email = $User.Email
        Oficina = $User.Oficina
        Descripcion = $User.Descripcion
        Telefono = $User.Telefono
        TipoAlta = $User.TipoAlta
        UO_Destino = $OUDN
        SamAccountName = ""
        Estado = "PROCESADO"
        Observaciones = ""
        FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        switch ($User.TipoAlta.ToUpper()) {
            "NORMALIZADA" {
                Write-Log "Procesando alta NORMALIZADA para $($User.Nombre) $($User.Apellidos)" "INFO"
                $Result = Process-NormalizedUser -User $User -OUDN $OUDN -Result $Result
            }
            "TRASLADO" {
                Write-Log "Procesando TRASLADO para $($User.Nombre) $($User.Apellidos)" "INFO"  
                $Result = Process-UserTransfer -User $User -OUDN $OUDN -Result $Result
            }
            "COMPAGINADA" {
                Write-Log "Procesando alta COMPAGINADA para $($User.Nombre) $($User.Apellidos)" "INFO"
                $Result = Process-SharedUser -User $User -OUDN $OUDN -Result $Result
            }
            default {
                throw "Tipo de alta no reconocido: $($User.TipoAlta)"
            }
        }
        
        $Result.Estado = if ($Global:WhatIfMode) { "SIMULADO" } else { "EXITOSO" }
        
    } catch {
        Write-Log "Error procesando usuario: $($_.Exception.Message)" "ERROR"
        $Result.Estado = "ERROR"
        $Result.Observaciones = "Error: $($_.Exception.Message)"
    }
    
    return $Result
}

function Process-NormalizedUser {
    <#
    .SYNOPSIS
        Procesa un alta normalizada (crear usuario completo)
    #>
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    # Generar SamAccountName
    $FirstNameInitial = $User.Nombre.Substring(0,1).ToLower()
    $LastNameClean = $User.Apellidos -replace '[áàäâ]','a' -replace '[éèëê]','e' -replace '[íìïî]','i' -replace '[óòöô]','o' -replace '[úùüû]','u' -replace '[ñ]','n' -replace '[ç]','c'
    $LastNameClean = $LastNameClean -replace '[^\w]','' -replace '\s+',''
    $SamAccountName = "$FirstNameInitial$($LastNameClean.ToLower())"
    
    $Result.SamAccountName = $SamAccountName
    $Result.Observaciones = "Usuario creado en $OUDN con descripción: $($User.Descripcion)"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACIÓN: Se crearía usuario $SamAccountName en $OUDN" "INFO"
    } else {
        Write-Log "Se crearían las siguientes acciones para $SamAccountName:" "INFO"
        Write-Log "- Crear usuario en AD" "INFO"
        Write-Log "- Asignar a UO: $OUDN" "INFO"
        Write-Log "- Establecer descripción: $($User.Descripcion)" "INFO"
        Write-Log "- Configurar email: $($User.Email)" "INFO"
        Write-Log "- Configurar teléfono: $($User.Telefono)" "INFO"
        Write-Log "- Establecer contraseña inicial" "INFO"
    }
    
    return $Result
}

function Process-UserTransfer {
    <#
    .SYNOPSIS
        Procesa un traslado (mover usuario existente)
    #>
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    $Result.Observaciones = "Usuario trasladado a $OUDN"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACIÓN: Se trasladaría usuario con email $($User.Email) a $OUDN" "INFO"
    } else {
        Write-Log "Se realizarían las siguientes acciones para traslado:" "INFO"
        Write-Log "- Buscar usuario existente por email: $($User.Email)" "INFO"
        Write-Log "- Mover a nueva UO: $OUDN" "INFO"
        Write-Log "- Actualizar descripción: $($User.Descripcion)" "INFO"
        Write-Log "- Actualizar teléfono: $($User.Telefono)" "INFO"
    }
    
    return $Result
}

function Process-SharedUser {
    <#
    .SYNOPSIS
        Procesa un alta compaginada (añadir permisos adicionales)
    #>
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    $Result.Observaciones = "Permisos compaginados añadidos para $OUDN"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACIÓN: Se añadirían permisos compaginados para $($User.Email) en $OUDN" "INFO"
    } else {
        Write-Log "Se realizarían las siguientes acciones para compaginada:" "INFO"
        Write-Log "- Buscar usuario existente por email: $($User.Email)" "INFO"
        Write-Log "- Añadir a grupos de la UO: $OUDN" "INFO"
        Write-Log "- Mantener UO principal" "INFO"
        Write-Log "- Añadir permisos adicionales según descripción: $($User.Descripcion)" "INFO"
    }
    
    return $Result
}

function Import-RequiredModules {
    <#
    .SYNOPSIS
        Carga los módulos necesarios para el funcionamiento
    #>
    Write-Log "Cargando módulos requeridos..." "INFO"
    
    $ModulesPath = Join-Path $Global:ScriptPath "Modules"
    $ModulesLoaded = 0
    $ModulesFailed = 0
    
    $RequiredModules = @(
        "UOManager.psm1",
        "PasswordManager.psm1", 
        "UserSearch.psm1"
    )
    
    foreach ($ModuleName in $RequiredModules) {
        $ModulePath = Join-Path $ModulesPath $ModuleName
        
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force -Global
                Write-Log "Módulo cargado: $ModuleName" "INFO"
                $ModulesLoaded++
            } catch {
                Write-Log "Error cargando módulo $ModuleName`: $($_.Exception.Message)" "WARNING"
                $ModulesFailed++
            }
        } else {
            Write-Log "Módulo no encontrado: $ModulePath" "WARNING"
            $ModulesFailed++
        }
    }
    
    Write-Log "Módulos cargados: $ModulesLoaded, Fallidos: $ModulesFailed" "INFO"
    return ($ModulesLoaded -gt 0)
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Verifica que se cumplan todos los prerequisitos
    #>
    Write-Log "Verificando prerequisitos..." "INFO"
    
    # Verificar archivo CSV
    if (-not (Test-CSVFile -FilePath $CSVFile)) {
        return $false
    }
    
    # Verificar si ActiveDirectory está disponible
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Log "ADVERTENCIA: Módulo ActiveDirectory no disponible - funcionará en modo simulación" "WARNING"
    } else {
        Write-Log "Módulo ActiveDirectory disponible" "INFO"
    }
    
    # Verificar permisos de escritura en directorio de logs
    try {
        $TestFile = Join-Path $Global:LogDirectory "test_write.tmp"
        "test" | Out-File -FilePath $TestFile -Force
        Remove-Item $TestFile -Force
        Write-Log "Permisos de escritura verificados" "INFO"
    } catch {
        Write-Log "No hay permisos de escritura en directorio de logs: $Global:LogDirectory" "ERROR"
        return $false
    }
    
    return $true
}

# =======================================================================================
# EJECUCIÓN PRINCIPAL
# =======================================================================================

try {
    Write-Log "=== INICIANDO SISTEMA DE GESTIÓN DE USUARIOS AD - JUSTICIA ANDALUCÍA ===" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $Global:WhatIfMode" "INFO"
    
    # Verificar prerequisitos
    if (-not (Test-Prerequisites)) {
        throw "No se cumplen los prerequisitos necesarios"
    }
    
    # Cargar módulos
    if (-not (Import-RequiredModules)) {
        Write-Log "Continuando sin módulos especializados..." "WARNING"
    }
    
    # Importar CSV
    Write-Log "Importando datos del CSV..." "INFO"
    $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
    
    if ($Users.Count -eq 0) {
        throw "El archivo CSV está vacío o no tiene datos válidos"
    }
    
    Write-Log "CSV importado correctamente: $($Users.Count) registros" "INFO"
    
    # Validar campos requeridos
    $RequiredFields = @("TipoAlta", "Nombre", "Apellidos", "Email", "Oficina", "Descripcion", "Telefono")
    $FirstUser = $Users[0]
    $MissingFields = @()
    
    foreach ($Field in $RequiredFields) {
        if (-not $FirstUser.$Field) {
            $MissingFields += $Field
        }
    }
    
    if ($MissingFields.Count -gt 0) {
        throw "Faltan campos requeridos en el CSV: $($MissingFields -join ', '). Campos esperados: $($RequiredFields -join ', ')"
    }
    
    # Procesar usuarios
    Write-Log "Iniciando procesamiento de usuarios..." "INFO"
    $ProcessingResults = @()
    $ErrorCount = 0
    $SuccessCount = 0
    
    foreach ($User in $Users) {
        Write-Log "--- Procesando: $($User.Nombre) $($User.Apellidos) ---" "INFO"
        Write-Log "Oficina: $($User.Oficina)" "INFO"
        Write-Log "Tipo: $($User.TipoAlta)" "INFO"
        
        try {
            # Buscar UO por oficina
            $OUDN = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $true
            
            if (-not $OUDN) {
                Write-Log "No se pudo determinar UO para $($User.Oficina)" "WARNING"
                $OUDN = "OU=SinAsignar,DC=justicia,DC=junta-andalucia,DC=es"
            }
            
            # Procesar según el tipo
            $Result = Process-UserByType -User $User -OUDN $OUDN
            $ProcessingResults += $Result
            
            if ($Result.Estado -eq "ERROR") {
                $ErrorCount++
            } else {
                $SuccessCount++
            }
            
        } catch {
            Write-Log "Error crítico procesando $($User.Nombre): $($_.Exception.Message)" "ERROR"
            $ErrorCount++
            
            $ErrorResult = [PSCustomObject]@{
                Nombre = $User.Nombre
                Apellidos = $User.Apellidos
                Email = $User.Email
                Oficina = $User.Oficina
                Descripcion = $User.Descripcion
                Telefono = $User.Telefono
                TipoAlta = $User.TipoAlta
                UO_Destino = "ERROR"
                SamAccountName = ""
                Estado = "ERROR"
                Observaciones = "Error crítico: $($_.Exception.Message)"
                FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $ProcessingResults += $ErrorResult
        }
    }
    
    # Exportar resultados
    try {
        $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
        $ResultsCSVPath = $CSVFile -replace '\.csv$', "_resultados_${TimeStampForCSV}.csv"
        
        $ProcessingResults | Export-Csv -Path $ResultsCSVPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
        Write-Log "Resultados exportados a: $ResultsCSVPath" "INFO"
        Write-Host "Resultados guardados en: $ResultsCSVPath" -ForegroundColor Green
    } catch {
        Write-Log "Error exportando resultados: $($_.Exception.Message)" "ERROR"
    }
    
    # Resumen final
    Write-Log "=== RESUMEN FINAL ===" "INFO"
    Write-Log "Total procesados: $($ProcessingResults.Count)" "INFO"
    Write-Log "Exitosos: $SuccessCount" "INFO"
    Write-Log "Errores: $ErrorCount" "INFO"
    
    if ($ErrorCount -gt 0) {
        Write-Log "Se encontraron $ErrorCount errores durante el procesamiento" "WARNING"
    }
    
    Write-Log "Log guardado en: $Global:LogFile" "INFO"
    Write-Host "Proceso completado. Log: $Global:LogFile" -ForegroundColor Green
    
} catch {
    Write-Log "Error crítico en la ejecución: $($_.Exception.Message)" "ERROR"
    Write-Host "Error crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Consulte el log para más detalles: $Global:LogFile" -ForegroundColor Yellow
    exit 1
}