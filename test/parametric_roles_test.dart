import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/role_definition.dart';

void main() {
  setUp(() {
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
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
        RolePermissions.hasCode('operario', Permission.viewWorkspaceRecords),
        isFalse,
      );
      expect(
        RolePermissions.hasCode('gerencia', Permission.editRecords),
        isFalse,
      );
      expect(
        RolePermissions.hasCode('supervisor', Permission.viewWorkspaceRecords),
        isTrue,
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
          Permission.viewWorkspaceRecords,
          Permission.exportReports,
        },
        sortOrder: 60,
      );
      RoleCatalog.instance.upsert(auditor);

      expect(RoleCatalog.instance.get('auditor')?.name, 'Auditor');
      expect(auditor.seesWorkspaceRecords, isTrue);
      expect(
        RolePermissions.hasCode('auditor', Permission.viewRecords),
        isTrue,
      );
      expect(
        RolePermissions.hasCode('auditor', Permission.viewWorkspaceRecords),
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

    test('rol vacío o null → deny', () {
      expect(RolePermissions.hasCode('', Permission.viewRecords), isFalse);
      expect(RolePermissions.hasCode(null, Permission.viewRecords), isFalse);
      expect(RolePermissions.hasCode('   ', Permission.viewRecords), isFalse);
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

  group('login / RoleCatalog', () {
    test('custom role se evalúa solo tras authorizationReady', () {
      RoleCatalog.instance.resetAuthorization();
      expect(RoleCatalog.instance.authorizationReady, isFalse);

      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'auditor',
          name: 'Auditor',
          permissions: {Permission.viewRecords},
        ),
      );
      // Catálogo ya tiene el rol; la UI debe esperar authorizationReady.
      expect(
        RolePermissions.hasCode('auditor', Permission.viewRecords),
        isTrue,
      );
      RoleCatalog.instance.markAuthorizationReady();
      expect(RoleCatalog.instance.authorizationReady, isTrue);
    });

    test('custom role desconocido → deny', () {
      expect(
        RolePermissions.hasCode('auditor_desconocido', Permission.viewRecords),
        isFalse,
      );
    });

    test('role inactivo → deny', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'supervisor',
          name: 'Supervisor',
          permissions: {
            Permission.viewRecords,
            Permission.viewWorkspaceRecords,
            Permission.editRecords,
          },
          isSystem: true,
          isActive: false,
        ),
      );
      expect(
        RolePermissions.hasCode('supervisor', Permission.editRecords),
        isFalse,
      );
    });

    test('roles base legacy siguen funcionando antes del seed remoto', () {
      RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
      expect(
        RolePermissions.hasCode('operario', Permission.captureRecords),
        isTrue,
      );
      expect(
        RolePermissions.hasCode('admin', Permission.manageFabrics),
        isTrue,
      );
    });

    test('RoleDefinition remoto de supervisor sustituye fallback base', () {
      expect(
        RolePermissions.hasCode('supervisor', Permission.editRecords),
        isTrue,
      );

      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'supervisor',
          name: 'Supervisor',
          permissions: {
            Permission.viewRecords,
            Permission.viewWorkspaceRecords,
            // sin editRecords
          },
          isSystem: true,
          isActive: true,
        ),
      );

      expect(
        RolePermissions.hasCode('supervisor', Permission.editRecords),
        isFalse,
      );
      expect(
        RolePermissions.hasCode('supervisor', Permission.viewWorkspaceRecords),
        isTrue,
      );
    });

    test('seesWorkspaceRecords se deriva del permiso', () {
      final withScope = RoleDefinition(
        code: 'auditor',
        name: 'Auditor',
        permissions: {
          Permission.viewRecords,
          Permission.viewWorkspaceRecords,
        },
      );
      final withoutScope = RoleDefinition(
        code: 'operario_x',
        name: 'Op',
        permissions: {Permission.viewRecords},
      );
      expect(withScope.seesWorkspaceRecords, isTrue);
      expect(withoutScope.seesWorkspaceRecords, isFalse);

      final migrated = RoleDefinition.fromJson({
        'code': 'legacy_auditor',
        'name': 'Legacy',
        'permissions': ['viewRecords'],
        'seesWorkspaceRecords': true,
      });
      expect(
        migrated.permissions.contains(Permission.viewWorkspaceRecords),
        isTrue,
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

    test('rol vacío no hereda permisos de operario', () {
      final user = AppUser(
        uid: 'u3',
        username: 'sinrol',
        roleCode: '',
      );
      expect(user.roleCode, isEmpty);
      expect(user.hasPermission(Permission.captureRecords), isFalse);
      expect(user.hasPermission(Permission.viewRecords), isFalse);
      // Adaptador enum legacy puede ser operario, pero autorización usa roleCode.
      expect(user.role, AppUserRole.operario);
    });

    test('rol_fantasma conserva roleCode sin permisos', () {
      final user = AppUser(
        uid: 'u4',
        username: 'fantasma',
        roleCode: 'rol_fantasma',
      );
      expect(user.roleCode, 'rol_fantasma');
      expect(user.hasPermission(Permission.viewRecords), isFalse);
    });
  });

  group('catálogo de permisos', () {
    test('viewWorkspaceRecords está en el catálogo técnico', () {
      expect(
        Permission.values.contains(Permission.viewWorkspaceRecords),
        isTrue,
      );
      expect(
        PermissionCatalog.labelOf(Permission.viewWorkspaceRecords),
        contains('workspace'),
      );
    });
  });
}
