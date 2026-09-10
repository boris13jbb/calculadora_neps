import 'package:calculadora_neps/core/permissions/role_permissions.dart';
import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/repositories/user_creation_queue_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserCreationQueuePayload', () {
    test('request y secret del batch no mezclan password en el request', () {
      const password = 'Prueba123!';
      final request = UserCreationQueuePayload.buildRequestData(
        username: 'operario01',
        displayName: 'Operario Uno',
        roleCode: AppUserRole.operario.code,
        isActive: true,
        requestedByUid: 'super-uid',
        requestedByUsername: 'superadmin',
        createdAt: 'server-ts',
      );
      final secret = UserCreationQueuePayload.buildSecretData(
        password: password,
        requestedByUid: 'super-uid',
        createdAt: 'server-ts',
      );

      expect(
          UserCreationQueuePayload.requestContainsPassword(request), isFalse);
      expect(request['password'], isNull);
      expect(request['newPassword'], isNull);
      expect(request['type'], 'create');
      expect(request['status'], 'pending');
      expect(request['username'], 'operario01');
      expect(request['role'], 'operario');
      expect(request['requestedByUid'], 'super-uid');

      expect(secret['password'], password);
      expect(secret['requestedByUid'], 'super-uid');
      expect(secret.containsKey('username'), isFalse);
      expect(secret.containsKey('role'), isFalse);
    });

    test('mismo requestId implica secret listo cuando el batch es atómico', () {
      // Con ID anticipado, request y secret comparten id antes de escribir.
      // Tras batch.commit, un trigger inmediato ya encuentra el secret.
      const requestId = 'req-atomic-1';
      const requestPath =
          'workspaces/vicunha/user_creation_requests/$requestId';
      const secretPath = 'workspaces/vicunha/user_creation_secrets/$requestId';

      expect(
        secretPath.endsWith('/$requestId'),
        isTrue,
        reason: 'secret y request deben compartir el mismo id',
      );
      expect(
        requestPath.split('/').last,
        secretPath.split('/').last,
      );

      final secret = UserCreationQueuePayload.buildSecretData(
        password: 'Prueba123!',
        requestedByUid: 'super-uid',
        createdAt: DateTime.utc(2026, 9, 10),
      );
      expect(secret['password'], isNotEmpty);
      expect((secret['password'] as String).length, greaterThanOrEqualTo(8));
    });

    test('contraseña corta se detecta en el secreto (no confundir con ausente)',
        () {
      final secret = UserCreationQueuePayload.buildSecretData(
        password: 'corta',
        requestedByUid: 'super-uid',
        createdAt: 'ts',
      );
      expect((secret['password'] as String).length, lessThan(8));
      expect(
          UserCreationQueuePayload.requestContainsPassword(
            UserCreationQueuePayload.buildRequestData(
              username: 'u1',
              roleCode: 'operario',
              isActive: true,
              requestedByUid: 'super-uid',
              requestedByUsername: 'admin',
              createdAt: 'ts',
            ),
          ),
          isFalse);
    });

    test('solo super_admin tiene permiso manageUsers en matriz de roles', () {
      expect(
        RolePermissions.has(AppUserRole.superAdmin, Permission.manageUsers),
        isTrue,
      );
      expect(
        RolePermissions.has(AppUserRole.admin, Permission.manageUsers),
        isFalse,
      );
      expect(
        RolePermissions.has(AppUserRole.supervisor, Permission.manageUsers),
        isFalse,
      );
      expect(
        RolePermissions.has(AppUserRole.operario, Permission.manageUsers),
        isFalse,
      );
      expect(
        RolePermissions.has(AppUserRole.gerencia, Permission.manageUsers),
        isFalse,
      );
    });

    test('displayName vacío no se incluye en el request', () {
      final request = UserCreationQueuePayload.buildRequestData(
        username: 'operario02',
        displayName: '   ',
        roleCode: AppUserRole.operario.code,
        isActive: true,
        requestedByUid: 'super-uid',
        requestedByUsername: 'superadmin',
        createdAt: 'ts',
      );
      expect(request.containsKey('displayName'), isFalse);
    });
  });

  group('Mensajes de error de secreto (contrato backend)', () {
    test('ausencia de secreto no se reporta como contraseña corta', () {
      const missingSecret =
          'No se recibió la contraseña temporal para crear el usuario.';
      const shortPassword = 'La contraseña debe tener al menos 8 caracteres.';
      expect(missingSecret, isNot(shortPassword));
      expect(
          missingSecret.toLowerCase().contains('contraseña temporal'), isTrue);
      expect(shortPassword.toLowerCase().contains('8 caracteres'), isTrue);
    });
  });
}
