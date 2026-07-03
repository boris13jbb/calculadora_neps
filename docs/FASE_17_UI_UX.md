# FASE 17 — UI/UX profesional

Documentación de la fase de pulido visual, estados vacíos, carga y errores.

## Objetivo

Unificar la experiencia de usuario con componentes reutilizables y mensajes contextuales en todas las pantallas principales.

## Componentes creados

| Widget | Ruta | Uso |
|--------|------|-----|
| `EmptyState` | `lib/core/widgets/empty_state.dart` | Estados vacíos con icono, título, mensaje y acciones |
| `StatusBanner` | `lib/core/widgets/status_banner.dart` | Avisos de sync, errores e información |
| `AppLoadingView` | `lib/core/widgets/app_loading_view.dart` | Carga inicial con branding |

## Mensajes FASE 17 implementados

| Mensaje | Pantalla |
|---------|----------|
| "No hay alertas críticas." | Alertas → sección críticos |
| "No hay advertencias activas." | Alertas → sección advertencias |
| "No hay registros para analizar." | Alertas → top telares |
| "Importe o capture registros para ver gráficas." | Dashboard → gráficas |

## Pantallas actualizadas

- **AppShell**: carga inicial mejorada, error de bootstrap con reintentar, banner de sync
- **Dashboard**: empty en gráficas con CTA a Captura/Registros
- **Alertas**: empty states enriquecidos por sección
- **Registros**: distingue tabla vacía vs filtros sin resultados
- **Exportar**: bloque vacío, botones deshabilitados sin datos
- **Telas**: empty con CTA importar, spinner en exportación
- **Informes**: migrado al widget `EmptyState`
- **Captura**: panel compacto con empty state

## Criterios de aceptación

- [x] Widget `EmptyState` reutilizable
- [x] Diferenciar "sin datos" vs "filtros sin coincidencias" en Registros
- [x] Exportación deshabilitada visualmente sin registros visibles
- [x] Carga inicial con mensaje (no solo spinner)
- [x] Error de datos locales con botón Reintentar
- [x] Banner global de sincronización en la nube
- [x] Test widget de `EmptyState`

## Pruebas manuales recomendadas

1. Abrir app sin registros → Dashboard muestra empty en gráficas con botones.
2. Aplicar filtro imposible en Registros → mensaje "Sin coincidencias" + limpiar filtros.
3. Ir a Exportar sin datos → card "Nada que exportar", botones deshabilitados.
4. Ir a Alertas sin críticos → icono verde "Sin alertas críticas".
5. Desconectar Firebase → banner amarillo en todas las pantallas.
