import 'dart:convert';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pending_report_sync_op.dart';
import 'package:calculadora_neps/models/report_sync_status.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/services/pending_report_sync_queue_service.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id) => NepRecord(
      id: id,
      telar: '7',
      tela: 'BOLTON',
      loteTrama: 'L-$id',
      neps: 12,
      createdAt: DateTime.utc(2026, 11, 10, 12),
    );

SavedReport _sizedReport({
  required String id,
  required String uid,
  required int recordCount,
  String? pad,
}) {
  return SavedReport(
    id: id,
    name: 'size-$recordCount${pad ?? ''}',
    createdAt: DateTime.utc(2026, 11, 10, 14),
    createdByUid: uid,
    records: [for (var i = 0; i < recordCount; i++) _rec('r$i')],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persistencia local de informes (tamaños / corrupción)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('pequeño / mediano / grande serializan y sobreviven reinicio',
        () async {
      final queue = PendingReportSyncQueueService();
      const uid = 'uid-storage';

      for (final count in [2, 40, 250]) {
        final report = _sizedReport(
          id: 'rep_$count',
          uid: uid,
          recordCount: count,
        );
        await queue.enqueueUpsert(uid: uid, report: report);
      }

      final reloaded = PendingReportSyncQueueService();
      final ops = await reloaded.loadForUid(uid);
      expect(ops.length, 3);
      expect(
        ops.map((o) => o.report?.records.length).toSet(),
        {2, 40, 250},
      );
    });

    test('JSON inválido no tumba la app y no inventa operaciones', () async {
      SharedPreferences.setMockInitialValues({
        pendingReportSyncKeyForUid('uid-bad'): '{not-json',
      });
      final queue = PendingReportSyncQueueService();
      final ops = await queue.loadForUid('uid-bad');
      expect(ops, isEmpty);
    });

    test('entradas parcialmente corruptas se podan; válidas se conservan',
        () async {
      final good = await PendingReportSyncQueueService().enqueueUpsert(
        uid: 'uid-mix',
        report: _sizedReport(id: 'rep_ok', uid: 'uid-mix', recordCount: 1),
      );
      final prefs = await SharedPreferences.getInstance();
      final key = pendingReportSyncKeyForUid('uid-mix');
      final decoded = jsonDecode(prefs.getString(key)!) as List;
      decoded.add({'reportId': 'broken'});
      decoded.add('no-map');
      await prefs.setString(key, jsonEncode(decoded));

      final ops = await PendingReportSyncQueueService().loadForUid('uid-mix');
      expect(ops.length, 1);
      expect(ops.first.reportId, good.reportId);
    });

    test('escritura fallida de cola no reporta synced', () async {
      final storage = ReportStorageService(
        cloudSync: null,
        pendingReportQueue: _FailingQueue(),
        isSessionActive: () => false,
      );
      final outcome = await storage.saveExistingReport(
        _sizedReport(id: 'rep_fail', uid: 'uid-fail', recordCount: 1),
        saveFiles: false,
        actorUid: 'uid-fail',
      );
      expect(outcome.status, isNot(ReportSyncStatus.synced));
      expect(outcome.errorCode, 'local_persist_failed');
    });

    test('muy grande: documenta tamaño JSON de cola', () async {
      final report = _sizedReport(
        id: 'rep_xl',
        uid: 'uid-xl',
        recordCount: 800,
        pad: '-xl',
      );
      final encoded = jsonEncode(report.toJson());
      // SharedPreferences suele tolerar cientos de KB; >1MB es zona de riesgo.
      expect(encoded.length, greaterThan(50 * 1024));
      await PendingReportSyncQueueService().enqueueUpsert(
        uid: 'uid-xl',
        report: report,
      );
      final ops = await PendingReportSyncQueueService().loadForUid('uid-xl');
      expect(ops.single.report?.records.length, 800);
    });

    test('toope de auto-reintentos sin borrar pendiente', () {
      final op = PendingReportSyncOp.upsert(
        report: _sizedReport(id: 'rep_retry', uid: 'uid-r', recordCount: 1),
        ownerUid: 'uid-r',
        status: ReportSyncStatus.retryableError,
      ).copyWith(attempts: PendingReportSyncOp.maxAutoRetryAttempts);
      expect(op.canAutoRetry, isFalse);
      expect(op.isTerminal, isFalse);
    });

    test('personalSessions no se modifica al encolar informes', () async {
      SharedPreferences.setMockInitialValues({
        personalSessionsKeyForUid('uid-ps'): '[{"keep":true}]',
      });
      await PendingReportSyncQueueService().enqueueUpsert(
        uid: 'uid-ps',
        report: _sizedReport(id: 'rep_ps', uid: 'uid-ps', recordCount: 1),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(personalSessionsKeyForUid('uid-ps')),
        '[{"keep":true}]',
      );
    });
  });
}

class _FailingQueue extends PendingReportSyncQueueService {
  @override
  Future<PendingReportSyncOp> enqueueUpsert({
    required String uid,
    required SavedReport report,
    String? baseFingerprint,
    ReportSyncStatus status = ReportSyncStatus.localPending,
    String? errorCode,
  }) async {
    throw StateError('No se pudo persistir la cola de sync de informes');
  }
}
