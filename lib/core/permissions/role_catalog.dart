import '../../models/role_definition.dart';
import 'permission.dart';

/// Catálogo en memoria de roles: seeds base + overlay Firestore.
/// Deny-by-default: código desconocido o inactivo → sin permisos.
class RoleCatalog {
  RoleCatalog._();

  static final RoleCatalog instance = RoleCatalog._();

  final Map<String, RoleDefinition> _roles = {
    for (final role in baseRoles) role.code: role,
  };

  static List<RoleDefinition> get baseRoles => [
        RoleDefinition(
          code: 'super_admin',
          name: 'Super Admin',
          description:
              'Control total del sistema. No asignable desde el panel.',
          permissions: Permission.values.toSet(),
          isSystem: true,
          isAssignable: false,
          sortOrder: 0,
          seesWorkspaceRecords: true,
        ),
        RoleDefinition(
          code: 'admin',
          name: 'Administrador',
          description: 'Administración operativa sin gestión de usuarios.',
          permissions: {
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
          isSystem: true,
          isAssignable: true,
          sortOrder: 10,
          seesWorkspaceRecords: true,
        ),
        RoleDefinition(
          code: 'supervisor',
          name: 'Supervisor',
          description: 'Supervisión de registros, alertas e informes.',
          permissions: {
            Permission.viewDashboard,
            Permission.viewRecords,
            Permission.editRecords,
            Permission.viewAlerts,
            Permission.applyCorrectiveAction,
            Permission.exportReports,
            Permission.manageReports,
          },
          isSystem: true,
          isAssignable: true,
          sortOrder: 20,
          seesWorkspaceRecords: true,
        ),
        RoleDefinition(
          code: 'operario',
          name: 'Operario',
          description: 'Captura y consulta de registros propios.',
          permissions: {
            Permission.captureRecords,
            Permission.viewRecords,
          },
          isSystem: true,
          isAssignable: true,
          sortOrder: 30,
          seesWorkspaceRecords: false,
        ),
        RoleDefinition(
          code: 'gerencia',
          name: 'Gerencia',
          description: 'Solo lectura de indicadores e informes.',
          permissions: {
            Permission.viewDashboard,
            Permission.viewRecords,
            Permission.viewAlerts,
            Permission.exportReports,
            Permission.manageReports,
          },
          isSystem: true,
          isAssignable: true,
          sortOrder: 40,
          seesWorkspaceRecords: true,
        ),
      ];

  /// Reemplaza/mezcla definiciones remotas sin borrar seeds si faltan.
  void replaceAll(Iterable<RoleDefinition> remote) {
    final next = <String, RoleDefinition>{
      for (final role in baseRoles) role.code: role,
    };
    for (final role in remote) {
      if (role.code.isEmpty) continue;
      next[role.code] = role;
    }
    // super_admin siempre protegido en catálogo local.
    next['super_admin'] = baseRoles.firstWhere((r) => r.code == 'super_admin');
    _roles
      ..clear()
      ..addAll(next);
  }

  void upsert(RoleDefinition role) {
    if (role.code.isEmpty) return;
    if (role.code == 'super_admin') {
      _roles['super_admin'] =
          baseRoles.firstWhere((r) => r.code == 'super_admin');
      return;
    }
    _roles[role.code] = role;
  }

  RoleDefinition? get(String? code) {
    final normalized = normalizeRoleCode(code);
    if (normalized == null) return null;
    return _roles[normalized];
  }

  List<RoleDefinition> listAll() {
    final list = _roles.values.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  List<RoleDefinition> listAssignable() {
    return listAll()
        .where((r) => r.isActive && r.isAssignable && !r.isSuperAdmin)
        .toList();
  }

  bool hasPermission(String? roleCode, Permission permission) {
    final role = get(roleCode);
    if (role == null || !role.isActive) return false;
    return role.hasPermission(permission);
  }

  bool seesWorkspaceRecords(String? roleCode) {
    final role = get(roleCode);
    if (role == null || !role.isActive) return false;
    return role.seesWorkspaceRecords;
  }

  String displayName(String? roleCode) {
    final role = get(roleCode);
    if (role != null) return role.name;
    final code = normalizeRoleCode(roleCode);
    if (code == null) return 'Sin rol';
    return 'Desconocido ($code)';
  }

  /// Normaliza legacy y códigos actuales. Null si vacío.
  static String? normalizeRoleCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    const legacy = {
      'administrador': 'admin',
      'supervisor': 'supervisor',
      'operario': 'operario',
      'gerencia': 'gerencia',
    };
    final upper = trimmed.toUpperCase();
    switch (upper) {
      case 'ADMINISTRADOR':
        return 'admin';
      case 'SUPERVISOR':
        return 'supervisor';
      case 'OPERARIO':
        return 'operario';
      case 'GERENCIA':
        return 'gerencia';
    }
    if (legacy.containsKey(lower)) return legacy[lower];
    return lower;
  }
}
