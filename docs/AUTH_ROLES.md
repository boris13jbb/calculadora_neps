# Autenticación y roles — VICUNHA Calculadora Neps

## Login con usuario (no correo visible)

Los usuarios normales ingresan con **usuario + contraseña**. Firebase Auth usa internamente un email oculto:

```
operario01  →  operario01@vicunha.local
```

El super_admin puede iniciar sesión con **correo real** (contiene `@`) o con username.

Reglas de username: minúsculas, letras, números, `.`, `-`, `_`. Sin espacios.

## Arquitectura

```
Flutter (cliente)
  ├── AuthService          → Firebase Auth (email/password)
  ├── AuthProvider         → estado de sesión y perfil
  ├── UserAdminService     → Cloud Functions HTTPS Callable
  └── PermissionGate       → bloqueo de pantallas por permiso

Backend
  ├── Firebase Auth        → credenciales y custom claims
  ├── Firestore            → workspaces/vicunha/users/{uid}
  ├── Cloud Functions      → Admin SDK (crear/editar usuarios)
  └── Firestore Rules      → validación por token.role
```

## Roles

| Rol | Código | Gestión usuarios | Captura | Registros | Exportar |
|-----|--------|------------------|---------|-----------|----------|
| Super Admin | `super_admin` | Sí | Sí | Total | Sí |
| Admin | `admin` | No | Sí | Total | Sí |
| Supervisor | `supervisor` | No | No | Ver/revisar | Sí |
| Operario | `operario` | No | Sí | Propios | No |
| Gerencia | `gerencia` | No | No | Solo lectura | Sí |

## Custom claims (solo Admin SDK)

```json
{
  "role": "super_admin",
  "workspaceId": "vicunha",
  "superAdmin": true
}
```

Tras cambiar rol, el cliente debe ejecutar `getIdToken(true)` para refrescar claims.

## Colección Firestore

`workspaces/vicunha/users/{uid}`

Campos principales:

| Campo | Descripción |
|-------|-------------|
| `username` | Usuario visible (obligatorio) |
| `internalEmail` | Email oculto para Auth (`usuario@vicunha.local`) |
| `realEmail` | Solo super_admin con correo real |
| `displayName` | Nombre opcional |
| `role` | Rol del sistema |
| `isActive` | Si puede iniciar sesión |
| `isSuperAdmin` | Flag de super administrador |

- No se guardan contraseñas.
- El cliente no puede modificar `role`, `isActive` ni `email`.
- Solo puede actualizar `lastLoginAt`, `fcmToken`, `fcmUpdatedAt`.

## Cloud Functions

| Función | Quién puede llamar |
|---------|-------------------|
| `createUserBySuperAdmin` | super_admin |
| `updateUserBySuperAdmin` | super_admin |
| `updateUserRoleBySuperAdmin` | super_admin |
| `disableUserBySuperAdmin` | super_admin |
| `enableUserBySuperAdmin` | super_admin |
| `deleteUserBySuperAdmin` | super_admin |
| `listUsersBySuperAdmin` | super_admin |
| `getCurrentUserProfile` | usuario autenticado |
| `bootstrapFirstSuperAdmin` | secreto temporal (uso único) |

## Auditoría

`workspaces/vicunha/audit_logs/{logId}` — escritura solo desde Cloud Functions.

Eventos: `user_created`, `user_role_changed`, `user_disabled`, `user_enabled`, `user_deleted`.

## Flujo de login

1. Usuario ingresa email/contraseña.
2. Firebase Auth valida credenciales.
3. `getCurrentUserProfile` carga perfil Firestore.
4. Se valida `isActive` y rol.
5. Se refresca token y claims.
6. `AuthGate` muestra `AppShell` si todo es válido.

## Flujo de creación de usuario

1. Super admin abre **Usuarios → Nuevo usuario**.
2. Flutter llama `createUserBySuperAdmin`.
3. Function crea usuario en Auth, asigna claims y documento Firestore.
4. Se registra auditoría.

## Proveedores de autenticación

- **Email/contraseña:** habilitado (`firebase.json` → `auth.providers.emailPassword: true`)
- **Anónimo:** deshabilitado (`auth.providers.anonymous: false`)

Para aplicar cambios de proveedores:

```bash
firebase deploy --only auth
```

Si el login anónimo sigue activo en consola, ejecute también:

```bash
node scripts/disable_anonymous_auth.js
```

## Usuarios de prueba por rol

Cuentas provisionadas en el workspace `vicunha`. Las contraseñas temporales se entregan por canal seguro; **cámbielas en el primer acceso**.

| Rol | Email |
|-----|-------|
| Super Admin | `admin@vicunha-neps.com` |
| Admin | `administrador@vicunha-neps.com` |
| Supervisor | `supervisor@vicunha-neps.com` |
| Operario | `operario@vicunha-neps.com` |
| Gerencia | `gerencia@vicunha-neps.com` |

Scripts de aprovisionamiento (requieren `firebase login`):

```bash
node scripts/provision_role_users.js   # crea cuentas Auth por REST
node scripts/setup_role_users.js       # claims + perfiles Firestore
```

## Primer super administrador

Opción recomendada — script local:

```bash
set GOOGLE_APPLICATION_CREDENTIALS=ruta\serviceAccountKey.json
node scripts/create_super_admin.js --email admin@empresa.com
```

Alternativa: crear usuario en Firebase Console y ejecutar el script con `--uid`.

## Seguridad

- No confiar solo en ocultar botones del menú.
- `PermissionGate` bloquea pantallas.
- Firestore Rules validan `request.auth.token.role`.
- Cloud Functions validan `super_admin` antes de mutaciones.
- No dejar `bootstrapFirstSuperAdmin` activo en producción sin secreto fuerte.
