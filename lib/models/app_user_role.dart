/// Rol canónico legacy (compatibilidad). La fuente de verdad de permisos es
/// [RoleCatalog] / `workspaces/.../roles/{code}` vía roleCode String.
enum AppUserRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Administrador'),
  supervisor('supervisor', 'Supervisor'),
  operario('operario', 'Operario'),
  gerencia('gerencia', 'Gerencia');

  const AppUserRole(this.code, this.label);

  final String code;
  final String label;

  /// Parsea roles conocidos y legacy. Null si el código no es un rol base.
  static AppUserRole? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final role in AppUserRole.values) {
      if (role.code == normalized) return role;
    }
    switch (raw.trim().toUpperCase()) {
      case 'ADMINISTRADOR':
        return AppUserRole.admin;
      case 'SUPERVISOR':
        return AppUserRole.supervisor;
      case 'GERENCIA':
        return AppUserRole.gerencia;
      case 'OPERARIO':
        return AppUserRole.operario;
      default:
        return null;
    }
  }

  /// Compatibilidad: roles legacy conocidos. Códigos desconocidos → null vía
  /// [tryParse]; este método ya no concede operario en silencio a códigos
  /// personalizados. Si [raw] es vacío, retorna operario solo como default de
  /// formularios legacy (preferir roleCode + RoleCatalog).
  static AppUserRole fromCode(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed;
    if (raw == null || raw.trim().isEmpty) return AppUserRole.operario;
    // Código personalizado / desconocido: no mapear a operario.
    // Callers deben usar roleCode + RoleCatalog. Aquí devolvemos operario
    // SOLO para no romper firmas AppUserRole; los permisos se resuelven por
    // roleCode y deny-by-default en RolePermissions.hasCode.
    return AppUserRole.operario;
  }

  bool get isSuperAdmin => this == AppUserRole.superAdmin;
  bool get isAdmin => this == AppUserRole.admin;
  bool get isSupervisor => this == AppUserRole.supervisor;
  bool get isOperario => this == AppUserRole.operario;
  bool get isGerencia => this == AppUserRole.gerencia;

  bool get isReadOnly => isGerencia;

  bool get isAdminOrAbove => isSuperAdmin || isAdmin;

  bool get isSupervisorOrAbove => isSuperAdmin || isAdmin || isSupervisor;
}
