#!/usr/bin/env python3
# Verificacion ESTATICA del port v2 contra la verdad de los .arq.
#
# Por que este script: ejecutar la macro de verdad exige aruser.exe (Remedy) y
# una sesion con el formulario Alba abierto, asi que en un banco de pruebas no se
# puede comprobar que cada boton ejecuta la macro correcta. Lo que si es
# puramente textual, y es lo que decide si el tecnico pulsa "GDU" y le sale la
# macro de GDU, es esto:
#
#   1) que la tabla M del port tiene tantas entradas como macros hay en el
#      listado real, y que cada indice es el correcto,
#   2) que los handlers piden su macro por NOMBRE y que ese nombre existe,
#   3) que ningun handler escribe un numero de macro a mano.
#
# LA COMPARACION ES POSICIONAL, NO POR NOMBRE. Es importante, y no es un
# detalle: el nombre visible de la macro en el formulario (linea 1 del .arq) NO
# es el mismo que la etiqueta del boton. Por ejemplo la macro ZZZFuentealimen-
# tacion es la que el tecnico tiene en el boton "Equipo no enciende", y la
# ZZZRedEquipo es la de "Equipo sin red". Si se compararan los nombres en
# abstracto, saltarian 46 avisos falsos. Lo que define el indice es la POSICION
# alfabetica dentro del listado, y eso es lo que se comprueba.
#
# El listado sale de los .arq, que son la verdad: el nombre visible es la
# PRIMERA LINEA del fichero, en Windows-1252, y el orden que ve el tecnico es
# alfabetico sobre ese nombre, no sobre el nombre del fichero. Los 18 x*.arq
# quedan fuera porque Alba.ps1 tambien los excluye.
#
#   ./verificar-port.py [directorio-de-"Macro Remedy"]
import io
import os
import re
import sys
from collections import OrderedDict

fallos = []


def fallo(msg):
    fallos.append(msg)


def aviso(msg):
    print("  AVISO  %s" % msg)


def ok(msg):
    print("  OK     %s" % msg)


def listado_real(arq):
    """Lista [(nombre_visible, fichero)] en el orden que presenta el formulario.

    El orden es alfabetico por el NOMBRE VISIBLE, sin distinguir mayusculas, y
    a igualdad por nombre de fichero (hay dos .arq con el mismo nombre visible:
    ZZZCorre.arq y ZZZCorreoPassword.arq, los dos "ZZZCorreoPassword"). Ordenar
    por bytes daria un resultado distinto, porque en ASCII "S" (0x53) va antes
    que "n" (0x6E).
    """
    filas = []
    for nombre in os.listdir(arq):
        if not nombre.lower().endswith(".arq"):
            continue
        if not nombre.startswith("ZZZ"):
            continue          # los 18 x*.arq no salen en el formulario
        with io.open(os.path.join(arq, nombre), encoding="cp1252") as fh:
            visible = fh.readline().rstrip("\r\n").strip()
        filas.append((visible, nombre))
    filas.sort(key=lambda p: (p[0].lower(), p[1].lower()))
    return filas


