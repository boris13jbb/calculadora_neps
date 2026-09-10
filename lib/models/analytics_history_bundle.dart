import '../models/saved_report.dart';

/// Paquete de historial para la pantalla de gráficas.
class AnalyticsHistoryBundle {
  const AnalyticsHistoryBundle({
    required this.historyReports,
    this.isPartial = false,
    this.partialMessage,
    this.skippedReportCount = 0,
  });

  final List<SavedReport> historyReports;
  final bool isPartial;
  final String? partialMessage;
  final int skippedReportCount;
}
