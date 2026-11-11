import 'package:firebase_core/firebase_core.dart';

import '../models/report_sync_status.dart';

/// Clasifica errores de sync de informes (sin tocar Firebase de prod).
class ReportSyncErrorClassification {
  const ReportSyncErrorClassification({
    required this.status,
    required this.code,
  });

  final ReportSyncStatus status;
  final String code;
}

ReportSyncErrorClassification classifyReportSyncError(Object error) {
  if (error is FirebaseException) {
    final code = error.code;
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
      case 'invalid-argument':
      case 'failed-precondition':
        return ReportSyncErrorClassification(
          status: ReportSyncStatus.permanentError,
          code: code,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'aborted':
      case 'cancelled':
      case 'network-request-failed':
        return ReportSyncErrorClassification(
          status: ReportSyncStatus.retryableError,
          code: code,
        );
      default:
        return ReportSyncErrorClassification(
          status: ReportSyncStatus.retryableError,
          code: code,
        );
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('permission-denied') ||
      text.contains('permission denied') ||
      text.contains('unauthenticated')) {
    return const ReportSyncErrorClassification(
      status: ReportSyncStatus.permanentError,
      code: 'permission-denied',
    );
  }
  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('offline') ||
      text.contains('unavailable') ||
      text.contains('timeout')) {
    return const ReportSyncErrorClassification(
      status: ReportSyncStatus.retryableError,
      code: 'network',
    );
  }
  return ReportSyncErrorClassification(
    status: ReportSyncStatus.retryableError,
    code: error.runtimeType.toString(),
  );
}
