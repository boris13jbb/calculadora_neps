import '../models/saved_report.dart';

/// Resultado de cargar informes con tolerancia a fallos parciales.
class ReportsLoadResult {
  const ReportsLoadResult({
    required this.reports,
    this.skippedCount = 0,
    this.cloudError,
    this.isPartial = false,
  });

  final List<SavedReport> reports;
  final int skippedCount;
  final String? cloudError;
  final bool isPartial;

  bool get hasUsableData => reports.isNotEmpty;
}
