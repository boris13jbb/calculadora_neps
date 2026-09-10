import 'package:calculadora_neps/core/permissions/record_visibility.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/pending_sync_queue_service.dart';
import 'package:calculadora_neps/services/personal_session_archive_service.dart';
import 'package:calculadora_neps/services/record_local_storage_service.dart';
import 'package:calculadora_neps/utils/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Almacenamiento local por UID', () {
    test('A y B no comparten registros en disco', () async {
      final storage = RecordLocalStorageService();
      await storage.bindUser('uid-a');
      final recordA = NepRecord(
        id: 'rec-a',
        telar: '10',
        neps: 5,
        tela: 'T',
        loteTrama: 'L',
        createdByUid: 'uid-a',
        captureSessionId: 'ses-a',
      );
      await storage.upsert(recordA);

      await storage.bindUser('uid-b');
      final forB = await storage.loadAll();
      expect(forB, isEmpty);

      await storage.bindUser('uid-a');
      final forA = await storage.loadAll();
      expect(forA, hasLength(1));
      expect(forA.single.id, 'rec-a');
    });

    test('legacy ambiguo no se atribuye al UID que inicia sesión', () async {
      SharedPreferences.setMockInitialValues({
        'vicunha_neps_flutter_exportaciones_v1': '''
[{"id":"legacy-1","telar":"1","neps":10,"tela":"T","loteTrama":"L",
"createdAt":"2020-01-01T00:00:00.000"}]
''',
      });

      final storage = RecordLocalStorageService();
      await storage.bindUser('uid-login');
      final owned = await storage.loadAll();
      expect(owned, isEmpty, reason: 'sin createdByUid no debe migrar al UID');

      final ambiguous = await storage.loadAmbiguousRecords();
      expect(ambiguous.any((r) => r.id == 'legacy-1'), isTrue);
      expect(isAmbiguousOwnership(ambiguous.first), isTrue);
    });

    test('legacy con createdByUid verificable sí migra al dueño', () async {
      SharedPreferences.setMockInitialValues({
        'vicunha_neps_flutter_exportaciones_v1': '''
[{"id":"owned-1","telar":"1","neps":10,"tela":"T","loteTrama":"L",
"createdAt":"2020-01-01T00:00:00.000","createdByUid":"uid-owner"}]
''',
      });

      final storage = RecordLocalStorageService();
      await storage.bindUser('uid-owner');
      final owned = await storage.loadAll();
      expect(owned.map((r) => r.id), contains('owned-1'));

      // Repetir bind no duplica.
      await storage.bindUser('uid-owner');
      final again = await storage.loadAll();
      expect(again.where((r) => r.id == 'owned-1'), hasLength(1));
    });

    test('legacy ajeno no entra en el store del usuario actual', () async {
      SharedPreferences.setMockInitialValues({
        'vicunha_neps_flutter_exportaciones_v1': '''
[{"id":"other-1","telar":"1","neps":10,"tela":"T","loteTrama":"L",
"createdAt":"2020-01-01T00:00:00.000","createdByUid":"uid-other"}]
''',
      });

      final storage = RecordLocalStorageService();
      await storage.bindUser('uid-login');
      expect(await storage.loadAll(), isEmpty);
    });
  });

  group('Cola de sync por UID', () {
    test('ops de A no se cargan bajo B', () async {
      final queue = PendingSyncQueueService();
      final record = NepRecord(
        id: 'r1',
        telar: '1',
        neps: 1,
        createdByUid: 'uid-a',
        captureSessionId: 'ses',
      );
      await queue.enqueueUpsert('uid-a', record);

      expect(await queue.loadForUid('uid-a'), hasLength(1));
      expect(await queue.loadForUid('uid-b'), isEmpty);
    });

    test('reintentar upsert del mismo id no duplica la cola', () async {
      final queue = PendingSyncQueueService();
      final record = NepRecord(
        id: 'r1',
        telar: '1',
        neps: 1,
        createdByUid: 'uid-a',
        captureSessionId: 'ses',
      );
      await queue.enqueueUpsert('uid-a', record);
      await queue.enqueueUpsert('uid-a', record.copyWith(neps: 2));
      final ops = await queue.loadForUid('uid-a');
      expect(ops, hasLength(1));
      expect(ops.single.record?.neps, 2);
    });
  });

  group('Archivo personal de sesión', () {
    test('upsert idempotente por id', () async {
      final service = PersonalSessionArchiveService();
      final archive = PersonalCaptureSessionArchive(
        id: 'pses-1',
        ownerUid: 'uid-a',
        captureSessionId: 'ses-1',
        savedAt: DateTime.now(),
        records: [
          NepRecord(
            id: generateStableId(prefix: 'rec'),
            telar: '1',
            neps: 3,
            createdByUid: 'uid-a',
            captureSessionId: 'ses-1',
          ),
        ],
        name: 'Sesión prueba',
      );
      await service.upsert(archive);
      await service.upsert(archive);
      final all = await service.loadForUid('uid-a');
      expect(all.where((a) => a.id == 'pses-1'), hasLength(1));
      expect(await service.loadForUid('uid-b'), isEmpty);
    });
  });

  group('Criterio de propiedad', () {
    test('recordBelongsToUid exige createdByUid verificable', () {
      final ambiguous = NepRecord(telar: '1', neps: 1);
      final owned = NepRecord(telar: '1', neps: 1, createdByUid: 'u1');
      expect(isAmbiguousOwnership(ambiguous), isTrue);
      expect(recordBelongsToUid(ambiguous, 'u1'), isFalse);
      expect(recordBelongsToUid(owned, 'u1'), isTrue);
      expect(recordBelongsToUid(owned, 'u2'), isFalse);
    });
  });
}
