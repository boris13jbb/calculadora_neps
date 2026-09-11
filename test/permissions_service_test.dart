import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/role_definition.dart';
import 'package:calculadora_neps/services/permissions_service.dart';

void main() {
  const service = PermissionsService();

  setUp(() {
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  tearDown(() {
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  group('Permisos operativos por rol', () {
    test('operario captura pero no exporta ni importa', () {
      expect(service.canCapture(AppUserRole.operario), isTrue);
      expect(service.canExportReports(AppUserRole.operario), isFalse);
      expect(service.canImportRecords(AppUserRole.operario), isFalse);
      expect(service.canImportRecordsForCode('operario'), isFalse);
      expect(service.canDeleteRecords(AppUserRole.operario), isFalse);
      expect(service.canClearAllRecords(AppUserRole.operario), isFalse);
    });

    test('gerencia solo lectura operativa con export', () {
      expect(service.canCapture(AppUserRole.gerencia), isFalse);
      expect(service.canEditRecords(AppUserRole.gerencia), isFalse);
      expect(service.canImportRecords(AppUserRole.gerencia), isFalse);
      expect(service.canImportRecordsForCode('gerencia'), isFalse);
      expect(service.canExportReports(AppUserRole.gerencia), isTrue);
      expect(service.canManageReports(AppUserRole.gerencia), isTrue);
      expect(service.isReadOnly(AppUserRole.gerencia), isTrue);
    });

    test('supervisor revisa y exporta sin capturar ni importar', () {
      expect(service.canCapture(AppUserRole.supervisor), isFalse);
      expect(service.canEditRecords(AppUserRole.supervisor), isTrue);
      expect(service.canImportRecords(AppUserRole.supervisor), isFalse);
      expect(service.canImportRecordsForCode('supervisor'), isFalse);
      expect(service.canApplyCorrectiveAction(AppUserRole.supervisor), isTrue);
      expect(service.canExportReports(AppUserRole.supervisor), isTrue);
      expect(service.canManageFabrics(AppUserRole.supervisor), isFalse);
    });

    test('admin captura y administra telas sin usuarios', () {
      expect(service.canCapture(AppUserRole.admin), isTrue);
      expect(service.canManageFabrics(AppUserRole.admin), isTrue);
      expect(service.canImportRecords(AppUserRole.admin), isTrue);
      expect(service.canImportRecordsForCode('admin'), isTrue);
      expect(
        RolePermissions.has(AppUserRole.admin, Permission.manageUsers),
        isFalse,
      );
    });

    test('super_admin acceso total', () {
      expect(
        RolePermissions.has(AppUserRole.superAdmin, Permission.manageUsers),
        isTrue,
      );
      expect(service.canManageSettings(AppUserRole.superAdmin), isTrue);
      expect(service.canImportRecords(AppUserRole.superAdmin), isTrue);
    });
  });

  group('Importación paramétrica (sin hardcode de rol)', () {
    test('edit sin capture → false', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'editor_sin_captura',
          name: 'Editor Sin Captura',
          permissions: {
            Permission.viewRecords,
            Permission.editRecords,
          },
          isActive: true,
          isSystem: false,
          isAssignable: true,
          sortOrder: 70,
        ),
      );
      expect(
        service.canImportRecordsForCode('editor_sin_captura'),
        isFalse,
      );
    });

    test('capture sin edit → false', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'captura_sin_edicion',
          name: 'Captura Sin Edición',
          permissions: {
            Permission.viewRecords,
            Permission.captureRecords,
          },
          isActive: true,
          isSystem: false,
          isAssignable: true,
          sortOrder: 71,
        ),
      );
      expect(
        service.canImportRecordsForCode('captura_sin_edicion'),
        isFalse,
      );
    });

    test('capture + edit → true', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'importador_prueba',
          name: 'Importador Prueba',
          permissions: {
            Permission.viewRecords,
            Permission.captureRecords,
            Permission.editRecords,
          },
          isActive: true,
          isSystem: false,
          isAssignable: true,
          sortOrder: 72,
        ),
      );
      expect(service.canImportRecordsForCode('importador_prueba'), isTrue);
    });

    test('operario remoto con capture+edit puede importar', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'operario',
          name: 'Operario',
          permissions: {
            Permission.captureRecords,
            Permission.viewRecords,
            Permission.editRecords,
          },
          isActive: true,
          isSystem: true,
          isAssignable: true,
          sortOrder: 30,
        ),
      );
      expect(service.canImportRecordsForCode('operario'), isTrue);
      expect(service.canImportRecords(AppUserRole.operario), isTrue);
    });

    test('gerencia remota con capture+edit puede importar', () {
      RoleCatalog.instance.upsert(
        RoleDefinition(
          code: 'gerencia',
          name: 'Gerencia',
          permissions: {
            Permission.viewDashboard,
            Permission.viewRecords,
            Permission.captureRecords,
            Permission.editRecords,
          },
          isActive: true,
          isSystem: true,
          isAssignable: true,
          sortOrder: 40,
        ),
      );
      expect(service.canImportRecordsForCode('gerencia'), isTrue);
      expect(service.canImportRecords(AppUserRole.gerencia), isTrue);
    });
  });
}
