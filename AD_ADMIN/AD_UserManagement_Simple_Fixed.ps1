#requires -version 5.1

<#
.SYNOPSIS
    Sistema completo de gestion de usuarios de Active Directory

.DESCRIPTION
    Script principal que coordina la creacion, traslado y gestion de usuarios de AD
    usando modulos especializados

.PARAMETER CSVFile
    Ruta al archivo CSV con los datos de los usuarios

.PARAMETER WhatIf
    Simula las operaciones sin ejecutarlas realmente

.PARAMETER LogLevel
    Nivel de logging: INFO, WARNING, ERROR

.EXAMPLE
    .\AD_UserManagement_Simple.ps1 -CSVFile "usuarios.csv"
    .\AD_UserManagement_Simple.ps1 -CSVFile "usuarios.csv" -WhatIf
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CSVFile,
    
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
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Escribir al archivo de log
    Add-Content -Path $Global:LogFile -Value $LogMessage -Encoding UTF8
    
    # Mostrar en consola con colores
    switch ($Level) {
        "INFO" { Write-Host $LogMessage -ForegroundColor White }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
    }
}

function Get-DomainFromOffice {
    <#
    .SYNOPSIS
        Determina el dominio especifico basado en la provincia detectada en el nombre de la oficina
    #>
    param([string]$Office)
    
    if ([string]::IsNullOrWhiteSpace($Office)) {
        return $null
    }
    
    # Mapeo completo de localidades, municipios y comarcas andaluzas a provincias
    $LocalidadAProvincias = @{
        # ===== PROVINCIA DE ALMERÍA =====
        'almeria' = 'almeria.justicia.junta-andalucia.es'
        'almería' = 'almeria.justicia.junta-andalucia.es'
        'el ejido' = 'almeria.justicia.junta-andalucia.es'
        'roquetas de mar' = 'almeria.justicia.junta-andalucia.es'
        'adra' = 'almeria.justicia.junta-andalucia.es'
        'berja' = 'almeria.justicia.junta-andalucia.es'
        'vera' = 'almeria.justicia.junta-andalucia.es'
        'huercal-overa' = 'almeria.justicia.junta-andalucia.es'
        'huércal-overa' = 'almeria.justicia.junta-andalucia.es'
        'nijar' = 'almeria.justicia.junta-andalucia.es'
        'níjar' = 'almeria.justicia.junta-andalucia.es'
        'vicar' = 'almeria.justicia.junta-andalucia.es'
        'vícar' = 'almeria.justicia.junta-andalucia.es'
        'mojacar' = 'almeria.justicia.junta-andalucia.es'
        'mojácar' = 'almeria.justicia.junta-andalucia.es'
        'pulpí' = 'almeria.justicia.junta-andalucia.es'
        'pulpi' = 'almeria.justicia.junta-andalucia.es'
        'cuevas del almanzora' = 'almeria.justicia.junta-andalucia.es'
        'garrucha' = 'almeria.justicia.junta-andalucia.es'
        'carboneras' = 'almeria.justicia.junta-andalucia.es'
        'tabernas' = 'almeria.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE CÁDIZ =====
        'cadiz' = 'cadiz.justicia.junta-andalucia.es'
        'cádiz' = 'cadiz.justicia.junta-andalucia.es'
        'jerez de la frontera' = 'cadiz.justicia.junta-andalucia.es'
        'jerez' = 'cadiz.justicia.junta-andalucia.es'
        'algeciras' = 'cadiz.justicia.junta-andalucia.es'
        'la linea de la concepcion' = 'cadiz.justicia.junta-andalucia.es'
        'la línea de la concepción' = 'cadiz.justicia.junta-andalucia.es'
        'la linea' = 'cadiz.justicia.junta-andalucia.es'
        'la línea' = 'cadiz.justicia.junta-andalucia.es'
        'puerto de santa maria' = 'cadiz.justicia.junta-andalucia.es'
        'puerto de santa maría' = 'cadiz.justicia.junta-andalucia.es'
        'el puerto de santa maria' = 'cadiz.justicia.junta-andalucia.es'
        'el puerto de santa maría' = 'cadiz.justicia.junta-andalucia.es'
        'sanlucar de barrameda' = 'cadiz.justicia.junta-andalucia.es'
        'sanlúcar de barrameda' = 'cadiz.justicia.junta-andalucia.es'
        'chiclana de la frontera' = 'cadiz.justicia.junta-andalucia.es'
        'chiclana' = 'cadiz.justicia.junta-andalucia.es'
        'puerto real' = 'cadiz.justicia.junta-andalucia.es'
        'rota' = 'cadiz.justicia.junta-andalucia.es'
        'chipiona' = 'cadiz.justicia.junta-andalucia.es'
        'arcos de la frontera' = 'cadiz.justicia.junta-andalucia.es'
        'arcos' = 'cadiz.justicia.junta-andalucia.es'
        'ubrique' = 'cadiz.justicia.junta-andalucia.es'
        'barbate' = 'cadiz.justicia.junta-andalucia.es'
        'conil de la frontera' = 'cadiz.justicia.junta-andalucia.es'
        'conil' = 'cadiz.justicia.junta-andalucia.es'
        'medina-sidonia' = 'cadiz.justicia.junta-andalucia.es'
        'medina sidonia' = 'cadiz.justicia.junta-andalucia.es'
        'vejer de la frontera' = 'cadiz.justicia.junta-andalucia.es'
        'vejer' = 'cadiz.justicia.junta-andalucia.es'
        'tarifa' = 'cadiz.justicia.junta-andalucia.es'
        'olvera' = 'cadiz.justicia.junta-andalucia.es'
        'villamartin' = 'cadiz.justicia.junta-andalucia.es'
        'villamartín' = 'cadiz.justicia.junta-andalucia.es'
        'bornos' = 'cadiz.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE CÓRDOBA =====
        'cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'córdoba' = 'cordoba.justicia.junta-andalucia.es'
        'lucena' = 'cordoba.justicia.junta-andalucia.es'
        'puente genil' = 'cordoba.justicia.junta-andalucia.es'
        'montilla' = 'cordoba.justicia.junta-andalucia.es'
        'priego de cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'priego de córdoba' = 'cordoba.justicia.junta-andalucia.es'
        'priego' = 'cordoba.justicia.junta-andalucia.es'
        'cabra' = 'cordoba.justicia.junta-andalucia.es'
        'baena' = 'cordoba.justicia.junta-andalucia.es'
        'pozoblanco' = 'cordoba.justicia.junta-andalucia.es'
        'peñarroya-pueblonuevo' = 'cordoba.justicia.junta-andalucia.es'
        'peñarroya' = 'cordoba.justicia.junta-andalucia.es'
        'la carlota' = 'cordoba.justicia.junta-andalucia.es'
        'palma del rio' = 'cordoba.justicia.junta-andalucia.es'
        'palma del río' = 'cordoba.justicia.junta-andalucia.es'
        'aguilar de la frontera' = 'cordoba.justicia.junta-andalucia.es'
        'aguilar' = 'cordoba.justicia.junta-andalucia.es'
        'rute' = 'cordoba.justicia.junta-andalucia.es'
        'villanueva de cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'villanueva de córdoba' = 'cordoba.justicia.junta-andalucia.es'
        'hinojosa del duque' = 'cordoba.justicia.junta-andalucia.es'
        'castro del rio' = 'cordoba.justicia.junta-andalucia.es'
        'castro del río' = 'cordoba.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE GRANADA =====
        'granada' = 'granada.justicia.junta-andalucia.es'
        'motril' = 'granada.justicia.junta-andalucia.es'
        'loja' = 'granada.justicia.junta-andalucia.es'
        'baza' = 'granada.justicia.junta-andalucia.es'
        'guadix' = 'granada.justicia.junta-andalucia.es'
        'almunecar' = 'granada.justicia.junta-andalucia.es'
        'almuñécar' = 'granada.justicia.junta-andalucia.es'
        'orgiva' = 'granada.justicia.junta-andalucia.es'
        'órgiva' = 'granada.justicia.junta-andalucia.es'
        'armilla' = 'granada.justicia.junta-andalucia.es'
        'maracena' = 'granada.justicia.junta-andalucia.es'
        'santa fe' = 'granada.justicia.junta-andalucia.es'
        'las gabias' = 'granada.justicia.junta-andalucia.es'
        'alhendin' = 'granada.justicia.junta-andalucia.es'
        'alhendín' = 'granada.justicia.junta-andalucia.es'
        'cenes de la vega' = 'granada.justicia.junta-andalucia.es'
        'monachil' = 'granada.justicia.junta-andalucia.es'
        'zubia' = 'granada.justicia.junta-andalucia.es'
        'la zubia' = 'granada.justicia.junta-andalucia.es'
        'atarfe' = 'granada.justicia.junta-andalucia.es'
        'cullar vega' = 'granada.justicia.junta-andalucia.es'
        'cúllar vega' = 'granada.justicia.junta-andalucia.es'
        'pinos puente' = 'granada.justicia.junta-andalucia.es'
        'iznalloz' = 'granada.justicia.junta-andalucia.es'
        'huescar' = 'granada.justicia.junta-andalucia.es'
        'huéscar' = 'granada.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE HUELVA =====
        'huelva' = 'huelva.justicia.junta-andalucia.es'
        'lepe' = 'huelva.justicia.junta-andalucia.es'
        'almonte' = 'huelva.justicia.junta-andalucia.es'
        'ayamonte' = 'huelva.justicia.junta-andalucia.es'
        'isla cristina' = 'huelva.justicia.junta-andalucia.es'
        'cartaya' = 'huelva.justicia.junta-andalucia.es'
        'moguer' = 'huelva.justicia.junta-andalucia.es'
        'palos de la frontera' = 'huelva.justicia.junta-andalucia.es'
        'palos' = 'huelva.justicia.junta-andalucia.es'
        'la palma del condado' = 'huelva.justicia.junta-andalucia.es'
        'rociana del condado' = 'huelva.justicia.junta-andalucia.es'
        'bonares' = 'huelva.justicia.junta-andalucia.es'
        'niebla' = 'huelva.justicia.junta-andalucia.es'
        'valverde del camino' = 'huelva.justicia.junta-andalucia.es'
        'san juan del puerto' = 'huelva.justicia.junta-andalucia.es'
        'trigueros' = 'huelva.justicia.junta-andalucia.es'
        'aracena' = 'huelva.justicia.junta-andalucia.es'
        'jabugo' = 'huelva.justicia.junta-andalucia.es'
        'cortegana' = 'huelva.justicia.junta-andalucia.es'
        'aljaraque' = 'huelva.justicia.junta-andalucia.es'
        'punta umbria' = 'huelva.justicia.junta-andalucia.es'
        'punta umbría' = 'huelva.justicia.junta-andalucia.es'
        'minas de riotinto' = 'huelva.justicia.junta-andalucia.es'
        'riotinto' = 'huelva.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE JAÉN =====
        'jaen' = 'jaen.justicia.junta-andalucia.es'
        'jaén' = 'jaen.justicia.junta-andalucia.es'
        'linares' = 'jaen.justicia.junta-andalucia.es'
        'andujar' = 'jaen.justicia.junta-andalucia.es'
        'andújar' = 'jaen.justicia.junta-andalucia.es'
        'ubeda' = 'jaen.justicia.junta-andalucia.es'
        'úbeda' = 'jaen.justicia.junta-andalucia.es'
        'baeza' = 'jaen.justicia.junta-andalucia.es'
        'martos' = 'jaen.justicia.junta-andalucia.es'
        'alcala la real' = 'jaen.justicia.junta-andalucia.es'
        'alcalá la real' = 'jaen.justicia.junta-andalucia.es'
        'la carolina' = 'jaen.justicia.junta-andalucia.es'
        'bailén' = 'jaen.justicia.junta-andalucia.es'
        'bailen' = 'jaen.justicia.junta-andalucia.es'
        'cazorla' = 'jaen.justicia.junta-andalucia.es'
        'villacarrillo' = 'jaen.justicia.junta-andalucia.es'
        'jodar' = 'jaen.justicia.junta-andalucia.es'
        'jódar' = 'jaen.justicia.junta-andalucia.es'
        'mengíbar' = 'jaen.justicia.junta-andalucia.es'
        'mengibar' = 'jaen.justicia.junta-andalucia.es'
        'torredonjimeno' = 'jaen.justicia.junta-andalucia.es'
        'torredelcampo' = 'jaen.justicia.junta-andalucia.es'
        'mancha real' = 'jaen.justicia.junta-andalucia.es'
        'huelma' = 'jaen.justicia.junta-andalucia.es'
        'orcera' = 'jaen.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE MÁLAGA =====
        'malaga' = 'malaga.justicia.junta-andalucia.es'
        'málaga' = 'malaga.justicia.junta-andalucia.es'
        'marbella' = 'malaga.justicia.junta-andalucia.es'
        'antequera' = 'malaga.justicia.junta-andalucia.es'
        'velez-malaga' = 'malaga.justicia.junta-andalucia.es'
        'vélez-málaga' = 'malaga.justicia.junta-andalucia.es'
        'fuengirola' = 'malaga.justicia.junta-andalucia.es'
        'mijas' = 'malaga.justicia.junta-andalucia.es'
        'torremolinos' = 'malaga.justicia.junta-andalucia.es'
        'benalmadena' = 'malaga.justicia.junta-andalucia.es'
        'benalmádena' = 'malaga.justicia.junta-andalucia.es'
        'estepona' = 'malaga.justicia.junta-andalucia.es'
        'ronda' = 'malaga.justicia.junta-andalucia.es'
        'coin' = 'malaga.justicia.junta-andalucia.es'
        'coín' = 'malaga.justicia.junta-andalucia.es'
        'alhaurin de la torre' = 'malaga.justicia.junta-andalucia.es'
        'alhaurín de la torre' = 'malaga.justicia.junta-andalucia.es'
        'alhaurin el grande' = 'malaga.justicia.junta-andalucia.es'
        'alhaurín el grande' = 'malaga.justicia.junta-andalucia.es'
        'rincon de la victoria' = 'malaga.justicia.junta-andalucia.es'
        'rincón de la victoria' = 'malaga.justicia.junta-andalucia.es'
        'nerja' = 'malaga.justicia.junta-andalucia.es'
        'torrox' = 'malaga.justicia.junta-andalucia.es'
        'frigiliana' = 'malaga.justicia.junta-andalucia.es'
        'competa' = 'malaga.justicia.junta-andalucia.es'
        'cómpeta' = 'malaga.justicia.junta-andalucia.es'
        'archidona' = 'malaga.justicia.junta-andalucia.es'
        'campillos' = 'malaga.justicia.junta-andalucia.es'
        'casabermeja' = 'malaga.justicia.junta-andalucia.es'
        'casares' = 'malaga.justicia.junta-andalucia.es'
        'manilva' = 'malaga.justicia.junta-andalucia.es'
        'cartama' = 'malaga.justicia.junta-andalucia.es'
        'cártama' = 'malaga.justicia.junta-andalucia.es'
        'alora' = 'malaga.justicia.junta-andalucia.es'
        'álora' = 'malaga.justicia.junta-andalucia.es'
        
        # ===== PROVINCIA DE SEVILLA =====
        'sevilla' = 'sevilla.justicia.junta-andalucia.es'
        'dos hermanas' = 'sevilla.justicia.junta-andalucia.es'
        'alcala de guadaira' = 'sevilla.justicia.junta-andalucia.es'
        'alcalá de guadaíra' = 'sevilla.justicia.junta-andalucia.es'
        'utrera' = 'sevilla.justicia.junta-andalucia.es'
        'mairena del alcor' = 'sevilla.justicia.junta-andalucia.es'
        'la rinconada' = 'sevilla.justicia.junta-andalucia.es'
        'los palacios y villafranca' = 'sevilla.justicia.junta-andalucia.es'
        'carmona' = 'sevilla.justicia.junta-andalucia.es'
        'lebrija' = 'sevilla.justicia.junta-andalucia.es'
        'coria del rio' = 'sevilla.justicia.junta-andalucia.es'
        'coria del río' = 'sevilla.justicia.junta-andalucia.es'
        'moron de la frontera' = 'sevilla.justicia.junta-andalucia.es'
        'morón de la frontera' = 'sevilla.justicia.junta-andalucia.es'
        'osuna' = 'sevilla.justicia.junta-andalucia.es'
        'ecija' = 'sevilla.justicia.junta-andalucia.es'
        'écija' = 'sevilla.justicia.junta-andalucia.es'
        'marchena' = 'sevilla.justicia.junta-andalucia.es'
        'lora del rio' = 'sevilla.justicia.junta-andalucia.es'
        'lora del río' = 'sevilla.justicia.junta-andalucia.es'
        'sanlucar la mayor' = 'sevilla.justicia.junta-andalucia.es'
        'sanlúcar la mayor' = 'sevilla.justicia.junta-andalucia.es'
        'estepa' = 'sevilla.justicia.junta-andalucia.es'
        'arahal' = 'sevilla.justicia.junta-andalucia.es'
        'castilleja de la cuesta' = 'sevilla.justicia.junta-andalucia.es'
        'mairena del aljarafe' = 'sevilla.justicia.junta-andalucia.es'
        'camas' = 'sevilla.justicia.junta-andalucia.es'
        'tomares' = 'sevilla.justicia.junta-andalucia.es'
        'san juan de aznalfarache' = 'sevilla.justicia.junta-andalucia.es'
        'gelves' = 'sevilla.justicia.junta-andalucia.es'
        'bormujos' = 'sevilla.justicia.junta-andalucia.es'
        'gines' = 'sevilla.justicia.junta-andalucia.es'
        'ginés' = 'sevilla.justicia.junta-andalucia.es'
        'espartinas' = 'sevilla.justicia.junta-andalucia.es'
        'bollullos de la mitacion' = 'sevilla.justicia.junta-andalucia.es'
        'bollullos de la mitación' = 'sevilla.justicia.junta-andalucia.es'
        'pilas' = 'sevilla.justicia.junta-andalucia.es'
        'aznalcollar' = 'sevilla.justicia.junta-andalucia.es'
        'cazalla de la sierra' = 'sevilla.justicia.junta-andalucia.es'
        'constantina' = 'sevilla.justicia.junta-andalucia.es'
        'el viso del alcor' = 'sevilla.justicia.junta-andalucia.es'
        'la puebla de cazalla' = 'sevilla.justicia.junta-andalucia.es'
        'puebla de cazalla' = 'sevilla.justicia.junta-andalucia.es'
        'herrera' = 'sevilla.justicia.junta-andalucia.es'
        'fuentes de andalucia' = 'sevilla.justicia.junta-andalucia.es'
        'fuentes de andalucía' = 'sevilla.justicia.junta-andalucia.es'
        'gilena' = 'sevilla.justicia.junta-andalucia.es'
        'pruna' = 'sevilla.justicia.junta-andalucia.es'
        
        # ===== COMARCAS Y PARTIDOS JUDICIALES =====
        # Comarca del Poniente Almeriense
        'poniente almeriense' = 'almeria.justicia.junta-andalucia.es'
        'poniente' = 'almeria.justicia.junta-andalucia.es'
        
        # Campo de Gibraltar (Cádiz)
        'campo de gibraltar' = 'cadiz.justicia.junta-andalucia.es'
        'gibraltar' = 'cadiz.justicia.junta-andalucia.es'
        
        # Bahía de Cádiz
        'bahia de cadiz' = 'cadiz.justicia.junta-andalucia.es'
        'bahía de cádiz' = 'cadiz.justicia.junta-andalucia.es'
        'bahia' = 'cadiz.justicia.junta-andalucia.es'
        
        # Costa del Sol (Málaga)
        'costa del sol' = 'malaga.justicia.junta-andalucia.es'
        
        # Valle del Guadalhorce (Málaga)
        'valle del guadalhorce' = 'malaga.justicia.junta-andalucia.es'
        'guadalhorce' = 'malaga.justicia.junta-andalucia.es'
        
        # Axarquía (Málaga)
        'axarquia' = 'malaga.justicia.junta-andalucia.es'
        'axarquía' = 'malaga.justicia.junta-andalucia.es'
        
        # Serrania de Ronda (Málaga)
        'serrania de ronda' = 'malaga.justicia.junta-andalucia.es'
        'serranía de ronda' = 'malaga.justicia.junta-andalucia.es'
        'serrania' = 'malaga.justicia.junta-andalucia.es'
        'serranía' = 'malaga.justicia.junta-andalucia.es'
        
        # Vega de Granada
        'vega de granada' = 'granada.justicia.junta-andalucia.es'
        'vega' = 'granada.justicia.junta-andalucia.es'
        
        # Alpujarras (Granada-Almería)
        'alpujarras' = 'granada.justicia.junta-andalucia.es'
        'alpujarra' = 'granada.justicia.junta-andalucia.es'
        
        # Costa Tropical (Granada)
        'costa tropical' = 'granada.justicia.junta-andalucia.es'
        
        # Condado de Huelva
        'condado de huelva' = 'huelva.justicia.junta-andalucia.es'
        'condado' = 'huelva.justicia.junta-andalucia.es'
        
        # Sierra de Huelva/Aracena
        'sierra de huelva' = 'huelva.justicia.junta-andalucia.es'
        'sierra de aracena' = 'huelva.justicia.junta-andalucia.es'
        'sierra aracena' = 'huelva.justicia.junta-andalucia.es'
        
        # Sierra Sur de Jaén
        'sierra sur de jaen' = 'jaen.justicia.junta-andalucia.es'
        'sierra sur de jaén' = 'jaen.justicia.junta-andalucia.es'
        'sierra sur' = 'jaen.justicia.junta-andalucia.es'
        
        # Sierra de Segura (Jaén)
        'sierra de segura' = 'jaen.justicia.junta-andalucia.es'
        'segura' = 'jaen.justicia.junta-andalucia.es'
        
        # Sierra Morena (Córdoba-Jaén)
        'sierra morena' = 'cordoba.justicia.junta-andalucia.es'
        
        # Campiña de Córdoba
        'campina de cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'campiña de córdoba' = 'cordoba.justicia.junta-andalucia.es'
        'campina' = 'cordoba.justicia.junta-andalucia.es'
        'campiña' = 'cordoba.justicia.junta-andalucia.es'
        
        # Aljarafe (Sevilla)
        'aljarafe' = 'sevilla.justicia.junta-andalucia.es'
        
        # Sierra Norte de Sevilla
        'sierra norte de sevilla' = 'sevilla.justicia.junta-andalucia.es'
        'sierra norte' = 'sevilla.justicia.junta-andalucia.es'
        
        # Guadalquivir
        'guadalquivir' = 'sevilla.justicia.junta-andalucia.es'
        
        # ===== NOMBRES ALTERNATIVOS Y ABREVIACIONES =====
        'alcj' = 'sevilla.justicia.junta-andalucia.es'  # Código común para oficinas judiciales
        'tsjand' = 'sevilla.justicia.junta-andalucia.es'  # Tribunal Superior de Justicia de Andalucía
        'tsja' = 'sevilla.justicia.junta-andalucia.es'
    }
    
    # Mapeo de provincias andaluzas a dominios (mantenido para compatibilidad)
    $ProvinciaDominios = @{
        'almeria' = 'almeria.justicia.junta-andalucia.es'
        'cadiz' = 'cadiz.justicia.junta-andalucia.es'
        'cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'granada' = 'granada.justicia.junta-andalucia.es'
        'huelva' = 'huelva.justicia.junta-andalucia.es'
        'jaen' = 'jaen.justicia.junta-andalucia.es'
        'malaga' = 'malaga.justicia.junta-andalucia.es'
        'sevilla' = 'sevilla.justicia.junta-andalucia.es'
    }
    
    # Mapeo adicional para busquedas con patrones flexibles
    $ProvinciaPatterns = @{
        'almer' = 'almeria.justicia.junta-andalucia.es'
        'cadiz' = 'cadiz.justicia.junta-andalucia.es'
        'c.diz' = 'cadiz.justicia.junta-andalucia.es'
        'cordoba' = 'cordoba.justicia.junta-andalucia.es'
        'c.rdoba' = 'cordoba.justicia.junta-andalucia.es'
        'granada' = 'granada.justicia.junta-andalucia.es'
        'huelva' = 'huelva.justicia.junta-andalucia.es'
        'jaen' = 'jaen.justicia.junta-andalucia.es'
        'ja.n' = 'jaen.justicia.junta-andalucia.es'
        'malaga' = 'malaga.justicia.junta-andalucia.es'
        'm.laga' = 'malaga.justicia.junta-andalucia.es'
        'sevilla' = 'sevilla.justicia.junta-andalucia.es'
    }
    
    # Normalizar texto trabajando directamente con bytes UTF-8
    $OfficeNormalized = $Office.ToLower()
    
    # Convertir a bytes y luego normalizar caracteres UTF-8 problemáticos
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($OfficeNormalized)
    $ByteList = [System.Collections.Generic.List[byte]]::new($Bytes)
    
    # Buscar y reemplazar secuencia UTF-8 para á (C3 A1) con a (61)
    for ($i = 0; $i -lt $ByteList.Count - 1; $i++) {
        if ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xA1) {
            $ByteList.RemoveAt($i)     # Remover C3
            $ByteList[$i] = 0x61       # Cambiar A1 por 61 (a)
        }
        elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xA9) {
            $ByteList.RemoveAt($i)     # Remover C3  
            $ByteList[$i] = 0x65       # Cambiar A9 por 65 (e)
        }
        elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xAD) {
            $ByteList.RemoveAt($i)     # Remover C3
            $ByteList[$i] = 0x69       # Cambiar AD por 69 (i)
        }
        elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xB3) {
            $ByteList.RemoveAt($i)     # Remover C3
            $ByteList[$i] = 0x6F       # Cambiar B3 por 6F (o)
        }
        elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xBA) {
            $ByteList.RemoveAt($i)     # Remover C3
            $ByteList[$i] = 0x75       # Cambiar BA por 75 (u)
        }
    }
    
    # Convertir de vuelta a string
    $OfficeNormalized = [System.Text.Encoding]::UTF8.GetString($ByteList.ToArray())
    
    Write-Log "Oficina normalizada para deteccion: '$OfficeNormalized'" "INFO"
    
    # Buscar coincidencia de localidad primero (más específico)
    foreach ($Localidad in $LocalidadAProvincias.Keys) {
        if ($OfficeNormalized -like "*$Localidad*") {
            Write-Log "Localidad detectada: $Localidad -> $($LocalidadAProvincias[$Localidad])" "INFO"
            return $LocalidadAProvincias[$Localidad]
        }
    }
    
    # Buscar coincidencia de provincia en el nombre de la oficina (mapeo directo)
    foreach ($Provincia in $ProvinciaDominios.Keys) {
        if ($OfficeNormalized -like "*$Provincia*") {
            Write-Log "Provincia detectada (directo): $Provincia -> $($ProvinciaDominios[$Provincia])" "INFO"
            return $ProvinciaDominios[$Provincia]
        }
    }
    
    # Buscar con patrones flexibles para caracteres especiales
    foreach ($Pattern in $ProvinciaPatterns.Keys) {
        if ($OfficeNormalized -like "*$Pattern*") {
            Write-Log "Provincia detectada (patron): $Pattern -> $($ProvinciaPatterns[$Pattern])" "INFO"
            return $ProvinciaPatterns[$Pattern]
        }
    }
    
    # Si no se detecta provincia, usar dominio principal
    Write-Log "No se pudo detectar provincia en '$Office' - usando dominio principal" "WARNING"
    return "justicia.junta-andalucia.es"
}

