import 'package:calculadora_neps/core/permissions/record_visibility.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('record_visibility', () {
    test('supervisor y gerencia ven registros del workspace', () {
      expect(canViewWorkspaceRecords(AppUserRole.supervisor), isTrue);
      expect(canViewWorkspaceRecords(AppUserRole.gerencia), isTrue);
      expect(canViewWorkspaceRecords(AppUserRole.admin), isTrue);
    });

    test('operario solo ve sus propios registros', () {
      expect(canViewWorkspaceRecords(AppUserRole.operario), isFalse);
    });

    test('recordOwnerUid usa createdByUid cuando existe', () {
      final record = NepRecord(
        telar: 'T1',
        neps: 10,
        createdByUid: 'uid-operario',
      );
      expect(recordOwnerUid(record, 'uid-supervisor'), 'uid-operario');
    });

    test('recordOwnerUid cae al usuario actual si falta dueño', () {
      final record = NepRecord(telar: 'T1', neps: 10);
      expect(recordOwnerUid(record, 'uid-actual'), 'uid-actual');
    });
  });
}
