import '../models/saved_report.dart';
import '../models/saved_report_summary.dart';

/// Plan puro de dual-write para un informe (sin I/O ni Firebase).
///
/// `reports/{id}` conserva el payload completo de [SavedReport].
/// `reportSummaries/{id}` solo metadata ligera.
class ReportDualWritePlan {
  const ReportDualWritePlan({
    required this.reportId,
    required this.reportData,
    required this.summaryData,
  });

  final String reportId;
  final Map<String, dynamic> reportData;
  final Map<String, dynamic> summaryData;

  factory ReportDualWritePlan.fromReport(SavedReport report) {
    final summary = SavedReportSummary.fromSavedReport(report);
    return ReportDualWritePlan(
      reportId: report.id,
      reportData: Map<String, dynamic>.from(report.toJson()),
      summaryData: Map<String, dynamic>.from(summary.toJson()),
    );
  }
}