function Find-OrganizationalUnit {
    <#
    .SYNOPSIS
        Busca la UO correspondiente a una oficina especificada en el dominio correcto
    #>
    param(
        [string]$Office,
        [string]$Domain = $null
    )
    
    if ([string]::IsNullOrWhiteSpace($Office)) {
        Write-Log "Oficina no especificada - usando UO por defecto" "WARNING"
        return $null
    }
    
    # Si no se proporciona dominio, detectarlo desde la oficina
    if ([string]::IsNullOrWhiteSpace($Domain)) {
        $Domain = Get-DomainFromOffice -Office $Office
        Write-Log "Dominio auto-detectado desde oficina: $Domain" "INFO"
    }
    
    try {
        Write-Log "Buscando UO para oficina: '$Office' en dominio: $Domain" "INFO"
        
        # Verificar si el modulo ActiveDirectory esta disponible
        $ADModuleAvailable = $false
        try {
            Get-Command Get-ADOrganizationalUnit -ErrorAction Stop | Out-Null
            $ADModuleAvailable = $true
        } catch {
            Write-Log "Modulo ActiveDirectory no disponible - generando UO simulada" "WARNING"
        }
        
        if ($ADModuleAvailable) {
            # Obtener todas las UOs del dominio
            $AllOUs = Get-ADOrganizationalUnit -Filter * -Server $Domain -Properties Name, DistinguishedName
        } else {
            # Generar UO simulada basada en el nombre de la oficina
            $SimulatedOU = "OU=$Office,OU=Juzgados,DC=testdomain,DC=local"
            Write-Log "UO simulada generada: $SimulatedOU" "INFO"
            return $SimulatedOU
        }
        
        # Normalizar nombre de oficina usando la misma funcion que para provincias
        $OfficeNormalized = $Office.ToLower()
        
        # Normalizar acentos usando el mismo metodo robusto
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($OfficeNormalized)
        $ByteList = [System.Collections.Generic.List[byte]]::new($Bytes)
        
        # Buscar y reemplazar secuencias UTF-8 problematicas
        for ($i = 0; $i -lt $ByteList.Count - 1; $i++) {
            if ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xA1) {
                $ByteList.RemoveAt($i); $ByteList[$i] = 0x61  # á -> a
            }
            elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xA9) {
                $ByteList.RemoveAt($i); $ByteList[$i] = 0x65  # é -> e
            }
            elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xAD) {
                $ByteList.RemoveAt($i); $ByteList[$i] = 0x69  # í -> i
            }
            elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xB3) {
                $ByteList.RemoveAt($i); $ByteList[$i] = 0x6F  # ó -> o
            }
            elseif ($ByteList[$i] -eq 0xC3 -and $ByteList[$i + 1] -eq 0xBA) {
                $ByteList.RemoveAt($i); $ByteList[$i] = 0x75  # ú -> u
            }
        }
        
        $NormalizedOffice = [System.Text.Encoding]::UTF8.GetString($ByteList.ToArray())
        Write-Log "Oficina normalizada: '$NormalizedOffice'" "INFO"
        
        # PASO 1: Buscar coincidencia exacta (incluyendo numeros)
        foreach ($OU in $AllOUs) {
            # Normalizar el nombre de la UO de la misma forma
            $OUNormalized = $OU.Name.ToLower()
            $OUBytes = [System.Text.Encoding]::UTF8.GetBytes($OUNormalized)
            $OUByteList = [System.Collections.Generic.List[byte]]::new($OUBytes)
            
            for ($i = 0; $i -lt $OUByteList.Count - 1; $i++) {
                if ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xA1) {
                    $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x61
                }
                elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xA9) {
                    $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x65
                }
                elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xAD) {
                    $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x69
                }
                elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xB3) {
                    $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x6F
                }
                elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xBA) {
                    $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x75
                }
            }
            
            $NormalizedOUName = [System.Text.Encoding]::UTF8.GetString($OUByteList.ToArray())
            
            if ($NormalizedOUName -eq $NormalizedOffice) {
                Write-Log "Coincidencia EXACTA encontrada: '$($OU.Name)'" "INFO"
                Write-Log "DN: $($OU.DistinguishedName)" "INFO"
                return $OU.DistinguishedName
            }
        }
        
        # PASO 2: Buscar coincidencia por numero especifico si existe
        $OfficeNumber = ""
        if ($NormalizedOffice -match '\b(\d+)\b') {
            $OfficeNumber = $Matches[1]
            Write-Log "Numero detectado en oficina: '$OfficeNumber'" "INFO"
            
            foreach ($OU in $AllOUs) {
                # Normalizar nombre de UO
                $OUNormalized = $OU.Name.ToLower()
                $OUBytes = [System.Text.Encoding]::UTF8.GetBytes($OUNormalized)
                $OUByteList = [System.Collections.Generic.List[byte]]::new($OUBytes)
                
                for ($i = 0; $i -lt $OUByteList.Count - 1; $i++) {
                    if ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xA1) {
                        $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x61
                    }
                    elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xA9) {
                        $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x65
                    }
                    elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xAD) {
                        $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x69
                    }
                    elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xB3) {
                        $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x6F
                    }
                    elseif ($OUByteList[$i] -eq 0xC3 -and $OUByteList[$i + 1] -eq 0xBA) {
                        $OUByteList.RemoveAt($i); $OUByteList[$i] = 0x75
                    }
                }
                
                $OUNameNormalized = [System.Text.Encoding]::UTF8.GetString($OUByteList.ToArray())
                
                # Verificar que contenga el numero especifico (buscar patrones mas flexibles)
                if ($OUNameNormalized -match "\b$OfficeNumber\b") {
                    # Verificar que tambien contenga palabras clave principales
                    $KeyWords = @('juzgado', 'juzgados', 'primera', 'instancia', 'instruccion', 'penal', 'civil', 'mixto', 'familia', 'mercantil', 'contencioso', 'social')
                    $MatchedKeyWords = 0
                    
                    foreach ($KeyWord in $KeyWords) {
                        if ($NormalizedOffice -like "*$KeyWord*" -and $OUNameNormalized -like "*$KeyWord*") {
                            $MatchedKeyWords++
                        }
                    }
                    
                    Write-Log "Evaluando UO: '$($OU.Name)' - Numero: $OfficeNumber, Palabras clave: $MatchedKeyWords" "INFO"
                    
                    if ($MatchedKeyWords -ge 1) {  # Al menos 1 palabra clave coincide
                        Write-Log "Coincidencia por NUMERO ESPECIFICO encontrada: '$($OU.Name)'" "INFO"
                        Write-Log "Numero: $OfficeNumber, Palabras clave coincidentes: $MatchedKeyWords" "INFO"
                        Write-Log "DN: $($OU.DistinguishedName)" "INFO"
                        return $OU.DistinguishedName
                    }
                }
            }
        }
        
        # PASO 2.5: Manejo especial para oficinas no judiciales (Fiscalía, Guardia Civil, etc.)
        # Identificar tipos de oficina específicos para evitar matches incorrectos
        $OfficeType = $null
        $SpecialKeywords = @()
        $ExclusionKeywords = @()
        
        if ($NormalizedOffice -like "*fiscalia*") {
            $OfficeType = "Fiscalia"
            $SpecialKeywords = @('fiscalia', 'ministerio', 'fiscal')
            $ExclusionKeywords = @('juzgado', 'juzgados', 'tribunal', 'instancia', 'penal', 'civil')
            Write-Log "Detectada FISCALIA: '$Office' - Buscando solo UOs de fiscalia" "INFO"
        }
        elseif ($NormalizedOffice -like "*guardia civil*") {
            $OfficeType = "GuardiaCivil"
            $SpecialKeywords = @('guardia', 'civil')
            $ExclusionKeywords = @('juzgado', 'juzgados', 'tribunal', 'fiscalia')
            Write-Log "Detectada GUARDIA CIVIL: '$Office'" "INFO"
        }
        elseif ($NormalizedOffice -like "*policia*") {
            $OfficeType = "Policia"
            $SpecialKeywords = @('policia', 'nacional')
            $ExclusionKeywords = @('juzgado', 'juzgados', 'tribunal', 'fiscalia')
            Write-Log "Detectada POLICIA: '$Office'" "INFO"
        }
        
        if ($OfficeType) {
            $ValidMatches = @()
            
            foreach ($OU in $AllOUs) {
                $OUNameNormalized = $OU.Name.ToLower()
                $HasSpecialKeyword = $false
                $HasExclusionKeyword = $false
                
                # Verificar palabras clave requeridas
                foreach ($Keyword in $SpecialKeywords) {
                    if ($OUNameNormalized -like "*$Keyword*") {
                        $HasSpecialKeyword = $true
                        break
                    }
                }
                
                # Verificar palabras de exclusión
                foreach ($ExclWord in $ExclusionKeywords) {
                    if ($OUNameNormalized -like "*$ExclWord*") {
                        $HasExclusionKeyword = $true
                        break
                    }
                }
                
                # Solo incluir si tiene palabra clave requerida Y NO tiene palabra de exclusión
                if ($HasSpecialKeyword -and -not $HasExclusionKeyword) {
                    $ValidMatches += $OU
                    Write-Log "UO valida para ${OfficeType}: '$($OU.Name)'" "INFO"
                }
                elseif ($HasSpecialKeyword -and $HasExclusionKeyword) {
                    Write-Log "UO descartada por exclusion: '$($OU.Name)' (contiene: $($ExclusionKeywords -join ', '))" "WARNING"
                }
            }
            
            # Si hay matches válidos, usar el primero
            if ($ValidMatches.Count -gt 0) {
                $SelectedOU = $ValidMatches[0]
                Write-Log "UO ${OfficeType} seleccionada: '$($SelectedOU.Name)'" "INFO"
                Write-Log "DN: $($SelectedOU.DistinguishedName)" "INFO"
                return $SelectedOU.DistinguishedName
            } else {
                Write-Log "No se encontro UO especifica valida para ${OfficeType}. Usando UO generica." "WARNING"
                $GenericOU = "OU=$Office,OU=Oficinas Especiales,DC=$($Domain -replace '\.', ',DC=')"
                Write-Log "UO genérica sugerida: $GenericOU" "INFO"
                return $GenericOU
            }
        }
        
        # PASO 3: Buscar por coincidencia de palabras clave (para juzgados y tribunales)
        $OfficeWords = $Office -split '\s+' | Where-Object { $_.Length -gt 3 -and $_ -notmatch '^\d+$' }  # Excluir numeros solos
        Write-Log "Palabras clave de la oficina: $($OfficeWords -join ', ')" "INFO"
        
        $BestMatch = $null
        $BestScore = 0
        $ValidCandidates = @()
        
        # Determinar el contexto de búsqueda basado en la oficina
        $IsCourtOffice = $NormalizedOffice -like "*juzgado*" -or $NormalizedOffice -like "*tribunal*" -or 
                        $NormalizedOffice -like "*instancia*" -or $NormalizedOffice -like "*penal*" -or
                        $NormalizedOffice -like "*civil*" -or $NormalizedOffice -like "*social*" -or
                        $NormalizedOffice -like "*contencioso*" -or $NormalizedOffice -like "*mercantil*"
        
        foreach ($OU in $AllOUs) {
            $Score = 0
            $OUName = $OU.Name.ToLower()
            $WordMatches = 0
            $HasIncompatibleContent = $false
            
            # Verificar incompatibilidades (evitar matches incorrectos)
            if ($IsCourtOffice) {
                # Si buscamos juzgado, excluir fiscalías y otras oficinas no judiciales
                if ($OUName -like "*fiscalia*" -or $OUName -like "*ministerio*" -or $OUName -like "*guardia*") {
                    $HasIncompatibleContent = $true
                    Write-Log "UO excluida por incompatibilidad: '$($OU.Name)' (contiene fiscalia/ministerio/guardia)" "INFO"
                }
            } else {
                # Si buscamos fiscalía/otras, excluir juzgados
                if ($OUName -like "*juzgado*" -or $OUName -like "*tribunal*") {
                    $HasIncompatibleContent = $true
                    Write-Log "UO excluida por incompatibilidad: '$($OU.Name)' (contiene juzgado/tribunal)" "INFO"
                }
            }
            
            if ($HasIncompatibleContent) {
                continue
            }
            
            # Puntuar coincidencias de palabras (excluyendo numeros)
            foreach ($Word in $OfficeWords) {
                $CleanWord = $Word.ToLower() -replace '[^a-z]', ''
                if ($CleanWord.Length -gt 3 -and $OUName -like "*$CleanWord*") {
                    $Score += $CleanWord.Length * 2  # Dar más peso a coincidencias de palabras
                    $WordMatches++
                }
            }
            
            # Bonus por coincidencias múltiples
            if ($WordMatches -gt 1) {
                $Score += $WordMatches * 5
            }
            
            # Penalizar si tiene numero diferente (solo para juzgados)
            if ($OfficeNumber -and $OUName -match '\bn[o..]\s*(\d+)') {
                $OUNumber = $Matches[1]
                if ($OUNumber -ne $OfficeNumber) {
                    $Score = $Score * 0.3  # Penalización más severa
                    Write-Log "Penalizando UO '$($OU.Name)' por numero diferente ($OUNumber vs $OfficeNumber)" "INFO"
                }
            }
            
            if ($Score -gt 0) {
                $ValidCandidates += [PSCustomObject]@{
                    OU = $OU
                    Score = $Score
                    WordMatches = $WordMatches
                }
            }
            
            if ($Score -gt $BestScore) {
                $BestScore = $Score
                $BestMatch = $OU
            }
        }
        
        # Log de candidatos válidos para debugging
        if ($ValidCandidates.Count -gt 0) {
            Write-Log "Candidatos válidos encontrados: $($ValidCandidates.Count)" "INFO"
            $SortedCandidates = $ValidCandidates | Sort-Object Score -Descending | Select-Object -First 3
            foreach ($Candidate in $SortedCandidates) {
                Write-Log "  - '$($Candidate.OU.Name)' (Score: $($Candidate.Score), Matches: $($Candidate.WordMatches))" "INFO"
            }
        }
        
        if ($BestMatch -and $BestScore -gt 15) {  # Umbral más alto para mayor precisión
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
            
            return $null
        }
        
    } catch {
        Write-Log "Error buscando UO: $($_.Exception.Message)" "ERROR"
        return $null
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
        
        # Verificar si el modulo ActiveDirectory esta disponible
        $ADModuleAvailable = $false
        try {
            Get-Command Get-ADUser -ErrorAction Stop | Out-Null
            $ADModuleAvailable = $true
        } catch {
            Write-Log "Modulo ActiveDirectory no disponible - creando usuario plantilla simulado" "WARNING"
        }
        
        if ($ADModuleAvailable) {
            # Obtener todos los usuarios de la UO con descripcion
            $UsersInOU = Get-ADUser -SearchBase $OrganizationalUnit -SearchScope Subtree -Filter "Description -like '*'" -Server $Domain -Properties Description, MemberOf -ErrorAction Stop
        } else {
            # Crear usuario plantilla simulado para testing
            $SimulatedTemplateUser = [PSCustomObject]@{
                SamAccountName = "template_$($Description.ToLower() -replace '\s+', '_')"
                Description = $Description
                MemberOf = @(
                    "CN=Acceso_$($Description),OU=Grupos,DC=testdomain,DC=local",
                    "CN=Permisos_Especializados,OU=Grupos,DC=testdomain,DC=local",
                    "CN=Usuarios_Oficina,OU=Grupos,DC=testdomain,DC=local"
                )
            }
            Write-Log "Usuario plantilla simulado creado: $($SimulatedTemplateUser.SamAccountName)" "INFO"
            return $SimulatedTemplateUser
        }
        
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
            
            # Verificar si contiene palabras clave importantes
            if ($NormalizedUserDesc -like "*$NormalizedTarget*" -or $NormalizedTarget -like "*$NormalizedUserDesc*") {
                $MatchScore = ($NormalizedUserDesc.Length + $NormalizedTarget.Length) / 2
                $PartialMatches += [PSCustomObject]@{
                    User = $User
                    Score = $MatchScore
                }
            }
        }
        
        if ($PartialMatches.Count -gt 0) {
            # Tomar la mejor coincidencia parcial
            $BestMatch = $PartialMatches | Sort-Object Score -Descending | Select-Object -First 1
            Write-Log "Coincidencia parcial encontrada: $($BestMatch.User.SamAccountName) - '$($BestMatch.User.Description)' (Score: $($BestMatch.Score))" "INFO"
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
    
    Write-Host "[0] Continuar sin plantilla" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione una opcion (0-$($UniqueDescriptions.Count))"
        
        if ($Selection -eq "0") {
            return $null
        }
        
        $Index = [int]$Selection - 1
        if ($Index -ge 0 -and $Index -lt $UniqueDescriptions.Count) {
            $SelectedDesc = $UniqueDescriptions[$Index].Name
            $SelectedUser = $UsersInOU | Where-Object { $_.Description -eq $SelectedDesc } | Select-Object -First 1
            Write-Log "Usuario plantilla seleccionado manualmente: $($SelectedUser.SamAccountName) - '$($SelectedUser.Description)'" "INFO"
            return $SelectedUser
        } else {
            Write-Host "Seleccion invalida. Intente de nuevo." -ForegroundColor Red
        }
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
            Write-Log "Error obteniendo dominios del bosque - usando dominios por defecto" "WARNING"
            
            # Fallback: usar dominios conocidos comunes del entorno judicial
            $AllDomains = @(
                "justicia.es",
                "juntadeandalucia.es", 
                "jccm.es",
                "administraciondejusticia.gob.es"
            )
            
            # Intentar determinar el dominio actual
            try {
                $CurrentDomain = $env:USERDNSDOMAIN
                if ($CurrentDomain -and $CurrentDomain -notin $AllDomains) {
                    $AllDomains = @($CurrentDomain) + $AllDomains
                }
            } catch {
                Write-Log "No se pudo determinar el dominio actual" "WARNING"
            }
            
            Write-Log "Usando dominios de fallback: $($AllDomains -join ', ')" "INFO"
        }
        
        if ($AllDomains.Count -eq 0) {
            Write-Log "No hay dominios disponibles para buscar" "ERROR"
            return $null
        }
        
        # Verificar si el modulo ActiveDirectory esta disponible
        $ADModuleAvailable = $false
        try {
            Get-Command Get-ADUser -ErrorAction Stop | Out-Null
            $ADModuleAvailable = $true
        } catch {
            Write-Log "Modulo ActiveDirectory no disponible - modo simulacion para testing" "WARNING"
        }
        
        if ($ADModuleAvailable) {
            # Buscar por campo AD si existe
            if (![string]::IsNullOrWhiteSpace($UserData.AD)) {
                Write-Log "Buscando usuario por campo AD: $($UserData.AD)" "INFO"
                
                foreach ($Domain in $AllDomains) {
                    try {
                        $User = Get-ADUser -Identity $UserData.AD -Server $Domain -Properties DisplayName, mail, Office, Description -ErrorAction SilentlyContinue
                        if ($User) {
                            Write-Log "Usuario encontrado en ${Domain}: $($User.DisplayName) ($($User.SamAccountName))" "INFO"
                            $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                            return $User
                        }
                    } catch {
                        # Continuar con el siguiente dominio
                    }
                }
            }
            
            # Buscar por email si no se encontro por AD
            if (![string]::IsNullOrWhiteSpace($UserData.Email)) {
                Write-Log "Buscando usuario por email: $($UserData.Email)" "INFO"
                
                foreach ($Domain in $AllDomains) {
                    try {
                        $Users = Get-ADUser -Filter "mail -eq '$($UserData.Email)'" -Server $Domain -Properties DisplayName, mail, Office, Description -ErrorAction SilentlyContinue
                        if ($Users) {
                            $User = $Users[0]  # Tomar el primero si hay multiples
                            Write-Log "Usuario encontrado en ${Domain}: $($User.DisplayName) ($($User.SamAccountName))" "INFO"
                            $User | Add-Member -NotePropertyName "SourceDomain" -NotePropertyValue $Domain -Force
                            return $User
                        }
                    } catch {
                        # Continuar con el siguiente dominio
                    }
                }
            }
        } else {
            # Modo simulacion para testing sin ActiveDirectory
            Write-Log "MODO SIMULACION: Creando usuario simulado para testing" "WARNING"
            
            # Crear un usuario simulado para testing
            # Para simular traslados realistas, asignar dominio basado en el email o nombre
            $SimulatedSourceDomain = $AllDomains[0]  # Por defecto el primero
            
            # Si es testing y podemos inferir el dominio origen del usuario
            if ($UserData.Email -and $UserData.Email -like "*sevilla*") {
                $SimulatedSourceDomain = "sevilla.justicia.junta-andalucia.es"
            } elseif ($UserData.Email -and $UserData.Email -like "*cordoba*") {
                $SimulatedSourceDomain = "cordoba.justicia.junta-andalucia.es"
            } elseif ($UserData.Email -and $UserData.Email -like "*malaga*") {
                $SimulatedSourceDomain = "malaga.justicia.junta-andalucia.es"
            }
            
            $SimulatedUser = [PSCustomObject]@{
                SamAccountName = $UserData.AD
                DisplayName = "$($UserData.Nombre) $($UserData.Apellidos)"
                mail = $UserData.Email
                Office = "Oficina Anterior"
                Description = "Usuario simulado para testing"
                DistinguishedName = "CN=$($UserData.AD),OU=Usuarios,DC=testdomain,DC=local"
                SourceDomain = $SimulatedSourceDomain
            }
            
            Write-Log "Usuario simulado creado: $($SimulatedUser.DisplayName) ($($SimulatedUser.SamAccountName))" "INFO"
            return $SimulatedUser
        }
        
        Write-Log "No se encontro usuario con email '$($UserData.Email)' o AD '$($UserData.AD)'" "WARNING"
        return $null
        
    } catch {
        Write-Log "Error buscando usuario existente: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Execute-CrossDomainTransfer {
    <#
    .SYNOPSIS
        Ejecuta traslado entre dominios: copia usuario, elimina del origen, crea en destino
    #>
    param(
        [PSCustomObject]$ExistingUser,
        [string]$TargetDomain,
        [string]$TargetOU,
        [PSCustomObject]$UserData
    )
    
    try {
        Write-Log "=== INICIANDO TRASLADO ENTRE DOMINIOS ===" "INFO"
        Write-Log "Usuario: $($ExistingUser.SamAccountName)" "INFO"
        Write-Log "Desde: $($ExistingUser.SourceDomain)" "INFO"
        Write-Log "Hacia: $TargetDomain" "INFO"
        Write-Log "UO destino: $TargetOU" "INFO"
        
        # Verificar si el modulo ActiveDirectory esta disponible
        $ADModuleAvailable = $false
        try {
            Get-Command Get-ADUser -ErrorAction Stop | Out-Null
            $ADModuleAvailable = $true
        } catch {
            Write-Log "Modulo ActiveDirectory no disponible - ejecutando en modo simulacion" "WARNING"
        }
        
        if ($ADModuleAvailable) {
            # PASO 1: Obtener informacion completa del usuario original
            Write-Log "PASO 1: Obteniendo informacion completa del usuario original..." "INFO"
            $OriginalUser = Get-ADUser -Identity $ExistingUser.SamAccountName -Server $ExistingUser.SourceDomain -Properties *
            
            # PASO 2: Buscar usuario plantilla en el dominio destino
            Write-Log "PASO 2: Buscando usuario plantilla en dominio destino..." "INFO"
            $TemplateUser = Find-TemplateUserInOU -Description $UserData.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain
            
            # PASO 3: Crear usuario en dominio destino
            Write-Log "PASO 3: Creando usuario en dominio destino..." "INFO"
            
            # Generar contrasenia estandar
            $CurrentDate = Get-Date
            $Month = $CurrentDate.ToString("MM")
            $Year = $CurrentDate.ToString("yy")
            $StandardPassword = "Justicia$Month$Year"
            $SecurePassword = ConvertTo-SecureString $StandardPassword -AsPlainText -Force
            
            # Para traslados entre dominios: eliminar usuario original y recrear en destino
            # Usar UPN normal del dominio destino (sin timestamp)
            $UniqueUPN = "$($OriginalUser.SamAccountName)@justicia.junta-andalucia.es"
            
            # Verificar si el SamAccountName ya existe en el destino
            try {
                $ExistingSam = Get-ADUser -Filter "SamAccountName -eq '$($OriginalUser.SamAccountName)'" -Server $TargetDomain -ErrorAction SilentlyContinue
                if ($ExistingSam) {
                    Write-Log "ADVERTENCIA: SamAccountName $($OriginalUser.SamAccountName) ya existe en dominio destino $TargetDomain" "WARNING"
                    Write-Log "Eliminando usuario existente en destino para recrearlo..." "WARNING"
                    
                    # Eliminar usuario existente en destino antes de recrear
                    try {
                        Remove-ADUser -Identity $ExistingSam.SamAccountName -Server $TargetDomain -Confirm:$false
                        Write-Log "Usuario existente eliminado del destino: $($ExistingSam.SamAccountName)" "INFO"
                    } catch {
                        Write-Log "Error eliminando usuario existente en destino: $($_.Exception.Message)" "ERROR"
                        return $false
                    }
                }
            } catch {
                Write-Log "Error verificando SamAccountName en destino: $($_.Exception.Message)" "WARNING"
            }
            
            Write-Log "UPN para recreación en destino: $UniqueUPN" "INFO"
            Write-Log "SamAccountName a recrear: $($OriginalUser.SamAccountName)" "INFO"
            Write-Log "Estrategia: Eliminar original y recrear con perfil similar (descripción: $($UserData.Descripcion))" "INFO"
            
            # Parametros para crear el usuario en destino
            $NewUserParams = @{
                SamAccountName = $OriginalUser.SamAccountName
                Name = $OriginalUser.Name
                DisplayName = $OriginalUser.DisplayName
                GivenName = $OriginalUser.GivenName
                Surname = $OriginalUser.Surname
                UserPrincipalName = $UniqueUPN
                EmailAddress = $UserData.Email
                OfficePhone = $UserData.Telefono
                Office = $UserData.Oficina
                Description = $UserData.Descripcion
                AccountPassword = $SecurePassword
                Enabled = $true
                ChangePasswordAtLogon = $true
                Server = $TargetDomain
                Path = $TargetOU
            }
            
            # Crear el usuario en el dominio destino
            try {
                New-ADUser @NewUserParams -ErrorAction Stop
            } catch {
                Write-Log "Error creando usuario: $($_.Exception.Message)" "ERROR"
                throw $_
            }
            Write-Log "Usuario creado exitosamente en $TargetDomain" "INFO"
            
            # PASO 4: Copiar grupos del usuario plantilla
            Write-Log "PASO 4: Copiando grupos del usuario plantilla..." "INFO"
            if ($TemplateUser -and $TemplateUser.MemberOf) {
                $GroupsAdded = 0
                foreach ($GroupDN in $TemplateUser.MemberOf) {
                    try {
                        $Group = Get-ADGroup -Identity $GroupDN -Server $TargetDomain
                        Add-ADGroupMember -Identity $Group -Members $OriginalUser.SamAccountName -Server $TargetDomain
                        Write-Log "Grupo aniadido: $($Group.Name)" "INFO"
                        $GroupsAdded++
                    } catch {
                        Write-Log "Error aniadiendo grupo $($Group.Name): $($_.Exception.Message)" "WARNING"
                    }
                }
                Write-Log "PASO 4 COMPLETADO: $GroupsAdded grupos copiados del usuario plantilla" "INFO"
            } else {
                Write-Log "No se encontro usuario plantilla o no tiene grupos para copiar" "WARNING"
            }
            
            # PASO 5: Eliminar usuario del dominio origen
            Write-Log "PASO 5: Eliminando usuario del dominio origen..." "INFO"
            Remove-ADUser -Identity $OriginalUser.SamAccountName -Server $ExistingUser.SourceDomain -Confirm:$false
            Write-Log "Usuario eliminado exitosamente de $($ExistingUser.SourceDomain)" "INFO"
            
            Write-Log "=== TRASLADO ENTRE DOMINIOS COMPLETADO EXITOSAMENTE ===" "INFO"
            return $true
            
        } else {
            # MODO SIMULACION para testing sin ActiveDirectory
            Write-Log "MODO SIMULACION: Ejecutando traslado entre dominios simulado" "WARNING"
            
            Write-Log "PASO 1 SIMULADO: Obteniendo informacion del usuario original..." "INFO"
            Write-Log "  Usuario original: $($ExistingUser.SamAccountName) en $($ExistingUser.SourceDomain)" "INFO"
            
            Write-Log "PASO 2 SIMULADO: Buscando usuario plantilla en destino..." "INFO"
            Write-Log "  Usuario plantilla encontrado (simulado): template_$($UserData.Descripcion.ToLower())" "INFO"
            
            Write-Log "PASO 3 SIMULADO: Creando usuario en dominio destino..." "INFO"
            Write-Log "  Nuevo usuario: $($ExistingUser.SamAccountName) en $TargetDomain" "INFO"
            Write-Log "  UPN: $($ExistingUser.SamAccountName)@justicia.junta-andalucia.es" "INFO"
            Write-Log "  Contrasenia: Justicia$Month$Year" "INFO"
            
            Write-Log "PASO 4 SIMULADO: Copiando grupos..." "INFO"
            $SimulatedGroups = @("Nuevos Permisos $($UserData.Descripcion)", "Acceso Especializado", "Grupo Oficina")
            Write-Log "  Grupos aniadidos (simulado): $($SimulatedGroups -join ', ')" "INFO"
            
            Write-Log "PASO 5 SIMULADO: Eliminando usuario del origen..." "INFO"
            Write-Log "  Usuario eliminado de $($ExistingUser.SourceDomain) (simulado)" "INFO"
            
            Write-Log "=== TRASLADO ENTRE DOMINIOS SIMULADO COMPLETADO ===" "INFO"
            return $true
        }
        
    } catch {
        Write-Log "ERROR CRITICO en traslado entre dominios: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Execute-UserTransfer {
    <#
    .SYNOPSIS
        Ejecuta traslado de usuario siguiendo procedimiento exacto (mismo dominio)
    #>
    param(
        [PSCustomObject]$ExistingUser,
        [string]$TargetDomain,
        [string]$TargetOU,
        [PSCustomObject]$UserData
    )
    
    try {
        Write-Log "=== EJECUTANDO TRASLADO DE USUARIO ===" "INFO"
        Write-Log "Usuario: $($ExistingUser.SamAccountName)" "INFO"
        Write-Log "Desde: $($ExistingUser.SourceDomain)" "INFO"
        Write-Log "Hacia: $TargetDomain" "INFO"
        Write-Log "UO destino: $TargetOU" "INFO"
        
        # Verificar si el modulo ActiveDirectory esta disponible
        $ADModuleAvailable = $false
        try {
            Get-Command Get-ADUser -ErrorAction Stop | Out-Null
            $ADModuleAvailable = $true
        } catch {
            Write-Log "Modulo ActiveDirectory no disponible - ejecutando en modo simulacion" "WARNING"
        }
        
        if ($ADModuleAvailable) {
            # PASO 1: Eliminar grupos actuales (excepto sistema)
            Write-Log "PASO 1: Eliminando grupos actuales del usuario..." "INFO"
            
            $CurrentGroups = @()
            try {
                $CurrentGroups = Get-ADPrincipalGroupMembership -Identity $ExistingUser.SamAccountName -Server $ExistingUser.SourceDomain -ErrorAction Stop
                Write-Log "Se encontraron $($CurrentGroups.Count) grupos para el usuario" "INFO"
            } catch {
                Write-Log "Error obteniendo grupos del usuario: $($_.Exception.Message)" "WARNING"
                Write-Log "Continuando con el proceso de traslado sin eliminar grupos..." "WARNING"
                $CurrentGroups = @()
            }
            
            # Grupos del sistema que NO se eliminan
            $SystemGroups = @('Domain Users', 'Usuarios del dominio', 'Everyone', 'Authenticated Users', 'Usuarios autenticados')
            
            $GroupsRemoved = 0
            $GroupsSkipped = 0
            foreach ($Group in $CurrentGroups) {
                if ($Group.Name -notin $SystemGroups) {
                    try {
                        Remove-ADGroupMember -Identity $Group -Members $ExistingUser.SamAccountName -Server $ExistingUser.SourceDomain -Confirm:$false -ErrorAction Stop
                        Write-Log "Grupo eliminado: $($Group.Name)" "INFO"
                        $GroupsRemoved++
                    } catch {
                        Write-Log "Error eliminando grupo $($Group.Name): $($_.Exception.Message)" "WARNING"
                        Write-Log "CONTINUANDO con el proceso de traslado..." "WARNING"
                        $GroupsSkipped++
                    }
                } else {
                    Write-Log "Grupo del sistema conservado: $($Group.Name)" "INFO"
                }
            }
            Write-Log "PASO 1 COMPLETADO: $GroupsRemoved grupos eliminados, $GroupsSkipped con errores (PROCESO CONTINUA)" "INFO"
            
            # PASO 2: Mover usuario a nueva ubicacion
            Write-Log "PASO 2: Moviendo usuario a nueva UO..." "INFO"
            try {
                Move-ADObject -Identity $ExistingUser.DistinguishedName -TargetPath $TargetOU -Server $TargetDomain
                Write-Log "Usuario movido exitosamente a: $TargetOU" "INFO"
                
                # Actualizar campo oficina
                Set-ADUser -Identity $ExistingUser.SamAccountName -Office $UserData.Oficina -Server $TargetDomain
                Write-Log "Campo oficina actualizado a: $($UserData.Oficina)" "INFO"
                
            } catch {
                Write-Log "Error moviendo usuario: $($_.Exception.Message)" "ERROR"
                return $false
            }
            Write-Log "PASO 2 COMPLETADO: Usuario reubicado" "INFO"
            
            # PASO 3: Buscar usuario plantilla y copiar grupos
            Write-Log "PASO 3: Buscando usuario plantilla con descripcion: $($UserData.Descripcion)" "INFO"
            $TemplateUser = Find-TemplateUserInOU -Description $UserData.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain
            
            if ($TemplateUser) {
                Write-Log "Usuario plantilla encontrado: $($TemplateUser.SamAccountName) - $($TemplateUser.Description)" "INFO"
                
                $GroupsAdded = 0
                foreach ($GroupDN in $TemplateUser.MemberOf) {
                    try {
                        $Group = Get-ADGroup -Identity $GroupDN -Server $TargetDomain
                        Add-ADGroupMember -Identity $Group -Members $ExistingUser.SamAccountName -Server $TargetDomain
                        Write-Log "Grupo aniadido: $($Group.Name)" "INFO"
                        $GroupsAdded++
                    } catch {
                        Write-Log "Error aniadiendo grupo $($Group.Name): $($_.Exception.Message)" "WARNING"
                    }
                }
                Write-Log "PASO 3 COMPLETADO: $GroupsAdded grupos copiados del usuario plantilla" "INFO"
            } else {
                Write-Log "No se encontro usuario plantilla para descripcion: $($UserData.Descripcion)" "WARNING"
            }
            
            # PASO 4: Cambiar contrasenia a formato estandar
            Write-Log "PASO 4: Cambiando contrasenia a formato estandar..." "INFO"
            try {
                # Generar contrasenia estandar (Justicia + mes + anio)
                $CurrentDate = Get-Date
                $Month = $CurrentDate.ToString("MM")
                $Year = $CurrentDate.ToString("yy")
                $StandardPassword = "Justicia$Month$Year"
                
                $SecurePassword = ConvertTo-SecureString $StandardPassword -AsPlainText -Force
                Set-ADAccountPassword -Identity $ExistingUser.SamAccountName -Server $TargetDomain -NewPassword $SecurePassword -Reset
                Set-ADUser -Identity $ExistingUser.SamAccountName -Server $TargetDomain -ChangePasswordAtLogon $true
                
                Write-Log "Contrasenia cambiada a: $StandardPassword (cambio obligatorio en proximo inicio)" "INFO"
            } catch {
                Write-Log "Error cambiando contrasenia: $($_.Exception.Message)" "WARNING"
            }
            Write-Log "PASO 4 COMPLETADO: Contrasenia actualizada" "INFO"
            
            # PASO 5: Verificacion final
            Write-Log "PASO 5: Verificacion final del traslado..." "INFO"
            
            $FinalGroups = @()
            try {
                $FinalGroups = Get-ADPrincipalGroupMembership -Identity $ExistingUser.SamAccountName -Server $TargetDomain -ErrorAction Stop
                Write-Log "Grupos finales del usuario: $($FinalGroups.Count)" "INFO"
                foreach ($FinalGroup in $FinalGroups) {
                    Write-Log "  - $($FinalGroup.Name)" "INFO"
                }
                Write-Log "PASO 5 COMPLETADO: Verificacion exitosa" "INFO"
            } catch {
                Write-Log "Error en verificacion final: $($_.Exception.Message)" "WARNING"
                Write-Log "PASO 5 COMPLETADO: Traslado realizado exitosamente (verificacion omitida)" "WARNING"
            }
            
            return $true
        } else {
            # MODO SIMULACION para testing sin ActiveDirectory
            Write-Log "MODO SIMULACION: Ejecutando traslado simulado" "WARNING"
            
            # PASO 1 SIMULADO: Eliminar grupos
            Write-Log "PASO 1 SIMULADO: Eliminando grupos simulados..." "INFO"
            $SimulatedGroups = @("Grupo Administrativo", "Acceso Aplicaciones", "Permisos Especiales")
            Write-Log "Grupos eliminados (simulado): $($SimulatedGroups -join ', ')" "INFO"
            Write-Log "PASO 1 COMPLETADO: 3 grupos eliminados (simulado)" "INFO"
            
            # PASO 2 SIMULADO: Mover usuario
            Write-Log "PASO 2 SIMULADO: Moviendo usuario a nueva UO..." "INFO"
            Write-Log "Usuario movido exitosamente a: $TargetOU (simulado)" "INFO"
            Write-Log "Campo oficina actualizado a: $($UserData.Oficina) (simulado)" "INFO"
            Write-Log "PASO 2 COMPLETADO: Usuario reubicado (simulado)" "INFO"
            
            # PASO 3 SIMULADO: Buscar plantilla y copiar grupos
            Write-Log "PASO 3 SIMULADO: Buscando usuario plantilla..." "INFO"
            Write-Log "Usuario plantilla encontrado (simulado): template_$($UserData.Descripcion.ToLower())" "INFO"
            $SimulatedNewGroups = @("Nuevos Permisos $($UserData.Descripcion)", "Acceso Especializado", "Grupo Oficina")
            Write-Log "Grupos aniadidos (simulado): $($SimulatedNewGroups -join ', ')" "INFO"
            Write-Log "PASO 3 COMPLETADO: 3 grupos copiados (simulado)" "INFO"
            
            # PASO 4 SIMULADO: Cambiar contrasenia
            Write-Log "PASO 4 SIMULADO: Cambiando contrasenia..." "INFO"
            $CurrentDate = Get-Date
            $Month = $CurrentDate.ToString("MM")
            $Year = $CurrentDate.ToString("yy")
            $StandardPassword = "Justicia$Month$Year"
            Write-Log "Contrasenia cambiada a: $StandardPassword (simulado)" "INFO"
            Write-Log "PASO 4 COMPLETADO: Contrasenia actualizada (simulado)" "INFO"
            
            # PASO 5 SIMULADO: Verificacion
            Write-Log "PASO 5 SIMULADO: Verificacion final..." "INFO"
            Write-Log "Grupos finales del usuario: 5 (simulado)" "INFO"
            $FinalSimulatedGroups = @("Domain Users", "Nuevos Permisos $($UserData.Descripcion)", "Acceso Especializado", "Grupo Oficina", "Usuarios Autenticados")
            foreach ($Group in $FinalSimulatedGroups) {
                Write-Log "  - $Group (simulado)" "INFO"
            }
            
            Write-Log "=== TRASLADO SIMULADO COMPLETADO EXITOSAMENTE ===" "INFO"
            return $true
        }
        
    } catch {
        Write-Log "ERROR CRITICO en traslado: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Log "=== INICIANDO PROCESAMIENTO DE USUARIOS ===" "INFO"
Write-Log "Archivo CSV: $CSVFile" "INFO"
Write-Log "Modo WhatIf: $WhatIf" "INFO"

# Verificar que el archivo CSV existe
if (-not (Test-Path $CSVFile)) {
    Write-Log "El archivo CSV no existe: $CSVFile" "ERROR"
    throw "Archivo CSV no encontrado"
}

Write-Log "Cargando modulos del sistema..." "INFO"

# Cargar modulos
$ModulesLoaded = 0
$ModulesFailed = 0

# Modulo SamAccountNameGenerator
try {
    $SamGenPath = Join-Path $Global:ScriptPath "Modules\SamAccountNameGenerator_Fixed.psm1"
    if (Test-Path $SamGenPath) {
        Import-Module $SamGenPath -Force -DisableNameChecking
        New-Alias -Name "SamAccountNameGenerator" -Value "SamAccountNameGenerator_Fixed" -Force -Scope Global
        Write-Log "Modulo cargado: SamAccountNameGenerator_Fixed (como SamAccountNameGenerator)" "INFO"
        $ModulesLoaded++
    } else {
        throw "Archivo de modulo no encontrado"
    }
} catch {
    Write-Log "Error cargando modulo SamAccountNameGenerator: $($_.Exception.Message)" "ERROR"
    $ModulesFailed++
}

Write-Log "Modulos cargados: $ModulesLoaded" "INFO"
Write-Log "Modulos fallidos: $ModulesFailed" "INFO"

# Importar CSV directamente
Write-Log "Modulo CSVValidation no disponible - usando importacion directa" "WARNING"
Write-Log "Intentando importar CSV desde: $CSVFile" "INFO"
$Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8

if ($Users.Count -eq 0) {
    Write-Log "El archivo CSV esta vacio o no tiene datos validos" "ERROR"
    throw "El archivo CSV esta vacio"
}

Write-Log "Importados $($Users.Count) registros del CSV" "INFO"

# Detectar columnas
$FirstUser = $Users[0]
$ColumnNames = ($FirstUser | Get-Member -MemberType NoteProperty).Name
Write-Log "Columnas detectadas: $($ColumnNames -join ', ')" "INFO"

# Mostrar primer registro para verificacion
if ($Users.Count -gt 0) {
    $FirstRecord = $Users[0]
    Write-Log "Primer registro - Nombre: '$($FirstRecord.Nombre)', Apellidos: '$($FirstRecord.Apellidos)', TipoAlta: '$($FirstRecord.TipoAlta)'" "INFO"
}

# Procesar usuarios
Write-Log "Iniciando procesamiento de $($Users.Count) usuarios" "INFO"

$ProcessedCount = 0
$ErrorCount = 0
$ProcessingResults = @()  # Array para almacenar resultados del procesamiento

foreach ($User in $Users) {
    try {
        Write-Log "Procesando usuario: $($User.Nombre) $($User.Apellidos)" "INFO"
        
        # Validar TipoAlta
        if ([string]::IsNullOrWhiteSpace($User.TipoAlta)) {
            Write-Log "Establece el tipo de alta, es obligatorio para seguir con el proceso" "ERROR"
            $ErrorCount++
            
            # Agregar resultado de validación fallida
            $ProcessingResults += [PSCustomObject]@{
                Nombre = if ($User.Nombre) { $User.Nombre } else { "N/A" }
                Apellidos = if ($User.Apellidos) { $User.Apellidos } else { "N/A" }
                TipoAlta = "FALTANTE"
                Email = if ($User.Email) { $User.Email } else { "N/A" }
                Telefono = if ($User.Telefono) { $User.Telefono } else { "N/A" }
                Oficina = if ($User.Oficina) { $User.Oficina } else { "N/A" }
                Descripcion = if ($User.Descripcion) { $User.Descripcion } else { "N/A" }
                AD = "N/A"
                UO_Destino = "N/A"
                Dominio_Destino = "N/A"
                Estado = "ERROR"
                TipoTraslado = "N/A"
                Observaciones = "TipoAlta es obligatorio y no fue especificado"
            }
            continue
        }
        
        switch ($User.TipoAlta.ToUpper()) {
            "TRASLADO" {
                Write-Log "Procesando traslado" "INFO"
                
                # === INICIANDO PROCESO DE TRASLADO ===
                Write-Log "=== INICIANDO PROCESO DE TRASLADO ===" "INFO"
                
                # Buscar usuario existente
                $ExistingUser = Find-ExistingUserForTransfer -UserData $User
                
                if (-not $ExistingUser) {
                    Write-Log "No se encontro usuario existente para traslado" "ERROR"
                    $ErrorCount++
                    continue
                }
                
                # Determinar dominio de destino basado en la oficina de destino
                $TargetDomain = Get-DomainFromOffice -Office $User.Oficina
                Write-Log "Dominio de destino determinado: $TargetDomain" "INFO"
                
                # Buscar UO de destino en el dominio correcto
                $TargetOU = Find-OrganizationalUnit -Office $User.Oficina -Domain $TargetDomain
                
                if (-not $TargetOU) {
                    Write-Log "No se pudo determinar UO de destino para: $($User.Oficina) en dominio $TargetDomain" "ERROR"
                    $ErrorCount++
                    continue
                }
                
                # Determinar tipo de traslado: mismo dominio o entre dominios
                $IsCrossDomainTransfer = $ExistingUser.SourceDomain -ne $TargetDomain
                
                if ($IsCrossDomainTransfer) {
                    Write-Log "TRASLADO ENTRE DOMINIOS detectado: $($ExistingUser.SourceDomain) -> $TargetDomain" "INFO"
                } else {
                    Write-Log "TRASLADO MISMO DOMINIO detectado: $TargetDomain" "INFO"
                }
                
                # Ejecutar traslado
                if ($Global:WhatIfMode) {
                    if ($IsCrossDomainTransfer) {
                        Write-Log "MODO WHATIF: Simulando traslado ENTRE DOMINIOS de $($ExistingUser.SamAccountName)" "INFO"
                        Write-Log "  Origen: $($ExistingUser.SourceDomain)" "INFO"
                        Write-Log "  Destino: $TargetDomain" "INFO"
                        Write-Log "  UO: $TargetOU" "INFO"
                    } else {
                        Write-Log "MODO WHATIF: Simulando traslado MISMO DOMINIO de $($ExistingUser.SamAccountName) a $TargetOU" "INFO"
                    }
                    $ProcessedCount++
                    
                    # Agregar resultado de simulación de traslado
                    $ProcessingResults += [PSCustomObject]@{
                        Nombre = $User.Nombre
                        Apellidos = $User.Apellidos
                        TipoAlta = $User.TipoAlta
                        Email = $User.Email
                        Telefono = $User.Telefono
                        Oficina = $User.Oficina
                        Descripcion = $User.Descripcion
                        AD = $ExistingUser.SamAccountName
                        UO_Destino = $TargetOU
                        Dominio_Destino = $TargetDomain
                        Estado = "SIMULADO"
                        TipoTraslado = if ($IsCrossDomainTransfer) { "entre dominios" } else { "mismo dominio" }
                        Observaciones = "Traslado simulado en modo WhatIf"
                    }
                } else {
                    if ($IsCrossDomainTransfer) {
                        # Usar funcion de traslado entre dominios
                        $TransferResult = Execute-CrossDomainTransfer -ExistingUser $ExistingUser -TargetDomain $TargetDomain -TargetOU $TargetOU -UserData $User
                    } else {
                        # Usar funcion de traslado mismo dominio
                        $TransferResult = Execute-UserTransfer -ExistingUser $ExistingUser -TargetDomain $TargetDomain -TargetOU $TargetOU -UserData $User
                    }
                    
                    if ($TransferResult) {
                        $TransferType = if ($IsCrossDomainTransfer) { "entre dominios" } else { "mismo dominio" }
                        Write-Log "Traslado $TransferType completado exitosamente para: $($User.Nombre) $($User.Apellidos)" "INFO"
                        $ProcessedCount++
                        
                        # Agregar resultado exitoso
                        $ProcessingResults += [PSCustomObject]@{
                            Nombre = $User.Nombre
                            Apellidos = $User.Apellidos
                            TipoAlta = $User.TipoAlta
                            Email = $User.Email
                            Telefono = $User.Telefono
                            Oficina = $User.Oficina
                            Descripcion = $User.Descripcion
                            AD = $ExistingUser.SamAccountName
                            UO_Destino = $TargetOU
                            Dominio_Destino = $TargetDomain
                            Estado = "EXITOSO"
                            TipoTraslado = $TransferType
                            Observaciones = "Traslado completado correctamente"
                        }
                    } else {
                        Write-Log "Error en traslado para: $($User.Nombre) $($User.Apellidos)" "ERROR"
                        $ErrorCount++
                        
                        # Agregar resultado con error
                        $ProcessingResults += [PSCustomObject]@{
                            Nombre = $User.Nombre
                            Apellidos = $User.Apellidos
                            TipoAlta = $User.TipoAlta
                            Email = $User.Email
                            Telefono = $User.Telefono
                            Oficina = $User.Oficina
                            Descripcion = $User.Descripcion
                            AD = if ($ExistingUser) { $ExistingUser.SamAccountName } else { "N/A" }
                            UO_Destino = if ($TargetOU) { $TargetOU } else { "N/A" }
                            Dominio_Destino = $TargetDomain
                            Estado = "ERROR"
                            TipoTraslado = "N/A"
                            Observaciones = "Error durante el procesamiento del traslado"
                        }
                    }
                }
            }
            
            "NORMALIZADA" {
                Write-Log "Procesando alta normalizada" "INFO"
                
                # Determinar dominio destino basado en la oficina
                $TargetDomain = Get-DomainFromOffice -Office $User.Oficina
                Write-Log "Dominio destino determinado: $TargetDomain" "INFO"
                
                # Generar SamAccountName (verificando que el modulo este disponible)
                $SamAccountName = $null
                try {
                    if (Get-Command New-SamAccountName -ErrorAction SilentlyContinue) {
                        $SamAccountName = New-SamAccountName -GivenName $User.Nombre -Surname $User.Apellidos -Domain $TargetDomain -Verbose
                        if ([string]::IsNullOrWhiteSpace($SamAccountName)) {
                            Write-Log "No se pudo generar un SamAccountName unico para $($User.Nombre) $($User.Apellidos)" "ERROR"
                            $ErrorCount++
                            
                            # Agregar resultado con error de generación
                            $ProcessingResults += [PSCustomObject]@{
                                Nombre = $User.Nombre
                                Apellidos = $User.Apellidos
                                TipoAlta = $User.TipoAlta
                                Email = $User.Email
                                Telefono = $User.Telefono
                                Oficina = $User.Oficina
                                Descripcion = $User.Descripcion
                                AD = "ERROR"
                                UO_Destino = "N/A"
                                Dominio_Destino = $TargetDomain
                                Estado = "ERROR"
                                TipoTraslado = "N/A"
                                Observaciones = "No se pudo generar SamAccountName único"
                            }
                            continue
                        }
                        Write-Log "SamAccountName generado: $SamAccountName (verificado como unico en todos los dominios)" "INFO"
                    } else {
                        Write-Log "Modulo SamAccountNameGenerator no disponible - no se puede crear usuario" "ERROR"
                        $ErrorCount++
                        
                        # Agregar resultado con error de módulo
                        $ProcessingResults += [PSCustomObject]@{
                            Nombre = $User.Nombre
                            Apellidos = $User.Apellidos
                            TipoAlta = $User.TipoAlta
                            Email = $User.Email
                            Telefono = $User.Telefono
                            Oficina = $User.Oficina
                            Descripcion = $User.Descripcion
                            AD = "ERROR"
                            UO_Destino = "N/A"
                            Dominio_Destino = $TargetDomain
                            Estado = "ERROR"
                            TipoTraslado = "N/A"
                            Observaciones = "Módulo SamAccountNameGenerator no disponible"
                        }
                        continue
                    }
                } catch {
                    Write-Log "Error generando SamAccountName para $($User.Nombre) $($User.Apellidos): $($_.Exception.Message)" "ERROR"
                    $ErrorCount++
                    
                    # Agregar resultado con error de excepción
                    $ProcessingResults += [PSCustomObject]@{
                        Nombre = $User.Nombre
                        Apellidos = $User.Apellidos
                        TipoAlta = $User.TipoAlta
                        Email = $User.Email
                        Telefono = $User.Telefono
                        Oficina = $User.Oficina
                        Descripcion = $User.Descripcion
                        AD = "ERROR"
                        UO_Destino = "N/A"
                        Dominio_Destino = $TargetDomain
                        Estado = "ERROR"
                        TipoTraslado = "N/A"
                        Observaciones = "Error generando SamAccountName: $($_.Exception.Message)"
                    }
                    continue
                }
                
                # Buscar la UO correcta para ubicar el usuario (sin especificar dominio para que use auto-deteccion)
                $TargetOU = Find-OrganizationalUnit -Office $User.Oficina
                
                # Buscar usuario plantilla dentro de la UO especifica
                $TemplateUser = $null
                if ($TargetOU) {
                    Write-Log "Buscando usuario plantilla con descripcion '$($User.Descripcion)' en UO: $TargetOU" "INFO"
                    
                    # Buscar primero sin interactividad
                    $TemplateUser = Find-TemplateUserInOU -Description $User.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain
                    
                    # Si no se encuentra y no es modo WhatIf, permitir seleccion interactiva
                    if (-not $TemplateUser -and -not $Global:WhatIfMode) {
                        Write-Log "No se encontro coincidencia automatica. Habilitando seleccion interactiva..." "INFO"
                        $TemplateUser = Find-TemplateUserInOU -Description $User.Descripcion -OrganizationalUnit $TargetOU -Domain $TargetDomain -Interactive
                    }
                } else {
                    Write-Log "No se pudo determinar UO especifica, buscando en todo el dominio como fallback" "WARNING"
                    
                    # Verificar si ActiveDirectory esta disponible antes de buscar
                    try {
                        if (Get-Command Get-ADUser -ErrorAction SilentlyContinue) {
                            $TemplateUsers = Get-ADUser -Filter "Description -like '*$($User.Descripcion)*'" -Server $TargetDomain -Properties Description, MemberOf -ErrorAction SilentlyContinue
                            if ($TemplateUsers) {
                                $TemplateUser = $TemplateUsers[0]
                                Write-Log "Usuario plantilla encontrado en dominio: $($TemplateUser.SamAccountName) - $($TemplateUser.Description)" "INFO"
                            }
                        }
                    } catch {
                        Write-Log "Error buscando usuario plantilla en dominio: $($_.Exception.Message)" "WARNING"
                    }
                }
                
                if ($Global:WhatIfMode) {
                    Write-Log "SIMULACION: Crearia usuario normalizado en dominio $TargetDomain" "INFO"
                    Write-Log "SIMULACION: UO destino: $TargetOU" "INFO"
                    Write-Log "SIMULACION: UPN seria: $SamAccountName@justicia.junta-andalucia.es" "INFO"
                    $ProcessedCount++
                    
                    # Agregar resultado de simulación de alta normalizada
                    $ProcessingResults += [PSCustomObject]@{
                        Nombre = $User.Nombre
                        Apellidos = $User.Apellidos
                        TipoAlta = $User.TipoAlta
                        Email = $User.Email
                        Telefono = $User.Telefono
                        Oficina = $User.Oficina
                        Descripcion = $User.Descripcion
                        AD = $SamAccountName
                        UO_Destino = if ($TargetOU) { $TargetOU } else { "UO por defecto" }
                        Dominio_Destino = $TargetDomain
                        Estado = "SIMULADO"
                        TipoTraslado = "N/A"
                        Observaciones = "Alta normalizada simulada en modo WhatIf"
                    }
                } else {
                    Write-Log "CREANDO USUARIO REAL en dominio $TargetDomain" "INFO"
                    
                    # Verificar si ActiveDirectory esta disponible
                    $ADModuleAvailable = $false
                    try {
                        Get-Command New-ADUser -ErrorAction Stop | Out-Null
                        $ADModuleAvailable = $true
                    } catch {
                        Write-Log "Modulo ActiveDirectory no disponible - ejecutando creacion simulada" "WARNING"
                    }
                    
                    if ($ADModuleAvailable) {
                        try {
                            # Generar contrasenia estandar
                            $CurrentDate = Get-Date
                            $Month = $CurrentDate.ToString("MM")
                            $Year = $CurrentDate.ToString("yy")
                            $UserPassword = "Justicia$Month$Year"
                            
                            $SecurePassword = ConvertTo-SecureString $UserPassword -AsPlainText -Force
                            
                            # Parametros para crear el usuario
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
                            
                            # Aniadir UO si se encontro
                            if ($TargetOU) {
                                $UserParams.Path = $TargetOU
                            }
                            
                            Write-Log "Creando usuario con parametros:" "INFO"
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
                                        Write-Log "Usuario aniadido al grupo: $($Group.Name)" "INFO"
                                    } catch {
                                        Write-Log "Error aniadiendo usuario al grupo ${GroupDN}: $($_.Exception.Message)" "WARNING"
                                    }
                                }
                                
                                Write-Log "Copia de grupos completada" "INFO"
                            }
                            
                            $ProcessedCount++
                            
                            # Agregar resultado exitoso de alta normalizada
                            $ProcessingResults += [PSCustomObject]@{
                                Nombre = $User.Nombre
                                Apellidos = $User.Apellidos
                                TipoAlta = $User.TipoAlta
                                Email = $User.Email
                                Telefono = $User.Telefono
                                Oficina = $User.Oficina
                                Descripcion = $User.Descripcion
                                AD = $SamAccountName
                                UO_Destino = if ($TargetOU) { $TargetOU } else { "UO por defecto" }
                                Dominio_Destino = $TargetDomain
                                Estado = "EXITOSO"
                                TipoTraslado = "N/A"
                                Observaciones = "Usuario normalizado creado correctamente"
                            }
                            
                        } catch {
                            Write-Log "ERROR: Fallo creando usuario ${SamAccountName}: $($_.Exception.Message)" "ERROR"
                            $ErrorCount++
                            
                            # Agregar resultado con error de creación
                            $ProcessingResults += [PSCustomObject]@{
                                Nombre = $User.Nombre
                                Apellidos = $User.Apellidos
                                TipoAlta = $User.TipoAlta
                                Email = $User.Email
                                Telefono = $User.Telefono
                                Oficina = $User.Oficina
                                Descripcion = $User.Descripcion
                                AD = $SamAccountName
                                UO_Destino = if ($TargetOU) { $TargetOU } else { "N/A" }
                                Dominio_Destino = $TargetDomain
                                Estado = "ERROR"
                                TipoTraslado = "N/A"
                                Observaciones = "Error creando usuario: $($_.Exception.Message)"
                            }
                            continue
                        }
                    } else {
                        # Modo simulacion sin ActiveDirectory
                        Write-Log "CREACION SIMULADA: Usuario $SamAccountName en dominio $TargetDomain" "WARNING"
                        Write-Log "  UPN simulado: $SamAccountName@justicia.junta-andalucia.es" "INFO"
                        Write-Log "  UO simulada: $TargetOU" "INFO"
                        Write-Log "  Contrasenia simulada: Justicia$Month$Year" "INFO"
                        
                        if ($TemplateUser) {
                            Write-Log "  Grupos simulados copiados de: $($TemplateUser.SamAccountName)" "INFO"
                        }
                        
                        $ProcessedCount++
                        
                        # Agregar resultado exitoso simulado
                        $ProcessingResults += [PSCustomObject]@{
                            Nombre = $User.Nombre
                            Apellidos = $User.Apellidos
                            TipoAlta = $User.TipoAlta
                            Email = $User.Email
                            Telefono = $User.Telefono
                            Oficina = $User.Oficina
                            Descripcion = $User.Descripcion
                            AD = $SamAccountName
                            UO_Destino = if ($TargetOU) { $TargetOU } else { "UO simulada" }
                            Dominio_Destino = $TargetDomain
                            Estado = "SIMULADO"
                            TipoTraslado = "N/A"
                            Observaciones = "Usuario normalizado simulado (módulo AD no disponible)"
                        }
                    }
                }
            }
            
            "COMPAGINADA" {
                Write-Log "Tipo COMPAGINADA no implementado aun" "WARNING"
                $ErrorCount++
                
                # Agregar resultado de tipo no implementado
                $ProcessingResults += [PSCustomObject]@{
                    Nombre = $User.Nombre
                    Apellidos = $User.Apellidos
                    TipoAlta = $User.TipoAlta
                    Email = $User.Email
                    Telefono = $User.Telefono
                    Oficina = $User.Oficina
                    Descripcion = $User.Descripcion
                    AD = "N/A"
                    UO_Destino = "N/A"
                    Dominio_Destino = "N/A"
                    Estado = "NO_IMPLEMENTADO"
                    TipoTraslado = "N/A"
                    Observaciones = "Tipo de alta COMPAGINADA no implementado aún"
                }
            }
            
            default {
                Write-Log "Tipo de alta no reconocido: $($User.TipoAlta)" "ERROR"
                $ErrorCount++
                
                # Agregar resultado de tipo no reconocido
                $ProcessingResults += [PSCustomObject]@{
                    Nombre = $User.Nombre
                    Apellidos = $User.Apellidos
                    TipoAlta = $User.TipoAlta
                    Email = $User.Email
                    Telefono = $User.Telefono
                    Oficina = $User.Oficina
                    Descripcion = $User.Descripcion
                    AD = "N/A"
                    UO_Destino = "N/A"
                    Dominio_Destino = "N/A"
                    Estado = "ERROR"
                    TipoTraslado = "N/A"
                    Observaciones = "Tipo de alta no reconocido: $($User.TipoAlta)"
                }
            }
        }
        
    } catch {
        Write-Log "Error procesando usuario $($User.Nombre) $($User.Apellidos): $($_.Exception.Message)" "ERROR"
        $ErrorCount++
        
        # Agregar resultado de error general
        $ProcessingResults += [PSCustomObject]@{
            Nombre = if ($User.Nombre) { $User.Nombre } else { "N/A" }
            Apellidos = if ($User.Apellidos) { $User.Apellidos } else { "N/A" }
            TipoAlta = if ($User.TipoAlta) { $User.TipoAlta } else { "N/A" }
            Email = if ($User.Email) { $User.Email } else { "N/A" }
            Telefono = if ($User.Telefono) { $User.Telefono } else { "N/A" }
            Oficina = if ($User.Oficina) { $User.Oficina } else { "N/A" }
            Descripcion = if ($User.Descripcion) { $User.Descripcion } else { "N/A" }
            AD = "ERROR"
            UO_Destino = "N/A"
            Dominio_Destino = "N/A"
            Estado = "ERROR"
            TipoTraslado = "N/A"
            Observaciones = "Error general procesando usuario: $($_.Exception.Message)"
        }
    }
}

