# Migración de roles Firebase — VICUNHA Neps

## Estado actual (Fase 10)

- Autenticación **anónima** vía `FirebaseAuth.signInAnonymously()`.
- Registros por usuario: `workspaces/vicunha/users/{uid}/records`.
- Catálogo de telas y meta: `workspaces/vicunha/meta/`.
- Reglas actuales en `firestore.rules`: cualquier usuario autenticado puede leer/escribir en la mayoría de rutas.

## Riesgos

1. Sin separación de permisos por rol.
2. Cualquier usuario autenticado puede modificar `meta/config` y reportes globales.
3. No hay elevación controlada a supervisor/administrador.

## Roles propuestos

| Rol | Permisos |
|-----|----------|
| **OPERARIO** | Crear registros propios, ver propios registros |
| **SUPERVISOR** | Ver todos los registros, revisar alertas, acción correctiva, exportar |
| **ADMINISTRADOR** | Gestionar usuarios, límites, catálogos, borrar registros |
| **GERENCIA** | Solo lectura: dashboard y reportes |

## Pasos de migración recomendados

### 1. Autenticación real

- Sustituir auth anónima por email/contraseña o SSO corporativo.
- Al registrar usuario, crear documento:

```json
workspaces/vicunha/users/{uid} {
  "role": "OPERARIO",
  "displayName": "...",
  "updatedAt": "<server timestamp>"
}
```

### 2. Reglas Firestore (borrador futuro)

```javascript
function userDoc() {
  return get(/databases/$(database)/documents/workspaces/$(workspaceId)/users/$(request.auth.uid));
}

function userRole() {
  return userDoc().data.role;
}

function isSupervisorOrAbove() {
  return userRole() in ['SUPERVISOR', 'ADMINISTRADOR'];
}

match /users/{userId}/records/{recordId} {
  allow read: if request.auth.uid == userId || isSupervisorOrAbove();
  allow create: if request.auth.uid == userId;
  allow update, delete: if isSupervisorOrAbove() || request.auth.uid == userId;
}

match /meta/config {
  allow read: if request.auth != null;
  allow write: if userRole() == 'ADMINISTRADOR';
}
```

### 3. Configuración de límites en la nube

- Colección: `workspaces/vicunha/meta/config`
- Campos: `limiteNormalMax`, `limiteAdvertenciaMax`, `diasParaReincidencia`, `cantidadReincidenciasCriticas`, `alertasActivas`
- La app ya prepara `AlertConfigService.toFirestoreMap()` para sincronización futura.

### 4. Cliente Flutter

- Leer rol del usuario al bootstrap de `CloudSyncService`.
- Ocultar acciones en UI según rol (no sustituye reglas del servidor).
- Migrar registros legacy de `workspaces/vicunha/records` si aún existen.

## Qué cambió en esta fase

- Reglas en `firestore.rules` con roles OPERARIO, SUPERVISOR, ADMINISTRADOR, GERENCIA.
- Nuevos usuarios anónimos reciben rol `OPERARIO` por defecto (solo si no existe rol previo).
- La app lee el rol desde Firestore y restringe acciones en UI.
- Config de alertas se sincroniza a `meta/config` (solo ADMIN puede escribir en reglas).

## Despliegue de reglas

```bash
firebase deploy --only firestore:rules
```

## Asignar rol a un usuario piloto

En Firebase Console → Firestore → `workspaces/vicunha/users/{uid}`:

```json
{
  "role": "SUPERVISOR",
  "displayName": "Nombre Supervisor"
}
```

Roles válidos: `OPERARIO`, `SUPERVISOR`, `ADMINISTRADOR`, `GERENCIA`.

## Próximo paso

1. Definir proveedor de identidad corporativo.
2. Poblar roles en Firestore para usuarios piloto.
3. Desplegar reglas en entorno de prueba.
4. Validar que operarios no puedan borrar registros ajenos ni modificar límites.
