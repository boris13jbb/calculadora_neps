import '../core/constants.dart';
import '../core/permissions/permission.dart';
import '../core/permissions/role_permissions.dart';
import '../utils/firestore_json_helper.dart';
import '../utils/username_auth_helper.dart';
import 'app_user_role.dart';

class AppUser {
  AppUser({
    required this.uid,
    required this.username,
    this.internalEmail,
    this.realEmail,
    this.displayName = '',
    required this.role,
    this.isActive = true,
    this.isSuperAdmin = false,
    this.phone,
    this.photoUrl,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.deletedAt,
  });

  final String uid;
  final String username;
  final String? internalEmail;
  final String? realEmail;
  final String displayName;
  final AppUserRole role;
  final bool isActive;
  final bool isSuperAdmin;
  final String? phone;
  final String? photoUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final DateTime? deletedAt;

  /// Compatibilidad: email de autenticación (real o interno).
  String get email => authEmail;

  /// Email usado por Firebase Auth (real para super_admin, interno para el resto).
  String get authEmail => realEmail ?? internalEmail ?? '';

  /// Nombre visible; si no hay displayName, usa username.
  String get effectiveDisplayName =>
      displayName.isNotEmpty ? displayName : username;

  bool get isSuperAdminRole => isSuperAdmin || role.isSuperAdmin;
  bool get isAdminRole => role.isAdmin;
  bool get isSupervisorRole => role.isSupervisor;
  bool get isOperarioRole => role.isOperario;
  bool get isGerenciaRole => role.isGerencia;

  bool get isAdmin => isAdminRole;
  bool get isSupervisor => isSupervisorRole;
  bool get isOperario => isOperarioRole;
  bool get isGerencia => isGerenciaRole;

  bool get canManageUsers =>
      isActive &&
      isSuperAdminRole &&
      RolePermissions.has(role, Permission.manageUsers);
  bool get canCreateUsers => canManageUsers;
  bool get canDeleteUsers =>
      isActive &&
      isSuperAdminRole &&
      RolePermissions.has(role, Permission.deleteUsers);
  bool get canResetPasswords => canManageUsers;
  bool get canChangeRoles =>
      isActive &&
      isSuperAdminRole &&
      RolePermissions.has(role, Permission.changeRoles);
  bool get canViewDashboard =>
      isActive && RolePermissions.has(role, Permission.viewDashboard);
  bool get canCaptureRecords =>
      isActive && RolePermissions.has(role, Permission.captureRecords);
  bool get canEditRecords =>
      isActive && RolePermissions.has(role, Permission.editRecords);
  bool get canDeleteRecords =>
      isActive && RolePermissions.has(role, Permission.deleteRecords);
  bool get canExportReports =>
      isActive && RolePermissions.has(role, Permission.exportReports);
  bool get canManageSettings =>
      isActive && RolePermissions.has(role, Permission.manageSettings);

  bool hasPermission(Permission permission) {
    if (!isActive) return false;
    return RolePermissions.has(role, permission);
  }

  AppUser copyWith({
    String? uid,
    String? username,
    String? internalEmail,
    String? realEmail,
    String? displayName,
    AppUserRole? role,
    bool? isActive,
    bool? isSuperAdmin,
    String? phone,
    String? photoUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    DateTime? deletedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      internalEmail: internalEmail ?? this.internalEmail,
      realEmail: realEmail ?? this.realEmail,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      if (internalEmail != null && internalEmail!.isNotEmpty)
        'internalEmail': internalEmail,
      if (realEmail != null && realEmail!.isNotEmpty) 'realEmail': realEmail,
      'displayName': displayName,
      'role': role.code,
      'isActive': isActive,
      'isSuperAdmin': isSuperAdminRole,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final normalized = FirestoreJsonHelper.normalizeMap(json);
    final legacyEmail = normalized['email']?.toString() ?? '';

    var internalEmail = normalized['internalEmail']?.toString();
    var realEmail = normalized['realEmail']?.toString();

    if ((internalEmail == null || internalEmail.isEmpty) &&
        (realEmail == null || realEmail.isEmpty) &&
        legacyEmail.isNotEmpty) {
      if (legacyEmail.toLowerCase().endsWith('@$internalAuthEmailDomain')) {
        internalEmail = legacyEmail.toLowerCase();
      } else {
        realEmail = legacyEmail.toLowerCase();
      }
    }

    final role = AppUserRole.fromCode(normalized['role']?.toString());
    final username = UsernameAuthHelper.deriveUsername(
      username: normalized['username']?.toString(),
      internalEmail: internalEmail,
      realEmail: realEmail,
      legacyEmail: legacyEmail,
    );

    final isSuperAdminFlag =
        normalized['isSuperAdmin'] == true || role.isSuperAdmin;

    return AppUser(
      uid: normalized['uid']?.toString() ?? '',
      username: username,
      internalEmail: internalEmail,
      realEmail: realEmail,
      displayName: normalized['displayName']?.toString() ?? '',
      role: role,
      isActive: normalized['isActive'] != false,
      isSuperAdmin: isSuperAdminFlag,
      phone: normalized['phone']?.toString(),
      photoUrl: normalized['photoUrl']?.toString(),
      createdBy: normalized['createdBy']?.toString(),
      createdAt: _parseDate(normalized['createdAt']),
      updatedAt: _parseDate(normalized['updatedAt']),
      lastLoginAt: _parseDate(normalized['lastLoginAt']),
      deletedAt: _parseDate(normalized['deletedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
