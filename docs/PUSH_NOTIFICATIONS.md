# Notificaciones push — Alertas críticas

## Implementación actual

| Componente | Descripción |
|------------|-------------|
| `NotificationService` | Notificaciones locales en Android y Windows |
| `firebase_messaging` | Token FCM registrado en perfil de usuario en Firestore |
| `NotificationPreferencesService` | Toggle en Configuración |

## Flujo

1. Al iniciar la app (Android/Windows), se solicitan permisos de notificación.
2. En Android, se obtiene el token FCM y se guarda en:
   `workspaces/vicunha/users/{uid}.fcmToken`
3. Al capturar un registro **crítico** (neps > límite advertencia), se muestra:
   - SnackBar rojo con acción "Ver alertas"
   - Notificación local del sistema (si está habilitada en Config)

## Configuración en Firebase Console

1. Habilitar **Cloud Messaging** en el proyecto Firebase.
2. Para Android: verificar que `google-services.json` esté en `android/app/`.
3. Canal por defecto: `critical_alerts` (definido en `AndroidManifest.xml`).

## Push remoto a supervisores (opcional — Cloud Function)

Para notificar supervisores cuando un operario registra un crítico:

La función desplegada se llama `onCriticalRecordCreated` (Gen 2, Firestore trigger).

```javascript
// functions/index.js
exports.onCriticalRecordCreated = onDocumentCreated(...)
```

Ejemplo legacy (no usar):

```javascript
exports.notifySupervisorsOnCritical = functions.firestore
  .document('workspaces/vicunha/users/{userId}/records/{recordId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || data.neps <= 60) return;

    const supervisors = await admin.firestore()
      .collection('workspaces/vicunha/users')
      .where('role', 'in', ['SUPERVISOR', 'ADMINISTRADOR'])
      .get();

    const tokens = supervisors.docs
      .map(d => d.data().fcmToken)
      .filter(Boolean);

    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `Alerta crítica — Telar ${data.telar}`,
        body: `${data.neps} neps registrados`,
      },
      data: { screen: 'alerts' },
    });
  });
```

## Prueba manual

1. Ejecutar en Android o Windows: `flutter run`.
2. Ir a **Configuración** → activar "Notificaciones de alertas críticas".
3. En **Captura**, registrar neps > 60.
4. **Esperado:** notificación del sistema además del SnackBar.

## Plataformas

| Plataforma | Local | FCM token |
|------------|-------|-----------|
| Android | Sí | Sí |
| Windows | Sí | No |
| Web | No (SnackBar únicamente) | Parcial |
