/// Permisos granulares del sistema (catálogo técnico; no creados desde la UI).
enum Permission {
  viewDashboard,
  captureRecords,
  viewRecords,

  /// Lectura de registros de todo el workspace (no solo propios).
  viewWorkspaceRecords,
  editRecords,
  deleteRecords,
  clearAllRecords,
  viewAlerts,
  applyCorrectiveAction,
  manageFabrics,
  manageReports,
  exportReports,
  editAlertConfig,
  manageUsers,
  deleteUsers,
  changeRoles,
  viewSettings,
  manageSettings,
}
