import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/models/user_role.dart';
import 'package:calculadora_neps/services/permissions_service.dart';

void main() {
  group('UserRole permisos', () {
    test('operario puede capturar pero no vaciar tabla', () {
      const role = UserRole.operario;
      expect(role.canCapture, isTrue);
      expect(role.canClearAllRecords, isFalse);
      expect(role.canEditAlertConfig, isFalse);
      expect(role.canApplyCorrectiveAction, isFalse);
    });

    test('supervisor puede acciones correctivas y vaciar', () {
      const role = UserRole.supervisor;
      expect(role.canApplyCorrectiveAction, isTrue);
      expect(role.canClearAllRecords, isTrue);
      expect(role.canEditAlertConfig, isFalse);
    });

    test('administrador puede editar límites', () {
      expect(UserRole.administrador.canEditAlertConfig, isTrue);
    });

    test('gerencia es solo lectura', () {
      const role = UserRole.gerencia;
      expect(role.isReadOnly, isTrue);
      expect(role.canCapture, isFalse);
      expect(permissionsService.canDeleteRecordsLegacy(role), isFalse);
    });

    test('fromCode reconoce roles y usa operario por defecto', () {
      expect(UserRole.fromCode('SUPERVISOR'), UserRole.supervisor);
      expect(UserRole.fromCode('desconocido'), UserRole.operario);
    });
  });
}
