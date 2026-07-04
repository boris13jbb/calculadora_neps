import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/utils/username_auth_helper.dart';

void main() {
  group('UsernameAuthHelper', () {
    test('isEmail detecta correo real', () {
      expect(UsernameAuthHelper.isEmail('admin@empresa.com'), isTrue);
      expect(UsernameAuthHelper.isEmail('operario01'), isFalse);
    });

    test('normalizeUsername quita espacios y pasa a minúsculas', () {
      expect(
          UsernameAuthHelper.normalizeUsername(' Operario01 '), 'operario01');
    });

    test('buildInternalEmail genera email oculto', () {
      expect(
        UsernameAuthHelper.buildInternalEmail('operario01'),
        'operario01@$internalAuthEmailDomain',
      );
    });

    test('resolveSignInEmail convierte username a email interno', () {
      expect(
        UsernameAuthHelper.resolveSignInEmail('supervisor.turno1'),
        'supervisor.turno1@$internalAuthEmailDomain',
      );
    });

    test('resolveSignInEmail conserva correo real', () {
      expect(
        UsernameAuthHelper.resolveSignInEmail('Admin@Empresa.com'),
        'admin@empresa.com',
      );
    });

    test('rechaza username con caracteres inválidos', () {
      expect(
        () => UsernameAuthHelper.resolveSignInEmail('usuario malo!'),
        throwsFormatException,
      );
    });

    test('validateUsernameOrEmailInput acepta username válido', () {
      expect(UsernameAuthHelper.validateUsernameOrEmailInput('operario01'),
          isNull);
    });
  });

  group('AppUser.fromJson', () {
    test('parsea usuario operario con email interno', () {
      final user = AppUser.fromJson({
        'uid': 'abc',
        'username': 'operario01',
        'internalEmail': 'operario01@$internalAuthEmailDomain',
        'realEmail': null,
        'displayName': 'Operario 01',
        'role': 'operario',
        'isActive': true,
        'isSuperAdmin': false,
      });

      expect(user.uid, 'abc');
      expect(user.username, 'operario01');
      expect(user.internalEmail, 'operario01@$internalAuthEmailDomain');
      expect(user.realEmail, isNull);
      expect(user.authEmail, 'operario01@$internalAuthEmailDomain');
      expect(user.role, AppUserRole.operario);
      expect(user.isSuperAdminRole, isFalse);
      expect(user.canManageUsers, isFalse);
    });

    test('parsea super_admin con correo real', () {
      final user = AppUser.fromJson({
        'uid': 'sa1',
        'username': 'superadmin',
        'internalEmail': null,
        'realEmail': 'admin@vicunha-neps.com',
        'displayName': 'Super Administrador',
        'role': 'super_admin',
        'isActive': true,
        'isSuperAdmin': true,
      });

      expect(user.username, 'superadmin');
      expect(user.realEmail, 'admin@vicunha-neps.com');
      expect(user.isSuperAdminRole, isTrue);
      expect(user.canCreateUsers, isTrue);
      expect(user.canResetPasswords, isTrue);
    });

    test('migra documento legacy con campo email', () {
      final user = AppUser.fromJson({
        'uid': 'legacy',
        'email': 'supervisor@vicunha-neps.com',
        'displayName': 'Supervisor',
        'role': 'supervisor',
      });

      expect(user.realEmail, 'supervisor@vicunha-neps.com');
      expect(user.username, 'supervisor');
    });

    test('migra documento legacy con email interno', () {
      final user = AppUser.fromJson({
        'uid': 'legacy2',
        'email': 'operario01@$internalAuthEmailDomain',
        'displayName': 'Operario',
        'role': 'operario',
      });

      expect(user.internalEmail, 'operario01@$internalAuthEmailDomain');
      expect(user.username, 'operario01');
    });

    test('acepta rol legacy ADMINISTRADOR', () {
      final user = AppUser.fromJson({
        'uid': 'x',
        'username': 'administrador',
        'realEmail': 'admin@empresa.com',
        'displayName': 'Admin',
        'role': 'ADMINISTRADOR',
      });

      expect(user.role, AppUserRole.admin);
    });
  });

  group('Permisos por rol', () {
    test('super_admin puede administrar usuarios', () {
      expect(
        RolePermissions.has(AppUserRole.superAdmin, Permission.manageUsers),
        isTrue,
      );
      expect(
        RolePermissions.has(AppUserRole.superAdmin, Permission.deleteUsers),
        isTrue,
      );
    });

    test('admin no puede administrar usuarios', () {
      expect(
        RolePermissions.has(AppUserRole.admin, Permission.manageUsers),
        isFalse,
      );
    });

    test('operario solo captura y ve registros', () {
      expect(
        RolePermissions.has(AppUserRole.operario, Permission.captureRecords),
        isTrue,
      );
      expect(
        RolePermissions.has(AppUserRole.operario, Permission.deleteRecords),
        isFalse,
      );
      expect(
        RolePermissions.has(AppUserRole.operario, Permission.exportReports),
        isFalse,
      );
    });

    test('gerencia es solo lectura operativa', () {
      expect(
        RolePermissions.has(AppUserRole.gerencia, Permission.viewDashboard),
        isTrue,
      );
      expect(
        RolePermissions.has(AppUserRole.gerencia, Permission.editRecords),
        isFalse,
      );
      expect(
        RolePermissions.has(AppUserRole.gerencia, Permission.captureRecords),
        isFalse,
      );
    });

    test('solo super_admin tiene canCreateUsers en AppUser', () {
      final superAdmin = AppUser(
        uid: '1',
        username: 'superadmin',
        realEmail: 'a@b.com',
        role: AppUserRole.superAdmin,
        isSuperAdmin: true,
      );
      final admin = AppUser(
        uid: '2',
        username: 'administrador',
        internalEmail: 'administrador@$internalAuthEmailDomain',
        role: AppUserRole.admin,
      );

      expect(superAdmin.canCreateUsers, isTrue);
      expect(superAdmin.canResetPasswords, isTrue);
      expect(admin.canCreateUsers, isFalse);
      expect(admin.canResetPasswords, isFalse);
    });
  });
}
