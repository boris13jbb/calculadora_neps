# Registro de cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y SemVer.

## [1.1.0] - 2026-11-10

### Añadido

- Las sesiones personales de captura (Historial) se sincronizan con la cuenta en Firestore. El mismo usuario las ve en el teléfono y en la web.
- Reglas de `users/{uid}/personalSessions`: solo el dueño lee y escribe; no es el archivo de equipo.

### Limitaciones

- Hace falta publicar las reglas de Firestore y una compilación nueva de la web y de la APK.
- Las sesiones ya guardadas en un teléfono se suben al abrir esa APK actualizada con internet.
- Una sesión de más de 400 registros se guarda en fragmentos completos. Si falta un fragmento, no se muestra como sesión terminada.
- El historial se descarga por páginas de 100 hasta agotar las sesiones de la cuenta.