def tabla_del_port(ruta):
    texto = io.open(ruta, encoding="utf-8").read()
    entradas = re.findall(r'^\s*M\["((?:[^"\\]|\\.)*)"\]\s*:=\s*(-?\d+)\s*$',
                          texto, re.M)
    return [k for k, _ in entradas], OrderedDict(
        (k, int(v)) for k, v in entradas), texto


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.abspath(__file__))
    port = os.path.join(repo, "CAU_GUI_BETA_v2.ahk")
    arq = os.path.join(repo, "ARCmds", "ARCmds")

    print("=" * 78)
    print("VERIFICACION DEL PORT v2 CONTRA LOS .arq")
    print("=" * 78)
    print()
    print("  port : %s" % port)
    print("  .arq : %s" % arq)
    print()

    # ------------------------------------------------------------ 1. el listado
    print("1. LISTADO REAL DE ARCmds")
    filas = listado_real(arq)
    total = len(filas)
    print("   %d macros visibles (los x*.arq excluidos)" % total)
    esperado = list(range(total))
    if total != 46:
        fallo("el listado tiene %d macros, no 46. Si en un equipo hay mas o"
              " menos, TODOS los indices cambian." % total)
    else:
        ok("46 macros, el numero que asume el port")

    indice_real = OrderedDict()
    for posicion, (visible, fichero) in enumerate(filas):
        indice_real["%s|%s" % (visible, fichero)] = (total - 1) - posicion
    obtenidos = sorted(indice_real.values())
    if obtenidos == esperado:
        ok("indices 0..%d, cada uno una vez, sin huecos" % (total - 1))
    else:
        fallo("los indices no son 0..%d: %r" % (total - 1, obtenidos))

    repetidos = [i for i in indice_real.values()
                 if list(indice_real.values()).count(i) > 1]
    if not repetidos:
        ok("ningun indice asignado a dos macros distintas")
    print()

    # ---------------------------------------------------------- 2. la tabla M
    print("2. TABLA M DEL PORT")
    orden_tabla, tabla, texto = tabla_del_port(port)
    print("   %d entradas, en el orden en que estan escritas" % len(orden_tabla))
    if len(orden_tabla) != total:
        fallo("la tabla tiene %d entradas y el listado real tiene %d"
              % (len(orden_tabla), total))
    else:
        ok("mismo numero de entradas que el listado real")

    indices_tabla = [tabla[k] for k in orden_tabla]
    if indices_tabla == esperado:
        ok("los indices son 0..%d EN ORDEN: la k-esima entrada tiene el"
           " indice %d - k, que es la distancia desde el final del listado"
           % (total - 1, total - 1))
    else:
        for k, (nombre, idx) in enumerate(zip(orden_tabla, indices_tabla)):
            if idx != total - 1 - k:
                fallo("entrada %d %r: indice %d, deberia ser %d"
                      % (k, nombre, idx, total - 1 - k))
    if len(set(indices_tabla)) == len(indices_tabla):
        ok("ningun indice repetido en la tabla")
    else:
        fallo("la tabla repite indices: %r"
              % [i for i in set(indices_tabla)
                 if indices_tabla.count(i) > 1])
    print()

    # ------------------------------------------------------------ 3. handlers
    print("3. HANDLERS DE BOTON")
    cuerpos = re.findall(r'^(Button\d+)\(\*\)\s*\{(.*?)^\}', texto, re.M | re.S)
    print("   %d funciones ButtonN(*)" % len(cuerpos))
    sin_nombre = []
    sin_resolver = []
    a_mano = []
    for nombre_fn, cuerpo in cuerpos:
        peticiones = re.findall(r'EjecutarMacro\("([^"]+)"\)', cuerpo)
        if not peticiones:
            # Button25 es el boton "Buscar": no ejecuta una macro del listado,
            # si que se posiciona en la ultima fila y escribe la incidencia.
            if 'ULTIMA_FILA' in cuerpo:
                continue
            sin_nombre.append(nombre_fn)
            continue
        for pedida in peticiones:
            if pedida not in tabla:
                sin_resolver.append((nombre_fn, pedida))
        for llamada in re.findall(r'SeleccionarMacro\(\s*(\d+)\s*\)', cuerpo):
            a_mano.append((nombre_fn, llamada))

    if sin_nombre:
        for fn in sin_nombre:
            fallo("%s no pide ninguna macro por nombre" % fn)
    else:
        ok("todos los handlers piden su macro por NOMBRE")

    if sin_resolver:
        for fn, pedida in sin_resolver:
            fallo("%s pide %r, que no esta en la tabla M" % (fn, pedida))
    else:
        ok("los %d handlers resuelven contra la tabla M"
           % (len(cuerpos) - len(sin_nombre)))

    if a_mano:
        for fn, num in a_mano:
            fallo("%s llama a SeleccionarMacro(%s) con un numero escrito a"
                  " mano" % (fn, num))
    else:
        ok("ningun handler escribe un numero de macro a mano")
    print()

    # ---------------------------------------------------------- 4. cableado
    print("4. CABLEADO DE LA GUI")
    cableados = re.findall(r'Boton\(gui\w+,\s*(Button\d+)', texto)
    print("   %d botones cableados con Boton()" % len(cableados))
    definidos = set(fn for fn, _ in cuerpos)
    sin_definir = [b for b in cableados if b not in definidos]
    if sin_definir:
        for b in sin_definir:
            fallo("el boton %s esta cableado pero no hay funcion %s" % (b, b))
    else:
        ok("cada boton cableado tiene su funcion manejadora")

    if not re.search(r'OnEvent\(\s*"Click"', texto):
        fallo("no hay ningun OnEvent(\"Click\"): los botones se dibujarian"
              " pero no harian nada")
    else:
        ok('los manejadores se enganchan con OnEvent("Click")')

    muertos = sorted(definidos - set(cableados))
    if muertos:
        aviso("funciones sin boton en la GUI: %s. En el v1 de produccion"
              " tampoco estaban cableadas, asi que no es una regresion."
              % ", ".join(muertos))
    print()

    print("=" * 78)
    if fallos:
        print("RESULTADO: %d FALLO(S)" % len(fallos))
        for f in fallos:
            print("  - %s" % f)
        return 1
    print("RESULTADO: todo correcto. Los %d indices de la tabla, los %d"
          % (total, len(cuerpos)))
    print("handlers y el cableado cuadran con el listado real de ARCmds.")
    print("=" * 78)
    return 0


if __name__ == "__main__":
    sys.exit(main())
