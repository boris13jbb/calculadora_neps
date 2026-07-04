# Entrega final — Calculadora Neps VICUNHA

Sistema de control de calidad textil para registro, análisis y exportación de mediciones de neps.

## Resumen del proyecto

| Aspecto | Detalle |
|---------|---------|
| **Stack** | Flutter 3.x, Provider, Firebase/Firestore, SharedPreferences |
| **Plataformas** | Android, Web, Windows |
| **Fórmula** | `Mts calculados = Neps / 0.09` |
| **Tests** | `flutter test` — 96 tests unitarios y widget |

## Fases completadas

| Fase | Descripción | Estado |
|------|-------------|--------|
| 1 | Diagnóstico de arquitectura | ✅ |
| 2–5 | Alertas, dashboard, gráficas | ✅ |
| 7–8 | PDF y Excel profesionales | ✅ |
| 9 | Modelo ampliado (turno, operario, seguimiento) | ✅ |
| 10 | Preparación Firebase/roles | ✅ |
| 11 | Configuración de límites de alerta | ✅ |
| 12 | Notificaciones base (SnackBar, badge) | ✅ |
| 13 | Captura mejorada con validaciones | ✅ |
| 14 | Filtros extendidos | ✅ |
| 15 | Acciones correctivas e historial | ✅ |
| 16 | Importación con vista previa y plantilla | ✅ |
| 17 | UI/UX — estados vacíos y pulido | ✅ |
| 18–19 | Tests ampliados y README | ✅ |
| 20 | Entrega final documentada | ✅ |
| 21 | Firebase roles + reglas endurecidas | ✅ |
| 22 | Notificaciones push/local críticas | ✅ |

## Módulos funcionales

1. **Captura** — registro con validación de duplicados y neps altos
2. **Registros** — tabla con alertas, filtros, importación preview, acciones correctivas
3. **Alertas** — críticos, advertencias, top telares, recomendaciones
4. **Dashboard** — 9 KPIs + 6 gráficas analíticas
5. **Telas** — catálogo import/export
6. **Informes** — guardar/cargar/compartir informes
7. **Exportar** — CSV, Excel, PDF, imprimir, copiar
8. **Configuración** — límites de alerta personalizables

## Comandos de validación

```bash
cd regneps
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # o chrome / dispositivo Android
```

## Variables y configuración externa

| Requisito | Archivo / nota |
|-----------|----------------|
| Firebase (opcional) | `lib/firebase_options.dart` |
| Reglas Firestore | `firestore.rules` + `docs/FIREBASE_ROLES_MIGRATION.md` |
| Límites de alerta | SharedPreferences (`alertConfigStorageKey`) |
| Registros locales | SharedPreferences (`storageKey`) |

## Guía de prueba integral

### Flujo básico
1. Capturar registro (telar, neps, tela, lote).
2. Verificar cálculo de mts y color de alerta en tabla.
3. Exportar a PDF/Excel desde Exportar.
4. Revisar dashboard con KPIs actualizados.

### Flujo de calidad
1. Registrar neps > 60 → alerta crítica + SnackBar.
2. Ir a Alertas → ver registro en sección críticos.
3. En Registros → icono de seguimiento → registrar acción correctiva.
4. Marcar como revisado → verificar historial.

### Flujo de importación
1. Registros → Descargar plantilla.
2. Completar Excel → Importar → revisar vista previa.
3. Confirmar importación → verificar registros en tabla.

### Flujo de informes
1. Exportar → Guardar informe.
2. Informes → cargar informe guardado.
3. Verificar filtros y registros restaurados.

## Archivos clave

```
lib/
  core/widgets/empty_state.dart      # Estados vacíos
  core/widgets/status_banner.dart    # Banners de aviso
  services/alert_service.dart        # Lógica de alertas
  services/analytics_service.dart    # KPIs y gráficas
  services/report_export_service.dart # PDF/Excel/CSV
  services/record_import_service.dart # Importación con preview
  providers/app_state.dart           # Estado global
docs/
  FASE_17_UI_UX.md
  FIREBASE_ROLES_MIGRATION.md
  ENTREGA_FINAL.md
```

## Riesgos y pendientes opcionales

- Endurecer reglas Firestore según `FIREBASE_ROLES_MIGRATION.md`
- Sync Windows (actualmente solo Android/Web)
- Skeleton loaders en dashboard (mejora futura)
- Notificaciones push para alertas críticas

## Contacto y mantenimiento

Mantener convenciones del proyecto: capas `features/`, `services/`, `providers/`, tests en `test/`, commits convencionales.
