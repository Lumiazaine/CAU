# Módulos
Import-Module ActiveDirectory
$comandos = @()
# Contraseña
$securePassword = ConvertTo-SecureString "Temporal01" -AsPlainText -Force

# Ruta fija del archivo CSV
# $filepath = "E:\Users\dlunag\Altas.csv"
$filepath = "./Descargas/Altas.csv"

# Importar archivo a variable
$users = Import-Csv $filepath

# Función para eliminar tildes
function Remove-Accents {
    param ([string]$text)
    $text = $text -replace '[áÁ]', 'a'
    $text = $text -replace '[éÉ]', 'e'
    $text = $text -replace '[íÍ]', 'i'
    $text = $text -replace '[óÓ]', 'o'
    $text = $text -replace '[úÚüÜ]', 'u'
    return $text
}

# Función para generar un SamAccountName único en AD
function Get-UniqueUsername {
    param (
        [string]$initials,
        [string]$lastName,
        [string]$secondLastName
    )

    # Quitar tildes
    #$initials = Remove-Accents $initials
    #$lastName = Remove-Accents $lastName
    #$secondLastName = Remove-Accents $secondLastName

    # Crear el nombre base con ambos apellidos completos
    $baseUsername = "$initials$lastName$secondLastName".ToLower()

    $username = $baseUsername
    $counter = 1

    # Verificar si el usuario ya existe en AD
    while (Get-ADUser -Filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue) {
        if ($counter -le $secondLastName.Length) {
            # Agregar letras del segundo apellido
            $username = "$baseUsername$($secondLastName.Substring(0, $counter))"
        } else {
            # Si ya se usaron todas las letras, agregar un número
            $username = "$baseUsername$counter"
        }
        $counter++
    }
    
    return $username
}

# Recorrer cada usuario en el archivo
ForEach ($user in $users) {
    
    # Obtener los datos
    $fname = Remove-Accents $user.'Nombre'
    #$apellidos = Remove-Accents $user.'Apellidos' -split '\s+', 2
    $apellidos = $user.'Apellidos' -split '\s+', 2
    $jtitle = $user.'Cargo'
    $office = $user.'Oficina'
    $dni = $user.'DNI'
    $emailaddress = Remove-Accents $user.'Correo'
    $ciudad = Remove-Accents $user.'Ciudad'
    $provincia = Remove-Accents $user.'Provincia'
    $OUpath = $user.'membresias'  # Cambio aquí

    # Obtener iniciales del nombre (para nombres compuestos)
    $nameParts = $fname -split '\s+'
    $initials = ($nameParts | ForEach-Object { $_[0] }) -join ''

    # Verificar si hay suficientes apellidos
    if ($apellidos.Count -ge 2) {
        $firstLastName = Remove-Accents $apellidos[0]  # Primer apellido
        $secondLastName = Remove-Accents $apellidos[1]  # Segundo apellido
    } else {
        Write-Warning "Usuario $fname omitido por tener un solo apellido."
        continue  # Saltar a la siguiente iteración
    }

    # Generar un nombre único de usuario
    $username = Get-UniqueUsername -initials $initials -lastName $firstLastName -secondLastName $secondLastName

    # Mostrar los datos
    Write-Output "Procesando: $fname $firstLastName $secondLastName, Username generado: $username"

    # Validar que el Path no esté vacío antes de ejecutar New-ADUser
    if (-not [string]::IsNullOrWhiteSpace($OUpath)) {
        try {
            # Crear usuario en AD
            New-ADUser -Name "$fname $firstLastName $secondLastName" `
                -GivenName $fname `
                -Surname "$firstLastName $secondLastName" `
                -SamAccountName $username `
                -UserPrincipalName "$username@justicia.junta-andalucia.es" `  # Cambio aquí
                -Path $OUpath `
                -AccountPassword $securePassword `
                -ChangePasswordAtLogon $false `
                -OfficePhone $dni `
                -Description $jtitle `
                -EmailAddress $emailaddress `
                -Enabled $true

            Write-Output "Usuario $username creado correctamente en $OUpath."
        }
        catch {
            Write-Error ("Error al crear usuario {0}: {1}" -f $username, $_)  # Cambio aquí
        }
    } else {
        Write-Warning "Usuario $fname $firstLastName $secondLastName omitido porque 'membresias' está vacío."
    }
    
}
