import '../../models/app_user_role.dart';
import 'permission.dart';
import 'role_catalog.dart';

class RolePermissions {
  const RolePermissions._();

  /// Deny-by-default por [roleCode] (fuente principal).
  static bool hasCode(String? roleCode, Permission permission) {
    return RoleCatalog.instance.hasPermission(roleCode, permission);
  }

  static Set<Permission> forRoleCode(String? roleCode) {
    final role = RoleCatalog.instance.get(roleCode);
    if (role == null || !role.isActive) return {};
    return Set<Permission>.from(role.permissions);
  }

  /// Compatibilidad con callers legacy basados en enum.
  static bool has(AppUserRole role, Permission permission) {
    return hasCode(role.code, permission);
  }

  static Set<Permission> forRole(AppUserRole role) {
    return forRoleCode(role.code);
  }
}
