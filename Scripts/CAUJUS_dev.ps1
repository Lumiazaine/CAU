# Script: CAUJUS_dev.ps1
# Purpose: Provides a menu-driven utility for various CAU IT support tasks.
# Version: 1.0.0 (Initial PowerShell Migration)
# Last Modified: $(Get-Date -Format 'yyyy-MM-dd')

# --- Configuration Variables ---
$config_RemoteLogDir = "\\iusnas05\SIJ\CAU-2012\logs"
$config_SoftwareBasePath = "\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas"
$config_DriverBasePath = "\\iusnas05\DDPP\COMUN\_DRIVERS\lectores tarjetas"

$config_IslMsiPath = Join-Path $config_SoftwareBasePath "isl.msi"
$config_FnmtConfigExe = Join-Path $config_SoftwareBasePath "Configurador_FNMT_5.0.0_64bits.exe"
$config_AutoFirmaExe = Join-Path $config_SoftwareBasePath "AutoFirma_64_v1_8_3_installer.exe"
$config_AutoFirmaMsi = Join-Path $config_SoftwareBasePath "AutoFirma_v1_6_0_JAv05_installer_64.msi" # Check if this is still needed alongside the .exe
$config_ChromeMsiPath = Join-Path $config_SoftwareBasePath "chrome.msi"
$config_LibreOfficeMsiPath = Join-Path $config_SoftwareBasePath "LibreOffice.msi"

$config_DriverPctPath = Join-Path $config_DriverBasePath "PCT-331_V8.52\SCR3xxx_V8.52.exe"
$config_DriverSatellitePath = Join-Path $config_DriverBasePath "satellite pro a50c169 smartcard\smr-20151028103759\TCJ0023500B.exe"

$config_UrlMiCuentaJunta = "https://micuenta.juntadeandalucia.es/micuenta/es.juntadeandalucia.micuenta.servlets.LoginInicial"
$config_UrlFnmtSolicitar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/solicitar-certificado"
$config_UrlFnmtRenovar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/renovar/solicitar-renovacion"
$config_UrlFnmtDescargar = "https://www.sede.fnmt.gob.es/certificados/persona-fisica/obtener-certificado-software/descargar-certificado"

$config_ScriptVersion = "1.0.0" # PowerShell Migration
# --- End Configuration Variables ---

# --- Global Script Variables ---
$global:adUser = $null
$global:userProfileName = $env:USERNAME
$global:currentHostname = $env:COMPUTERNAME
$global:LOG_DIR = Join-Path $env:TEMP "CAUJUS_Logs"
$global:LOG_FILE = "" # Will be set after AD user input

# --- Jump Host Check ---
if ($env:COMPUTERNAME -eq "IUSSWRDPCAU02") {
    Write-Error "Error, se está ejecutando el script desde la máquina de salto."
    Read-Host "Presiona Enter para salir..."
    exit 1
}

