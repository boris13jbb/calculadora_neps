# Calculadora Neps VICUNHA

Aplicacion Flutter multiplataforma (Android, Web, Windows) para calcular:

`Mts calculados = Neps / 0.09`

## Funcionalidades

- Captura de registros (telar, neps, tela, lote/trama)
- Tabla de registros con filtros y edicion
- Catalogo de telas compartido
- Informes guardados y exportacion (CSV, Excel, PDF)
- Sincronizacion en la nube con Firebase (Firestore)

## Sincronizacion en la nube

### Plataformas soportadas

- Android
- Web
- Windows

### Modelo de datos (workspace `vicunha`)

| Recurso | Ruta Firestore | Alcance |
|---------|----------------|---------|
| Registros de captura | `workspaces/vicunha/records/{id}` | Compartido por todo el equipo |
| Catalogo de telas | `workspaces/vicunha/meta/fabrics` | Compartido |
| Informes | `workspaces/vicunha/reports/{id}` | Compartido |
| Metadatos de usuario | `workspaces/vicunha/users/{uid}` | Por dispositivo (auth anonima) |

Los registros de captura se sincronizan entre dispositivos del mismo workspace. La autenticacion es anonima por instalacion; los datos operativos viven en colecciones compartidas del workspace.

### Migracion automatica

Al conectar con Firebase, la app:

1. Migra registros historicos de `users/{uid}/records` a `records` (una vez por dispositivo).
2. Sube datos locales pendientes al workspace compartido.

### Despliegue Web (Firebase Hosting + reglas)

**Automatico (GitHub Actions):** cada push a `main` ejecuta el workflow **Deploy Web Firebase**.

1. En [Firebase Console](https://console.firebase.google.com/) > Configuracion del proyecto > Cuentas de servicio, genera una clave JSON.
2. La cuenta debe tener permisos de **Firebase Hosting Admin** y **Cloud Datastore User** (o rol **Firebase Admin**).
3. En GitHub: **Settings > Secrets and variables > Actions** > crea `FIREBASE_SERVICE_ACCOUNT` con el JSON completo.
4. Tras el primer push, revisa **Actions** y la URL https://vicunha-calculadora-neps.web.app

**Manual (local):**

```bash
flutter build web --release
npx firebase-tools deploy --only firestore:rules,hosting --project vicunha-calculadora-neps
```

Requiere Firebase CLI autenticado y proyecto `vicunha-calculadora-neps` seleccionado.

## Desarrollo local

```bash
flutter pub get
flutter run -d windows   # o chrome / dispositivo Android
flutter test
flutter analyze
```

## Generar APK con GitHub Actions

1. Sube el codigo al repositorio.
2. Entra a **Actions**.
3. Ejecuta **Build APK**.
4. Descarga el artifact `calculadora-neps-apk`.
5. Dentro estara `app-release.apk`.
