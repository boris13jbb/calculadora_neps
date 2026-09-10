import '../../models/saved_report.dart';

/// Visibilidad de informes locales/equipo en dispositivo compartido.
///
/// - Con [canViewTeamReports] (p. ej. manageReports): ve el archivo de equipo.
/// - Sin ese permiso: solo ve informes con [SavedReport.createdByUid] == viewer.
/// - Informes legacy sin createdByUid no se muestran a cuentas sin alcance de equipo.
bool canViewSavedReport(
  SavedReport report, {
  required String? viewerUid,
  required bool canViewTeamReports,
}) {
  if (viewerUid == null || viewerUid.trim().isEmpty) return false;
  if (canViewTeamReports) return true;
  final owner = report.createdByUid?.trim();
  if (owner == null || owner.isEmpty) return false;
  return owner == viewerUid;
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
