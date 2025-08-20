#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CAU IT Support Utility - PowerShell Version
    
.DESCRIPTION
    Advanced menu-driven utility for CAU IT support tasks optimized for Windows 10.
    Features include comprehensive logging, error handling, progress tracking, and
    Windows 10 specific optimizations.
    
.NOTES
    Version: 3.0-PowerShell
    Author: CAU IT Team
    Last Modified: 2025-08-20
    Requirements: PowerShell 5.1+, Windows 10, Administrator privileges
    
.EXAMPLE
    .\CAUJUS.ps1
    Runs the interactive menu system
    
.EXAMPLE
    .\CAUJUS.ps1 -LogLevel Debug
    Runs with debug logging enabled
#>

[CmdletBinding()]
param(
    [ValidateSet('Error', 'Warning', 'Information', 'Debug')]
    [string]$LogLevel = 'Information',
    
    [string]$ConfigPath = "$PSScriptRoot\CAUJUS.config.json",
    
    [switch]$NoUpload
)

# =============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
# =============================================================================

$Global:CAUConfig = @{
    # Network paths
    RemoteLogDir = "\\iusnas05\SIJ\CAU-2012\logs"
    SoftwareBase = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
    DriverBase = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"
    
    # Software packages
    IslMsi = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\isl.msi"
    FnmtConfig = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\Configurador_FNMT_5.0.0_64bits.exe"
    AutoFirmaExe = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_64_v1_8_3_installer.exe"
    AutoFirmaMsi = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\AutoFirma_v1_6_0_JAv05_installer_64.msi"
    ChromeMsi = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\chrome.msi"
    LibreOfficeMsi = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas\LibreOffice.msi"
    
    # Driver packages
    DriverPct = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\PCT-331_V8.52\SCR3xxx_V8.52.exe"
    DriverSatellite = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas\satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"
    
    # URLs
    UrlMiCuenta = "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
    UrlFnmtRequest = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
    UrlFnmtRenew = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
    UrlFnmtDownload = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"
    
    # Script metadata
    ScriptVersion = "3.0-PowerShell"
    BlockedHostname = "IUSSWRDPCAU02"
}

$Global:CAUSession = @{
    StartTime = Get-Date
    LogFile = $null
    ADUser = $null
    UserProfile = $env:USERNAME
    Hostname = $env:COMPUTERNAME
    SystemInfo = @{}
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Initialize-CAULogging {
    [CmdletBinding()]
    param()
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logDir = Join-Path $env:TEMP "CAUJUS_Logs"
        
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $logFileName = "$($Global:CAUSession.ADUser)_$($Global:CAUSession.Hostname)_$timestamp.log"
        $Global:CAUSession.LogFile = Join-Path $logDir $logFileName
        
        Write-CAULog -Level Information -Message "CAU PowerShell Utility v$($Global:CAUConfig.ScriptVersion) started"
        Write-CAULog -Level Information -Message "Session: User=$($Global:CAUSession.UserProfile), AD=$($Global:CAUSession.ADUser), Host=$($Global:CAUSession.Hostname)"
        
        return $true
    }
    catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
        return $false
    }
}

