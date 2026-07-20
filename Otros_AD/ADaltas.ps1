#Modulos
Import-Module ActiveDirectory

#Contraseña
$securePassword = ConvertTo-SecureString "Temporal01" -AsPlainText -Force

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
    New-ADUser - Name "$fname $lname" -GivenName $fname -Surname $lname -UserPrincipalName "$fname.$lname" -Path $OUpath -AccountPassword $securePassword -ChangePasswordAtLogon $False -OfficePhone $dni -Description $jtitle -Enabled $true $emailaddress

}