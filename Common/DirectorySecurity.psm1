# Windows PowerShell 5.1: DPAPI CurrentUser, no plaintext fallback or legacy .env reads.
Set-StrictMode -Version 2.0
function Get-DirectoryCredentialPath {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'DPAPI requiere Windows.' }
    return Join-Path $env:LOCALAPPDATA 'CAU\Directory\credential.xml'
}
function Get-DirectoryCredential {
    param([string]$Path = (Get-DirectoryCredentialPath))
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'DPAPI requiere Windows.' }
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $credential = Import-Clixml -LiteralPath $Path -ErrorAction Stop
        if ($credential -isnot [Management.Automation.PSCredential]) { throw 'Tipo incorrecto' }
        return $credential
    } catch { Write-Warning 'Credencial protegida no disponible para este usuario/equipo. Vuelva a introducirla.'; return $null }
}
function Save-DirectoryCredential {
    param([Parameter(Mandatory=$true)][Management.Automation.PSCredential]$Credential,
          [string]$Path = (Get-DirectoryCredentialPath))
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'DPAPI requiere Windows; no se permite guardar en claro.' }
    $directory = Split-Path -Parent $Path
    $null = New-Item -ItemType Directory -Force -Path $directory -ErrorAction Stop
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $system = New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner($sid); $acl.SetAccessRuleProtection($true,$false)
    foreach ($identity in @($sid,$system)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule $identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $directory -AclObject $acl -ErrorAction Stop
    $temporary = Join-Path $directory ([Guid]::NewGuid().ToString() + '.xml')
    try {
        $Credential | Export-Clixml -LiteralPath $temporary -ErrorAction Stop
        $fileAcl = Get-Acl -LiteralPath $temporary
        $fileAcl.SetAccessRuleProtection($true,$true)
        Set-Acl -LiteralPath $temporary -AclObject $fileAcl -ErrorAction Stop
        Move-Item -LiteralPath $temporary -Destination $Path -Force -ErrorAction Stop
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}
function New-DirectoryPassword {
    # Fixed class prefix is not entropy: the following 256 random bits are.
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
        return ConvertTo-SecureString ('Aa1!' + [Convert]::ToBase64String($bytes)) -AsPlainText -Force
    } finally { $rng.Dispose(); [Array]::Clear($bytes,0,$bytes.Length) }
}
Export-ModuleMember -Function Get-DirectoryCredentialPath,Get-DirectoryCredential,Save-DirectoryCredential,New-DirectoryPassword