function Write-CAULog {
    [CmdletBinding()]
    param(
        [ValidateSet('Error', 'Warning', 'Information', 'Debug')]
        [string]$Level = 'Information',
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    # Write to console based on level and preference
    if (-not $NoConsole) {
        switch ($Level) {
            'Error' { Write-Host $logEntry -ForegroundColor Red }
            'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
            'Information' { 
                if ($LogLevel -in @('Information', 'Debug')) {
                    Write-Host $logEntry -ForegroundColor Green 
                }
            }
            'Debug' { 
                if ($LogLevel -eq 'Debug') {
                    Write-Host $logEntry -ForegroundColor Cyan 
                }
            }
        }
    }
    
    # Write to log file
    if ($Global:CAUSession.LogFile) {
        try {
            Add-Content -Path $Global:CAUSession.LogFile -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

# =============================================================================
# INITIALIZATION FUNCTIONS
# =============================================================================

function Initialize-CAUEnvironment {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Initializing CAU environment"
    
    # Check if running on blocked machine
    if ($env:COMPUTERNAME -eq $Global:CAUConfig.BlockedHostname) {
        Write-CAULog -Level Error -Message "Script cannot run on jump server ($($Global:CAUConfig.BlockedHostname))"
        throw "Script execution blocked on jump server"
    }
    
    # Load configuration if exists
    if (Test-Path $ConfigPath) {
        try {
            $configData = Get-Content $ConfigPath | ConvertFrom-Json
            foreach ($key in $configData.PSObject.Properties.Name) {
                $Global:CAUConfig[$key] = $configData.$key
            }
            Write-CAULog -Level Information -Message "Configuration loaded from $ConfigPath"
        }
        catch {
            Write-CAULog -Level Warning -Message "Failed to load configuration: $($_.Exception.Message)"
        }
    }
    
    # Get AD credentials
    if (-not $Global:CAUSession.ADUser) {
        $Global:CAUSession.ADUser = Read-Host "Enter your AD username"
        if ([string]::IsNullOrWhiteSpace($Global:CAUSession.ADUser)) {
            throw "AD username is required"
        }
    }
    
    # Initialize logging
    if (-not (Initialize-CAULogging)) {
        throw "Failed to initialize logging system"
    }
    
    # Get system information
    Get-CAUSystemInfo
    
    Write-CAULog -Level Information -Message "Environment initialization completed"
}

function Get-CAUSystemInfo {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Debug -Message "Gathering system information"
    
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $bios = Get-CimInstance -ClassName Win32_BIOS
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        
        # Get IP address
        $networkAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | 
                         Where-Object { $_.IPEnabled -eq $true -and $_.IPAddress[0] -notlike "169.254.*" } |
                         Select-Object -First 1
        
        $Global:CAUSession.SystemInfo = @{
            ComputerName = $computerSystem.Name
            SerialNumber = $bios.SerialNumber
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            OSCaption = $os.Caption
            OSVersion = $os.Version
            OSBuild = $os.BuildNumber
            IPAddress = if ($networkAdapter) { $networkAdapter.IPAddress[0] } else { "Unknown" }
            TotalMemory = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            LastBootTime = $os.LastBootUpTime
        }
        
        Write-CAULog -Level Debug -Message "System information gathered successfully"
    }
    catch {
        Write-CAULog -Level Warning -Message "Failed to gather some system information: $($_.Exception.Message)"
    }
}

# =============================================================================
# USER INTERFACE FUNCTIONS
# =============================================================================

function Show-CAUMainMenu {
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "                   CAU" -ForegroundColor White
        Write-Host "      IT Support Utility v$($Global:CAUConfig.ScriptVersion)" -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Display system information
        $sysInfo = $Global:CAUSession.SystemInfo
        Write-Host "System Information:" -ForegroundColor Yellow
        Write-Host "  User: $($Global:CAUSession.UserProfile)" -ForegroundColor Gray
        Write-Host "  AD User: $($Global:CAUSession.ADUser)" -ForegroundColor Gray
        Write-Host "  Computer: $($sysInfo.ComputerName)" -ForegroundColor Gray
        Write-Host "  Serial: $($sysInfo.SerialNumber)" -ForegroundColor Gray
        Write-Host "  IP: $($sysInfo.IPAddress)" -ForegroundColor Gray
        Write-Host "  OS: $($sysInfo.OSCaption) (Build $($sysInfo.OSBuild))" -ForegroundColor Gray
        Write-Host "  Memory: $($sysInfo.TotalMemory) GB" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Available Options:" -ForegroundColor Yellow
        Write-Host "  1. System Optimization (Battery Test)" -ForegroundColor White
        Write-Host "  2. Change Email Password" -ForegroundColor White
        Write-Host "  3. Reset Print Spooler" -ForegroundColor White
        Write-Host "  4. Device Manager" -ForegroundColor White
        Write-Host "  5. Digital Certificate Management" -ForegroundColor White
        Write-Host "  6. Install ISL Always On" -ForegroundColor White
        Write-Host "  7. Utilities" -ForegroundColor White
        Write-Host "  8. System Information" -ForegroundColor White
        Write-Host "  9. Exit" -ForegroundColor White
        Write-Host ""
        
        $choice = Read-Host "Select an option (1-9)"
        
        Write-CAULog -Level Information -Message "Main menu selection: $choice"
        
        switch ($choice) {
            '1' { Invoke-CAUSystemOptimization }
            '2' { Invoke-CAUChangeEmailPassword }
            '3' { Invoke-CAUResetPrintSpooler }
            '4' { Invoke-CAUOpenDeviceManager }
            '5' { Show-CAUCertificateMenu }
            '6' { Invoke-CAUInstallISL }
            '7' { Show-CAUUtilitiesMenu }
            '8' { Show-CAUSystemInformation }
            '9' { 
                Write-CAULog -Level Information -Message "User requested exit"
                return 
            }
            default { 
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        
    } while ($true)
}

function Show-CAUCertificateMenu {
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "           Digital Certificate" -ForegroundColor White
        Write-Host "             Management" -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "  1. Silent FNMT Configuration" -ForegroundColor White
        Write-Host "  2. Manual FNMT Configuration" -ForegroundColor White
        Write-Host "  3. Request Certificate" -ForegroundColor White
        Write-Host "  4. Renew Certificate" -ForegroundColor White
        Write-Host "  5. Download Certificate" -ForegroundColor White
        Write-Host "  6. View Installed Certificates" -ForegroundColor White
        Write-Host "  7. Back to Main Menu" -ForegroundColor White
        Write-Host ""
        
        $choice = Read-Host "Select an option (1-7)"
        
        Write-CAULog -Level Information -Message "Certificate menu selection: $choice"
        
        switch ($choice) {
            '1' { Invoke-CAUConfigureFNMTSilent }
            '2' { Invoke-CAUConfigureFNMTManual }
            '3' { Invoke-CAURequestCertificate }
            '4' { Invoke-CAURenewCertificate }
            '5' { Invoke-CAUDownloadCertificate }
            '6' { Show-CAUInstalledCertificates }
            '7' { return }
            default { 
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        
        if ($choice -ne '6' -and $choice -ne '7') {
            Write-Host "Press any key to continue..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
    } while ($true)
}

function Show-CAUUtilitiesMenu {
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "              Utilities" -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "  1. Internet Options" -ForegroundColor White
        Write-Host "  2. Install Chrome 109" -ForegroundColor White
        Write-Host "  3. Fix Black Screen" -ForegroundColor White
        Write-Host "  4. Windows Version Info" -ForegroundColor White
        Write-Host "  5. Reinstall Card Reader Drivers" -ForegroundColor White
        Write-Host "  6. Install AutoFirma" -ForegroundColor White
        Write-Host "  7. Install LibreOffice" -ForegroundColor White
        Write-Host "  8. Force Time Sync" -ForegroundColor White
        Write-Host "  9. Windows Update Check" -ForegroundColor White
        Write-Host " 10. Network Diagnostics" -ForegroundColor White
        Write-Host " 11. Back to Main Menu" -ForegroundColor White
        Write-Host ""
        
        $choice = Read-Host "Select an option (1-11)"
        
        Write-CAULog -Level Information -Message "Utilities menu selection: $choice"
        
        switch ($choice) {
            '1' { Invoke-CAUOpenInternetOptions }
            '2' { Invoke-CAUInstallChrome }
            '3' { Invoke-CAUFixBlackScreen }
            '4' { Invoke-CAUShowWindowsVersion }
            '5' { Invoke-CAUReinstallCardDrivers }
            '6' { Invoke-CAUInstallAutoFirma }
            '7' { Invoke-CAUInstallLibreOffice }
            '8' { Invoke-CAUForceTimeSync }
            '9' { Invoke-CAUWindowsUpdateCheck }
            '10' { Invoke-CAUNetworkDiagnostics }
            '11' { return }
            default { 
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        
        if ($choice -notin @('10', '11')) {
            Write-Host "Press any key to continue..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
    } while ($true)
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

function Invoke-CAUSystemOptimization {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Starting system optimization"
    
    Write-Host ""
    Write-Host "Starting System Optimization..." -ForegroundColor Green
    Write-Host ""
    
    # Show progress
    $activities = @(
        "Terminating browser processes",
        "Clearing system caches",
        "Applying performance tweaks",
        "Running system maintenance",
        "Updating group policy"
    )
    
    for ($i = 0; $i -lt $activities.Count; $i++) {
        Write-Progress -Activity "System Optimization" -Status $activities[$i] -PercentComplete (($i + 1) / $activities.Count * 100)
        
        switch ($i) {
            0 { Stop-CAUBrowserProcesses }
            1 { Clear-CAUSystemCaches }
            2 { Set-CAUPerformanceTweaks }
            3 { Invoke-CAUSystemMaintenance }
            4 { Update-CAUGroupPolicy }
        }
        
        Start-Sleep -Seconds 1
    }
    
    Write-Progress -Activity "System Optimization" -Completed
    
    Write-Host "System optimization completed successfully!" -ForegroundColor Green
    Write-Host ""
    
    $restart = Read-Host "Restart computer now? (Y/N)"
    if ($restart -match '^[Yy]') {
        Write-CAULog -Level Information -Message "User chose to restart system"
        Send-CAULogFile
        Restart-Computer -Force
    }
}

function Invoke-CAUChangeEmailPassword {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening email password change URL"
    Start-Process "chrome.exe" -ArgumentList $Global:CAUConfig.UrlMiCuenta
    Write-Host "Email password change page opened in browser" -ForegroundColor Green
}

function Invoke-CAUResetPrintSpooler {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Resetting print spooler"
    
    try {
        Write-Host "Stopping print spooler..." -ForegroundColor Yellow
        Stop-Service -Name Spooler -Force
        
        Write-Host "Starting print spooler..." -ForegroundColor Yellow
        Start-Service -Name Spooler
        
        Write-Host "Print spooler has been reset successfully!" -ForegroundColor Green
    }
    catch {
        Write-CAULog -Level Error -Message "Failed to reset print spooler: $($_.Exception.Message)"
        Write-Host "Failed to reset print spooler: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CAUOpenDeviceManager {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening Device Manager"
    Start-Process "devmgmt.msc"
}

function Invoke-CAUInstallISL {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Installing ISL Always On"
    
    if (-not (Test-Path $Global:CAUConfig.IslMsi)) {
        Write-CAULog -Level Error -Message "ISL installer not found: $($Global:CAUConfig.IslMsi)"
        Write-Host "ISL installer not found!" -ForegroundColor Red
        return
    }
    
    try {
        Write-Host "Installing ISL Always On..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($Global:CAUConfig.IslMsi)`"", "/qn" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "ISL Always On installed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "ISL installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-CAULog -Level Error -Message "ISL installation failed: $($_.Exception.Message)"
        Write-Host "ISL installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# CERTIFICATE MANAGEMENT FUNCTIONS
# =============================================================================

function Invoke-CAUConfigureFNMTSilent {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Running silent FNMT configuration"
    
    if (-not (Test-Path $Global:CAUConfig.FnmtConfig)) {
        Write-Host "FNMT configurator not found!" -ForegroundColor Red
        return
    }
    
    try {
        Push-Location "$env:USERPROFILE\Downloads"
        Write-Host "Running FNMT configuration silently..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $Global:CAUConfig.FnmtConfig -ArgumentList "/S" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "FNMT configuration completed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "FNMT configuration failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-CAULog -Level Error -Message "FNMT configuration failed: $($_.Exception.Message)"
        Write-Host "FNMT configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
}

function Invoke-CAUConfigureFNMTManual {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Running manual FNMT configuration"
    
    if (-not (Test-Path $Global:CAUConfig.FnmtConfig)) {
        Write-Host "FNMT configurator not found!" -ForegroundColor Red
        return
    }
    
    Push-Location "$env:USERPROFILE\Downloads"
    Start-Process -FilePath $Global:CAUConfig.FnmtConfig
    Pop-Location
}

function Invoke-CAURequestCertificate {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening certificate request URL"
    Start-Process "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtRequest
}

function Invoke-CAURenewCertificate {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening certificate renewal URL"
    Start-Process "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtRenew
}

function Invoke-CAUDownloadCertificate {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening certificate download URL"
    Start-Process "chrome.exe" -ArgumentList $Global:CAUConfig.UrlFnmtDownload
}

function Show-CAUInstalledCertificates {
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "        Installed Certificates" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $certs = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*CN=*" }
        
        if ($certs.Count -eq 0) {
            Write-Host "No personal certificates found." -ForegroundColor Yellow
        }
        else {
            foreach ($cert in $certs) {
                Write-Host "Subject: $($cert.Subject)" -ForegroundColor White
                Write-Host "Issuer: $($cert.Issuer)" -ForegroundColor Gray
                Write-Host "Valid From: $($cert.NotBefore)" -ForegroundColor Gray
                Write-Host "Valid To: $($cert.NotAfter)" -ForegroundColor Gray
                Write-Host "Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                
                if ($cert.NotAfter -lt (Get-Date)) {
                    Write-Host "Status: EXPIRED" -ForegroundColor Red
                }
                elseif ($cert.NotAfter -lt (Get-Date).AddDays(30)) {
                    Write-Host "Status: EXPIRING SOON" -ForegroundColor Yellow
                }
                else {
                    Write-Host "Status: VALID" -ForegroundColor Green
                }
                
                Write-Host ("-" * 50) -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "Error retrieving certificates: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function Invoke-CAUOpenInternetOptions {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Opening Internet Options"
    Start-Process "inetcpl.cpl"
}

function Invoke-CAUInstallChrome {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Installing Chrome 109"
    
    if (-not (Test-Path $Global:CAUConfig.ChromeMsi)) {
        Write-Host "Chrome installer not found!" -ForegroundColor Red
        return
    }
    
    try {
        Write-Host "Installing Chrome 109..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($Global:CAUConfig.ChromeMsi)`"", "/qn" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Chrome installed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "Chrome installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-CAULog -Level Error -Message "Chrome installation failed: $($_.Exception.Message)"
        Write-Host "Chrome installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CAUFixBlackScreen {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Fixing black screen issue"
    
    try {
        Write-Host "Resetting display configuration..." -ForegroundColor Yellow
        Start-Process "DisplaySwitch.exe" -ArgumentList "/internal" -Wait
        Start-Sleep -Seconds 3
        Start-Process "DisplaySwitch.exe" -ArgumentList "/extend" -Wait
        Write-Host "Display configuration reset successfully!" -ForegroundColor Green
    }
    catch {
        Write-CAULog -Level Error -Message "Failed to fix black screen: $($_.Exception.Message)"
        Write-Host "Failed to fix black screen: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CAUShowWindowsVersion {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Showing Windows version"
    Start-Process "winver.exe"
}

function Invoke-CAUWindowsUpdateCheck {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Checking Windows Updates"
    
    try {
        Write-Host "Checking for Windows Updates..." -ForegroundColor Yellow
        
        # Use Windows Update PowerShell module if available
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Import-Module PSWindowsUpdate
            $updates = Get-WUList
            
            if ($updates.Count -eq 0) {
                Write-Host "No updates available." -ForegroundColor Green
            }
            else {
                Write-Host "Available updates:" -ForegroundColor Yellow
                foreach ($update in $updates) {
                    Write-Host "  - $($update.Title)" -ForegroundColor White
                }
            }
        }
        else {
            # Fall back to opening Windows Update settings
            Start-Process "ms-settings:windowsupdate"
            Write-Host "Windows Update settings opened." -ForegroundColor Green
        }
    }
    catch {
        Write-CAULog -Level Error -Message "Windows Update check failed: $($_.Exception.Message)"
        Write-Host "Windows Update check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-CAUNetworkDiagnostics {
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "         Network Diagnostics" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-CAULog -Level Information -Message "Running network diagnostics"
    
    # Test network connectivity
    $tests = @(
        @{ Name = "Local Network Gateway"; Target = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1 },
        @{ Name = "DNS Server"; Target = "8.8.8.8" },
        @{ Name = "Internet Connectivity"; Target = "google.com" },
        @{ Name = "Company Domain"; Target = "justicia" }
    )
    
    foreach ($test in $tests) {
        Write-Host "Testing $($test.Name)..." -NoNewline
        try {
            $result = Test-NetConnection -ComputerName $test.Target -InformationLevel Quiet
            if ($result) {
                Write-Host " [OK]" -ForegroundColor Green
            }
            else {
                Write-Host " [FAILED]" -ForegroundColor Red
            }
        }
        catch {
            Write-Host " [ERROR]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Network Configuration:" -ForegroundColor Yellow
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $config = Get-NetIPConfiguration -InterfaceIndex $adapter.InterfaceIndex
        Write-Host "  $($adapter.Name):" -ForegroundColor White
        Write-Host "    IP: $($config.IPv4Address.IPAddress)" -ForegroundColor Gray
        Write-Host "    Gateway: $($config.IPv4DefaultGateway.NextHop)" -ForegroundColor Gray
        Write-Host "    DNS: $($config.DNSServer.ServerAddresses -join ', ')" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =============================================================================
# SYSTEM OPTIMIZATION HELPERS
# =============================================================================

function Stop-CAUBrowserProcesses {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Terminating browser processes"
    
    $browsers = @('chrome', 'iexplore', 'msedge', 'firefox')
    foreach ($browser in $browsers) {
        try {
            Get-Process -Name $browser -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        catch {
            # Ignore errors for processes that don't exist
        }
    }
}

function Clear-CAUSystemCaches {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Clearing system caches"
    
    try {
        # DNS cache
        Clear-DnsClientCache
        
        # Windows Update cache
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        
        # Temporary files
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Browser caches
        $chromePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache"
        if (Test-Path $chromePath) {
            Remove-Item -Path "$chromePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-CAULog -Level Warning -Message "Some cache clearing operations failed: $($_.Exception.Message)"
    }
}

function Set-CAUPerformanceTweaks {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Applying performance registry tweaks"
    
    try {
        # Disable visual effects
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force
        
        # Optimize for performance
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "ComboBoxAnimation" -Value 0 -Force
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "MenuAnimation" -Value 0 -Force
    }
    catch {
        Write-CAULog -Level Warning -Message "Some performance tweaks failed: $($_.Exception.Message)"
    }
}

function Invoke-CAUSystemMaintenance {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Running system maintenance tasks"
    
    try {
        # Run disk cleanup
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden
        
        # System file checker (if needed)
        # Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -WindowStyle Hidden -Verb RunAs
    }
    catch {
        Write-CAULog -Level Warning -Message "Some maintenance tasks failed: $($_.Exception.Message)"
    }
}

function Update-CAUGroupPolicy {
    [CmdletBinding()]
    param()
    
    Write-CAULog -Level Information -Message "Updating group policy"
    
    try {
        Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -Wait -WindowStyle Hidden
    }
    catch {
        Write-CAULog -Level Warning -Message "Group policy update failed: $($_.Exception.Message)"
    }
}

function Show-CAUSystemInformation {
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "         System Information" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $sysInfo = $Global:CAUSession.SystemInfo
    
    Write-Host "Computer Information:" -ForegroundColor Yellow
    Write-Host "  Name: $($sysInfo.ComputerName)" -ForegroundColor White
    Write-Host "  Manufacturer: $($sysInfo.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($sysInfo.Model)" -ForegroundColor White
    Write-Host "  Serial Number: $($sysInfo.SerialNumber)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Operating System:" -ForegroundColor Yellow
    Write-Host "  OS: $($sysInfo.OSCaption)" -ForegroundColor White
    Write-Host "  Version: $($sysInfo.OSVersion)" -ForegroundColor White
    Write-Host "  Build: $($sysInfo.OSBuild)" -ForegroundColor White
    Write-Host "  Last Boot: $($sysInfo.LastBootTime)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Hardware:" -ForegroundColor Yellow
    Write-Host "  Total Memory: $($sysInfo.TotalMemory) GB" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Network:" -ForegroundColor Yellow
    Write-Host "  IP Address: $($sysInfo.IPAddress)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Session Information:" -ForegroundColor Yellow
    Write-Host "  Current User: $($Global:CAUSession.UserProfile)" -ForegroundColor White
    Write-Host "  AD User: $($Global:CAUSession.ADUser)" -ForegroundColor White
    Write-Host "  Session Start: $($Global:CAUSession.StartTime)" -ForegroundColor White
    Write-Host "  Script Version: $($Global:CAUConfig.ScriptVersion)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =============================================================================
# FILE MANAGEMENT
# =============================================================================

function Send-CAULogFile {
    [CmdletBinding()]
    param()
    
    if ($NoUpload -or -not $Global:CAUSession.LogFile) {
        return
    }
    
    Write-CAULog -Level Information -Message "Uploading log file to network"
    
    try {
        $remoteDir = $Global:CAUConfig.RemoteLogDir
        
        if (-not (Test-Path $remoteDir)) {
            New-Item -Path $remoteDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $remoteFile = Join-Path $remoteDir "$($Global:CAUSession.ADUser)_$($Global:CAUSession.Hostname)_$timestamp.log"
        
        Copy-Item -Path $Global:CAUSession.LogFile -Destination $remoteFile -Force
        Write-CAULog -Level Information -Message "Log file uploaded successfully to $remoteFile"
    }
    catch {
        Write-CAULog -Level Warning -Message "Failed to upload log file: $($_.Exception.Message)"
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Start-CAUUtility {
    [CmdletBinding()]
    param()
    
    try {
        # Initialize environment
        Initialize-CAUEnvironment
        
        # Show main menu
        Show-CAUMainMenu
        
        # Upload log file on exit
        Send-CAULogFile
        
        Write-Host ""
        Write-Host "Thank you for using CAU IT Support Utility!" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Write-CAULog -Level Error -Message "Fatal error: $($_.Exception.Message)"
        exit 1
    }
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run if script is executed directly (not imported)
if ($MyInvocation.InvocationName -ne '.') {
    Start-CAUUtility
}