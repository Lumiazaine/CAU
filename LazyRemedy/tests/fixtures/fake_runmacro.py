"""Simulador de runmacro.exe SOLO para pruebas de integración (camino real).

Recibe el path del macro como argv[1] y escribe la "salida" en el archivo
indicado por la variable de entorno LAZYREMEDY_OUTPUT_FILE (que inyecta el
motor). Permite simular:
- éxito (exit 0) con salida CSV,
- fallo (LAZYREMEDY_FAKE_FAIL=1 -> exit != 0 + stderr),
- retardo (LAZYREMEDY_FAKE_DELAY segundos) para probar concurrencia/timeouts,
- sin salida (LAZYREMEDY_FAKE_NO_OUTPUT=1) para probar timeout de salida.

No forma parte del paquete: es un fichero de fixtures.
"""

from __future__ import annotations

import os
import sys
import time


def main() -> int:
    macro = sys.argv[1] if len(sys.argv) > 1 else "?"
    out = os.environ.get("LAZYREMEDY_OUTPUT_FILE", "")
    delay = float(os.environ.get("LAZYREMEDY_FAKE_DELAY", "0.05"))

    if os.environ.get("LAZYREMEDY_FAKE_FAIL") == "1":
        print(f"ERROR: simulación de fallo ejecutando {macro}", file=sys.stderr)
        return 3

    time.sleep(delay)

    if os.environ.get("LAZYREMEDY_FAKE_NO_OUTPUT") == "1":
        return 0

    if not out:
        print("ERROR: falta LAZYREMEDY_OUTPUT_FILE", file=sys.stderr)
        return 4

    with open(out, "w", encoding="cp1252") as fh:
        fh.write("ID incidencia,Usuario Temis,Correo,Teléfono,Estado\r\n")
        fh.write("INC001,29567764,caujus.sandetel@juntadeandalucia.es,955040955,Abierta\r\n")
        fh.write("INC002,87654321X,otro@juntadeandalucia.es,955040956,Pendiente\r\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
