import '../../models/saved_report.dart';
import '../../models/saved_report_summary.dart';

/// Visibilidad de informes locales/equipo en dispositivo compartido.
///
/// - Con [canViewTeamReports] (p. ej. manageReports): ve el archivo de equipo.
/// - Sin ese permiso: solo ve informes con [SavedReport.createdByUid] == viewer.
/// - Informes legacy sin createdByUid no se muestran a cuentas sin alcance de equipo.
bool canViewReportOwner({
  required String? createdByUid,
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  if (viewerUid == null || viewerUid.trim().isEmpty) return false;
  if (canViewTeamReports) return true;
  final owner = createdByUid?.trim();
  if (owner == null || owner.isEmpty) return false;
  return owner == viewerUid;
}

bool canViewSavedReport(
  SavedReport report, {
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  return canViewReportOwner(
    createdByUid: report.createdByUid,
    viewerUid: viewerUid,
    canViewTeamReports: canViewTeamReports,
  );
}

bool canViewSavedReportSummary(
  SavedReportSummary summary, {
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  return canViewReportOwner(
    createdByUid: summary.createdByUid,
    viewerUid: viewerUid,
    canViewTeamReports: canViewTeamReports,
  );
}

List<SavedReport> filterVisibleReports(
  Iterable<SavedReport> reports, {
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  return reports
      .where(
        (report) => canViewSavedReport(
          report,
          viewerUid: viewerUid,
          canViewTeamReports: canViewTeamReports,
        ),
      )
      .toList(growable: false);
}

List<SavedReportSummary> filterVisibleReportSummariesByOwner(
  Iterable<SavedReportSummary> summaries, {
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  return summaries
      .where(
        (summary) => canViewSavedReportSummary(
          summary,
          viewerUid: viewerUid,
          canViewTeamReports: canViewTeamReports,
        ),
      )
      .toList(growable: false);
}
