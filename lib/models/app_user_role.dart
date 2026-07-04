/// Rol canónico alineado con custom claims de Firebase Auth y permisos de la app.
enum AppUserRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Administrador'),
  supervisor('supervisor', 'Supervisor'),
  operario('operario', 'Operario'),
  gerencia('gerencia', 'Gerencia');

  const AppUserRole(this.code, this.label);

  final String code;
  final String label;

  static AppUserRole fromCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return AppUserRole.operario;
    final normalized = raw.trim().toLowerCase();
    for (final role in AppUserRole.values) {
      if (role.code == normalized) return role;
    }
    // Compatibilidad con roles legacy en mayúsculas.
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
        return AppUserRole.operario;
    }
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
