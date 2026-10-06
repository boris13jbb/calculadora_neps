# Auditoría de paridad — RegNeps.Net vs Flutter productivo

**Fecha:** 2026-10-02
**Alcance:** gaps relevantes **antes** de sustituir el cloud en planta.
**Flutter de referencia:** app raíz (`lib/`) + criterios en `neps_quality_criteria.dart`.
**RegNeps.Net:** `RegNeps.Net/src/**`.

## Resumen

RegNeps.Net cubre el flujo web/PC (login, captura, registros, alertas, telas, informes, export, usuarios) sobre SQL local. **No** es paridad funcional completa con el Flutter 2026 cloud. **No sustituir** Firebase Hosting/APK en planta hasta cerrar los gaps bloqueantes abajo.

## Alineado

| Área | Estado |
|------|--------|
| Fórmula `Mts = Neps / 0.09` | OK (`NepsConstants.TestLengthM`) |
| Workspace id `vicunha` | OK (constante) |
| Módulos UI principales | Presentes (rutas Blazor) |
| Operario: captura + ver registros | OK (matriz fija) |
| Auth local usuario/clave | OK (cookies; sin exigir correo salvo super admin seed) |
| Export CSV/Excel/PDF | Presente |
| Migración histórica Firestore→SQL | Herramientas documentadas |

## Gaps bloqueantes / altos (antes de cutover)

| Gap | Flutter actual | RegNeps.Net | Riesgo |
|-----|----------------|-------------|--------|
| Criterios oficiales de calificación | `classifyNeps` + umbrales 0–18 / 19–45 / 46–54 / ≥55 y NEPS/m² ≤200/≤500/≤600/>600; labels OK · Mención · Crítico — Realizar Ajuste · 2da Calidad | `AlertEvaluator` usa umbrales configurables legacy **30 / 60** (Normal / Advertencia / Crítico); no hay categorías oficiales de calidad | Clasificación y reportes **no equivalentes** al producto cloud |
| Roles parametrizables | `workspaces/vicunha/roles/{roleCode}` + permisos granulares | Matriz enum fija `RolePermissions` | No hay roles custom ni `viewWorkspaceRecords` cloud |
| Sync multiusuario / tombstones | Firestore + delete-wins | BD SQL única en servidor | Modelo distinto (aceptable en intranet si un solo servidor) |
| Android / offline Hive | APK + cola offline | Fuera de alcance | Planta móvil sigue en Flutter o queda sin app nativa |
| FCM push | Alertas push | Sin push | Solo UI/local |
| Informes Fase 2A | `reportSummaries` + lazy fetch | `SavedReports` locales | Metadatos/listado distintos |
| Analytics avanzado | fl_chart + builder profesional amplio | KPIs/tablas + charts JS limitados | Paridad parcial |
| AD / Entra ID | N/A (Firebase Auth) | No implementado | Usuarios locales |

## Gaps medios

- `alertasActivas` en Flutter no altera clasificación; en .NET `AlertasActivas=false` fuerza Normal.
- Sin App Check / Hosting público: correcto para intranet; no aplica.
- Seed admin local en BD vacía (cambiar contraseña en primer acceso).
- Criterios PDF «CRITERIOS OFICIALES DE CALIFICACIÓN» del Flutter no están portados 1:1.

## Recomendación de cutover

1. **Piloto intranet** con SQLite/Kestrel en LAN (este plan) sin apagar Flutter.
2. Portar `NepsQualityCriteria` / `classifyNeps` a Domain .NET (misma convención inclusiva) y alinear UI/export/alertas a `displayLabel`.
3. Decidir si roles fijos bastan en planta o hace falta tabla de roles.
4. Migrar históricos solo con petición explícita (ver `MIGRACION_FIRESTORE.md` + estado diferido).
5. Solo entonces valorar apagar Hosting/APK para PCs de planta.

## Conclusión

**Factible operar en intranet hoy** como producto paralelo. **No listo** para sustituir el Flutter cloud en calificación oficial ni en roles/sync avanzados sin trabajo de paridad adicional.
