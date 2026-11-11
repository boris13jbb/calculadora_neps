import 'pending_report_sync_op.dart';
import 'report_sync_status.dart';
import 'saved_report.dart';

/// Resultado de guardar o reintentar un informe (estado real de sync).
class ReportSaveOutcome {
  const ReportSaveOutcome({
    required this.report,
    required this.status,
    required this.userMessage,
    this.errorCode,
    this.pendingOp,
    this.offlineHint = false,
  });

  final SavedReport report;
  final ReportSyncStatus status;
  final String userMessage;
  final String? errorCode;
  final PendingReportSyncOp? pendingOp;
  final bool offlineHint;

  bool get isCloudConfirmed => status == ReportSyncStatus.synced;

  bool get needsManualRetry =>
      status == ReportSyncStatus.retryableError ||
      status == ReportSyncStatus.localPending ||
      status == ReportSyncStatus.conflict;
}
