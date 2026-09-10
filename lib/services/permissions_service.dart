import '../core/permissions/permission.dart';
import '../core/permissions/role_catalog.dart';
import '../core/permissions/role_permissions.dart';
import '../models/app_user_role.dart';

/// Comprueba permisos según rol autenticado (la UI no sustituye reglas de Firestore).
class PermissionsService {
  const PermissionsService();

  bool has(AppUserRole? role, Permission permission) {
    if (role == null) return false;
    return RolePermissions.hasCode(role.code, permission);
  }

  bool hasCode(String? roleCode, Permission permission) {
    return RolePermissions.hasCode(roleCode, permission);
  }

  bool canCapture(AppUserRole? role) => has(role, Permission.captureRecords);

  bool canImportRecords(AppUserRole? role) =>
      has(role, Permission.editRecords) &&
      role != AppUserRole.operario &&
      role != AppUserRole.gerencia;

  bool canImportRecordsForCode(String? roleCode) {
    if (!hasCode(roleCode, Permission.editRecords)) return false;
    final code = RoleCatalog.normalizeRoleCode(roleCode);
    return code != 'operario' && code != 'gerencia';
  }

  bool canDeleteRecords(AppUserRole? role) =>
      has(role, Permission.deleteRecords);

  bool canClearAllRecords(AppUserRole? role) =>
      has(role, Permission.clearAllRecords);

  bool canApplyCorrectiveAction(AppUserRole? role) =>
      has(role, Permission.applyCorrectiveAction);

  bool canManageFabrics(AppUserRole? role) =>
      has(role, Permission.manageFabrics);

  bool canManageReports(AppUserRole? role) =>
      has(role, Permission.manageReports);

  bool canExportReports(AppUserRole? role) =>
      has(role, Permission.exportReports);

  bool canEditRecords(AppUserRole? role) => has(role, Permission.editRecords);

  bool canEditAlertConfig(AppUserRole? role) =>
      has(role, Permission.editAlertConfig);

  bool canManageSettings(AppUserRole? role) =>
      has(role, Permission.manageSettings);

  bool isReadOnly(AppUserRole? role) => role?.isGerencia ?? false;

  bool isReadOnlyCode(String? roleCode) {
    final code = RoleCatalog.normalizeRoleCode(roleCode);
    if (code == 'gerencia') return true;
    final def = RoleCatalog.instance.get(roleCode);
    return def?.isReadOnly ?? false;
  }

  String deniedMessage(String action) =>
      'No tiene permisos para $action. Contacte al super administrador.';
}

const PermissionsService permissionsService = PermissionsService();
