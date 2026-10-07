/// Capacidad de lectura cloud de informes / `reportSummaries`.
///
/// Debe alinearse con `firestore.rules` para
/// `workspaces/{id}/reports` y `reportSummaries`.
bool canReadCloudReportArchive({
  required bool canViewRecords,
  required bool canViewWorkspaceRecords,
  required bool canExportReports,
  required bool canManageReports,
  required bool canViewDashboard,
}) {
  return canManageReports ||
      canExportReports ||
      canViewRecords ||
      canViewWorkspaceRecords ||
      canViewDashboard;
}
