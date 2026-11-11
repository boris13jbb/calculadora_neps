import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/record_tombstone.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/report_sync_status.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:calculadora_neps/services/pending_report_sync_queue_service.dart';
import 'package:calculadora_neps/services/report_dual_write_plan.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:calculadora_neps/utils/report_archive_integrity.dart';
import 'package:calculadora_neps/utils/report_content_fingerprint.dart';
import 'package:calculadora_neps/utils/report_sync_error_classifier.dart';
import 'package:calculadora_neps/utils/report_upsert_decision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id, {double neps = 12}) {
  return NepRecord(
    id: id,
    telar: '7',
    tela: 'BOLTON',
    loteTrama: 'L-$id',
    neps: neps,
    createdAt: DateTime.utc(2026, 11, 10, 12),
  );
}

SavedReport _report({
  String id = 'rep_stable_1',
  String name = 'Informe A',
  String? createdByUid = 'uid-a',
  List<NepRecord>? records,
}) {
  return SavedReport(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 11, 10, 14),
    records: records ?? [_rec('r1'), _rec('r2')],
    createdByUid: createdByUid,
  );
}

class _FakeCloud implements CloudSyncPort {
  final reports = <String, SavedReport>{};
  final summaries = <String, Map<String, dynamic>>{};
  bool failNextSave = false;
  bool failWithPermission = false;
  bool failFetch = false;
  int saveCalls = 0;
  bool sessionActive = true;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<SavedReport> saveReport(
    SavedReport report, {
    String? expectedBaseFingerprint,
  }) async {
    saveCalls++;
    if (failWithPermission) {
      throw Exception('permission-denied');
    }
    if (failNextSave) {
      failNextSave = false;
      throw Exception('network unavailable');
    }
    final localFp = reportContentFingerprint(report);
    final remote = reports[report.id];
    final remoteFp =
        remote == null ? null : reportContentFingerprint(remote);
    final decision = decideReportUpsert(
      localFingerprint: localFp,
      remoteFingerprint: remoteFp,
      expectedBaseFingerprint: expectedBaseFingerprint,
    );
    if (decision == ReportUpsertDecision.conflict) {
      throw ReportSyncConflictException(report.id);
    }
    if (decision == ReportUpsertDecision.alreadySynced) {
      return remote!;
    }
    final plan = ReportDualWritePlan.fromReport(report);
    reports[plan.reportId] = report;
    summaries[plan.reportId] = Map<String, dynamic>.from(plan.summaryData);
    return report;
  }

  @override
  Future<void> deleteReport(String reportId) async {
    reports.remove(reportId);
    summaries.remove(reportId);
  }

  @override
  Future<SavedReport?> fetchReportById(String id) async {
    if (failFetch) throw Exception('network');
    return reports[id];
  }

  @override
  Future<List<SavedReport>> fetchReports() async => reports.values.toList();

  @override
  Future<List<SavedReportSummary>> fetchReportSummaries() async {
    return summaries.values
        .map((m) => SavedReportSummary.tryFromJson(Map<String, dynamic>.from(m)))
        .whereType<SavedReportSummary>()
        .toList();
  }

  @override
  Future<List<SavedReport>> fetchReportsByIds(List<String> ids) async {
    return ids.map((id) => reports[id]).whereType<SavedReport>().toList();
  }

