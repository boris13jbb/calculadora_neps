import '../core/permissions/permission.dart';

/// Definición parametrizable de un rol (fuente de verdad de permisos).
class RoleDefinition {
  const RoleDefinition({
    required this.code,
    required this.name,
    this.description = '',
    required this.permissions,
    this.isActive = true,
    this.isSystem = false,
    this.isAssignable = true,
    this.sortOrder = 100,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String code;
  final String name;
  final String description;
  final Set<Permission> permissions;
  final bool isActive;
  final bool isSystem;
  final bool isAssignable;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  bool get isSuperAdmin => code == 'super_admin';

  /// Derivado de [Permission.viewWorkspaceRecords] (no es un segundo sistema).
  bool get seesWorkspaceRecords =>
      permissions.contains(Permission.viewWorkspaceRecords);

  bool get isReadOnly =>
      isActive &&
      permissions.contains(Permission.viewRecords) &&
      !permissions.contains(Permission.captureRecords) &&
      !permissions.contains(Permission.editRecords) &&
      code == 'gerencia';

  bool hasPermission(Permission permission) {
    if (!isActive) return false;
    return permissions.contains(permission);
  }

  RoleDefinition copyWith({
    String? code,
    String? name,
    String? description,
    Set<Permission>? permissions,
    bool? isActive,
    bool? isSystem,
    bool? isAssignable,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RoleDefinition(
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      isAssignable: isAssignable ?? this.isAssignable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'permissions': permissions.map((p) => p.name).toList()..sort(),
      'isActive': isActive,
      'isSystem': isSystem,
      'isAssignable': isAssignable,
      'sortOrder': sortOrder,
      // Campo derivado para compatibilidad con lecturas antiguas / Rules.
      'seesWorkspaceRecords': seesWorkspaceRecords,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  factory RoleDefinition.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    final perms = <Permission>{};
    if (rawPerms is Iterable) {
      for (final item in rawPerms) {
        final parsed = PermissionCatalog.tryParse(item?.toString());
        if (parsed != null) perms.add(parsed);
      }
    }
    // Migración: bool antiguo → permiso explícito.
    if (json['seesWorkspaceRecords'] == true) {
      perms.add(Permission.viewWorkspaceRecords);
    }

    return RoleDefinition(
      code: (json['code']?.toString() ?? '').trim().toLowerCase(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      permissions: perms,
      isActive: json['isActive'] != false,
      isSystem: json['isSystem'] == true,
      isAssignable: json['isAssignable'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 100,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Código de rol: minúsculas, letras/números/guion bajo, sin espacios.
  static final RegExp codePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static String? validateCode(String? raw) {
    final code = (raw ?? '').trim().toLowerCase();
    if (code.isEmpty) return 'Código requerido';
    if (code.length > 64) return 'Máximo 64 caracteres';
    if (!codePattern.hasMatch(code)) {
      return 'Use minúsculas, números y guion bajo (ej. jefe_turno)';
    }
    if (code == 'super_admin') {
      return 'El código super_admin está reservado';
    }
    return null;
  }
}

/// Catálogo técnico de permisos (no creados desde la UI).
class PermissionCatalog {
  const PermissionCatalog._();

  static Permission? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = raw.trim();
    for (final p in Permission.values) {
      if (p.name == key) return p;
    }
    return null;
  }

  static const Map<String, List<Permission>> groups = {
    'GENERAL': [
      Permission.viewDashboard,
      Permission.viewSettings,
      Permission.manageSettings,
    ],
    'REGISTROS': [
      Permission.viewRecords,
      Permission.viewWorkspaceRecords,
      Permission.captureRecords,
      Permission.editRecords,
      Permission.deleteRecords,
      Permission.clearAllRecords,
    ],
    'ALERTAS': [
      Permission.viewAlerts,
      Permission.applyCorrectiveAction,
      Permission.editAlertConfig,
    ],
    'REPORTES': [
      Permission.manageReports,
      Permission.exportReports,
    ],
    'TELAS': [
      Permission.manageFabrics,
    ],
    'USUARIOS': [
      Permission.manageUsers,
      Permission.deleteUsers,
      Permission.changeRoles,
    ],
  };

  static String labelOf(Permission permission) {
    switch (permission) {
      case Permission.viewDashboard:
        return 'Ver dashboard';
      case Permission.captureRecords:
        return 'Capturar registros';
      case Permission.viewRecords:
        return 'Ver registros propios';
      case Permission.viewWorkspaceRecords:
        return 'Ver registros de todo el workspace';
      case Permission.editRecords:
        return 'Editar registros';
      case Permission.deleteRecords:
        return 'Eliminar registros';
      case Permission.clearAllRecords:
        return 'Vaciar registros';
      case Permission.viewAlerts:
        return 'Ver alertas';
      case Permission.applyCorrectiveAction:
        return 'Aplicar acción correctiva';
      case Permission.manageFabrics:
        return 'Administrar telas';
      case Permission.manageReports:
        return 'Gestionar informes';
      case Permission.exportReports:
        return 'Exportar reportes';
      case Permission.editAlertConfig:
        return 'Editar configuración de alertas';
      case Permission.manageUsers:
        return 'Administrar usuarios';
      case Permission.deleteUsers:
        return 'Eliminar usuarios';
      case Permission.changeRoles:
        return 'Cambiar roles de usuarios';
      case Permission.viewSettings:
        return 'Ver configuración';
      case Permission.manageSettings:
        return 'Administrar configuración';
    }
  }
}