# --- Initial User Setup & Logging Initialization ---
try {
    $global:adUser = Read-Host "Introduce tu usuario de AD (sin @JUSTICIA)"
    if ([string]::IsNullOrWhiteSpace($global:adUser)) {
        Write-Error "El usuario de AD no puede estar vacío."
        Read-Host "Presiona Enter para salir..."
        exit 1
    }

    $global:userProfileName = $env:USERNAME # Already set globally, but good to be aware here
    $global:currentHostname = $env:COMPUTERNAME # Already set globally

    # Set the full LOG_FILE path now that adUser is known
    $timestampLogName = Get-Date -Format "yyyyMMdd_HHmmss"
    $global:LOG_FILE = Join-Path $global:LOG_DIR "$($global:adUser)_$($global:currentHostname)_$($timestampLogName).log"

    # Initial log messages
    Write-Log -Message "Script CAUJUS_dev.ps1 started."
    Write-Log -Message "User: $($global:userProfileName), AD User: $($global:adUser), Machine: $($global:currentHostname). Logging to: $($global:LOG_FILE)"

    # Attempt to pre-create log directory here explicitly if Write-Log doesn't handle it early enough for first message
    if (-not (Test-Path $global:LOG_DIR -PathType Container)) {
        New-Item -Path $global:LOG_DIR -ItemType Directory -Force | Out-Null
        Write-Log -Message "Log directory created: $($global:LOG_DIR)"
    } else {
        Write-Log -Message "Log directory already exists: $($global:LOG_DIR)"
    }

    Write-Log -Message "Attempting initial ISL MSI installation for $adUser@JUSTICIA."
    $islCommand = "msiexec /i \`"$($config_IslMsiPath)\`" /qn" # Path to MSI is quoted for msiexec
    Write-Log -Message "Preparing ISL installation command: $islCommand"

    $islInstallResult = Invoke-ElevatedCommand -CommandToRun $islCommand

    if ($islInstallResult -eq 0) {
        Write-Log -Message "Initial ISL MSI installation via Invoke-ElevatedCommand succeeded."
    } else {
        Write-Log -Message "Initial ISL MSI installation via Invoke-ElevatedCommand failed or ran with errors. Exit code: $islInstallResult" -Level "ERROR"
    }

}
catch {
    Write-Error "Error durante la configuración inicial: $($_.Exception.Message)"
    # Try to log the error if possible
    if (-not [string]::IsNullOrWhiteSpace($global:LOG_FILE))) {
        Write-Log -Message "CRITICAL ERROR during initial setup: $($_.Exception.Message)" -Level "ERROR"
    }
    Read-Host "Presiona Enter para salir..."
    exit 1
}
# --- End Initial User Setup & Logging Initialization ---

# --- Logging Functionality ---
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "RUNAS")]
        [string]$Level = "INFO"
    )

    # Ensure Log Directory Exists
    if (-not (Test-Path $global:LOG_DIR -PathType Container)) {
        try {
            New-Item -Path $global:LOG_DIR -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Failed to create log directory: $($global:LOG_DIR). Error: $($_.Exception.Message)"
            # Fallback or critical error handling might be needed if logging is absolutely essential before this point
            return
        }
    }

    # Ensure LOG_FILE is initialized (it will be fully set after AD User input)
    if ([string]::IsNullOrWhiteSpace($global:LOG_FILE)) {
        # This condition is a safeguard. LOG_FILE should be set before the first important log message.
        # For now, we won't log if LOG_FILE isn't set, or we could define a temporary pre-init log.
        # However, the plan is to set LOG_FILE after getting $adUser.
        Write-Warning "LOG_FILE is not set. Message not logged: $Message"
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Level - $Message"

    try {
        Add-Content -Path $global:LOG_FILE -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $($global:LOG_FILE). Error: $($_.Exception.Message)"
    }
}
# --- End Logging Functionality ---

# --- Helper Function for Executing Commands with Elevation ---
function Invoke-ElevatedCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CommandToRun,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewWindow = $true # Default to true for cmd /c commands
    )

    if ([string]::IsNullOrWhiteSpace($global:adUser)) {
        Write-Log -Message "Invoke-ElevatedCommand: adUser is not set. Cannot proceed." -Level "ERROR"
        # Optionally, re-prompt or exit
        # Read-Host "Critical error: AD User not set. Press Enter to exit."
        # exit 1 # Or handle more gracefully depending on where it's called
        return -1 # Indicate failure
    }

    $fullUser = "$($global:adUser)@JUSTICIA"
    # Ensure the command within quotes is properly escaped if it contains quotes itself.
    # For simple commands passed as strings, direct embedding is often fine.
    # Complex commands might need careful handling of nested quotes.
    $runasArgs = "/user:$fullUser /savecred `"$CommandToRun`""

    Write-Log -Message "Attempting to execute with elevation: $CommandToRun (User: $fullUser)" -Level "RUNAS"

    try {
        $process = Start-Process runas.exe -ArgumentList $runasArgs -Wait -PassThru -ErrorAction Stop -WindowStyle Hidden # Use Hidden for console commands
        if ($NoNewWindow -eq $false) { # If a new window is expected/allowed (e.g. for GUI apps)
             $process = Start-Process runas.exe -ArgumentList $runasArgs -Wait -PassThru -ErrorAction Stop
        }


        Write-Log -Message "Elevated command executed. Command: `"$CommandToRun`". Exit Code: $($process.ExitCode)" -Level "INFO"
        return $process.ExitCode
    }
    catch {
        Write-Log -Message "Failed to start elevated process for command: `"$CommandToRun`". Error: $($_.Exception.Message)" -Level "ERROR"
        # Specific error for access denied if runas itself fails due to bad creds (though /savecred complicates this)
        if ($_.Exception.NativeErrorCode -eq 5) { # Access is denied
             Write-Log -Message "Access Denied error when trying to runas. Ensure credentials for $fullUser are saved and valid." -Level "ERROR"
        }
        return -1 # Indicate failure (or a specific error code)
    }
}
# --- End Helper Function ---

# --- Helper Function for Executing Elevated PowerShell ScriptBlocks ---
function Invoke-ElevatedPowerShellCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptBlockContent,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewWindow = $true # Default to true, similar to Invoke-ElevatedCommand for console commands
    )

    Write-Log -Message "Preparing to run elevated PowerShell script content." -Level "INFO"

    try {
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ScriptBlockContent))
        $commandForPowerShell = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

        Write-Log -Message "Encoded PowerShell command: $commandForPowerShell" # Log the command for debugging if needed

        $exitCode = Invoke-ElevatedCommand -CommandToRun $commandForPowerShell -NoNewWindow:$NoNewWindow
        return $exitCode
    }
    catch {
        Write-Log -Message "Error preparing or invoking elevated PowerShell command: $($_.Exception.Message)" -Level "ERROR"
        return -1 # Indicate failure
    }
}
# --- End Helper Function for Elevated PowerShell ---

