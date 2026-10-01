import '../models/saved_report.dart';

/// Métricas internas/debug del cargado lazy de historial (PR3).
///
/// No se muestran en UI; útiles para tests y diagnóstico.
class AnalyticsHistoryLoadMetrics {
  const AnalyticsHistoryLoadMetrics({
    this.reportsCandidates = 0,
    this.reportsHydrated = 0,
    this.reportsReusedFromCache = 0,
    this.reportsMissingSummary = 0,
    this.recordsDeserialized = 0,
    this.duration = Duration.zero,
    this.usedFetchReports = false,
  });

  final int reportsCandidates;
  final int reportsHydrated;
  final int reportsReusedFromCache;
  final int reportsMissingSummary;
  final int recordsDeserialized;
  final Duration duration;

  /// Debe ser siempre false en el camino PR3 de Analíticas.
  final bool usedFetchReports;
}

/// Paquete de historial para la pantalla de gráficas.
class AnalyticsHistoryBundle {
  const AnalyticsHistoryBundle({
    required this.historyReports,
    this.isPartial = false,
    this.partialMessage,
    this.skippedReportCount = 0,
    this.metrics = const AnalyticsHistoryLoadMetrics(),
  });

  final List<SavedReport> historyReports;
  final bool isPartial;
  final String? partialMessage;
  final int skippedReportCount;
  final AnalyticsHistoryLoadMetrics metrics;
}