  @override
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
  }) =>
      Stream.value(const []);

  @override
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

  @override
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

  @override
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

  @override
  Future<RecordsPageResult> fetchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) async =>
      const RecordsPageResult(records: []);

  @override
  Stream<List<String>> watchFabrics() => Stream.value(const []);

  @override
  Future<void> migrateLocalDataIfNeeded({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  }) async {}

  @override
  Future<void> syncFabricsWithLocal(List<String> localFabrics) async {}

  @override
  Future<List<String>> saveFabrics(List<String> fabrics) async => fabrics;

  @override
  Future<void> upsertRecord(NepRecord record) async {}

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {}

  @override
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {}

  @override
  Stream<List<RecordTombstone>> watchRecordTombstones() =>
      Stream.value(const []);

  @override
  Future<bool> hasRecordTombstone(String recordId) async => false;

  @override
  Future<void> clearRecords() async {}

  @override
  Future<void> replaceRecords(List<NepRecord> records) async {}

  @override
  Future<AppUserRole> fetchUserRole() async => AppUserRole.admin;

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async => null;

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> registerFcmToken(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PendingReportSyncQueueService queue;
  late _FakeCloud cloud;
  late ReportStorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    queue = PendingReportSyncQueueService();
    cloud = _FakeCloud();
    storage = ReportStorageService(
      cloudSync: cloud,
      pendingReportQueue: queue,
      isSessionActive: () => cloud.sessionActive,
    );
  });

  group('Cola persistente y guardado', () {
    test('1) guardado con conexión → synced + dual-write', () async {
      final outcome = await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.synced);
      expect(outcome.userMessage, ReportSyncUserMessages.synced);
      expect(cloud.reports.containsKey('rep_stable_1'), isTrue);
      expect(cloud.summaries.containsKey('rep_stable_1'), isTrue);
      expect(await queue.loadForUid('uid-a'), isEmpty);
      final audit = auditReportArchiveIntegrity(
        reports: {
          for (final e in cloud.reports.entries) e.key: e.value.toJson(),
        },
        summaries: cloud.summaries,
      );
      expect(audit.isHealthy, isTrue);
    });

    test('2-3) sin conexión encola y persiste tras reinicio', () async {
      cloud.sessionActive = false;
      final outcome = await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.localPending);
      expect(outcome.userMessage, ReportSyncUserMessages.offline);
      expect(cloud.saveCalls, 0);

      // 4) reinicio: nueva instancia de cola lee SharedPreferences
      final queue2 = PendingReportSyncQueueService();
      final loaded = await queue2.loadForUid('uid-a');
      expect(loaded, hasLength(1));
      expect(loaded.single.reportId, 'rep_stable_1');
      expect(loaded.single.report?.records, hasLength(2));
    });

    test('5-6) recuperación + reintento exitoso mismo ID', () async {
      cloud.sessionActive = false;
      await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      cloud.sessionActive = true;
      final outcomes = await storage.flushPendingReports(uid: 'uid-a');
      expect(outcomes, hasLength(1));
      expect(outcomes.single.status, ReportSyncStatus.synced);
      expect(outcomes.single.report.id, 'rep_stable_1');
      expect(cloud.reports.keys, ['rep_stable_1']);
      expect(await queue.loadForUid('uid-a'), isEmpty);
    });

    test('7) error temporal → retryable_error y conserva local', () async {
      cloud.failNextSave = true;
      final outcome = await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.retryableError);
      expect(outcome.userMessage, ReportSyncUserMessages.retryableError);
      final local = await storage.loadLocalReportsById();
      expect(local.containsKey('rep_stable_1'), isTrue);
      expect((await queue.loadForUid('uid-a')).single.status,
          ReportSyncStatus.retryableError);
    });

    test('8-9) error permanente / permisos', () async {
      cloud.failWithPermission = true;
      final outcome = await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.permanentError);
      expect(outcome.userMessage, ReportSyncUserMessages.permanentError);
      expect(outcome.errorCode, 'permission-denied');
      // flush no reintenta permanent_error automáticamente
      cloud.failWithPermission = false;
      final flushed = await storage.flushPendingReports(uid: 'uid-a');
      expect(flushed, isEmpty);
      expect(cloud.reports, isEmpty);
    });

    test('10-12) ACK perdido: mismo fingerprint → synced sin duplicar', () async {
      final report = _report();
      cloud.reports[report.id] = report;
      cloud.summaries[report.id] =
          Map<String, dynamic>.from(ReportDualWritePlan.fromReport(report).summaryData);
      await queue.enqueueUpsert(
        uid: 'uid-a',
        report: report,
        status: ReportSyncStatus.retryableError,
        errorCode: 'network',
      );
      final before = cloud.saveCalls;
      final outcome = await storage.retryPendingReport(
        uid: 'uid-a',
        reportId: report.id,
      );
      expect(outcome?.status, ReportSyncStatus.synced);
      expect(cloud.reports.length, 1);
      // Puede no llamar save si detecta idempotencia por fingerprint.
      expect(cloud.saveCalls, lessThanOrEqualTo(before + 1));
    });

    test('13-15) dual-write atómico, recordCount y createdByUid', () async {
      final report = _report(createdByUid: 'uid-owner');
      await storage.saveExistingReport(
        report,
        saveFiles: false,
        actorUid: 'uid-owner',
      );
      expect(cloud.summaries['rep_stable_1']?['recordCount'], 2);
      expect(cloud.summaries['rep_stable_1']?['createdByUid'], 'uid-owner');
      expect(
        auditReportArchiveIntegrity(
          reports: {
            for (final e in cloud.reports.entries) e.key: e.value.toJson(),
          },
          summaries: cloud.summaries,
        ).isHealthy,
        isTrue,
      );
    });

    test('16) conflicto de versiones no sobrescribe', () async {
      final local = _report(name: 'Local');
      final remote = _report(name: 'Remoto distinto', createdByUid: 'uid-other');
      cloud.reports[remote.id] = remote;
      cloud.summaries[remote.id] =
          Map<String, dynamic>.from(ReportDualWritePlan.fromReport(remote).summaryData);

      await queue.enqueueUpsert(
        uid: 'uid-a',
        report: local,
        status: ReportSyncStatus.localPending,
      );
      final outcome = await storage.saveExistingReport(
        local,
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.conflict);
      expect(cloud.reports[remote.id]?.name, 'Remoto distinto');
      expect(outcome.userMessage, ReportSyncUserMessages.conflict);
    });

    test('16b) mismo dueño sin baseFingerprint → conflicto (no overwrite)',
        () async {
      final remote = _report(name: 'En nube', createdByUid: 'uid-a');
      final local = _report(name: 'Local distinto', createdByUid: 'uid-a');
      cloud.reports[remote.id] = remote;
      cloud.summaries[remote.id] =
          Map<String, dynamic>.from(ReportDualWritePlan.fromReport(remote).summaryData);

      final outcome = await storage.saveExistingReport(
        local,
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(outcome.status, ReportSyncStatus.conflict);
      expect(cloud.reports[remote.id]?.name, 'En nube');
    });

    test('16c) actualización legítima con base = lastSynced', () async {
      final v1 = _report(name: 'V1', createdByUid: 'uid-a');
      await storage.saveExistingReport(v1, saveFiles: false, actorUid: 'uid-a');
      final v2 = _report(name: 'V2', createdByUid: 'uid-a');
      final outcome =
          await storage.saveExistingReport(v2, saveFiles: false, actorUid: 'uid-a');
      expect(outcome.status, ReportSyncStatus.synced);
      expect(cloud.reports[v2.id]?.name, 'V2');
    });

    test('política pura decideReportUpsert', () {
      expect(
        decideReportUpsert(
          localFingerprint: 'a',
          remoteFingerprint: null,
        ),
        ReportUpsertDecision.write,
      );
      expect(
        decideReportUpsert(
          localFingerprint: 'a',
          remoteFingerprint: 'a',
        ),
        ReportUpsertDecision.alreadySynced,
      );
      expect(
        decideReportUpsert(
          localFingerprint: 'b',
          remoteFingerprint: 'a',
          expectedBaseFingerprint: 'a',
        ),
        ReportUpsertDecision.write,
      );
      expect(
        decideReportUpsert(
          localFingerprint: 'b',
          remoteFingerprint: 'a',
        ),
        ReportUpsertDecision.conflict,
      );
    });

    test('17) dos flush simultáneos no duplican escrituras', () async {
      cloud.sessionActive = false;
      await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      cloud.sessionActive = true;
      final results = await Future.wait([
        storage.flushPendingReports(uid: 'uid-a'),
        storage.flushPendingReports(uid: 'uid-a'),
      ]);
      final nonEmpty = results.where((r) => r.isNotEmpty).length;
      expect(nonEmpty, lessThanOrEqualTo(1));
      expect(cloud.reports.length, 1);
    });

    test('18) cambio de usuario: aislamiento de cola', () async {
      cloud.sessionActive = false;
      await storage.saveExistingReport(
        _report(id: 'rep_a', createdByUid: 'uid-a'),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      await storage.saveExistingReport(
        _report(id: 'rep_b', createdByUid: 'uid-b'),
        saveFiles: false,
        actorUid: 'uid-b',
      );
      expect(await queue.loadForUid('uid-a'), hasLength(1));
      expect(await queue.loadForUid('uid-b'), hasLength(1));
      expect((await queue.loadForUid('uid-a')).single.reportId, 'rep_a');
    });

    test('19) workspace distinto se descarta al cargar', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        pendingReportSyncKeyForUid('uid-a'),
        '[{"id":"x","reportId":"rep_x","ownerUid":"uid-a","workspaceId":"otro",'
        '"type":"upsert","status":"localPending","createdAt":"2026-01-01T00:00:00.000Z",'
        '"attempts":0,"contentFingerprint":"abc","report":${_encodeReport(_report(id: 'rep_x'))}}]',
      );
      final loaded = await queue.loadForUid('uid-a');
      expect(loaded, isEmpty);
    });

    test('20-21) persistencia SharedPreferences (web/android misma capa)', () async {
      await queue.enqueueUpsert(
        uid: 'uid-a',
        report: _report(),
        status: ReportSyncStatus.localPending,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingReportSyncKeyForUid('uid-a')), isNotNull);
      final again = PendingReportSyncQueueService();
      expect(await again.loadForUid('uid-a'), hasLength(1));
    });

    test('22) informes antiguos locales sin cola no se migran automáticamente',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        savedReportsStorageKey,
        '[${_encodeReport(_report(id: 'legacy'))}]',
      );
      expect(await queue.loadForUid('uid-a'), isEmpty);
      final local = await storage.loadLocalReportsById();
      expect(local.containsKey('legacy'), isTrue);
    });

    test('23) cola parcialmente dañada se recupera sin tumbar app', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        pendingReportSyncKeyForUid('uid-a'),
        '[{"bad":true},{"id":"ok","reportId":"rep_ok","ownerUid":"uid-a",'
        '"workspaceId":"$cloudWorkspaceId","type":"upsert","status":"localPending",'
        '"createdAt":"2026-01-01T00:00:00.000Z","attempts":0,'
        '"contentFingerprint":"${reportContentFingerprint(_report(id: 'rep_ok'))}",'
        '"report":${_encodeReport(_report(id: 'rep_ok'))}}]',
      );
      final loaded = await queue.loadForUid('uid-a');
      expect(loaded, hasLength(1));
      expect(loaded.single.reportId, 'rep_ok');
    });

    test('24) reintento manual', () async {
      cloud.failNextSave = true;
      await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      final outcome = await storage.retryPendingReport(
        uid: 'uid-a',
        reportId: 'rep_stable_1',
      );
      expect(outcome?.status, ReportSyncStatus.synced);
      expect(await queue.loadForUid('uid-a'), isEmpty);
    });

    test('25-26) mensajes UI y synced solo tras confirmación', () async {
      expect(
        ReportSyncUserMessages.forStatus(ReportSyncStatus.synced),
        'Informe sincronizado correctamente',
      );
      cloud.sessionActive = false;
      final pending = await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(pending.status, isNot(ReportSyncStatus.synced));
      expect(pending.isCloudConfirmed, isFalse);
    });

    test('27) conserva datos tras error', () async {
      cloud.failNextSave = true;
      await storage.saveExistingReport(
        _report(name: 'Conservar'),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      final local = await storage.loadLocalReportsById();
      expect(local['rep_stable_1']?.name, 'Conservar');
    });

    test('28) clave personalSessions no se toca', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(personalSessionsKeyForUid('uid-a'), '[{"keep":true}]');
      cloud.sessionActive = false;
      await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      expect(
        prefs.getString(personalSessionsKeyForUid('uid-a')),
        '[{"keep":true}]',
      );
      expect(
        prefs.getString(pendingReportSyncKeyForUid('uid-a')),
        isNot(contains('personalSessions')),
      );
    });

    test('29) eliminación quita pending y documentos cloud', () async {
      await storage.saveExistingReport(
        _report(),
        saveFiles: false,
        actorUid: 'uid-a',
      );
      await storage.deleteReport('rep_stable_1', actorUid: 'uid-a');
      expect(cloud.reports, isEmpty);
      expect(cloud.summaries, isEmpty);
      expect(await queue.loadForUid('uid-a'), isEmpty);
    });

    test('fingerprint estable para mismo contenido', () {
      final a = _report();
      final b = _report();
      expect(reportContentFingerprint(a), reportContentFingerprint(b));
      expect(
        reportContentFingerprint(_report(name: 'Otro')),
        isNot(reportContentFingerprint(a)),
      );
    });

    test('clasificador de errores', () {
      expect(
        classifyReportSyncError(Exception('permission-denied')).status,
        ReportSyncStatus.permanentError,
      );
      expect(
        classifyReportSyncError(Exception('network unavailable')).status,
        ReportSyncStatus.retryableError,
      );
    });
  });
}

String _encodeReport(SavedReport report) {
  // jsonEncode-compatible fragment for embedding in prefs fixtures.
  return '{"id":"${report.id}","name":"${report.name}",'
      '"createdAt":"${report.createdAt.toIso8601String()}",'
      '"createdByUid":"${report.createdByUid}",'
      '"records":[{"id":"r1","telar":"7","neps":12,"tela":"BOLTON",'
      '"loteTrama":"L-r1","createdAt":"2026-11-10T12:00:00.000Z"}]}';
}
