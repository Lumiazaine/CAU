# Candidato Aegis — seguridad y límites de verificación

Este candidato conserva la CLI existente y endurece sus fronteras. **No constituye certificación de integración corporativa.**

## Cambios
- Acceso live deshabilitado por defecto; el backend HTML experimental solo acepta fixtures loopback hasta contar con contrato verificado.
- HTTP local con autenticación Bearer cuando está configurada y guardas de pares remotos; CORS sin comodín por defecto.
- TLS verificado, redirecciones de autenticación rechazadas y errores sin URLs, cualificaciones ni valores personales.
- Ejecución de macros con timeout y cancelación, proceso hijo propio y exclusión mutua con ownership consistente.
- Cualificaciones y campos validados; no exportación masiva ni registros de criterios personales.
- Eliminado ExecutionPolicy Bypass del prototipo COM; lifecycle y cleanup Windows todavía sin validar live.

## Evidencia offline
La revisión anterior ejecutó 134 casos pytest y 19 casos unittest del prototipo de terminal, usando datos sintéticos, simulaciones y servidores loopback. No autenticó ni consultó incidencias de producción. La evidencia detallada con metadata de infraestructura se conserva fuera de Git.

## Integración nativa
Se inspeccionó estáticamente una instalación del cliente AR System 7.0.1 x86. Se localizaron ARInitialization, ARVerifyUser, ARSetServerPort, ARGetEntry, ARGetListEntryWithFields, ARTermination y liberadores de resultados. La presencia de símbolos y pseudocódigo no valida alineamiento, ABI, tipos recuperados ni acceso a servidor.

Antes de habilitar el adaptador nativo se requieren SDK/headers oficiales compatibles, configuración aprobada de servidor/TCP/RPC, identidad autorizada y pruebas acotadas de sesión y cleanup. No se distribuyen DLLs ni pseudocódigo del proveedor en este repositorio.

Para REST se requiere endpoint HTTPS exacto, versión servidor, autenticación, formulario/campos permitidos y un registro de prueba no sensible. La versión del cliente no identifica la del servidor. Para COM se requiere la sesión propia comprobada y el contrato correspondiente; no se reutilizan sesiones ajenas ni se lanza un cliente para fabricar autenticación.

## Estado
Conservación de funcionalidad significa compatibilidad comprobada con las pruebas existentes; no significa validar todas las macros/workflows del entorno real. Los fallos legacy y operaciones productivas no ensayadas siguen siendo límites explícitos.
