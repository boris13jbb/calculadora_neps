# Módulo de Reportes Profesionales

Documentación técnica del generador de reportes configurables de Calculadora Neps VICUNHA.

## Arquitectura

```
lib/features/reports/professional/
├── models/           # Configuración, estadísticas, plantillas
├── services/         # Estadísticas, agrupación, comparación, exportación, captura de gráficas
├── provider/         # Estado del asistente (ReportBuilderProvider)
└── widgets/          # Pantalla del generador y filtros avanzados
```

## Pantallas

| Pantalla | Ruta | Permiso |
|----------|------|---------|
| Generador de reportes | Navegación → Reportes | `exportReports` |
| Exportar (legacy) | Navegación → Exportar | `exportReports` |
| Informes guardados | Navegación → Informes | `manageReports` |

## Flujo de generación

1. **Periodo** — Selección de preset o rango personalizado
2. **Filtros** — Panel avanzado: telares, telas, lotes, turnos, operarios, líneas, alertas, revisión, acciones, rangos neps/mts, búsqueda
3. **Contenido** — Secciones, métricas, gráficas, plantillas
4. **Vista previa** — Procesamiento asíncrono con `ReportDataBuilder`
5. **Exportar** — Compartir PDF (con gráficas PNG embebidas), Excel o gráficas PNG sueltas

## Modelos principales

- `ReportConfiguration` — Configuración completa del reporte
- `ReportStatistics` — Estadísticas calculadas (mediana, percentiles, etc.)
- `ReportComparison` — Comparación entre periodos
- `ReportConclusion` — Conclusiones automáticas por reglas locales
- `ReportTemplate` — Plantillas guardadas

## Servicios

| Servicio | Responsabilidad |
|----------|-----------------|
| `ReportStatisticsService` | Mediana, moda, percentiles, varianza, filtros |
| `ReportGroupingService` | Agrupación temporal y por dimensión |
| `ReportComparisonService` | Comparación periodo actual vs anterior |
| `ReportConclusionEngine` | Conclusiones sin IA externa |
| `ReportDataBuilder` | Orquestación y validación |
| `ReportChartBuilder` | Widgets fl_chart para captura |
| `ReportChartCaptureService` | Captura PNG vía overlay + `WidgetCaptureHelper` |
| `ProfessionalReportPdfService` | PDF multi-sección con imágenes de gráficas |
| `ProfessionalReportExcelService` | Excel multi-hoja |
| `ReportTemplateRepository` | Persistencia de plantillas |

## Fórmulas

- **Metros calculados:** `Mts = Neps / 0.09` (`testLengthM`)
- **Mediana:** Valor central de la serie ordenada
- **Percentil:** Interpolación lineal (p en 0–100)
- **Varianza:** Media de cuadrados de desviaciones
- **Coeficiente de variación:** `(desviación estándar / |media|) × 100`
- **Índice de calidad:** `100 - % críticos`

## Permisos

| Acción | Roles |
|--------|-------|
| Generar/exportar reportes | super_admin, admin, supervisor, gerencia |
| Análisis por operario | Todos excepto operario |
| Datos del creador | super_admin, admin, supervisor |
| Guardar plantillas | Quien tenga `manageReports` |
| Plantillas globales | super_admin |

## Exportación y compartir

### PDF
- Portada, secciones configurables, tablas, conclusiones
- **Gráficas:** capturadas como PNG e incrustadas con `pw.Image` (una por página)
- Fuente OpenSans empaquetada
- Compartir vía `FileShareHelper.shareBytes` (sheet nativo en móvil; diálogo guardar en escritorio)

### Excel
- Hojas: Resumen, Indicadores, Serie temporal, Por dimensión, Alertas, Acciones, Comparación, Registros, Metadatos
- Compartir con `FileShareHelper`

### PNG
- Gráficas individuales o lote completo desde paso Exportar
- Captura con `ReportChartCaptureService` + `RepaintBoundary`

### CSV
- Exportación legacy desde pantalla Exportar

## Filtros avanzados (`ReportAdvancedFiltersPanel`)

| Grupo | Campos |
|-------|--------|
| Producción | Telares, telas, lotes, turnos, operarios*, líneas |
| Calidad | Nivel de alerta, revisado supervisor, acción correctiva, observaciones, responsable |
| Auditoría* | Usuario creador, rol creador |
| Numéricos | Rango neps, rango mts |
| Texto | Búsqueda libre |

\* Operarios oculto para rol `operario`. Datos de creador solo con permiso `canViewCreatorInfo`.

Los registros fuente provienen de `AppState.loadAnalyticsRecords()` (vivos + informes guardados).

## Plantillas predefinidas

1. **Ejecutivo** — KPIs, alertas, tendencia, comparación, conclusiones
2. **Técnico** — Estadísticas completas, análisis por dimensión, tabla
3. **Calidad** — Cumplimiento, alertas, variabilidad
4. **Seguimiento** — Revisiones, acciones correctivas, tiempos
5. **Personalizado** — Solo elementos seleccionados

## Pruebas

```bash
flutter test test/report_professional_module_test.dart
```

## Limitaciones conocidas

- Plantillas globales en Firestore: solo persistencia local por ahora
- Comparación rango A vs B personalizado: usar presets de periodo
- Captura de gráficas requiere contexto Flutter (no disponible en tests unitarios puros sin binding)

## Auditoría

Ver `docs/AUDITORIA_MODULO_REPORTES_FASE1.md` para el estado previo al rediseño.
