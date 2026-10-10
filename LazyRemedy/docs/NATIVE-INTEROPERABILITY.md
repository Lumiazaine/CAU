# Interoperabilidad nativa: hallazgos y frontera de seguridad

Análisis estático de AR System 7.0.1 x86 con Ghidra 12.1.4; no ejecución de DLL ni conexión RPC. Binario observado: SHA256 `b856e4e9330ca94fae3caecaa6d728dc1bf5e0481a6002b28c392c72230bfb37`. El binario y el pseudocódigo del proveedor no se distribuyen.

## Hallazgos
- `ARInitialization` delega en inicialización interna. Los tipos/retornos inferidos por el decompilador no son el contrato de un header SDK.
- `ARVerifyUser` valida contexto/status, usa transporte y devuelve información asociada a la identidad. No concede permisos ni evita autenticación.
- `ARGetEntry` valida contexto, formulario e identificador y construye la petición; maneja resultados y memoria de su runtime. El futuro adaptador debe exigir Request ID verificado y campos explícitos.
- `ARTermination` contiene espera interna y liberación de recursos: se necesita deadline de proceso, no asumir cierre inmediato.
- `FreeARFieldValueList` libera contenido y, según un indicador, el contenedor. No mezclar sus allocations con heaps Python u otro CRT.

## Decisión de arquitectura
La entrada CLI/MCP no debe depender de layouts recuperados de modo heurístico. El puerto `ReadPort` separa la aplicación de un futuro adaptador de integración. La ruta preferida es REST oficial si existe un contrato de instancia confirmado. Para C API se requiere SDK/headers oficiales compatibles con versión y x86; el bridge debe ejecutarse en proceso separado, con sesión/cleanup, límites, timeout, proyección de campos y errores sanitizados.

Ni direcciones estáticas ni número de argumentos bastan para generar `ctypes` seguro. No se adivinan puertos ni estructuras ni se usa una sesión ajena. COM queda condicionado a sesión propia y lifecycle verificado, sin sustituir autorización corporativa.

## Próximo criterio live
Una lectura acotada de registro de prueba con identidad autorizada, endpoint/configuración aprobados, metadata exacta de formulario/campos/Request ID y verificación de salida y cleanup. Hasta entonces el MCP informa `live=false` y no ofrece escrituras.