# --- Log Upload Functionality ---
function Upload-LogFile {
    [CmdletBinding()]
    param () # No parameters needed, uses global vars

    if ([string]::IsNullOrWhiteSpace($global:LOG_FILE) -or (-not (Test-Path $global:LOG_FILE -PathType Leaf))) {
        Write-Log -Message "Upload-LogFile: Log file path is not set or file does not exist: $($global:LOG_FILE)" -Level "WARN"
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($config_RemoteLogDir)) {
        Write-Log -Message "Upload-LogFile: Remote log directory (config_RemoteLogDir) is not configured." -Level "ERROR"
        return $false
    }

    Write-Log -Message "Preparing to upload log file $($global:LOG_FILE) to network share."

    # Extract filename from the full path of $global:LOG_FILE
    $logFileName = Split-Path -Path $global:LOG_FILE -Leaf
    $finalLogPathOnShare = Join-Path $config_RemoteLogDir $logFileName

    # Ensure remote log directory exists using PowerShell command via Invoke-ElevatedPowerShellCommand
    # Using -LiteralPath for Test-Path and New-Item to handle potential special characters in $config_RemoteLogDir
    $psMkdirCommand = "if (-not (Test-Path -LiteralPath \`"$config_RemoteLogDir\`" -PathType Container)) { New-Item -Path \`"$config_RemoteLogDir\`" -ItemType Directory -Force -ErrorAction Stop | Out-Null }"
    Write-Log -Message "Ensuring remote log directory exists with PowerShell script block: $psMkdirCommand"
    $mkdirResult = Invoke-ElevatedPowerShellCommand -ScriptBlockContent $psMkdirCommand # -NoNewWindow $true is default

    if ($mkdirResult -ne 0) {
        Write-Log -Message "Failed to create or verify remote log directory using Invoke-ElevatedPowerShellCommand: $config_RemoteLogDir. PowerShell execution Exit Code: $mkdirResult. Upload aborted." -Level "ERROR"
        return $false
    }
    Write-Log -Message "Remote log directory confirmed or created: $config_RemoteLogDir"

    # Copy the log file using PowerShell Copy-Item via Invoke-ElevatedPowerShellCommand
    # Using -LiteralPath for source and -Destination for target path
    $psCopyCommand = "Copy-Item -LiteralPath \`"$($global:LOG_FILE)\`" -Destination \`"$finalLogPathOnShare\`" -Force -ErrorAction Stop"
    Write-Log -Message "Attempting to copy log file with PowerShell script block: $psCopyCommand"
    $copyResult = Invoke-ElevatedPowerShellCommand -ScriptBlockContent $psCopyCommand # -NoNewWindow $true is default

    if ($copyResult -eq 0) {
        Write-Log -Message "Log file upload attempt with Invoke-ElevatedPowerShellCommand successful to $finalLogPathOnShare."
        return $true
    } else {
        Write-Log -Message "Log file upload with Invoke-ElevatedPowerShellCommand failed. PowerShell execution Exit Code: $copyResult. Source: $($global:LOG_FILE), Destination: $finalLogPathOnShare" -Level "ERROR"
        return $false
    }
}
# --- End Log Upload Functionality ---

# --- Self-Delete Functionality ---
function Invoke-SelfDelete {
    [CmdletBinding()]
    param ()

    Write-Log -Message "Initiating self-delete sequence."

    # Upload the log file before deleting the script
    Write-Log -Message "Attempting to upload log file before self-deletion."
    $uploadSuccess = Upload-LogFile
    if ($uploadSuccess) {
        Write-Log -Message "Log file uploaded successfully prior to self-delete."
    } else {
        Write-Log -Message "Log file upload failed or was skipped prior to self-delete. Check previous logs." -Level "WARN"
    }

    $currentScriptPath = $MyInvocation.MyCommand.Path
    Write-Log -Message "Script path to be deleted: $currentScriptPath"

    try {
        # Log this message just before actual deletion
        Write-Log -Message "Attempting to delete the script file now: $currentScriptPath"

        # Brief pause to ensure log is written before file disappears
        Start-Sleep -Milliseconds 200

        Remove-Item -Path $currentScriptPath -Force -ErrorAction Stop

        # This message below won't be logged to the deleted file,
        # but it's here for completeness of what the function tries to do.
        # If there was a central/external logging, it could go there.
        # Write-Log -Message "Script file has been deleted." # This won't make it to its own log

        Write-Host "Script has been removed and will now exit."
        Start-Sleep -Seconds 1 # Allow user to see message
        Exit 0 # Exit script execution
    }
    catch {
        # This will also likely not make it to the log file if deletion was partial or path is now bad
        Write-Log -Message "Error during self-deletion: $($_.Exception.Message). Script may still exist at $currentScriptPath" -Level "ERROR"
        Write-Host "Error attempting to self-delete. Script may still exist."
        Read-Host "Press Enter to exit."
        Exit 1 # Exit with an error code
    }
}
# --- End Self-Delete Functionality ---

# --- Batery_test Helper Functions ---
function Stop-CommonBrowsers {
    Write-Log -Message "BT: Killing common browser processes."
    $browsers = "chrome", "iexplore", "msedge", "firefox" # Added firefox
    foreach ($browser in $browsers) {
        Stop-Process -Name $browser -Force -ErrorAction SilentlyContinue
        if ($?) { Write-Log -Message "BT: Process $browser stopped or was not running." } # $? might be true even if process not found with SilentlyContinue
    }
}

function Clear-SystemAndUserCaches {
    Write-Log -Message "BT: Clearing system and user caches."

    Write-Log -Message "BT: Flushing DNS cache."
    Clear-DnsClientCache
    Write-Log -Message "BT: DNS cache flushed."

    $clearTracksCommands = @(
        "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16", # Passwords
        "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8",  # History
        "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2",  # Cookies
        "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1"   # Temp Internet Files
    )
    foreach ($command in $clearTracksCommands) {
        Write-Log -Message "BT: Executing cache clearing: $command"
        try {
            # Splitting command and arguments for Start-Process
            $executable = $command.Split(' ',2)[0]
            $arguments = $command.Split(' ',2)[1]
            Start-Process -FilePath $executable -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction Stop
            Write-Log -Message "BT: Successfully executed $command"
        } catch {
            Write-Log -Message "BT: Failed to execute $command. Error: $($_.Exception.Message)" -Level "WARN"
        }
    }

    $chromeCachePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache"
    if (Test-Path $chromeCachePath) {
        Write-Log -Message "BT: Clearing Chrome cache at $chromeCachePath"
        # Ensure the path for Remove-Item is correctly quoted if it might contain spaces, though $chromeCachePath typically doesn't.
        Remove-Item -Path "$($chromeCachePath)\*" -Recurse -Force -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0 -or $? ) { Write-Log -Message "BT: Chrome cache cleared or attempt finished."} # Check $? or $LASTEXITCODE
    } else {
        Write-Log -Message "BT: Chrome cache path not found: $chromeCachePath" -Level "WARN"
    }
}

function Apply-VisualEffectRegTweaks {
    Write-Log -Message "BT: Applying visual effect registry tweaks."
    # Using HKCU paths directly. These are applied to the user context under which Invoke-ElevatedCommand runs the REG command.
    # If $adUser is different from current user, these apply to $adUser's HKCU.
    $regTweaks = @{
        "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" = @{ "MinAnimate" = @{ Value = "0"; Type = "REG_SZ" } }
        "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" = @{ "TaskbarAnimations" = @{ Value = 0; Type = "REG_DWORD" } }
        "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" = @{
            "VisualFXSetting" = @{ Value = 2; Type = "REG_DWORD" };
            "ComboBoxAnimation" = @{ Value = 0; Type = "REG_DWORD" };
            "CursorShadow" = @{ Value = 0; Type = "REG_DWORD" };
            "DropShadow" = @{ Value = 0; Type = "REG_DWORD" };
            "ListBoxSmoothScrolling" = @{ Value = 0; Type = "REG_DWORD" };
            "MenuAnimation" = @{ Value = 0; Type = "REG_DWORD" };
            "SelectionFade" = @{ Value = 0; Type = "REG_DWORD" };
            "TooltipAnimation" = @{ Value = 0; Type = "REG_DWORD" };
            "Fade" = @{ Value = 0; Type = "REG_DWORD" } # Assuming this was for VisualEffects too
        }
    }

    foreach ($path in $regTweaks.Keys) {
        $values = $regTweaks[$path]
        foreach ($name in $values.Keys) {
            $item = $values[$name]
            $valueData = $item.Value
            $valueType = $item.Type

            # Path for REG ADD needs to be unescaped (no 'HKEY_CURRENT_USER:' prefix from PS)
            $regPathForCommand = $path.Replace("HKEY_CURRENT_USER", "HKCU") # Or use full HKEY_CURRENT_USER
                                    .Replace("HKEY_LOCAL_MACHINE", "HKLM") # If ever needed

            $command = "REG ADD `"$regPathForCommand`" /v `"$name`" /t $valueType /d `"$valueData`" /f"
            Write-Log -Message "BT: Applying reg tweak: $command"
            $result = Invoke-ElevatedCommand -CommandToRun $command
            if ($result -ne 0) {
                Write-Log -Message "BT: Failed to apply reg tweak for $name at $regPathForCommand. Exit code: $result" -Level "WARN"
            }
        }
    }
    Write-Log -Message "BT: Visual effect registry tweaks application process finished."
}

function Perform-SystemMaintenanceTasks {
    Write-Log -Message "BT: Performing system maintenance tasks."

    Write-Log -Message "BT: Running gpupdate /force."
    $gpResult = Invoke-ElevatedCommand -CommandToRun "gpupdate /force"
    Write-Log -Message "BT: gpupdate /force completed. Exit code: $gpResult"

    Write-Log -Message "BT: Ensuring ISL is installed (re-running installer)."
    $islCommand = "msiexec /i `"$($config_IslMsiPath)`" /qn" # $config_IslMsiPath should be correctly defined globally
    $islResult = Invoke-ElevatedCommand -CommandToRun $islCommand
    Write-Log -Message "BT: ISL MSI installer executed. Exit code: $islResult"

    # System-wide paths for cleaning
    Write-Log -Message "BT: Cleaning system-wide paths."
    $pathsToCleanSystemDrive = @(
        "%windir%\*.bak",
        "%windir%\SoftwareDistribution\Download\*.*",
        "%SystemDrive%\*.tmp",
        "%SystemDrive%\*._mp",
        "%SystemDrive%\*.gid",
        "%SystemDrive%\*.chk",
        "%SystemDrive%\*.old"
    )

    foreach ($pathPattern in $pathsToCleanSystemDrive) {
        $psPath = $pathPattern.Replace("%windir%", '$env:windir') `
                               .Replace("%SystemDrive%", '$env:SystemDrive') `
                               .Replace("%TEMP%", '$env:TEMP') `
                               .Replace("%LOCALAPPDATA%", '$env:LOCALAPPDATA') `
                               .Replace("%APPDATA%", '$env:APPDATA') `
                               .Replace("*.*", "*") `
                               .Replace("`"", "") # Remove outer quotes from original pattern if any were left

        $psCommand = "Remove-Item -Path '${psPath}' -Recurse -Force -ErrorAction Stop"
        Write-Log -Message "BT: Cleaning files with PowerShell script block: $psCommand"
        Invoke-ElevatedPowerShellCommand -ScriptBlockContent $psCommand
    }

    # User-specific paths for cleaning
    Write-Log -Message "BT: Cleaning user-specific paths (Note: context is for AD User: $($global:adUser))." -Level "WARN"
    $userSpecificPathsForElevatedDel = @(
        "%TEMP%\*.*",
        "%LOCALAPPDATA%\Microsoft\Windows\Temporary Internet Files\*.*",
        "%LOCALAPPDATA%\Microsoft\Windows\INetCache\*.*",
        "%LOCALAPPDATA%\Microsoft\Windows\INetCookies\*.*",
        "%LOCALAPPDATA%\Microsoft\Terminal Server Client\Cache\*.*",
        "%LOCALAPPDATA%\CrashDumps\*.*",
        "%APPDATA%\Microsoft\Windows\cookies\*.*"
    )

    foreach ($pathPattern in $userSpecificPathsForElevatedDel) {
        $psPath = $pathPattern.Replace("%windir%", '$env:windir') `
                               .Replace("%SystemDrive%", '$env:SystemDrive') `
                               .Replace("%TEMP%", '$env:TEMP') `
                               .Replace("%LOCALAPPDATA%", '$env:LOCALAPPDATA') `
                               .Replace("%APPDATA%", '$env:APPDATA') `
                               .Replace("*.*", "*") `
                               .Replace("`"", "")

        # For user-specific paths, it's good to ensure the parent directory exists before attempting deletion,
        # though Remove-Item with -Force and SilentlyContinue handles non-existent paths gracefully.
        # The original IF EXIST was for cmd.exe; Remove-Item handles this inherently.
        $psCommand = "Remove-Item -Path '${psPath}' -Recurse -Force -ErrorAction Stop"
        Write-Log -Message "BT: Cleaning user files with PowerShell script block: $psCommand"
        Invoke-ElevatedPowerShellCommand -ScriptBlockContent $psCommand
    }

    # Recreating folders
    Write-Log -Message "BT: Recreating specified folders (Note: context is for AD User: $($global:adUser) if env vars like %windir% are used directly)."
    $foldersToRecreate = @(
        "%windir%\Temp"
        # "%USERPROFILE%\Local Settings\Temp" # This is effectively $env:TEMP, handled by user specific cleaning if pattern matches
    )

    foreach ($folderPathPattern in $foldersToRecreate) {
        $psPath = $folderPathPattern.Replace("%windir%", '$env:windir') `
                                    .Replace("%SystemDrive%", '$env:SystemDrive') `
                                    .Replace("%TEMP%", '$env:TEMP') `
                                    .Replace("%LOCALAPPDATA%", '$env:LOCALAPPDATA') `
                                    .Replace("%APPDATA%", '$env:APPDATA') `
                                    .Replace("`"", "")

        $psCommand = "Remove-Item -Path '${psPath}' -Recurse -Force -ErrorAction Stop; New-Item -Path '${psPath}' -ItemType Directory -Force -ErrorAction Stop"
        Write-Log -Message "BT: Recreating folder with PowerShell script block: $psCommand"
        Invoke-ElevatedPowerShellCommand -ScriptBlockContent $psCommand
    }
    Write-Log -Message "BT: System maintenance tasks finished."
}
# --- End Batery_test Helper Functions ---

# --- Batery_test Main Function ---
function Invoke-BatteryTest {
    Write-Log -Message "Action: Starting Batery_test."

    Stop-CommonBrowsers
    Clear-SystemAndUserCaches
    Apply-VisualEffectRegTweaks
    Perform-SystemMaintenanceTasks

    Write-Log -Message "INFO - Action: Prompting for restart in Batery_test."
    Write-Host "`nBateria de pruebas completada." # Added newline for better spacing

    $validResponse = $false
    $restartChoice = ""
    while (-not $validResponse) {
        $restartChoice = Read-Host "Reiniciar equipo ahora? (s/n)"
        if ($restartChoice.ToLower() -match '^[sn]$') { # .ToLower() for case-insensitivity
            $validResponse = $true
        } else {
            Write-Warning "Respuesta no válida. Introduce 's' para sí o 'n' para no."
        }
    }

    if ($restartChoice.ToLower() -eq 's') { # Ensure case-insensitivity for safety
        Write-Log -Message "User chose to restart."

        Write-Log -Message "Attempting to upload log file before system restart."
        $uploadSuccess = Upload-LogFile
        if ($uploadSuccess) {
            Write-Log -Message "Log file uploaded successfully before restart."
        } else {
            Write-Log -Message "Log file upload failed or was skipped before restart. Check previous logs." -Level "WARN"
        }

        Write-Log -Message "Initiating computer restart NOW."
        Restart-Computer -Force

        # --- Best effort self-delete after restart command ---
        # The following lines are a best-effort attempt as Restart-Computer might terminate script execution abruptly.
        Write-Log -Message "Attempting self-deletion of script post-restart command (best effort)."
        $currentScriptPathForDelete = $MyInvocation.MyCommand.Path # Use a different variable name to avoid conflict if $currentScriptPath is used elsewhere
        try {
            # Brief pause, may allow logs to flush or restart to fully initialize in background.
            Start-Sleep -Milliseconds 250
            if (Test-Path $currentScriptPathForDelete -PathType Leaf) {
                Remove-Item -Path $currentScriptPathForDelete -Force -ErrorAction SilentlyContinue
                # Log this attempt, but it might not be written if restart is too fast.
                # Consider that this log entry is for a scenario where the script *might* continue for a moment.
                Add-Content -Path $global:LOG_FILE -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - INFO - Best-effort self-delete: Remove-Item command issued for $currentScriptPathForDelete." -ErrorAction SilentlyContinue
            }
        }
        catch {
            # This catch block and its log are also best-effort.
            Add-Content -Path $global:LOG_FILE -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - WARN - Best-effort self-delete: Error trying to remove script $currentScriptPathForDelete. Error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
        }
        # Script execution will be taken over by the restart process. No explicit Exit needed here.
    } else {
        Write-Log -Message "User chose not to restart. Uploading log and self-deleting script."
        Invoke-SelfDelete # This function handles log upload, script deletion, and then Exits.
    }
    # Script execution effectively stops here due to Invoke-SelfDelete or Restart-Computer (in the 's' case).
}
# --- End Batery_test Main Function ---

# --- Cambiar password correo Function ---
function Invoke-OpenChangePasswordUrl {
    Write-Log -Message "Action: Starting Invoke-OpenChangePasswordUrl. Opening URL: $($config_UrlMiCuentaJunta)"

    try {
        Start-Process "chrome.exe" -ArgumentList $config_UrlMiCuentaJunta -ErrorAction Stop
        Write-Log -Message "Successfully launched Chrome with URL: $($config_UrlMiCuentaJunta)"
    }
    catch {
        Write-Log -Message "Failed to start Chrome with URL: $($config_UrlMiCuentaJunta). Error: $($_.Exception.Message)" -Level "ERROR"
        Write-Warning "No se pudo abrir Chrome. Verifica que esté instalado y accesible."
        # Decide if we should still self-delete or return to menu
        Read-Host "Presiona Enter para continuar..."
        return # Return to main menu if Chrome fails to start
    }

    # Original script self-deletes after this action
    Write-Log -Message "URL opened. Script will now self-delete as per original logic."
    Invoke-SelfDelete # This handles log upload, script deletion, and exit
}
# --- End Cambiar password correo Function ---

# --- Reiniciar cola impresion Function ---
function Invoke-ResetPrintSpooler {
    Write-Log -Message "Action: Starting Invoke-ResetPrintSpooler."

    # The command from the batch script is complex due to FOR loop and embedded commands.
    # Escaping for cmd /c run via Invoke-ElevatedCommand needs care.
    # Original: FOR /F "tokens=3,*" %%a IN ('cscript c:\windows\System32\printing_Admin_Scripts\es-ES\prnmngr.vbs -l ^| FINDSTR "Nombre de impresora"') DO cscript c:\windows\System32\printing_Admin_Scripts\es-ES\prnqctl.vbs -m -p "%%b"
    # PowerShell translation for the command string:
    # - %%a becomes %a, %%b becomes %b inside the cmd /c string
    # - Inner single quotes for the IN clause of FOR
    # - Escaped quotes for FINDSTR and for -p parameter
    # - Pipe character ^| becomes just | within the cmd /c string, but might need escaping if PowerShell parses it first.
    #   It's safer to pass the whole thing as a literal string to cmd /c.

    $vbScriptPath = "c:\windows\System32\printing_Admin_Scripts\es-ES" # Standard path
    $prnmngrCmd = "cscript.exe `"$vbScriptPath\prnmngr.vbs`" -l"
    $findstrCmd = "FINDSTR `"/C:Nombre de impresora`"" # Using /C: for literal search string
    $prnqctlBaseCmd = "cscript.exe `"$vbScriptPath\prnqctl.vbs`" -m -p"

    # Constructing the FOR loop command string for cmd.exe:
    # Note: %%a and %%b are for batch files. In a direct CMD command line, it's %a and %b.
    # The `cmd /c` will interpret %a and %b correctly.
    $commandToRun = "FOR /F `"tokens=3,*`" %a IN ('$prnmngrCmd ^| $findstrCmd') DO $prnqctlBaseCmd `"%b`""
    # Full command for cmd /c
    $fullCmdCommand = "cmd /c $commandToRun"

    Write-Log -Message "Attempting to reset printer queues with command: $fullCmdCommand" -Level "RUNAS"

    $result = Invoke-ElevatedCommand -CommandToRun $fullCmdCommand -NoNewWindow $true # Ensure NoNewWindow

    if ($result -eq 0) {
        Write-Log -Message "Printer queue reset command executed successfully (Exit Code: $result)."
        Write-Host "Comando para reiniciar las colas de impresión ejecutado."
    } else {
        Write-Log -Message "Printer queue reset command failed or executed with errors (Exit Code: $result)." -Level "ERROR"
        Write-Warning "El comando para reiniciar las colas de impresión pudo haber fallado (Código de salida: $result)."
    }

    # Original script self-deletes after this action
    Write-Log -Message "Printer queue reset action finished. Script will now self-delete."
    # Give a moment for user to see any messages from the command if it wasn't entirely silent.
    Read-Host "Presiona Enter para continuar con la salida del script..."
    Invoke-SelfDelete # This handles log upload, script deletion, and exit
}
# --- End Reiniciar cola impresion Function ---

# --- Administrador de dispositivos Function ---
function Show-DeviceManager {
    Write-Log -Message "Action: Starting Show-DeviceManager. Opening Device Manager."

    # This corresponds to line 214 of the original batch script:
    # CALL :ExecuteWithRunas "RunDll32.exe devmgr.dll DeviceManager_Execute"
    $commandToRun = "RunDll32.exe devmgr.dll DeviceManager_Execute"

    Write-Log -Message "Attempting to open Device Manager with command: $commandToRun" -Level "RUNAS"
    $result = Invoke-ElevatedCommand -CommandToRun $commandToRun -NoNewWindow $false # Ensure GUI is visible

    if ($result -eq 0) {
        Write-Log -Message "Device Manager launch command executed successfully (Exit Code: $result)."
        Write-Host "Device Manager debería haberse iniciado."
    } else {
        Write-Log -Message "Device Manager launch command failed or executed with errors (Exit Code: $result)." -Level "ERROR"
        Write-Warning "El comando para iniciar el Administrador de Dispositivos pudo haber fallado (Código de salida: $result)."
    }

    # Unlike other options, the original script returns to the main menu here, no self-delete.
    Write-Log -Message "Device Manager action finished. Returning to main menu."
    Read-Host "Presiona Enter para volver al menú principal..."
    # Show-MainMenu will be called by the main loop after this function returns
}
# --- End Administrador de dispositivos Function ---

# --- Manage Digital Certificates Menu ---
function Manage-DigitalCertificatesMenu {
    Write-Log -Message "Action: Navigated to Digital Certificates Menu."
    Clear-Host
    Write-Host "------------------------------------------"
    Write-Host "             CERTIFICADOS DIGITALES"
    Write-Host "------------------------------------------"
    Write-Host "1. Abrir FNMT: Solicitar Certificado"
    Write-Host "2. Abrir FNMT: Renovar Certificado"
    Write-Host "3. Abrir FNMT: Descargar Certificado"
    Write-Host "4. Abrir Administrador de Certificados (certmgr.msc)"
    Write-Host "M. Volver al Menú Principal"
    Write-Host ""

    $certChoice = Read-Host "Escoge una opcion"
    Write-Log -Message "Digital Certificates Menu: User selected option '$certChoice'."

    switch ($certChoice.ToLower()) { # Use .ToLower() for case-insensitivity
        '1' {
            Write-Log -Message "Attempting to open FNMT Solicitar URL: $config_UrlFnmtSolicitar"
            try {
                Start-Process "chrome.exe" -ArgumentList $config_UrlFnmtSolicitar -ErrorAction Stop
                Write-Log -Message "Successfully launched Chrome with FNMT Solicitar URL."
            }
            catch {
                Write-Log -Message "Failed to start Chrome for FNMT Solicitar URL. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir Chrome para FNMT Solicitar. Verifica que esté instalado."
            }
            Read-Host "Presiona Enter para continuar..."
            Manage-DigitalCertificatesMenu # Loop back
        }
        '2' {
            Write-Log -Message "Attempting to open FNMT Renovar URL: $config_UrlFnmtRenovar"
            try {
                Start-Process "chrome.exe" -ArgumentList $config_UrlFnmtRenovar -ErrorAction Stop
                Write-Log -Message "Successfully launched Chrome with FNMT Renovar URL."
            }
            catch {
                Write-Log -Message "Failed to start Chrome for FNMT Renovar URL. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir Chrome para FNMT Renovar. Verifica que esté instalado."
            }
            Read-Host "Presiona Enter para continuar..."
            Manage-DigitalCertificatesMenu # Loop back
        }
        '3' {
            Write-Log -Message "Attempting to open FNMT Descargar URL: $config_UrlFnmtDescargar"
            try {
                Start-Process "chrome.exe" -ArgumentList $config_UrlFnmtDescargar -ErrorAction Stop
                Write-Log -Message "Successfully launched Chrome with FNMT Descargar URL."
            }
            catch {
                Write-Log -Message "Failed to start Chrome for FNMT Descargar URL. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir Chrome para FNMT Descargar. Verifica que esté instalado."
            }
            Read-Host "Presiona Enter para continuar..."
            Manage-DigitalCertificatesMenu # Loop back
        }
        '4' {
            Write-Log -Message "Attempting to open Certificate Manager (certmgr.msc)."
            try {
                Start-Process "certmgr.msc" -ErrorAction Stop
                Write-Log -Message "Successfully launched certmgr.msc."
            }
            catch {
                Write-Log -Message "Failed to start certmgr.msc. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir el Administrador de Certificados (certmgr.msc)."
            }
            Read-Host "Presiona Enter para continuar..."
            Manage-DigitalCertificatesMenu # Loop back
        }
        'm' {
            Write-Log -Message "Returning to Main Menu from Digital Certificates Menu."
            return # This will allow Show-MainMenu to redisplay itself
        }
        default {
            Write-Log -Message "Invalid option '$certChoice' selected in Digital Certificates Menu." -Level "WARN"
            Write-Warning "'$certChoice' opcion no valida, intentalo de nuevo."
            Start-Sleep -Seconds 2
            Manage-DigitalCertificatesMenu # Loop back
        }
    }
}
# --- End Manage Digital Certificates Menu ---

# --- Show ISL Always On Info ---
function Show-IslAlwaysOnInfo {
    Write-Log -Message "Action: Navigated to ISL Always On Info."
    Clear-Host
    Write-Host "------------------------------------------"
    Write-Host "                 ISL ALWAYS ON"
    Write-Host "------------------------------------------"
    Write-Host "Configurar ISL Always On (Acceso Remoto Permanente) es una tarea compleja"
    Write-Host "que usualmente requiere paquetes de instalación específicos y configuración detallada."
    Write-Host ""
    Write-Host "Esta funcionalidad está prevista para una futura implementación automatizada."
    Write-Host "Por ahora, la configuración podría necesitar realizarse manualmente."
    Write-Host ""
    Write-Host "- El software de ISL (si está disponible centralmente) podría encontrarse en:"
    Write-Host "  $config_SoftwareBasePath"
    Write-Host "- El script intentó una instalación inicial de ISL Light Client desde:"
    Write-Host "  $config_IslMsiPath"
    Write-Host "- Asegúrate que ISL Light Client esté instalado y configurado según sea necesario."
    Write-Host ""
    Read-Host "Presiona Enter para volver al menú principal..."
    Write-Log -Message "User returning from ISL Always On Info to Main Menu."
    # Show-MainMenu will be called by the main loop after this function returns
}
# --- End Show ISL Always On Info ---

# --- Show Utilities Menu ---
function Show-UtilitiesMenu {
    Write-Log -Message "Action: Navigated to Utilities Menu."
    Clear-Host
    Write-Host "------------------------------------------"
    Write-Host "                   UTILIDADES"
    Write-Host "------------------------------------------"
    Write-Host "1. Abrir Liberador de espacio en disco (cleanmgr.exe)"
    Write-Host "2. Abrir Información del sistema (msinfo32.exe)"
    Write-Host "3. Abrir Visor de eventos (eventvwr.msc)"
    Write-Host "4. Abrir Administrador de Tareas (taskmgr.exe)"
    Write-Host "M. Volver al Menú Principal"
    Write-Host ""

    $utilChoice = Read-Host "Escoge una opcion"
    Write-Log -Message "Utilities Menu: User selected option '$utilChoice'."

    switch ($utilChoice.ToLower()) { # Use .ToLower() for case-insensitivity
        '1' {
            Write-Log -Message "Attempting to open Disk Cleanup (cleanmgr.exe)."
            try {
                Start-Process "cleanmgr.exe" -ErrorAction Stop
                Write-Log -Message "Successfully launched cleanmgr.exe."
            }
            catch {
                Write-Log -Message "Failed to start cleanmgr.exe. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir el Liberador de espacio en disco."
            }
            Read-Host "Presiona Enter para continuar..."
            Show-UtilitiesMenu # Loop back
        }
        '2' {
            Write-Log -Message "Attempting to open System Information (msinfo32.exe)."
            try {
                Start-Process "msinfo32.exe" -ErrorAction Stop
                Write-Log -Message "Successfully launched msinfo32.exe."
            }
            catch {
                Write-Log -Message "Failed to start msinfo32.exe. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir Información del sistema."
            }
            Read-Host "Presiona Enter para continuar..."
            Show-UtilitiesMenu # Loop back
        }
        '3' {
            Write-Log -Message "Attempting to open Event Viewer (eventvwr.msc)."
            try {
                Start-Process "eventvwr.msc" -ErrorAction Stop
                Write-Log -Message "Successfully launched eventvwr.msc."
            }
            catch {
                Write-Log -Message "Failed to start eventvwr.msc. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir el Visor de eventos."
            }
            Read-Host "Presiona Enter para continuar..."
            Show-UtilitiesMenu # Loop back
        }
        '4' {
            Write-Log -Message "Attempting to open Task Manager (taskmgr.exe)."
            try {
                Start-Process "taskmgr.exe" -ErrorAction Stop
                Write-Log -Message "Successfully launched taskmgr.exe."
            }
            catch {
                Write-Log -Message "Failed to start taskmgr.exe. Error: $($_.Exception.Message)" -Level "ERROR"
                Write-Warning "No se pudo abrir el Administrador de Tareas."
            }
            Read-Host "Presiona Enter para continuar..."
            Show-UtilitiesMenu # Loop back
        }
        'm' {
            Write-Log -Message "Returning to Main Menu from Utilities Menu."
            return # This will allow Show-MainMenu to redisplay itself
        }
        default {
            Write-Log -Message "Invalid option '$utilChoice' selected in Utilities Menu." -Level "WARN"
            Write-Warning "'$utilChoice' opcion no valida, intentalo de nuevo."
            Start-Sleep -Seconds 2
            Show-UtilitiesMenu # Loop back
        }
    }
}
# --- End Show Utilities Menu ---

# (Keep existing placeholder Write-Host lines or remove them as functions are added)
# For testing the Write-Log function during development:
# $global:LOG_FILE = Join-Path $global:LOG_DIR "test_initial.log" # Temporary for direct testing
# Write-Log -Message "Test log entry from initial script structure."
# Write-Log -Message "Another test log entry." -Level "WARN"

# --- Main Menu and System Information ---
function Show-MainMenu {
    Clear-Host # Clears the screen, similar to CLS

    # Gather system information
    $computerName = $global:currentHostname # Already fetched
    $serialNumber = (Get-CimInstance Win32_BIOS).SerialNumber
    # Attempt to get the primary IPv4 address more reliably
    $primaryInterface = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Sort-Object -Property {$_.Name -notlike "Ethernet*"} | Select-Object -First 1
    $ipAddress = "N/A"
    if ($primaryInterface) {
        $ipConfiguration = Get-NetIPConfiguration -InterfaceIndex $primaryInterface.InterfaceIndex
        $ipv4Address = ($ipConfiguration | Select-Object -ExpandProperty IPv4Address | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddress -First 1)
        if ($ipv4Address) {
            $ipAddress = $ipv4Address
        }
    }

    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osCaption = $osInfo.Caption
    $osBuildNumber = $osInfo.BuildNumber

    Write-Log -Message "System Info: User: $($global:userProfileName), AD User: $($global:adUser), Computer: $computerName, SN: $serialNumber, IP: $ipAddress, OS: $osCaption ($osBuildNumber), Script Version: $config_ScriptVersion"

    # Display system information and menu
    Write-Host "------------------------------------------"
    Write-Host "                 CAU"
    Write-Host "------------------------------------------"
    Write-Host ""
    Write-Host "Usuario: $($global:userProfileName)"
    Write-Host "Usuario AD utilizado: $($global:adUser)"
    Write-Host "Nombre equipo: $computerName"
    Write-Host "Numero de serie: $serialNumber"
    Write-Host "Numero de IP: $ipAddress"
    Write-Host "Version: $osCaption, con la compilacion $osBuildNumber"
    Write-Host "Version Script: $config_ScriptVersion"
    Write-Host ""
    Write-Host "1. Bateria pruebas"
    Write-Host "2. Cambiar password correo"
    Write-Host "3. Reiniciar cola impresion"
    Write-Host "4. Administrador de dispositivos (desinstalar drivers)"
    Write-Host "5. Certificado digital"
    Write-Host "6. ISL Allways on"
    Write-Host "7. Utilidades"
    Write-Host "X. Salir" # Added an Exit option
    Write-Host ""

    $choice = Read-Host "Escoge una opcion"

    Write-Log -Message "Main menu: User selected option '$choice'."

    switch ($choice) {
        "1" { Invoke-BatteryTest }
        "2" { Invoke-OpenChangePasswordUrl }
        "3" { Invoke-ResetPrintSpooler }
        "4" { Show-DeviceManager; Show-MainMenu } # Call Show-DeviceManager then return to Show-MainMenu
        "5" { Manage-DigitalCertificatesMenu; Show-MainMenu }
        "6" { Show-IslAlwaysOnInfo; Show-MainMenu }
        "7" { Show-UtilitiesMenu; Show-MainMenu }
        "X" {
            Write-Host "Saliendo del script."
            Write-Log -Message "User selected Exit. Attempting to upload log before terminating."
            Upload-LogFile # Attempt to upload logs on normal exit
            Write-Log -Message "Script terminating now."
            exit 0
        }
        default {
            Write-Host "'$choice' opcion no valida, intentalo de nuevo."
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}
# --- End Main Menu and System Information ---

# --- Main script execution starts here ---
# (This call should be at the very end of the script, after all function definitions)
Show-MainMenu
# --- End Main script execution ---
