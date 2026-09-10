# Aislamiento multiusuario — notas de migración y despliegue

## Criterio de propiedad

| Campo | Significado |
|---|---|
| `createdByUid` | Autoría: quién capturó el registro. Inmutable salvo admin/supervisor en rules. |
| `ownerUid` (Firestore) | Propietario del documento (ruta `users/{uid}/records` + campo flat). |
| `captureSessionId` | Sesión de captura del propietario. No se usa Telar/Lote como id. |

**Evidencia verificable de propiedad:** `createdByUid` (o `ownerUid` en docs cloud) igual al UID autenticado.

**Ambiguo:** sin `createdByUid`/`ownerUid`. Se conserva en `vicunha_records_ambiguous_v1`. **No** se sube a la nube ni se atribuye al login casual.

## Almacenamiento local por UID

- Registros: prefs/Hive `vicunha_records_uid_v1_{uid}`
- Borrador: `vicunha_capture_draft_v1_{uid}`
- Sesión activa: `vicunha_active_capture_session_v1_{uid}`
- Sesiones personales: `vicunha_personal_sessions_v1_{uid}`
- Cola sync: `vicunha_pending_sync_v1_{uid}`

Al cerrar sesión se guarda el borrador del UID saliente y se limpia la UI.
Al entrar otro UID no se cargan ni se drenan ops ajenas.

## Emuladores

```bash
firebase emulators:start --only auth,firestore
flutter test test/integration/multiuser_emulator_test.dart --dart-define=USE_FIREBASE_EMULATOR=true
```

## Despliegue (después de verificar)

1. `firebase deploy --only firestore:rules`
2. Publicar app Flutter (web/Android/Windows) con este código.
3. No ejecutar migraciones de producción automáticas sobre datos ambiguos.
