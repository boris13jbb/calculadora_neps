import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/services/permissions_service.dart';

void main() {
  const service = PermissionsService();

  group('Permisos operativos por rol', () {
    test('operario captura pero no exporta ni importa', () {
      expect(service.canCapture(AppUserRole.operario), isTrue);
      expect(service.canExportReports(AppUserRole.operario), isFalse);
      expect(service.canImportRecords(AppUserRole.operario), isFalse);
      expect(service.canDeleteRecords(AppUserRole.operario), isFalse);
      expect(service.canClearAllRecords(AppUserRole.operario), isFalse);
    });

    test('gerencia solo lectura operativa con export', () {
      expect(service.canCapture(AppUserRole.gerencia), isFalse);
      expect(service.canEditRecords(AppUserRole.gerencia), isFalse);
      expect(service.canExportReports(AppUserRole.gerencia), isTrue);
      expect(service.canManageReports(AppUserRole.gerencia), isTrue);
      expect(service.isReadOnly(AppUserRole.gerencia), isTrue);
    });

    test('supervisor revisa y exporta sin capturar', () {
      expect(service.canCapture(AppUserRole.supervisor), isFalse);
      expect(service.canApplyCorrectiveAction(AppUserRole.supervisor), isTrue);
      expect(service.canExportReports(AppUserRole.supervisor), isTrue);
      expect(service.canManageFabrics(AppUserRole.supervisor), isFalse);
    });

    test('admin captura y administra telas sin usuarios', () {
      expect(service.canCapture(AppUserRole.admin), isTrue);
      expect(service.canManageFabrics(AppUserRole.admin), isTrue);
      expect(service.canImportRecords(AppUserRole.admin), isTrue);
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
    });
  });
}
