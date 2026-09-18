import 'package:calculadora_neps/core/errors/record_tombstoned_exception.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_tombstone.dart';
import 'package:calculadora_neps/providers/domain/records_scope.dart';
import 'package:calculadora_neps/services/cloud_sync_service.dart';
import 'package:calculadora_neps/services/pending_sync_queue_service.dart';
import 'package:calculadora_neps/services/record_local_storage_service.dart';
import 'package:calculadora_neps/services/record_tombstone_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id, {String uid = 'uid-1'}) => NepRecord(
      id: id,
      telar: 'T1',
      neps: 10,
      tela: 'Tela',
      loteTrama: 'L1',
      createdByUid: uid,
      captureSessionId: 'ses-$uid',
      createdAt: DateTime.utc(2024, 1, 1),
    );

RecordTombstone _tomb(String id,
        {String owner = 'uid-1', String by = 'uid-1'}) =>
    RecordTombstone(
      recordId: id,
      ownerUid: owner,
      deletedByUid: by,
      deletedAt: DateTime.utc(2024, 6, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordLocalStorageService storage;
  late PendingSyncQueueService queue;
  late RecordsScope scope;
  late RecordTombstoneReconciler reconciler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = RecordLocalStorageService();
    queue = PendingSyncQueueService();
    scope = RecordsScope(localStorage: storage);
    reconciler = const RecordTombstoneReconciler();
  });

  group('1 REMOTE DELETE PURGE', () {
    test('tombstone B elimina B de memoria y storage; A y C permanecen',
        () async {
      await storage.bindUser('uid-1');
      for (final id in ['A', 'B', 'C']) {
        final r = _rec(id);
        scope.upsert(r);
        await storage.upsert(r);
      }
      expect(scope.items.map((e) => e.id).toSet(), {'A', 'B', 'C'});

      await reconciler.applyLocally(
        tombstone: _tomb('B'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );

      expect(scope.items.map((e) => e.id).toSet(), {'A', 'C'});
      final disk = await storage.loadAll();
      expect(disk.map((e) => e.id).toSet(), {'A', 'C'});
      expect(disk.any((e) => e.id == 'B'), isFalse);
    });
  });

  group('2 STALE PENDING UPSERT', () {
    test('tombstone B quita UPSERT B y deja UPSERT C', () async {
      await storage.bindUser('uid-1');
      await queue.enqueueUpsert('uid-1', _rec('B'));
      await queue.enqueueUpsert('uid-1', _rec('C'));

      await reconciler.applyLocally(
        tombstone: _tomb('B'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );

      final ops = await queue.loadForUid('uid-1');
      expect(ops.any((o) => o.recordId == 'B' || o.record?.id == 'B'), isFalse);
      expect(ops.any((o) => o.recordId == 'C' || o.record?.id == 'C'), isTrue);
    });

    test('removeUpsertsForRecordId solo afecta el ID indicado', () async {
      await queue.enqueueUpsert('uid-1', _rec('B'));
      await queue.enqueueUpsert('uid-1', _rec('C'));
      await queue.removeUpsertsForRecordId('uid-1', 'B');
      final ops = await queue.loadForUid('uid-1');
      expect(ops.map((o) => o.recordId), ['C']);
    });
  });

  group('3 DELETE WINS', () {
    test('RecordTombstonedException es definitivo (no retry)', () {
      const err = RecordTombstonedException('B');
      expect(err, isA<RecordTombstonedException>());
      expect(err.recordId, 'B');
    });

    test('filtrar migrables excluye IDs tombstoned', () {
      final local = [_rec('A'), _rec('B'), _rec('C')];
      final tombstoned = {'B'};
      final migratable =
          local.where((r) => !tombstoned.contains(r.id)).toList();
      expect(migratable.map((r) => r.id), ['A', 'C']);
    });
  });

  group('4 PAGINATION SAFETY', () {
    test('snapshot [A,C] sin tombstone B NO borra B', () {
      final local = [_rec('A'), _rec('B'), _rec('C')];
      final page = [_rec('A'), _rec('C')];
      final merged = reconciler.mergePreservingLocalExceptTombstones(
        local: local,
        remotePage: page,
        tombstonedIds: {},
      );
      expect(merged.map((e) => e.id).toSet(), {'A', 'B', 'C'});
    });

    test('snapshot [A,C] CON tombstone B sí elimina B', () {
      final local = [_rec('A'), _rec('B'), _rec('C')];
      final page = [_rec('A'), _rec('C')];
      final merged = reconciler.mergePreservingLocalExceptTombstones(
        local: local,
        remotePage: page,
        tombstonedIds: {'B'},
      );
      expect(merged.map((e) => e.id).toSet(), {'A', 'C'});
    });
  });

  group('5 RESTART', () {
    test('tras tombstone, re-bind y loadAll no revive B', () async {
      await storage.bindUser('uid-1');
      for (final id in ['A', 'B', 'C']) {
        await storage.upsert(_rec(id));
      }
      scope.replaceAll([_rec('A'), _rec('B'), _rec('C')]);

      await reconciler.applyLocally(
        tombstone: _tomb('B'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );

      // Simula reinicio: nuevo scope + rebind mismo UID.
      final storage2 = RecordLocalStorageService();
      await storage2.bindUser('uid-1');
      final loaded = await storage2.loadAll();
      expect(loaded.map((e) => e.id).toSet(), {'A', 'C'});
      expect(loaded.any((e) => e.id == 'B'), isFalse);
    });
  });

  group('6 UID ISOLATION', () {
    test('tombstone de U1 no limpia storage de U2', () async {
      await storage.bindUser('uid-1');
      await storage.upsert(_rec('B', uid: 'uid-1'));
      await storage.bindUser('uid-2');
      await storage.upsert(_rec('B2', uid: 'uid-2'));

      await storage.bindUser('uid-1');
      scope.replaceAll([_rec('B')]);
      await reconciler.applyLocally(
        tombstone: _tomb('B'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );

      await storage.bindUser('uid-2');
      final forU2 = await storage.loadAll();
      expect(forU2.map((e) => e.id), contains('B2'));
    });
  });

  group('7 CLEAR RECORDS DELETE-WINS', () {
    test('CLEAR1 clear crea tombstones de todos los IDs eliminados', () {
      final batches = CloudSyncService.planClearBatches(
        recordIds: ['A', 'B'],
        ownerUid: 'uid-1',
        deletedByUid: 'uid-actor',
      );
      final writes = batches.expand((b) => b).toList();
      expect(writes.map((w) => w.recordId).toSet(), {'A', 'B'});
      expect(writes.every((w) => w.createsTombstone), isTrue);
      expect(writes.every((w) => w.deletesWorkspaceMirror), isTrue);
      expect(writes.every((w) => w.deletesUserMirror), isTrue);
      expect(writes.every((w) => w.ownerUid == 'uid-1'), isTrue);
      expect(writes.every((w) => w.deletedByUid == 'uid-actor'), isTrue);
    });

    test('CLEAR1b lotes respetan techo de escrituras Firestore', () {
      final ids = List.generate(320, (i) => 'r$i');
      final batches = CloudSyncService.planClearBatches(
        recordIds: ids,
        ownerUid: 'uid-1',
        deletedByUid: 'uid-1',
      );
      expect(batches.length, greaterThan(1));
      for (final batch in batches) {
        expect(
          batch.length * ClearRecordsWrite.writesPerRecord,
          lessThanOrEqualTo(CloudSyncService.clearRecordsMaxWritesPerBatch),
        );
      }
      expect(
        batches.expand((b) => b).map((w) => w.recordId).toSet(),
        ids.toSet(),
      );
    });

    test('CLEAR2 stale upsert después de clear => no resurrección', () async {
      await storage.bindUser('uid-1');
      for (final id in ['A', 'B']) {
        scope.upsert(_rec(id));
        await storage.upsert(_rec(id));
      }
      await queue.enqueueUpsert('uid-1', _rec('A'));

      final plan = CloudSyncService.planClearBatches(
        recordIds: ['A', 'B'],
        ownerUid: 'uid-1',
        deletedByUid: 'uid-1',
      ).expand((b) => b);

      scope.clear();
      await storage.clear();
      await queue.removeAllUpserts('uid-1');

      for (final write in plan) {
        await reconciler.applyLocally(
          tombstone: _tomb(write.recordId),
          scope: scope,
          storage: storage,
          queue: queue,
          actorUid: 'uid-1',
        );
      }

      expect(scope.items, isEmpty);
      expect(await storage.loadAll(), isEmpty);
      final ops = await queue.loadForUid('uid-1');
      expect(ops.any((o) => o.type == PendingSyncOpType.upsert), isFalse);

      // Re-aplicar tombstone A bloquea cualquier intento de revivir A en cola.
      await queue.enqueueUpsert('uid-1', _rec('A'));
      await reconciler.applyLocally(
        tombstone: _tomb('A'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );
      final after = await queue.loadForUid('uid-1');
      expect(
          after.any((o) => o.recordId == 'A' || o.record?.id == 'A'), isFalse);
    });

    test('CLEAR3 otro UID intacto', () async {
      await storage.bindUser('uid-1');
      await storage.upsert(_rec('A', uid: 'uid-1'));
      await storage.bindUser('uid-2');
      await storage.upsert(_rec('X', uid: 'uid-2'));
      await queue.enqueueUpsert('uid-2', _rec('X', uid: 'uid-2'));

      await storage.bindUser('uid-1');
      scope.replaceAll([_rec('A')]);
      scope.clear();
      await storage.clear();
      await queue.removeAllUpserts('uid-1');
      await reconciler.applyLocally(
        tombstone: _tomb('A'),
        scope: scope,
        storage: storage,
        queue: queue,
        actorUid: 'uid-1',
      );

      await storage.bindUser('uid-2');
      final forU2 = await storage.loadAll();
      expect(forU2.map((e) => e.id), contains('X'));
      final opsU2 = await queue.loadForUid('uid-2');
      expect(
          opsU2.any((o) => o.recordId == 'X' || o.record?.id == 'X'), isTrue);
    });

    test('CLEAR4 plan de clear no incluye informes históricos', () {
      final writes = CloudSyncService.planClearBatches(
        recordIds: ['A', 'B'],
        ownerUid: 'uid-1',
        deletedByUid: 'uid-1',
      ).expand((b) => b);
      for (final w in writes) {
        expect(w.touchesReports, isFalse);
      }
    });
  });
}
