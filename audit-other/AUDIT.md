# Estado del candidato Aegis: herramientas de soporte

Este documento resume el código vigente, no la matriz histórica de defectos. Las evidencias completas de entorno e inventario se conservan privadas; no se incluyen rutas de staging ni datos corporativos.

## Reparaciones verificadas offline
- HelpDesk: autenticación, política same-origin, sesión explícita, dashboard sin scripts CDN, worker/runspace y cierre de listener; caché vacía y colecciones 0/1 serializadas correctamente.
- LDAP: escaping RFC4515 en búsquedas revisadas, filtros VDI y validación de destinos. Credenciales de directorio protegidas con DPAPI opt-in; entrada segura sin logs de passwords.
- Altas legacy: claves embebidas retiradas, SecureString/entrada segura, ShouldProcess y cambio obligatorio al iniciar sesión. No altas reales ensayadas.
- Temis/lazytemis: retirados defaults predecibles; reset exige endpoint HTTPS aprobado, TLS normal sin redirects, certificado vigente con clave privada y selección explícita si hay ambigüedad. WhatIf sin petición ni captura de secretos.
- Atajos: conservan switches y PersistCredentials; no convierten SecureString a texto en el camino LDAP.
- Dashboard: CSV con comillas/comas/multilínea y escape XSS. UO Checker: dominios/configuración y salida revisados.
- Launchers AHK v2: destino correcto, compilación sin depender de icono ausente. Validación de sintaxis no prueba GUI ni workflows.
- Cookies de wiki y contraseña de Meraki retiradas del código activo; credenciales antes expuestas requieren revocación y revisión de historial/copias.

## Evidencia
El gate principal previo pasó 49 casos Windows PowerShell 5.1 de fixtures y HTTP loopback. Las regresiones adicionales de password safety pasaron 16 contratos y 88 comprobaciones runtime. Se validaron diez fuentes AHK v2 con intérprete portable; no se ejecutaron macros productivos. Los harnesses públicos de esta carpeta usan fixtures; no apuntarlos a producción.

## Límites pendientes
- HTTPS y contrato web Temis aprobados; dos POSTs pueden producir estado parcial. No se afirma éxito corporativo.
- Diez fuentes de backups legacy presentan errores parser en la lectura por defecto; variantes abandonadas no se activan ni se certifican.
- AHK v1, GUI, formularios y creación/cierre de tickets sin prueba E2E autorizada.
- Menús de limpieza, cambios de red/registro, desinstalaciones y mutadores administrativos fuera de aprobación; no se ejecutaron para probarlos.
- VPN/certificados, permisos, entrega de contraseñas, replicación AD y recursos corporativos requieren verificaciones propias.
- Retirar secretos de fuentes actuales no revoca los originales ni limpia el historial Git. No se reescribe historia automáticamente.

**Candidato revisado y probado offline; no certificación global de producción.**
