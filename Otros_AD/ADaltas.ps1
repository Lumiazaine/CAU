[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][Security.SecureString]$AccountPassword)
$ErrorActionPreference = 'Stop'
#Modulos
Import-Module ActiveDirectory

#Contraseña
$securePassword = $AccountPassword
if ($AccountPassword.Length -eq 0) { throw 'La clave segura no puede estar vacia.' }

#Ruta archivo csv
$filepath = Read-Host -Prompt "Selecciona el archivo csv"

#Importar archivo a variable
$users = Import-Csv $filepath

#
ForEach ($user in $users) {
    
    #Obtener los datos
    $fname = $user.'Nombre'
    $lname = $user.'Apellidos'
    $jtitle = $user.'Cargo'
    $office = $user.'Oficina'
    $dni = $user.'DNI'
    $emailaddress = $user.'Correo'
    $ciudad = $user.'Ciudad'
    $provincia = $user.'Provincia'
    $OUpath = $user.'Memberesias'

    echo $fname $lname $jtitle $office $dni $emailaddress $ciudad $provincia $OUpath

    #Crear AD
    if ($PSCmdlet.ShouldProcess($emailaddress, 'Crear cuenta AD')) {
        New-ADUser -Name "$fname $lname" -GivenName $fname -Surname $lname -UserPrincipalName $emailaddress -Path $OUpath -AccountPassword $securePassword -ChangePasswordAtLogon $true -OfficePhone $dni -Description $jtitle -EmailAddress $emailaddress -Enabled $true -ErrorAction Stop
    }

}
