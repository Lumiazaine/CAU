Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuración de la Ventana Principal ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Buscador de Ubicación de Usuarios - Junta de Andalucía"
$Form.Size = New-Object System.Drawing.Size(650, 520)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedSingle"
$Form.MaximizeBox = $false

# --- Etiqueta de instrucción ---
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(20, 20)
$Label.Size = New-Object System.Drawing.Size(400, 20)
$Label.Text = "Introduce el login, nombre o apellido del usuario:"
$Form.Controls.Add($Label)

# --- Cuadro de texto para buscar ---
$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Location = New-Object System.Drawing.Point(20, 45)
$TextBox.Size = New-Object System.Drawing.Size(440, 20)
$Form.Controls.Add($TextBox)

# --- Botón de Buscar ---
$Button = New-Object System.Windows.Forms.Button
$Button.Location = New-Object System.Drawing.Point(480, 43)
$Button.Size = New-Object System.Drawing.Size(130, 24)
$Button.Text = "Buscar Usuario"
$Button.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($Button)

# --- Cuadro de texto inferior para mostrar resultados ---
$ResultBox = New-Object System.Windows.Forms.TextBox
$ResultBox.Location = New-Object System.Drawing.Point(20, 90)
$ResultBox.Size = New-Object System.Drawing.Size(590, 360)
$ResultBox.MultiLine = $true
$ResultBox.ScrollBars = "Vertical"
$ResultBox.ReadOnly = $true
$ResultBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$ResultBox.BackColor = [System.Drawing.Color]::White
$Form.Controls.Add($ResultBox)

# --- Lógica de la Búsqueda y Limpieza de Datos ---
$BuscarAccion = {
    $Busqueda = $TextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($Busqueda)) {
        [System.Windows.Forms.MessageBox]::Show("Por favor, escribe algo para poder buscar.", "Campo vacío", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $ResultBox.Text = "Buscando en todos los dominios... Por favor, espera."
    $Form.Refresh()
    
    $Filtro = "SamAccountName -like '*$Busqueda*' -or Name -like '*$Busqueda*' -or DisplayName -like '*$Busqueda*'"
    $Resultados = Get-ADUser -Filter $Filtro -Server "justicia.junta-andalucia.es:3268" -Properties CanonicalName -ErrorAction SilentlyContinue
    
    if ($Resultados) {
        $TextoSalida = ""
        foreach ($Usuario in $Resultados) {
            
            # --- PROCESAMIENTO DE LA RUTA ---
            $RutaCompleta = $Usuario.CanonicalName
            
            # Limpiamos la UO quitando el dominio del principio (ej: cadiz.justicia.junta-andalucia.es/)
            $RutaSinDominio = $RutaCompleta -replace '^[^/]+/', ''
            
            # Quitamos el nombre del usuario del final para dejar solo las carpetas de las UOs
            $NombreUsuario = [regex]::Escape($Usuario.Name)
            $RutaLimpia = $RutaSinDominio -replace "/$NombreUsuario$", ''
            # ---------------------------------

            # Construimos la vista solicitada incluyendo el ID de cuenta de AD
            $TextoSalida += "Nombre y apellidos: " + $Usuario.Name + "`r`n"
            $TextoSalida += "AD del usuario: " + $Usuario.SamAccountName + "`r`n"
            $TextoSalida += "UBICACIÓN / UO: " + $RutaLimpia + "`r`n"
            $TextoSalida += "======================================================================`r`n`r`n"
        }
        $ResultBox.Text = $TextoSalida
    } else {
        $ResultBox.Text = "No se encontró ningún usuario que coincida con: '$Busqueda'."
    }
}

# Vincular la acción al hacer clic en el botón o pulsar Enter
$Button.Add_Click($BuscarAccion)
$TextBox.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        & $BuscarAccion
        $_.SuppressKeyPress = $true
    }
})

# --- Mostrar la interfaz ---
$Form.ShowDialog() | Out-Null