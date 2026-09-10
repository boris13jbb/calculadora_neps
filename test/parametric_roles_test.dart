import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/role_definition.dart';

void main() {
  setUp(() {
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
  });

  group('roles base', () {
    test('roles base existentes siguen funcionando', () {
      expect(
        RolePermissions.hasCode('super_admin', Permission.manageUsers),
        isTrue,
      );
      expect(
        RolePermissions.hasCode('admin', Permission.manageUsers),
        isFalse,
      );
      expect(
        RolePermissions.hasCode('operario', Permission.captureRecords),
        isTrue,
      );
      expect(
        RolePermissions.hasCode('gerencia', Permission.editRecords),
        isFalse,
      );
    });

    test('legacy ADMINISTRADOR/SUPERVISOR siguen siendo compatibles', () {
      expect(AppUserRole.tryParse('ADMINISTRADOR'), AppUserRole.admin);
      expect(AppUserRole.tryParse('SUPERVISOR'), AppUserRole.supervisor);
      expect(RoleCatalog.normalizeRoleCode('OPERARIO'), 'operario');
      expect(
        RolePermissions.hasCode(
          RoleCatalog.normalizeRoleCode('GERENCIA'),
          Permission.viewDashboard,
        ),
        isTrue,
      );
    });
  });

  group('roles personalizados', () {
    test('crear rol Auditor en catálogo', () {
      final auditor = RoleDefinition(
        code: 'auditor',
        name: 'Auditor',
        description: 'Solo lectura',
        permissions: {
          Permission.viewDashboard,
          Permission.viewRecords,
          Permission.exportReports,
        },
        seesWorkspaceRecords: true,
        sortOrder: 60,
      );
      RoleCatalog.instance.upsert(auditor);

      expect(RoleCatalog.instance.get('auditor')?.name, 'Auditor');
      expect(
        RolePermissions.hasCode('auditor', Permission.viewRecords),
        isTrue,
      );
      expect(
        RolePermissions.hasCode('auditor', Permission.editRecords),
        isFalse,
      );
    });

    test('rol desconocido no recibe permisos', () {
      expect(
        RolePermissions.hasCode('rol_fantasma', Permission.viewRecords),
        isFalse,
      );
      expect(
        RolePermissions.hasCode('rol_fantasma', Permission.manageUsers),
        isFalse,
      );
    });

    test('rol inactivo no recibe permisos', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {Permission.viewRecords},
          isActive: false,
        ),
      );
      expect(
        RolePermissions.hasCode('auditor', Permission.viewRecords),
        isFalse,
      );
    });

    test('cambiar permisos del rol afecta autorización', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {Permission.viewRecords},
        ),
      );
      expect(
        RolePermissions.hasCode('auditor', Permission.exportReports),
        isFalse,
      );

      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {
            Permission.viewRecords,
            Permission.exportReports,
          },
        ),
      );
      expect(
        RolePermissions.hasCode('auditor', Permission.exportReports),
        isTrue,
      );
    });

    test('rol desactivado no es asignable', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'jefe_turno',
          name: 'Jefe de turno',
          permissions: {Permission.viewRecords},
          isActive: false,
          isAssignable: true,
        ),
      );
      expect(
        RoleCatalog.instance
            .listAssignable()
            .any((r) => r.code == 'jefe_turno'),
        isFalse,
      );
    });

    test('super_admin no es asignable', () {
      expect(
        RoleCatalog.instance
            .listAssignable()
            .any((r) => r.code == 'super_admin'),
        isFalse,
      );
    });
  });

  group('AppUser roleCode', () {
    test('usuario con rol parametrizable usa roleCode', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {Permission.viewRecords},
        ),
      );
      final user = AppUser(
        uid: 'u1',
        username: 'aud01',
        roleCode: 'auditor',
      );
      expect(user.roleCode, 'auditor');
      expect(user.hasPermission(Permission.viewRecords), isTrue);
      expect(user.hasPermission(Permission.editRecords), isFalse);
    });

    test('usuarios actuales siguen funcionando', () {
      final user = AppUser(
        uid: 'u2',
        username: 'op01',
        role: AppUserRole.operario,
      );
      expect(user.roleCode, 'operario');
      expect(user.hasPermission(Permission.captureRecords), isTrue);
    });

    test('código de rol inválido en validateCode', () {
      expect(RoleDefinition.validateCode('Jefe Turno'), isNotNull);
      expect(RoleDefinition.validateCode('jefe_turno'), isNull);
      expect(RoleDefinition.validateCode('super_admin'), isNotNull);
    });

    test('fromJson conserva roleCode personalizado', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {Permission.viewDashboard},
        ),
      );
      final user = AppUser.fromJson({
        'uid': 'x',
        'username': 'aud',
        'role': 'auditor',
        'isActive': true,
      });
      expect(user.roleCode, 'auditor');
      expect(user.hasPermission(Permission.viewDashboard), isTrue);
    });
  });
}