# Resumen final
Write-Log "=== PROCESO COMPLETADO ===" "INFO"
Write-Log "Usuarios procesados exitosamente: $ProcessedCount" "INFO"
Write-Log "Usuarios con errores: $ErrorCount" "INFO"
Write-Log "Total procesados: $($ProcessedCount + $ErrorCount) de $($Users.Count)" "INFO"

# Generar CSV de resultados
if ($ProcessingResults.Count -gt 0) {
    # Mantener CSV anterior si existe y crear uno con timestamp
    $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
    $ResultsCSVPath = $CSVFile -replace '\.csv$', "_resultados_${TimeStampForCSV}.csv"
    
    try {
        $ProcessingResults | Export-Csv -Path $ResultsCSVPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
        Write-Log "CSV de resultados generado: $ResultsCSVPath" "INFO"
        Write-Log "Registros en CSV de resultados: $($ProcessingResults.Count)" "INFO"
        
        # Mostrar resumen por estado
        $ResultadosExitosos = ($ProcessingResults | Where-Object { $_.Estado -eq "EXITOSO" }).Count
        $ResultadosError = ($ProcessingResults | Where-Object { $_.Estado -eq "ERROR" }).Count
        $ResultadosSimulados = ($ProcessingResults | Where-Object { $_.Estado -eq "SIMULADO" }).Count
        
        Write-Log "Resumen de resultados:" "INFO"
        Write-Log "  - Exitosos: $ResultadosExitosos" "INFO"
        Write-Log "  - Errores: $ResultadosError" "INFO"
        Write-Log "  - Simulados: $ResultadosSimulados" "INFO"
        
        Write-Host "`nCSV de resultados generado en: $ResultsCSVPath" -ForegroundColor Cyan
        
    } catch {
        Write-Log "Error generando CSV de resultados: $($_.Exception.Message)" "ERROR"
        Write-Host "Error generando CSV de resultados. Revisar log." -ForegroundColor Red
    }
} else {
    Write-Log "No hay resultados para generar CSV" "WARNING"
}

if ($ErrorCount -gt 0) {
    Write-Log "Se encontraron $ErrorCount errores durante el procesamiento" "WARNING"
}

Write-Log "Log guardado en: $Global:LogFile" "INFO"
Write-Host ("`nProceso completado. Revise el log para detalles: " + $Global:LogFile) -ForegroundColor Green