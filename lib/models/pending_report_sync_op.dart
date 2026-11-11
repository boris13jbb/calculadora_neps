import '../core/constants.dart';
import '../utils/report_content_fingerprint.dart';
import '../utils/stable_id.dart';
import 'report_sync_status.dart';
import 'saved_report.dart';

enum PendingReportSyncOpType { upsert, delete }

/// Operación pendiente de sync de Informes (`reports` / `reportSummaries`).
///
/// Incluye payload íntegro para sobrevivir reinicios. No guarda tokens.
class PendingReportSyncOp {
  PendingReportSyncOp({
    required this.id,
    required this.reportId,
    required this.ownerUid,
    required this.workspaceId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.contentFingerprint,
    this.lastAttemptAt,
    this.attempts = 0,
    this.errorCode,
    this.baseFingerprint,
    this.report,
  });

  final String id;
  final String reportId;
  final String ownerUid;
  final String workspaceId;
  final PendingReportSyncOpType type;
  final ReportSyncStatus status;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int attempts;
  final String? errorCode;

  /// Huella del payload local pendiente.
  final String contentFingerprint;

  /// Huella remota conocida al encolar una actualización legítima (nullable).
  final String? baseFingerprint;

  /// Copia íntegra del informe (upsert). Null en delete.
  final SavedReport? report;

  bool get isTerminal =>
      status == ReportSyncStatus.synced ||
      status == ReportSyncStatus.permanentError ||
      status == ReportSyncStatus.conflict;

  bool get canAutoRetry =>
      status == ReportSyncStatus.localPending ||
      status == ReportSyncStatus.retryableError ||
      status == ReportSyncStatus.syncing;

  PendingReportSyncOp copyWith({
    ReportSyncStatus? status,
    DateTime? lastAttemptAt,
    int? attempts,
    String? errorCode,
    bool clearErrorCode = false,
    SavedReport? report,
    String? contentFingerprint,
    String? baseFingerprint,
  }) {
    return PendingReportSyncOp(
      id: id,
      reportId: reportId,
      ownerUid: ownerUid,
      workspaceId: workspaceId,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attempts: attempts ?? this.attempts,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
      baseFingerprint: baseFingerprint ?? this.baseFingerprint,
      report: report ?? this.report,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportId': reportId,
        'ownerUid': ownerUid,
        'workspaceId': workspaceId,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (lastAttemptAt != null)
          'lastAttemptAt': lastAttemptAt!.toIso8601String(),
        'attempts': attempts,
        if (errorCode != null && errorCode!.isNotEmpty) 'errorCode': errorCode,
        'contentFingerprint': contentFingerprint,
        if (baseFingerprint != null && baseFingerprint!.isNotEmpty)
          'baseFingerprint': baseFingerprint,
        if (report != null) 'report': report!.toJson(),
      };

  static PendingReportSyncOp? tryFromJson(Map<String, dynamic> json) {
    try {
      final reportId = json['reportId']?.toString().trim() ?? '';
      final ownerUid = json['ownerUid']?.toString().trim() ?? '';
      if (reportId.isEmpty || ownerUid.isEmpty) return null;

      final typeName = json['type']?.toString() ?? 'upsert';
      final type = PendingReportSyncOpType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => PendingReportSyncOpType.upsert,
      );

      final statusName = json['status']?.toString() ?? 'localPending';
      final status = ReportSyncStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ReportSyncStatus.localPending,
      );

      SavedReport? report;
      final rawReport = json['report'];
      if (rawReport is Map) {
        report = SavedReport.tryFromJson(
          Map<String, dynamic>.from(rawReport),
        );
      }
      if (type == PendingReportSyncOpType.upsert && report == null) {
        return null;
      }

      final fingerprint = json['contentFingerprint']?.toString().trim();
      final resolvedFingerprint = (fingerprint == null || fingerprint.isEmpty)
          ? (report != null ? reportContentFingerprint(report) : '')
          : fingerprint;
      if (resolvedFingerprint.isEmpty &&
          type == PendingReportSyncOpType.upsert) {
        return null;
      }

      return PendingReportSyncOp(
        id: json['id']?.toString() ?? generateStableId(prefix: 'prso'),
        reportId: reportId,
        ownerUid: ownerUid,
        workspaceId:
            json['workspaceId']?.toString().trim().isNotEmpty == true
                ? json['workspaceId'].toString().trim()
                : cloudWorkspaceId,
        type: type,
        status: status == ReportSyncStatus.synced
            ? ReportSyncStatus.localPending
            : status,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        lastAttemptAt:
            DateTime.tryParse(json['lastAttemptAt']?.toString() ?? ''),
        attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
        errorCode: json['errorCode']?.toString(),
        contentFingerprint: resolvedFingerprint,
        baseFingerprint: json['baseFingerprint']?.toString(),
        report: report,
      );
    } catch (_) {
      return null;
    }
  }

  factory PendingReportSyncOp.upsert({
    required SavedReport report,
    required String ownerUid,
    String workspaceId = cloudWorkspaceId,
    String? baseFingerprint,
    ReportSyncStatus status = ReportSyncStatus.localPending,
  }) {
    return PendingReportSyncOp(
      id: generateStableId(prefix: 'prso'),
      reportId: report.id,
      ownerUid: ownerUid,
      workspaceId: workspaceId,
      type: PendingReportSyncOpType.upsert,
      status: status,
      createdAt: DateTime.now(),
      contentFingerprint: reportContentFingerprint(report),
      baseFingerprint: baseFingerprint,
      report: report,
    );
  }
}
