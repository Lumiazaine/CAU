# CAU IT Support Tools - Project Context

## Project Overview
This repository is an integrated suite of automation tools developed for the **CAU IT Support Team** (Centro de Atención de Usuarios) at the **Junta de Andalucía (Justice Department)**. It automates common technical support tasks, standardizes procedures across corporate workstations (Windows 10/11), and maintains detailed activity logs.

The project is divided into three main systems:
1.  **AD_ADMIN**: A modular PowerShell system for Active Directory user management.
2.  **Macro Remedy**: An AutoHotkey v2.0 application for automated incident management in Remedy.
3.  **Scripts**: A collection of PowerShell and Batch utilities for system optimization and software deployment, centered around the **CAUJUS** tool.

## Core Systems & Architectures

### 1. AD_ADMIN (Active Directory Administration)
- **Purpose**: Automates user creation, transfers, and management in the `justicia.junta-andalucia.es` domain.
- **Architecture**: Modular PowerShell design with specialized modules for UO management, password handling, and user search.
- **Key Features**:
  - High-precision UO mapping (<100ms response).
  - Advanced scoring system for user matching.
  - Comprehensive Pester test suite (500+ cases).
- **Main Script**: `AD_ADMIN/AD_UserManagement.ps1`

### 2. Macro Remedy (Incident Management)
- **Purpose**: Automates the filling and management of incidents in the Remedy system.
- **Architecture**: Object-Oriented AutoHotkey v2.0 application using the Singleton pattern.
- **Key Features**:
  - Support for 42+ incident types across various categories (Incidencias, Solicitudes, Cierres, DP).
  - Automatic DNI letter calculation and validation.
  - Self-updating via GitHub.
  - Multi-level logging system.
- **Main Class**: `Macro Remedy/Core/CAUApplication.ahk`

### 3. Scripts (CAUJUS Utility)
- **Purpose**: Interactive tool for system optimization, software installation, and hardware troubleshooting.
- **Architecture**: Advanced menu-driven PowerShell (v3.0) and Batch versions.
- **Key Features**:
  - **System Optimization**: Cleanup of temp files, browser caches, and performance tweaks.
  - **Digital Certificates**: Automated FNMT certificate configuration and management.
  - **Software Deployment**: Silent installation of Chrome, LibreOffice, AutoFirma, and ISL Always On from corporate shares.
  - **Hardware Support**: Smart card reader driver management and display fixes.
- **Main Script**: `Scripts/CAUJUS.ps1` (PowerShell) and `Scripts/CAUJUS_refactored.bat` (Batch).

## Building and Running

### Prerequisites
- **OS**: Windows 10/11.
- **Permissions**: Administrative privileges are required for most operations.
- **Network**: Connectivity to the `JUSTICIA` domain and specific UNC paths is essential.
- **Software**: 
  - PowerShell 5.1+
  - AutoHotkey v2.0+ (for Macro Remedy)
  - Active Directory PowerShell Module (for AD_ADMIN)

### Key Commands
- **AD_ADMIN**: 
  - `.\AD_UserManagement.ps1 -CSVFile "users.csv" -WhatIf` (Simulation)
  - `.\Tests\Run-AllTests.ps1` (Execute test suite)
- **Macro Remedy**:
  - `.\Macro Remedy\CAU_GUI_Refactored.ahk` (Run development version)
  - `.\Macro Remedy\compilar.bat` (Compile to EXE)
- **Scripts (CAUJUS)**:
  - `.\Scripts\CAUJUS.ps1` (Main interactive menu)
  - `.\Scripts\CAUJUS.ps1 -LogLevel Debug` (Run with detailed logging)

## Development Conventions
- **Language**: UI and comments are primarily in **Spanish**, while function names and variables follow a mix of English and Spanish.
- **Modularization**: Strong emphasis on modular code (`Modules/` in AD_ADMIN, `Core/Utils/Config` in Macro Remedy).
- **Error Handling**: Uses `Try-Catch` blocks in PowerShell/AHK and conditional checks in Batch.
- **Logging**: All actions are logged locally (`%TEMP%\CAUJUS_Logs` or `C:\Logs`) and synchronized to centralized network shares.
- **Testing**: Pester is used for PowerShell unit and integration tests.

## External Dependencies (Network Resources)
The tools rely heavily on the following corporate network paths:
- **Centralized Logs**: `\\iusnas05\SIJ\CAU-2012\logs`
- **Software Repository**: `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas`
- **Drivers Repository**: `\\iusnas05\DDPP\COMUN\_DRIVERS`

## Important Files
- `README.md`: Root documentation with high-level overview.
- `Scripts/GEMINI.md`: Specific context for the Scripts directory.
- `AD_ADMIN/Modules/UOManager.psm1`: Core logic for organizational unit mapping.
- `Macro Remedy/Config/AppConfig.ahk`: Application configuration for the Remedy macro.
