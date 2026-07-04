# Calculadora Neps VICUNHA

Aplicación Flutter multiplataforma (**Android**, **Web**, **Windows**) para control de calidad textil: registro, análisis, alertas y exportación de mediciones de neps en producción.

**Fórmula central:** `Mts calculados = Neps / 0.09`

---

## Objetivo

Digitalizar el control de neps en telares VICUNHA: capturar mediciones, clasificar alertas, generar informes y sincronizar datos en la nube con roles de acceso diferenciados.

---

## Funcionalidades principales

| Módulo | Descripción |
|--------|-------------|
| **Captura** | Registro de telar, neps, tela, lote/trama, turno, operario y observaciones |
| **Registros** | Tabla con filtros, importación CSV/Excel con vista previa, acciones correctivas |
| **Alertas** | Clasificación Normal / Advertencia / Crítico con recomendaciones |
| **Dashboard** | KPIs y gráficas de tendencia (`fl_chart`) |
| **Informes** | Guardado y carga de informes con filtros aplicados |
| **Exportar** | CSV, Excel (.xlsx) y PDF con resumen ejecutivo |
| **Telas** | Catálogo de telas con importación/exportación |
| **Usuarios** | Administración de usuarios (solo super_admin) |
| **Configuración** | Límites de alerta personalizables |

---

## Tecnologías

| Capa | Stack |
|------|-------|
| Cliente | Flutter 3.x, Dart 3.x, Provider |
| Persistencia local | SharedPreferences |
| Backend | Firebase Auth, Firestore, Cloud Functions, FCM |
| Exportación | `pdf`, `printing`, `excel`, `share_plus`, `file_picker` |
| CI | GitHub Actions (APK, deploy web) |

---

## Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (Dart ≥ 3.5)
- Android Studio / VS Code con extensiones Flutter
- Node.js 22+ (Cloud Functions y scripts admin)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`firebase login`)
- Cuenta Firebase con proyecto configurado

---

## Instalación

```bash
git clone <url-del-repositorio>
cd regneps
flutter pub get
```

---

## Configuración de Firebase

1. El cliente usa `lib/firebase_options.dart` (generado con FlutterFire CLI).
2. Despliegue de reglas y funciones:

```bash
firebase deploy --only firestore:rules,functions
```

3. Documentación detallada:
   - [docs/FIREBASE_ROLES_MIGRATION.md](docs/FIREBASE_ROLES_MIGRATION.md)
   - [docs/AUTH_USERS_ROLES.md](docs/AUTH_USERS_ROLES.md)

### Primer super administrador

```bash
set GOOGLE_APPLICATION_CREDENTIALS=ruta\serviceAccountKey.json
node scripts/create_super_admin.js --email admin@empresa.com
```

El usuario debe **cerrar sesión y volver a entrar** para cargar los custom claims.

---

## Variables de entorno

Copie `.env.example` a `.env` si su flujo lo requiere. **No suba `.env` ni service accounts al repositorio.**

```bash
copy .env.example .env   # Windows
# cp .env.example .env   # Linux/macOS
```

La app Flutter no depende de `.env` en runtime; usa `firebase_options.dart`.

---

## Ejecución por plataforma

```bash
flutter run                    # dispositivo/emulador por defecto
flutter run -d chrome          # Web
flutter run -d windows         # Windows desktop
flutter build apk --release    # Android APK
flutter build web --release    # Web estática (build/web)
```

---

## Comandos de validación

```bash
flutter clean
flutter pub get
dart format .
flutter analyze
flutter test
```

---

## Comandos de build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build web --release
flutter build windows --release
```

### Firebase (cuando aplique)

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only hosting
```

### Cloud Functions

```bash
cd functions
npm install
npm run lint
```

---

## Estructura del proyecto

```
lib/
  bootstrap/       # Inicialización Firebase
  core/            # Tema, widgets, permisos, errores, constantes
    errors/        # AppException, ErrorHandler
    widgets/       # Componentes reutilizables incl. filtros de registros
  features/        # Pantallas por módulo (auth, capture, records, …)
  models/          # NepRecord, alertas, filtros, usuarios
  providers/       # AppState, AuthProvider
  repositories/    # Cola Firestore para admin de usuarios
  services/        # Alertas, import/export, Firebase, analytics, sync
    record_export_coordinator.dart  # Orquestación CSV/Excel/PDF
  utils/           # Helpers de filtros, archivos, auth username
test/              # Tests unitarios y widget (96 casos)
docs/              # Documentación técnica — ver docs/README.md
functions/         # Cloud Functions (Admin SDK, roles, alertas)
scripts/           # Scripts admin locales (super admin, bootstrap)
```

