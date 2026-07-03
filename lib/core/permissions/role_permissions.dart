import '../../models/app_user_role.dart';
import 'permission.dart';

class RolePermissions {
  const RolePermissions._();

  static bool has(AppUserRole role, Permission permission) {
    return _matrix[role]?.contains(permission) ?? false;
  }

  static Set<Permission> forRole(AppUserRole role) {
    return _matrix[role] ?? {};
  }

  static const Map<AppUserRole, Set<Permission>> _matrix = {
    AppUserRole.superAdmin: {
      Permission.viewDashboard,
      Permission.captureRecords,
      Permission.viewRecords,
      Permission.editRecords,
      Permission.deleteRecords,
      Permission.clearAllRecords,
      Permission.viewAlerts,
      Permission.applyCorrectiveAction,
      Permission.manageFabrics,
      Permission.manageReports,
      Permission.exportReports,
      Permission.editAlertConfig,
      Permission.manageUsers,
      Permission.deleteUsers,
      Permission.changeRoles,
      Permission.viewSettings,
      Permission.manageSettings,
    },
    AppUserRole.admin: {
      Permission.viewDashboard,
      Permission.captureRecords,
      Permission.viewRecords,
      Permission.editRecords,
      Permission.deleteRecords,
      Permission.clearAllRecords,
      Permission.viewAlerts,
      Permission.applyCorrectiveAction,
      Permission.manageFabrics,
      Permission.manageReports,
      Permission.exportReports,
      Permission.viewSettings,
      Permission.manageSettings,
    },
    AppUserRole.supervisor: {
      Permission.viewDashboard,
      Permission.viewRecords,
      Permission.editRecords,
      Permission.viewAlerts,
      Permission.applyCorrectiveAction,
      Permission.exportReports,
      Permission.manageReports,
    },
    AppUserRole.operario: {
      Permission.captureRecords,
      Permission.viewRecords,
    },
    AppUserRole.gerencia: {
      Permission.viewDashboard,
      Permission.viewRecords,
      Permission.viewAlerts,
      Permission.exportReports,
      Permission.manageReports,
    },
  };
}
