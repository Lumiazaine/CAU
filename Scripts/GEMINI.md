# CAU IT Support Scripts - Project Context

## Project Overview
This directory contains a suite of automation tools (PowerShell and Batch) developed for the **CAU IT Support Team** at the **Junta de Andalucía (Justice department)**. The primary goal is to automate common technical support tasks, standardize procedures across corporate workstations (Windows 10/11), and maintain detailed activity logs.

The core application is **CAUJUS**, a menu-driven utility that handles system optimization, software installation, and troubleshooting.

## Project Structure
- **CAUJUS.ps1**: The modern, feature-rich PowerShell version (v3.0). Recommended for Windows 10/11 environments.
- **CAUJUS_refactored.bat**: A modular Batch version for environments where PowerShell might be restricted or for legacy support.
- **CAUJUS_dev.ps1**: Development version containing experimental features like dynamic scraping of the latest FNMT configurator.
- **UO_Checker.ps1**: Active Directory utility for mapping Organizational Units and objects across multiple domains.
- **Checkpoint_checker.bat**: Utility for managing and verifying Check Point VPN client connections.
- **Meraki.ps1**: Automation script likely related to Cisco Meraki device management (needs further verification).
- **Documentation**: 
  - `CAUJUS_Documentation.md`: Detailed technical specification.
  - `CAUJUS_UserGuide.md`: Instructions for technical staff.

## Core Capabilities
1.  **System Optimization**: Automated cleanup of temporary files, browser caches, and performance registry tweaks.
2.  **Digital Certificates**: Silent configuration, request, renewal, and download of FNMT certificates.
3.  **Software Deployment**: Silent installation of Chrome, LibreOffice, AutoFirma, and ISL Always On from corporate network shares.
4.  **Hardware & Drivers**: Reinstallation of smart card reader drivers and display troubleshooting (black screen fix).
5.  **Logging**: All operations are logged to `%TEMP%\CAUJUS_Logs` and synchronized to `\\iusnas05\SIJ\CAU-2012\logs`.

## Building and Running
### Prerequisites
- **Administrative Privileges**: Most tasks require elevation.
- **Network Connectivity**: Access to the `JUSTICIA` domain and specific UNC paths is required for software installation and logging.
- **AD Credentials**: Scripts typically prompt for an Active Directory username to identify the technician.

### Commands
- **Run PowerShell Version**: `.\CAUJUS.ps1`
- **Run Batch Version**: `.\CAUJUS_refactored.bat`
- **Debug Mode**: `.\CAUJUS.ps1 -LogLevel Debug`

## Development Conventions
- **Language**: UI and comments are primarily in Spanish, while function names and variables follow a mix of English and Spanish.
- **Error Handling**: Uses `Try-Catch` blocks in PowerShell and conditional checks in Batch.
- **Modularization**: Code is organized into functional sections (UI, Core, Helpers, Initialization).
- **Security**: Hardcoded credentials are avoided; `Get-Credential` is used for elevation contexts.
- **Logging**: Every action must be recorded using the `Write-CAULog` (PS) or `LogMessage` (Batch) functions.

## External Dependencies
The scripts rely on the following network resources:
- `\\iusnas05\SIJ\CAU-2012\logs`: Centralized log repository.
- `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas`: Software installation source.
- `\\iusnas05\DDPP\COMUN\_DRIVERS`: Hardware driver repository.

## TODO / Future Improvements
- [ ] Transition remaining legacy Batch logic to PowerShell.
- [ ] Implement a GUI version using Windows Forms or WPF.
- [ ] Add auto-update functionality for the scripts themselves.
- [ ] Integrate with ITSM APIs for automatic ticket updates.