---

## Roles y autenticación

Login con **usuario + contraseña** (email interno oculto `@vicunha.local`). Ver [docs/AUTH_ROLES.md](docs/AUTH_ROLES.md).

| Rol | Código | Gestión usuarios | Captura | Exportar |
|-----|--------|------------------|---------|----------|
| Super Admin | `super_admin` | Sí | Sí | Sí |
| Admin | `admin` | No | Sí | Sí |
| Supervisor | `supervisor` | No | No | Sí |
| Operario | `operario` | No | Sí | No |
| Gerencia | `gerencia` | No | No | Sí (solo lectura) |

---

## Importación de registros

1. **Registros** → **Descargar plantilla** (Excel de ejemplo).
2. Complete columnas obligatorias: Telar, Tela, Lote de trama, Neps (o Mts).
3. **Importar CSV/Excel** → revise vista previa (válidas, duplicadas, errores).
4. Confirme la importación.

---

## Exportación de informes

Desde **Exportar** o acciones de reporte: CSV, Excel, PDF e impresión. Los PDF usan fuentes OpenSans empaquetadas para caracteres Unicode.

---

## Acciones correctivas

En registros con alerta **Advertencia** o **Crítico**, use el icono de seguimiento para registrar responsable, acción e historial.

---

## Alertas (valores por defecto)

| Nivel | Condición |
|-------|-----------|
| Normal | Neps ≤ 30 |
| Advertencia | 30 < Neps ≤ 60 |
| Crítico | Neps > 60 |

Configurable en **Configuración**.

---

## Cloud Functions

Ubicación: `functions/`. Gestión segura de usuarios (custom claims), procesamiento de colas Firestore y alertas críticas. Node.js 22.

---

## Scripts administrativos

| Script | Uso |
|--------|-----|
| `scripts/create_super_admin.js` | Primer super administrador |
| `scripts/create_first_admin.js` | Alternativa bootstrap |
| `scripts/setup_role_users.js` | Usuarios de prueba por rol |
| `scripts/disable_anonymous_auth.js` | Desactivar auth anónima |

Requieren `GOOGLE_APPLICATION_CREDENTIALS` o `firebase login`. **Nunca commitear service accounts.**

---

## Seguridad — archivos que NO deben subirse

- `.env` y credenciales Firebase
- `**/serviceAccount*.json`, `auth_users.json`
- `functions/.env`, builds (`/build/`), `.dart_tool/`
- Tokens o exports de usuarios Auth

Ver `.gitignore` y `.env.example`.

---

## Estado actual del proyecto

| Aspecto | Estado |
|---------|--------|
| `flutter analyze` | Sin issues |
| `flutter test` | 91 tests pasando |
| Plataformas | Android, Web, Windows |
| Firebase | Auth + Firestore + Functions + reglas por rol |
| Versión | 1.0.0+14 |

---

## Próximas mejoras recomendadas

- Ampliar cobertura de tests en `ReportExportService`, `CloudSyncCoordinator` y sync cloud.
- Actualizar dependencias Firebase/Flutter cuando el equipo valide compatibilidad.

---

## Checklist para desarrolladores

- [ ] `flutter pub get && flutter analyze && flutter test`
- [ ] No commitear secretos ni `.env`
- [ ] Probar en al menos Web + una plataforma nativa antes de PR
- [ ] Revisar permisos en UI **y** reglas Firestore para cambios sensibles
- [ ] Documentar scripts admin en `docs/` si se añaden nuevos
- [ ] Ejecutar `dart format .` antes de commit

---

## Documentación adicional

Índice completo: [docs/README.md](docs/README.md)

- [docs/ENTREGA_FINAL.md](docs/ENTREGA_FINAL.md) — checklist de fases y guía integral
- [docs/FIREBASE_ROLES_MIGRATION.md](docs/FIREBASE_ROLES_MIGRATION.md)
- [docs/PUSH_NOTIFICATIONS.md](docs/PUSH_NOTIFICATIONS.md)

## APK con GitHub Actions

1. Suba el repo a GitHub.
2. **Actions** → **Build APK** → Run workflow.
3. Descargue artifact `calculadora-neps-apk` → `app-release.apk`.
