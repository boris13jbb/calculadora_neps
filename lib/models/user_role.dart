/// Roles de usuario en el workspace VICUNHA.
enum UserRole {
  operario('OPERARIO', 'Operario'),
  supervisor('SUPERVISOR', 'Supervisor'),
  administrador('ADMINISTRADOR', 'Administrador'),
  gerencia('GERENCIA', 'Gerencia');

  const UserRole(this.code, this.label);

  final String code;
  final String label;

  static UserRole fromCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return UserRole.operario;
    final lower = raw.trim().toLowerCase();
    if (lower == 'super_admin' || lower == 'admin') {
      return UserRole.administrador;
    }
    final normalized = raw.trim().toUpperCase();
    for (final role in UserRole.values) {
      if (role.code == normalized) return role;
    }
    switch (lower) {
      case 'supervisor':
        return UserRole.supervisor;
      case 'operario':
        return UserRole.operario;
      case 'gerencia':
        return UserRole.gerencia;
      default:
        return UserRole.operario;
    }
  }

  bool get isReadOnly => this == UserRole.gerencia;

  bool get isSupervisorOrAbove =>
      this == UserRole.supervisor ||
      this == UserRole.administrador;

  bool get isAdmin => this == UserRole.administrador;

  bool get canCapture => !isReadOnly;

  bool get canImportRecords => !isReadOnly;

  bool get canExport => true;

  bool get canDeleteRecords => !isReadOnly;

  bool get canClearAllRecords => isSupervisorOrAbove;

  bool get canApplyCorrectiveAction => isSupervisorOrAbove;

  bool get canManageFabrics => isSupervisorOrAbove;

  bool get canManageReports => isSupervisorOrAbove;

  bool get canEditAlertConfig => isAdmin;

  bool get canViewAllWorkspaceData => isSupervisorOrAbove || isReadOnly;
}
