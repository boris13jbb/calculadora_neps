# Autenticación, usuarios y roles — VICUNHA Calculadora Neps

> Guía operativa. Para arquitectura, matriz de permisos y reglas Firestore, ver [AUTH_ROLES.md](AUTH_ROLES.md).

## Login con usuario (sin correo visible)

| Tipo | Campo login | Firebase Auth interno |
|------|-------------|------------------------|
| Operario, admin, supervisor, gerencia | `operario01` | `operario01@vicunha.local` |
| Super admin | `admin@empresa.com` | correo real |

El usuario **nunca** ve el email interno `@vicunha.local`.

## Crear primer super administrador

```bash
set GOOGLE_APPLICATION_CREDENTIALS=ruta\serviceAccountKey.json
node scripts/create_super_admin.js --email admin@empresa.com
```

El script crea perfil Firestore con `username: superadmin`, `realEmail` y claims `isSuperAdmin`.

## Crear usuarios normales (panel)

Solo **super_admin** → menú **Usuarios** → **Nuevo usuario**:

1. Usuario (ej. `operario01`) — obligatorio, único
2. Contraseña temporal — mínimo 8 caracteres
3. Nombre — opcional
4. Rol — admin, supervisor, operario o gerencia
5. Estado activo

La Cloud Function `createAppUser`:

- Crea Auth con email interno oculto
- Asigna custom claims (`role`, `username`, `workspaceId`)
- Guarda documento en `workspaces/vicunha/users/{uid}`
- **No** retorna ni guarda la contraseña

## Resetear contraseña

Solo super_admin desde **Usuarios** → icono candado → nueva contraseña.

Cloud Function: `resetAppUserPassword`.

Los usuarios normales **no** usan recuperación por correo.

## Cloud Functions (Admin SDK)

| Función | Descripción |
|---------|-------------|
| `createAppUser` | Crear usuario con username |
| `updateAppUser` | Editar nombre, rol, estado |
| `changeUserRole` | Cambiar solo rol |
| `disableAppUser` / `enableAppUser` | Activar/desactivar |
| `deleteAppUser` | Soft delete + deshabilitar Auth |
| `resetAppUserPassword` | Reset de contraseña |
| `listAppUsers` | Listar con búsqueda/filtros |
| `getCurrentUserProfile` | Perfil del usuario autenticado |
| `bootstrapFirstSuperAdmin` | Bootstrap único (secreto en `.env`) |
| `processUserCreationRequest` | Trigger: procesa la cola de creación |
| `processUserAdminRequest` | Trigger: procesa la cola de edición/estado/borrado/contraseña |

Alias legacy: `createUserBySuperAdmin`, `listUsersBySuperAdmin`, etc.

## Patrón de cola en Firestore (evita CORS en web)

Llamar callables `onCall` directo desde el navegador puede fallar con
`Failed to fetch` (CORS). Por eso las **mutaciones** de usuarios no llaman al
callable directamente: escriben una solicitud en Firestore y un trigger la
procesa en segundo plano con el Admin SDK.

| Operación | Colección de cola | `type` |
|-----------|-------------------|--------|
| Crear | `workspaces/vicunha/user_creation_requests` | `create` |
| Editar / Activar / Desactivar / Eliminar / Reset contraseña | `workspaces/vicunha/user_admin_requests` | `update`, `enable`, `disable`, `delete`, `resetPassword` |

Flujo (implementado en `lib/repositories/user_admin_repository.dart`):

1. El cliente escribe `{type, ...datos, status: 'pending', requestedByUid}`.
2. El trigger valida que el solicitante sea `super_admin` activo, ejecuta la
   lógica compartida (`execute*` en `functions/admin_users.js`) y escribe
   `status: 'completed'` (con `user` o `success`) o `status: 'failed'`
   (con `errorMessage`).
3. El cliente escucha el documento y resuelve/rechaza según el resultado.

Notas:

- El repositorio hace **fallback** al callable directo solo ante fallos de
  infraestructura (trigger sin desplegar, timeout, red). Los errores de
  negocio (`status: failed`) se muestran tal cual, sin reintentar.
- La contraseña (`password` / `newPassword`) se guarda en el documento solo de
  forma transitoria y el trigger la borra con `FieldValue.delete()` al terminar.
- Los callables siguen disponibles para Android/iOS y como respaldo.
- Reglas: solo `super_admin` puede crear en ambas colecciones; nadie puede
  actualizar/borrar los documentos desde el cliente (solo el Admin SDK).

Todas las mutaciones validan:

- `request.auth` presente
- Caller es `super_admin` activo
- No eliminar/desactivar último super_admin
- No crear `super_admin` desde panel (usar script)

## Auditoría

`workspaces/vicunha/audit_logs/{logId}`

Eventos: `user_created`, `user_updated`, `user_role_changed`, `user_disabled`, `user_enabled`, `user_deleted`, `password_reset`.

Campos: `performedByUsername`, `targetUsername`, `oldValue`, `newValue`, `metadata`.

## Roles y permisos

Ver `docs/AUTH_ROLES.md` para matriz completa.

Solo `super_admin` tiene `Permission.manageUsers`.

## Seguridad

1. Contraseñas solo en Firebase Auth — nunca en Firestore
2. Cliente no puede modificar `role`, `username`, `internalEmail`, `isActive`
3. Custom claims solo desde Cloud Functions / Admin SDK
4. Tras cambio de rol: cerrar sesión y volver a entrar

## Despliegue

```bash
firebase deploy --only functions,firestore:rules
flutter build web --release
firebase deploy --only hosting
```

## Menú y operaciones protegidas

- Navegación filtrada por `RolePermissions` en `AppNavigation`.
- `PermissionGate` en Captura, Telas, Exportar y Usuarios.
- `AppState` bloquea exportación, importación, edición, informes y catálogo de telas según rol autenticado.

## Advertencias

- Usuarios legacy con email real siguen funcionando hasta migrarlos a username
- No dejar `bootstrapFirstSuperAdmin` activo en producción sin secreto fuerte
- Entregar contraseñas temporales por canal seguro (no chat/email grupal)
