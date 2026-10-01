import 'report_list_metrics.dart';
import 'saved_report_summary.dart';

/// Resultado de cargar el listado liviano de informes (summaries).
class ReportSummariesLoadResult {
  const ReportSummariesLoadResult({
    required this.summaries,
    required this.metrics,
    this.skippedCount = 0,
    this.cloudError,
    this.isPartial = false,
  });

  final List<SavedReportSummary> summaries;
  final ReportListMetrics metrics;
  final int skippedCount;
  final String? cloudError;
  final bool isPartial;

  bool get hasUsableData => summaries.isNotEmpty;
}
