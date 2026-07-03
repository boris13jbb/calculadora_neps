# Calculadora Neps VICUNHA — Control de calidad textil

Aplicación Flutter multiplataforma (Android, Web, Windows) para registro, análisis y exportación de mediciones de neps en producción textil.

**Fórmula central:** `Mts calculados = Neps / 0.09`

## Funcionalidades principales

| Módulo | Descripción |
|--------|-------------|
| **Captura** | Registro de telar, neps, tela, lote/trama, turno, operario y observaciones |
| **Registros** | Tabla con filtros avanzados, importación CSV/Excel con vista previa, acciones correctivas |
| **Alertas** | Clasificación Normal / Advertencia / Crítico con recomendaciones |
| **Dashboard** | KPIs y gráficas de tendencia (fl_chart) |
| **Informes** | Guardado y carga de informes con filtros aplicados |
| **Exportar** | CSV, Excel (.xlsx) y PDF profesional con resumen ejecutivo |
| **Configuración** | Límites de alerta personalizables (SharedPreferences) |
| **Firebase** | Auth email/contraseña, Firestore, Cloud Functions y roles |

## Autenticación y roles

El sistema usa **Firebase Auth** con email/contraseña. Los roles se asignan mediante **custom claims** (solo desde Cloud Functions / Admin SDK).

Documentación detallada: [docs/AUTH_ROLES.md](docs/AUTH_ROLES.md)

### Crear el primer super administrador

1. Cree el usuario en Firebase Console (Authentication → Add user).
2. Ejecute el script local (requiere service account, **no subir al repo**):

```bash
set GOOGLE_APPLICATION_CREDENTIALS=ruta\serviceAccountKey.json
node scripts/create_super_admin.js --email admin@empresa.com
```

3. El usuario debe cerrar sesión y volver a entrar para cargar los claims.

### Desplegar backend

```bash
firebase deploy --only firestore:rules,functions
```

### Crear usuarios (producción)

Solo un **super_admin** puede crear usuarios desde la pantalla **Usuarios** en la app (llama Cloud Functions de forma segura).

## Requisitos

- Flutter SDK 3.x
- Dart 3.x

## Instalación y ejecución

```bash
git clone <repo>
cd regneps
flutter pub get
flutter run
```

### Plataformas

```bash
flutter run -d chrome          # Web
flutter run -d windows         # Windows
flutter build apk --release    # Android APK
```

## Validación

```bash
flutter analyze
flutter test
```

## Importación de registros

1. En **Registros**, pulse **Descargar plantilla** para obtener el Excel de ejemplo.
2. Complete las columnas obligatorias: Telar, Tela, Lote de trama, Neps (o Mts).
3. Pulse **Importar CSV/Excel** y seleccione el archivo.
4. Revise la **vista previa** (válidas, duplicadas, errores) y confirme.

## Acciones correctivas

En registros con alerta **Advertencia** o **Crítico** no revisados, use el icono de seguimiento en la tabla para registrar responsable, acción e historial.

## Alertas (valores por defecto)

| Nivel | Condición |
|-------|-----------|
| Normal | Neps ≤ 30 |
| Advertencia | 30 < Neps ≤ 60 |
| Crítico | Neps > 60 |

Configurable en **Configuración**.

## Estructura del proyecto

```
lib/
  core/          # Tema, widgets reutilizables, constantes
  features/      # Pantallas por módulo
  models/        # NepRecord, filtros, alertas
  providers/     # AppState (estado global)
  services/      # Alertas, analytics, import/export, Firebase
  utils/         # Helpers de filtros, lote/trama, archivos
test/            # Tests unitarios
docs/            # Documentación (entrega final, FASE 17, Firebase)
```

Ver [docs/ENTREGA_FINAL.md](docs/ENTREGA_FINAL.md) para el checklist completo de fases y guía de prueba integral.

Documentación adicional:
- [docs/FIREBASE_ROLES_MIGRATION.md](docs/FIREBASE_ROLES_MIGRATION.md) — roles y reglas Firestore
- [docs/PUSH_NOTIFICATIONS.md](docs/PUSH_NOTIFICATIONS.md) — notificaciones críticas

## Generar APK con GitHub Actions

1. Sube el repositorio a GitHub.
2. Entra a **Actions**.
3. Ejecuta **Build APK**.
4. Descarga el artifact `calculadora-neps-apk`.
5. Dentro estará `app-release.apk`.

## Variables y configuración Firebase

Para sincronización en la nube, configure Firebase según `lib/firebase_options.dart` y revise `docs/FIREBASE_ROLES_MIGRATION.md` antes de endurecer reglas de Firestore.
