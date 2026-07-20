Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- VENTANA PRINCIPAL ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Buscador y Administrador de Usuarios - Junta de Andalucía"
$Form.Size = New-Object System.Drawing.Size(800, 560)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedSingle"
$Form.MaximizeBox = $false

# Etiqueta de instrucción
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(20, 20)
$Label.Size = New-Object System.Drawing.Size(400, 20)
$Label.Text = "Introduce el login, nombre o apellido del usuario:"
$Form.Controls.Add($Label)

# Cuadro de texto para buscar
$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Location = New-Object System.Drawing.Point(20, 45)
$TextBox.Size = New-Object System.Drawing.Size(590, 20)
$Form.Controls.Add($TextBox)

# Botón de Buscar
$Button = New-Object System.Windows.Forms.Button
$Button.Location = New-Object System.Drawing.Point(630, 43)
$Button.Size = New-Object System.Drawing.Size(130, 24)
$Button.Text = "Buscar Usuario"
$Form.Controls.Add($Button)

# Etiqueta de aviso intermedio
$LblAviso = New-Object System.Windows.Forms.Label
$LblAviso.Location = New-Object System.Drawing.Point(20, 75)
$LblAviso.Size = New-Object System.Drawing.Size(740, 15)
$LblAviso.Text = "Resultados (Marca la casilla y pulsa abajo, o haz doble clic para abrir las Propiedades oficiales del AD):"
$LblAviso.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$Form.Controls.Add($LblAviso)

# CASILLA DE SELECCIÓN AVANZADA (Visualización limpia en columnas con Checkboxes)
$ListView = New-Object System.Windows.Forms.ListView
$ListView.Location = New-Object System.Drawing.Point(20, 95)
$ListView.Size = New-Object System.Drawing.Size(740, 350)
$ListView.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$ListView.View = [System.Windows.Forms.View]::Details
$ListView.CheckBoxes = $true        # Requisito innegociable: mantiene los Checkboxes
$ListView.FullRowSelect = $true     # Facilita la selección de la fila completa
$ListView.GridLines = $true         # Añade cuadrícula para que no se vea desordenado

# Estructura de columnas alineadas
$ListView.Columns.Add("Nombre y apellidos", 220) | Out-Null
$ListView.Columns.Add("AD del usuario", 120) | Out-Null
$ListView.Columns.Add("UBICACIÓN / UO", 375) | Out-Null
$Form.Controls.Add($ListView)

# Botón inferior para abrir propiedades
$BtnAbrirProp = New-Object System.Windows.Forms.Button
$BtnAbrirProp.Location = New-Object System.Drawing.Point(20, 465)
$BtnAbrirProp.Size = New-Object System.Drawing.Size(240, 35)
$BtnAbrirProp.Text = "Abrir Propiedades de AD"
$BtnAbrirProp.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($BtnAbrirProp)


# --- LÓGICA REPARADA: Ejecución limpia del menú de Propiedades Nativo ---
$AbrirMenuPropiedadesNativo = {
    # Priorizamos los elementos que tengan el Checkbox marcado
    $ElementosAProcesar = $ListView.CheckedItems
    
    # Comodidad de usuario: si no marcó la casilla pero tiene la fila sombreada, la procesamos también
    if ($ElementosAProcesar.Count -eq 0 -and $ListView.SelectedItems.Count -gt 0) {
        $ElementosAProcesar = $ListView.SelectedItems
    }
    
    if ($ElementosAProcesar.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Por favor, marca la casilla de algún usuario.", "Atención", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    foreach ($Item in $ElementosAProcesar) {
        $DatosUsuario = $Item.Tag
        $DNUsuario = $DatosUsuario.DN
        $DominioLimpio = $DatosUsuario.Dominio

        # SOLUCIÓN AL ERROR: Al especificar el /server, el /objectproperties requiere SOLO el DistinguishedName plano (sin el prefijo LDAP:// repetido)
        $ArgumentoMmc = "dsa.msc /server=$DominioLimpio /objectproperties `"$DNUsuario`""
        Start-Process "mmc.exe" -ArgumentList $ArgumentoMmc -WindowStyle Normal
    }
}

# --- LÓGICA: Extracción y Limpieza de datos ---
$BuscarAccion = {
    $Busqueda = $TextBox.Text.Trim()
    if ([string]::IsNullOrEmpty($Busqueda)) {
        [System.Windows.Forms.MessageBox]::Show("Por favor, escribe un término de búsqueda.", "Campo vacío", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $ListView.Items.Clear()
    $Form.Refresh()

    $Filtro = "SamAccountName -like '*$Busqueda*' -or Name -like '*$Busqueda*' -or DisplayName -like '*$Busqueda*'"
    $Resultados = Get-ADUser -Filter $Filtro -Server "justicia.junta-andalucia.es:3268" -Properties CanonicalName -ErrorAction SilentlyContinue

    if ($Resultados) {
        foreach ($Usuario in $Resultados) {
            # Desglosamos el dominio de origen a partir de la ruta canónica
            $RutaCompleta = $Usuario.CanonicalName
            $DominioDetectado = $RutaCompleta -replace '/.*$', ''
            
            # Limpiamos la UO quitando dominio y nombre de usuario
            $RutaSinDominio = $RutaCompleta -replace '^[^/]+/', ''
            $NombreEscapado = [regex]::Escape($Usuario.Name)
            $UOLimpia = $RutaSinDominio -replace "/$NombreEscapado$", ''

            # Insertamos los datos de manera tabulada en las columnas del ListView
            $Fila = New-Object System.Windows.Forms.ListViewItem($Usuario.Name) # Columna 1
            $Fila.SubItems.Add($Usuario.SamAccountName) | Out-Null               # Columna 2
            $Fila.SubItems.Add($UOLimpia) | Out-Null                             # Columna 3
            
            # Almacenamos los metadatos de conexión de forma invisible en la propiedad Tag
            $Fila.Tag = @{
                DN = $Usuario.DistinguishedName
                Dominio = $DominioDetectado
            }
            
            $ListView.Items.Add($Fila) | Out-Null
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("No se encontraron coincidencias.", "Sin resultados", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
}

# --- ENLACE DE ACCIONES ---
$Button.Add_Click($BuscarAccion)
$TextBox.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        & $BuscarAccion
        $_.SuppressKeyPress = $true
    }
})

$ListView.Add_DoubleClick($AbrirMenuPropiedadesNativo)
$BtnAbrirProp.Add_Click($AbrirMenuPropiedadesNativo)

# --- INICIAR INTERFAZ ---
$Form.ShowDialog() | Out-Null