param(
    [bool] $Instala = $false,
    [bool] $Actualiza = $false
)

if ($Instala){
    Out-Default -InputObject "Proceso de InstalaciÃ³n"
    break
}
if ($Actualiza){
    Out-Default -InputObject "Proceso de Actualizacion"
    break
}

if (!($Instala) -and !($Actualiza)){

    #FunciÃ³n para seleccionar archivos
    function PintaMenu($Datos,$seleccionados=$null){
        clear
        if($null -ne $seleccionados){
            $seleccion = $seleccionados.split(" ",2000)
        }
            for($i=0;$i -lt $Archivos.count;$i++){
                if($null -eq $seleccionados){
                    $texto = " "+[string]$i+".- "+$Archivos[$i].name
                }else{
                    if ($seleccion -match $i){
                        $texto = "*"+[string]$i+".- "+$Archivos[$i].name
                    }else{
                        $texto = " "+[string]$i+".- "+$Archivos[$i].name
                    }
                }
                Out-Default -InputObject $texto
            }
    }
    function SeleccionaArchivos($ruta){
        $Archivos = Get-ChildItem -Path $Ruta | Sort-Object Name
        $salida = $false
        while (!($salida)){
            PintaMenu($Archivos.name)
            $Selecciones = Read-Host -Prompt "Selecciona los archivos separados por espacios"
            PintaMenu($Archivos.name)($Selecciones)
            $Finaliza = Read-Host -Prompt "Â¿Es correcta la selecciÃ³n? (s/n)"
            if ($Finaliza.ToUpper() -like "S"){
                $salida = $true
                $selec = @()
                foreach ($seleccion in ($Selecciones.split(" ",200))) {
                    if ($seleccion -ge 0 -and $seleccion -lt $Archivos.Count){
                        $selec += $Archivos[$seleccion]                
                    }
                }
                return $selec
            }
        }
    }
    ## Guardamos la ruta en una variable
    $Ruta = "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\*.arq"
    $TodosLosArchivos = Get-ChildItem -Path $Ruta | Sort-Object Name
    $ArchivosASeleccionar = @("ZZZAbbyp.arq","ZZZAD.arq","ZZZAdria.arq","ZZZAgend.arq","ZZZAlmac.arq","ZZZAr001.arq","ZZZArcon.arq","ZZZCerti.arq","ZZZCorre.arq","ZZZDisco.arq","ZZZDrago.arq","ZZZEdoc.arq","ZZZEmpar.arq","ZZZEquip.arq","ZZZEscri.arq","ZZZExped.arq","ZZZGanes.arq","ZZZGdu.arq","ZZZGM.arq","ZZZHerme.arq","ZZZInter.arq","ZZZJara.arq","ZZZLexne.arq","ZZZNuevo.arq","ZZZOrfil.arq","ZZZPNJ.arq","ZZZPorta.arq","ZZZQuend.arq","ZZZRed.arq","ZZZSiraj.arq","ZZZSoftw.arq","ZZZSumin.arq","ZZZTarje.arq","ZZZTelef.arq","ZZZTemis.arq","ZZZZConn.arq")
    ## Seleccionamos 
    $archivos = @()
    #$Archivos = SeleccionaArchivos($ruta)
    foreach ($archivo in $ArchivosASeleccionar){
        if ($TodosLosArchivos.name -match $archivo){
            $archivos += $TodosLosArchivos | where {$_.name -like $archivo} 
        }
    }
    ## Ahora un bucle para realizar la tarea sobre todos los seleccionados
    foreach ($NombreArchivo in $Archivos){
        $fechas = @()
        $contenidos = get-content -path $NombreArchivo
        foreach ($contenido in $contenidos){
            foreach ($valor in $contenido.Split([char]1,200)){
                if ($valor -match "1010000200=" -or $valor -match "1010000150="){
                    $fechas += $valor.Substring(11)
                }
            }
        }
        $FechaActual = (get-date).ToString("dd/MM/yyyy HH:mm:ss")
        foreach ($fecha in $fechas){
            (get-content -path $NombreArchivo).Replace($fecha,$FechaActual)| Set-Content -Path $NombreArchivo
        }
        #Fin del bucle
    }
}
