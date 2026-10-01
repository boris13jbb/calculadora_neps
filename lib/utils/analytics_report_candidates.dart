import '../core/permissions/report_visibility.dart';
import '../models/saved_report_summary.dart';

/// ¿El rango de records del summary intersecta [periodStart, periodEnd] (inclusive)?
///
/// Usa [SavedReportSummary.recordsCreatedAtMin]/[SavedReportSummary.recordsCreatedAtMax],
/// **nunca** [SavedReportSummary.createdAt] del informe.
///
/// Casos:
/// - A: `recordCount > 0` y min/max no nulos → intersección normal.
/// - B: `recordCount == 0` → excluir.
/// - C: `recordCount > 0` con min o max nulo → candidato conservador (incluir).
bool summaryIntersectsAnalyticsPeriod(
  SavedReportSummary summary, {
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  if (summary.recordCount <= 0) return false;

  final min = summary.recordsCreatedAtMin;
  final max = summary.recordsCreatedAtMax;
  if (min == null || max == null) return true;

  // max >= start AND min <= end (límites inclusivos)
  return !max.isBefore(periodStart) && !min.isAfter(periodEnd);
}

/// Selecciona IDs de informes candidatos para hidratar en Analíticas.
///
/// - Determinista y con orden estable (orden de entrada de [summaries]).
/// - Elimina IDs duplicados.
/// - Aplica [filterVisibleReportSummariesByOwner] (mismos permisos que Informes).
/// - Si [periodStart]/[periodEnd] son null (p. ej. custom sin fechas), incluye
///   todos los visibles con records (o min/max incompletos), sin filtrar por
///   intersección.
List<String> selectAnalyticsReportCandidateIds({
  required Iterable<SavedReportSummary> summaries,
  DateTime? periodStart,
  DateTime? periodEnd,
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  final visible = filterVisibleReportSummariesByOwner(
    summaries,
    viewerUid: viewerUid,
    canViewTeamReports: canViewTeamReports,
  );

  final seen = <String>{};
  final ids = <String>[];
  final hasBounds = periodStart != null && periodEnd != null;

  for (final summary in visible) {
    final id = summary.id.trim();
    if (id.isEmpty) continue;

    if (hasBounds) {
      if (!summaryIntersectsAnalyticsPeriod(
        summary,
        periodStart: periodStart,
        periodEnd: periodEnd,
      )) {
        continue;
      }
    } else if (summary.recordCount <= 0) {
      continue;
    }

    if (seen.add(id)) {
      ids.add(id);
    }
  }

  return ids;
}
