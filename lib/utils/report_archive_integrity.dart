import '../models/saved_report.dart';
import '../models/saved_report_summary.dart';
import '../services/report_dual_write_plan.dart';

/// Tipo de inconsistencia entre `reports` y `reportSummaries`.
enum ReportArchiveIntegrityIssueType {
  reportWithoutSummary,
  summaryWithoutReport,
  recordCountMismatch,
  idMismatch,
  nameMismatch,
  createdByUidMismatch,
  createdAtMismatch,
  missingRequiredSummaryField,
  summaryContainsRecords,
  invalidReportPayload,
  invalidSummaryPayload,
}

/// Hallazgo de auditoría metadata-only (sin registros personales).
class ReportArchiveIntegrityIssue {
  const ReportArchiveIntegrityIssue({
    required this.type,
    required this.reportId,
    this.detail,
  });

  final ReportArchiveIntegrityIssueType type;
  final String reportId;
  final String? detail;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'reportId': reportId,
        if (detail != null && detail!.isNotEmpty) 'detail': detail,
      };
}

/// Resultado de comparar colecciones dual-write en memoria.
class ReportArchiveIntegrityReport {
  const ReportArchiveIntegrityReport({
    required this.reportCount,
    required this.summaryCount,
    required this.issues,
  });

  final int reportCount;
  final int summaryCount;
  final List<ReportArchiveIntegrityIssue> issues;

  int get orphanReportCount => orphanReportIds.length;

  int get orphanSummaryCount => orphanSummaryIds.length;

  List<String> get orphanReportIds => issues
      .where((i) => i.type == ReportArchiveIntegrityIssueType.reportWithoutSummary)
      .map((i) => i.reportId)
      .toList(growable: false);

  List<String> get orphanSummaryIds => issues
      .where((i) => i.type == ReportArchiveIntegrityIssueType.summaryWithoutReport)
      .map((i) => i.reportId)
      .toList(growable: false);

  bool get isHealthy => issues.isEmpty;

  Map<String, dynamic> toJson() => {
        'reportCount': reportCount,
        'summaryCount': summaryCount,
        'orphanReportCount': orphanReportCount,
        'orphanSummaryCount': orphanSummaryCount,
        'issueCount': issues.length,
        'isHealthy': isHealthy,
        'issues': issues.map((i) => i.toJson()).toList(growable: false),
      };
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

/// Audita mapas documentales `id → data` (solo lectura, sin I/O).
///
/// Pensado para tests, dry-run local y futuras auditorías Admin de solo lectura.
/// No escribe en Firestore ni modifica las entradas de entrada.
ReportArchiveIntegrityReport auditReportArchiveIntegrity({
  required Map<String, Map<String, dynamic>> reports,
  required Map<String, Map<String, dynamic>> summaries,
}) {
  final issues = <ReportArchiveIntegrityIssue>[];
  final reportIds = reports.keys.toSet();
  final summaryIds = summaries.keys.toSet();

  for (final id in reportIds) {
    if (!summaryIds.contains(id)) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.reportWithoutSummary,
          reportId: id,
          detail: 'Existe reports/$id sin reportSummaries/$id',
        ),
      );
    }
  }

  for (final id in summaryIds) {
    if (!reportIds.contains(id)) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.summaryWithoutReport,
          reportId: id,
          detail: 'Existe reportSummaries/$id sin reports/$id',
        ),
      );
    }
  }

  for (final id in reportIds.intersection(summaryIds)) {
    final reportRaw = Map<String, dynamic>.from(reports[id]!);
    final summaryRaw = Map<String, dynamic>.from(summaries[id]!);

    if (summaryRaw.containsKey('records')) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.summaryContainsRecords,
          reportId: id,
          detail: 'El summary no debe incluir records[]',
        ),
      );
    }

    final report = SavedReport.tryFromJson(reportRaw);
    if (report == null) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.invalidReportPayload,
          reportId: id,
          detail: 'No se pudo parsear reports/$id',
        ),
      );
      continue;
    }

    final summary = SavedReportSummary.tryFromJson(summaryRaw);
    if (summary == null) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.invalidSummaryPayload,
          reportId: id,
          detail: 'No se pudo parsear reportSummaries/$id',
        ),
      );
      continue;
    }

    final expected = SavedReportSummary.fromSavedReport(report);
    final requiredMissing = <String>[];
    if (_nonEmpty(summaryRaw['id']) == null) requiredMissing.add('id');
    if (_nonEmpty(summaryRaw['name']) == null) requiredMissing.add('name');
    if (_parseDate(summaryRaw['createdAt']) == null) {
      requiredMissing.add('createdAt');
    }
    if (summaryRaw['recordCount'] == null) requiredMissing.add('recordCount');
    if (requiredMissing.isNotEmpty) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.missingRequiredSummaryField,
          reportId: id,
          detail: 'Faltan: ${requiredMissing.join(', ')}',
        ),
      );
    }

    final pathId = id.trim();
    final reportFieldId = _nonEmpty(reportRaw['id']) ?? report.id.trim();
    final summaryFieldId = _nonEmpty(summaryRaw['id']) ?? summary.id.trim();
    if (reportFieldId != pathId || summaryFieldId != pathId) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.idMismatch,
          reportId: id,
          detail:
              'path=$pathId report.id=$reportFieldId summary.id=$summaryFieldId',
        ),
      );
    }

    if (summary.recordCount != expected.recordCount) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.recordCountMismatch,
          reportId: id,
          detail:
              'summary=${summary.recordCount} esperado=${expected.recordCount}',
        ),
      );
    }

    if (summary.name.trim() != report.name.trim()) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.nameMismatch,
          reportId: id,
          detail: 'summary y report tienen name distinto',
        ),
      );
    }

    final reportOwner = _nonEmpty(report.createdByUid);
    final summaryOwner = _nonEmpty(summary.createdByUid);
    if (reportOwner != summaryOwner) {
      issues.add(
        ReportArchiveIntegrityIssue(
          type: ReportArchiveIntegrityIssueType.createdByUidMismatch,
          reportId: id,
          detail: 'Propietario distinto entre full y summary',
        ),
      );
    }

    final reportCreated = report.createdAt.toUtc();
    final summaryCreated = summary.createdAt.toUtc();
    if (reportCreated.difference(summaryCreated).inSeconds.abs() > 0) {
      // Comparación por ISO exacta tolerante a precisión de milisegundos.
      final sameInstant =
          report.createdAt.toIso8601String() == summary.createdAt.toIso8601String() ||
              reportCreated.millisecondsSinceEpoch ==
                  summaryCreated.millisecondsSinceEpoch;
      if (!sameInstant) {
        issues.add(
          ReportArchiveIntegrityIssue(
            type: ReportArchiveIntegrityIssueType.createdAtMismatch,
            reportId: id,
            detail: 'createdAt distinto entre full y summary',
          ),
        );
      }
    }
  }

  return ReportArchiveIntegrityReport(
    reportCount: reports.length,
    summaryCount: summaries.length,
    issues: List.unmodifiable(issues),
  );
}

/// Construye el mapa summary esperado desde un [SavedReport] (sin I/O).
Map<String, dynamic> expectedSummaryDataFromReport(SavedReport report) {
  return Map<String, dynamic>.from(
    ReportDualWritePlan.fromReport(report).summaryData,
  );
}

/// True si un reintento reutiliza el mismo id (evita duplicar en cloud).
bool reportRetryPreservesIdentity({
  required String originalReportId,
  required String retryReportId,
}) {
  final a = originalReportId.trim();
  final b = retryReportId.trim();
  if (a.isEmpty || b.isEmpty) return false;
  return a == b;
}
