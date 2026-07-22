# Auditoría Fase 1 — Módulo de Reportes

**Proyecto:** Calculadora Neps VICUNHA  
**Fecha:** Julio 2026  
**Objetivo:** Documentar el estado actual antes del rediseño del generador de reportes profesionales.

---

## 1. Resumen ejecutivo

El proyecto dispone de exportación funcional (CSV, Excel, PDF) y analítica básica, pero **no existe un constructor de reportes configurable**. La exportación actual opera sobre registros visibles con selección limitada de columnas y dos estilos PDF. Las estadísticas avanzadas (mediana, percentiles, varianza, comparación entre periodos) **no están implementadas**.

---

## 2. Módulos existentes

### 2.1 Registros
- **Pantalla:** `lib/features/records/records_screen.dart`
- **Modelo:** `lib/models/nep_record.dart` — incluye campos para acciones correctivas, revisión, historial, creador
- **Filtros:** `lib/models/record_filters.dart` — filtro simple (un valor por campo), sin selección múltiple
- **Fórmula:** `mtsCalculados = neps / 0.09` (`testLengthM` en `lib/core/constants.dart`)

### 2.2 Gráficas (Analytics)
- **Pantalla:** `lib/features/analytics/analytics_screen.dart`
- **Servicio:** `lib/services/analytics_service.dart` — promedio, min/max, distribución alertas, agrupación día/semana/mes/año
- **Gráficas:** `fl_chart` vía `analytics_charts.dart`, `custom_chart_builder.dart`
- **Exportación analítica:** `lib/features/analytics/services/analytics_export_service.dart`

### 2.3 Informes guardados
- **Pantalla:** `lib/features/reports/reports_screen.dart` — lista informes guardados, exportación batch
- **Modelo:** `lib/models/saved_report.dart`
- **Persistencia:** `lib/services/report_storage_service.dart` (local + Firestore)

### 2.4 Exportación
- **Pantalla:** `lib/features/export/export_screen.dart` — columnas, estilo PDF, compartir
- **Motor:** `lib/services/report_export_service.dart` (~1200 líneas) — CSV, Excel, PDF completo/clásico
- **Coordinador:** `lib/services/record_export_coordinator.dart`

### 2.5 Dashboard
- **Pantalla:** `lib/features/dashboard/dashboard_screen.dart` — KPIs resumen, gráficas ligeras (límite 100 registros)

### 2.6 Filtros
- **UI:** `lib/core/widgets/record_filters_panel.dart`
- **Aplicación:** `lib/utils/record_filter_helper.dart` — filtros en memoria vs Firestore
- **Rangos rápidos:** hoy, ayer, esta semana, este mes, este año (sin trimestre ni periodo anterior)

### 2.7 Acciones correctivas
- **Modelo:** `lib/models/corrective_action_entry.dart`
- **UI:** `lib/core/widgets/corrective_action_dialog.dart`
- **Campos en registro:** `revisadoPorSupervisor`, `accionCorrectiva`, `historialAcciones`, `fechaRevision`

### 2.8 Firestore
- **Sync:** `lib/services/cloud_sync_service.dart`
- **Reglas:** `firestore.rules` — permisos por rol en workspace `vicunha`

---

## 3. Brechas identificadas

| Requerimiento | Estado actual |
|---------------|---------------|
| Constructor de reportes por pasos | No existe |
| Selección múltiple de filtros | No existe |
| Periodos (trimestre, anterior, todos) | Parcial |
| Estadísticas avanzadas | No existe (mediana, moda, percentiles, varianza) |
| Comparación entre periodos | No existe |
| Conclusiones automáticas | No existe |
| Plantillas configurables | No existe |
| Vista previa profesional | Solo impresión básica vía `printing` |
| Columnas extendidas en exportación | 10 columnas; faltan turno, operario, línea, revisión, etc. |
| Gráficas configurables en reporte | Solo en módulo Gráficas |
| Excel multi-hoja por sección | Parcial (hojas alertas/rankings en PDF completo) |
| Permisos granulares operario/creador | No existe |
| Análisis por operario restringido | No implementado |

---

## 4. Componentes reutilizables

- `AnalyticsService` — agrupaciones, KPIs básicos, tendencias
- `ReportExportService` — generación PDF/Excel/CSV, tema OpenSans
- `RecordFilterHelper` — aplicación de filtros, valores únicos
- `RecordFiltersPanel` — UI de filtros (extender para multi-select)
- `ExportColumnSelector` — patrón de selección de columnas
- `WidgetCaptureHelper` — captura PNG de gráficas
- `PermissionGate` / `RolePermissions` — control de acceso
- `ChartDataBuilder` / `ChartConfig` — construcción de datasets

---

## 5. Dependencias relevantes

| Paquete | Uso |
|---------|-----|
| `pdf` 3.11.1 | PDF |
| `printing` 5.13.4 | Vista previa/impresión |
| `excel` 4.0.6 | Excel |
| `fl_chart` 0.70.2 | Gráficas |
| `share_plus` | Compartir archivos |

---

## 6. Permisos actuales

- `exportReports` — exportar (super_admin, admin, supervisor, gerencia)
- `manageReports` — informes guardados
- `applyCorrectiveAction` — acciones correctivas (no gerencia)

**Nuevos permisos propuestos:** `viewOperatorAnalysis`, `viewCreatorInfo`, `manageReportTemplates`, `administerGlobalTemplates`

---

## 7. Tests existentes relacionados

- `test/report_export_service_test.dart`
- `test/analytics_service_test.dart`
- `test/analytics_period_grouping_test.dart`
- `test/permissions_service_test.dart`

---

## 8. Plan de implementación

Ver `docs/MODULO_REPORTES_PROFESIONALES.md` para arquitectura del nuevo módulo en `lib/features/reports/professional/`.
