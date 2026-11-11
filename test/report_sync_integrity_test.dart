import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/services/report_dual_write_plan.dart';
import 'package:calculadora_neps/utils/report_archive_integrity.dart';
import 'package:calculadora_neps/utils/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';

NepRecord _record({
  required String id,
  required DateTime createdAt,
  double neps = 12,
}) {
  return NepRecord(
    id: id,
    telar: '7',
    tela: 'BOLTON',
    loteTrama: 'L-$id',
    neps: neps,
    createdAt: createdAt,
  );
}

SavedReport _report({
  String id = 'rep_test_1',
  String name = 'Informe prueba',
  DateTime? createdAt,
  List<NepRecord>? records,
  String? createdByUid = 'uid-owner',
}) {
  return SavedReport(
    id: id,
    name: name,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 10, 14, 27, 11),
    records: records ??
        [
          _record(id: 'r1', createdAt: DateTime.utc(2026, 11, 10, 14, 4)),
          _record(id: 'r2', createdAt: DateTime.utc(2026, 11, 10, 14, 26)),
        ],
    createdByUid: createdByUid,
  );
}

/// Fake cloud dual-write con fallos inyectables (sin Firebase).
class _FakeReportCloud {
  final reports = <String, Map<String, dynamic>>{};
  final summaries = <String, Map<String, dynamic>>{};
  bool failNextSave = false;
  bool failAfterReportOnly = false;
  int saveAttempts = 0;

  void saveAtomic(SavedReport report) {
    saveAttempts++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('cloud offline');
    }
    if (failAfterReportOnly) {
      // Simula inconsistencia histórica / ruta no atómica (NO es el código actual).
      failAfterReportOnly = false;
      reports[report.id] = Map<String, dynamic>.from(report.toJson());
      throw StateError('summary write failed');
    }
    final plan = ReportDualWritePlan.fromReport(report);
    reports[plan.reportId] = Map<String, dynamic>.from(plan.reportData);
    summaries[plan.reportId] = Map<String, dynamic>.from(plan.summaryData);
  }

  void deleteBoth(String id) {
    reports.remove(id);
    summaries.remove(id);
  }

  ReportArchiveIntegrityReport integrity() => auditReportArchiveIntegrity(
        reports: reports,
        summaries: summaries,
      );
}

/// Capa local + cloud al estilo ReportStorageService.saveExistingReport (simplificada).
class _FakeReportStorage {
  final local = <String, SavedReport>{};
  final cloud = _FakeReportCloud();
  final pendingIds = <String>{};
  bool cloudEnabled = true;

  /// Equivalente conceptual a guardar con id estable.
  Future<SavedReport> saveExisting(SavedReport report) async {
    if (cloudEnabled) {
      try {
        cloud.saveAtomic(report);
        local[report.id] = report;
        pendingIds.remove(report.id);
        return report;
      } catch (_) {
        // Fallo cloud: conserva local y marca pendiente (diseño propuesto).
        local[report.id] = report;
        pendingIds.add(report.id);
        return report;
      }
    }
    local[report.id] = report;
    pendingIds.add(report.id);
    return report;
  }

  Future<void> retryPending() async {
    final ids = pendingIds.toList(growable: false);
    for (final id in ids) {
      final report = local[id];
      if (report == null) continue;
      await saveExisting(report);
    }
  }
}

void main() {
  group('Detección de integridad (solo lectura)', () {
    test('1-2) creación de informe implica summary en plan dual-write', () {
      final report = _report();
      final plan = ReportDualWritePlan.fromReport(report);
      expect(plan.reportId, report.id);
      expect(plan.reportData['records'], isA<List>());
      expect(plan.summaryData['recordCount'], 2);
      expect(plan.summaryData.containsKey('records'), isFalse);
      expect(plan.summaryData['createdByUid'], 'uid-owner');
    });

    test('3) saveAtomic deja integridad limpia', () {
      final cloud = _FakeReportCloud()..saveAtomic(_report());
      final audit = cloud.integrity();
      expect(audit.reportCount, 1);
      expect(audit.summaryCount, 1);
      expect(audit.orphanReportIds, isEmpty);
      expect(audit.orphanSummaryIds, isEmpty);
      expect(audit.issues, isEmpty);
    });

    test('9) detecta informe completo sin summary', () {
      final cloud = _FakeReportCloud()..seedLegacyOnly(_report(id: 'orphan-full'));
      final audit = cloud.integrity();
      expect(audit.orphanReportIds, ['orphan-full']);
      expect(
        audit.issues.any(
          (i) => i.type == ReportArchiveIntegrityIssueType.reportWithoutSummary,
        ),
        isTrue,
      );
    });

    test('10) detecta summary sin informe completo', () {
      final cloud = _FakeReportCloud();
      cloud.summaries['orphan-sum'] = {
        'id': 'orphan-sum',
        'name': 'X',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'recordCount': 0,
      };
      final audit = cloud.integrity();
      expect(audit.orphanSummaryIds, ['orphan-sum']);
    });

    test('11) detecta diferencia de recordCount', () {
      final report = _report(id: 'rep-mismatch');
      final cloud = _FakeReportCloud()..saveAtomic(report);
      cloud.summaries['rep-mismatch'] = {
        ...cloud.summaries['rep-mismatch']!,
        'recordCount': 99,
      };
      final audit = cloud.integrity();
      expect(
        audit.issues.any(
          (i) => i.type == ReportArchiveIntegrityIssueType.recordCountMismatch,
        ),
        isTrue,
      );
    });

    test('12) detecta createdByUid inconsistente', () {
      final report = _report(id: 'rep-owner');
      final cloud = _FakeReportCloud()..saveAtomic(report);
      cloud.summaries['rep-owner'] = {
        ...cloud.summaries['rep-owner']!,
        'createdByUid': 'otro-uid',
      };
      final audit = cloud.integrity();
      expect(
        audit.issues.any(
          (i) => i.type == ReportArchiveIntegrityIssueType.createdByUidMismatch,
        ),
        isTrue,
      );
    });

    test('campos obligatorios faltantes / id incorrecto', () {
      final cloud = _FakeReportCloud()..saveAtomic(_report(id: 'rep-id'));
      cloud.summaries['rep-id'] = {
        'id': 'otro-id',
        'name': 'Informe prueba',
        'createdAt': '2026-11-10T14:27:11.000Z',
        'recordCount': 2,
        'createdByUid': 'uid-owner',
      };
      final audit = cloud.integrity();
      expect(
        audit.issues.any(
          (i) => i.type == ReportArchiveIntegrityIssueType.idMismatch,
        ),
        isTrue,
      );
    });
  });

  group('Escenarios offline / reintento (diseño con fake)', () {
    test('4) error de conexión conserva local y marca pendiente', () async {
      final storage = _FakeReportStorage()..cloud.failNextSave = true;
      final report = _report(id: 'rep_offline');
      await storage.saveExisting(report);
      expect(storage.local.containsKey('rep_offline'), isTrue);
      expect(storage.pendingIds, contains('rep_offline'));
      expect(storage.cloud.reports.containsKey('rep_offline'), isFalse);
    });

    test('5) error de permisos/cloud también deja pendiente local', () async {
      final storage = _FakeReportStorage()..cloud.failNextSave = true;
      await storage.saveExisting(_report(id: 'rep_perm'));
      expect(storage.pendingIds, contains('rep_perm'));
    });

    test('6-7) sin internet + recuperación sincroniza con mismo id', () async {
      final storage = _FakeReportStorage()..cloudEnabled = false;
      final id = 'rep_pending_stable';
      await storage.saveExisting(_report(id: id));
      expect(storage.pendingIds, contains(id));

      storage.cloudEnabled = true;
      await storage.retryPending();
      expect(storage.pendingIds, isEmpty);
      expect(storage.cloud.reports.containsKey(id), isTrue);
      expect(storage.cloud.summaries.containsKey(id), isTrue);
      expect(storage.cloud.saveAttempts, 1);
    });

    test('8) reintento no duplica: conserva identidad', () async {
      final original = generateStableId(prefix: 'rep');
      expect(
        reportRetryPreservesIdentity(
          originalReportId: original,
          retryReportId: original,
        ),
        isTrue,
      );
      expect(
        reportRetryPreservesIdentity(
          originalReportId: original,
          retryReportId: generateStableId(prefix: 'rep'),
        ),
        isFalse,
      );

      final storage = _FakeReportStorage()..cloud.failNextSave = true;
      final report = _report(id: 'rep_dup_guard');
      await storage.saveExisting(report);
      await storage.retryPending();
      expect(storage.cloud.reports.keys, ['rep_dup_guard']);
      expect(storage.cloud.summaries.keys, ['rep_dup_guard']);
      // Segundo retry no crea otro documento.
      await storage.retryPending();
      expect(storage.cloud.reports.length, 1);
    });

    test('14) tras interrupción (ACK perdido) reintento idempotente por id', () async {
      final storage = _FakeReportStorage();
      final report = _report(id: 'rep_ack_lost');
      // Primera escritura cloud OK pero cliente cree que falló → vuelve a encolar.
      await storage.saveExisting(report);
      storage.pendingIds.add('rep_ack_lost');
      await storage.retryPending();
      expect(storage.cloud.reports.length, 1);
      expect(storage.cloud.summaries.length, 1);
      expect(storage.integrityClean, isTrue);
    });
  });

  group('Eliminación y listado', () {
    test('13) eliminación coordinada quita full y summary', () {
      final cloud = _FakeReportCloud()..saveAtomic(_report(id: 'rep_del'));
      cloud.deleteBoth('rep_del');
      expect(cloud.integrity().issues, isEmpty);
      expect(cloud.reports, isEmpty);
      expect(cloud.summaries, isEmpty);
    });

    test('15) legacy full-only sigue legible por id aunque no liste', () {
      final cloud = _FakeReportCloud()
        ..seedLegacyOnly(_report(id: 'legacy-1', name: 'Histórico'));
      expect(cloud.fetchSummaries(), isEmpty);
      expect(cloud.fetchById('legacy-1')?.name, 'Histórico');
      expect(cloud.integrity().orphanReportIds, ['legacy-1']);
    });

    test('16-17) listado usa summaries; apertura usa full', () {
      final cloud = _FakeReportCloud()
        ..saveAtomic(_report(id: 'rep_list', name: 'Visible'));
      final list = cloud.fetchSummaries();
      expect(list, hasLength(1));
      expect(list.single.id, 'rep_list');
      expect(list.single.recordCount, 2);
      final full = cloud.fetchById('rep_list');
      expect(full?.records, hasLength(2));
      expect(full?.name, 'Visible');
    });

    test('18) escritura concurrente del mismo id termina en un solo par', () {
      final cloud = _FakeReportCloud();
      final a = _report(id: 'rep_race', name: 'A', createdByUid: 'uid-1');
      final b = _report(
        id: 'rep_race',
        name: 'B',
        createdByUid: 'uid-1',
        records: [
          _record(id: 'r9', createdAt: DateTime.utc(2026, 11, 10, 15)),
        ],
      );
      cloud.saveAtomic(a);
      cloud.saveAtomic(b);
      expect(cloud.reports.length, 1);
      expect(cloud.summaries.length, 1);
      expect(cloud.summaries['rep_race']?['name'], 'B');
      expect(cloud.summaries['rep_race']?['recordCount'], 1);
      expect(cloud.integrity().issues, isEmpty);
    });
  });

  group('Inconsistencia histórica vs camino actual', () {
    test('ruta no atómica deja huérfano detectable', () {
      final cloud = _FakeReportCloud()..failAfterReportOnly = true;
      expect(
        () => cloud.saveAtomic(_report(id: 'rep_broken')),
        throwsA(isA<StateError>()),
      );
      expect(cloud.reports.containsKey('rep_broken'), isTrue);
      expect(cloud.summaries.containsKey('rep_broken'), isFalse);
      expect(cloud.integrity().orphanReportIds, ['rep_broken']);
    });

    test('expectedSummaryDataFromReport no inventa id', () {
      final report = _report(id: 'rep_fixed');
      final data = expectedSummaryDataFromReport(report);
      expect(data['id'], 'rep_fixed');
      expect(data['recordCount'], 2);
      expect(data.containsKey('records'), isFalse);
    });
  });
}

extension on _FakeReportCloud {
  void seedLegacyOnly(SavedReport report) {
    reports[report.id] = Map<String, dynamic>.from(report.toJson());
  }

  SavedReport? fetchById(String id) {
    final data = reports[id];
    if (data == null) return null;
    return SavedReport.tryFromJson(Map<String, dynamic>.from(data));
  }

  List<SavedReportSummary> fetchSummaries() {
    return summaries.values
        .map((m) => SavedReportSummary.tryFromJson(Map<String, dynamic>.from(m)))
        .whereType<SavedReportSummary>()
        .toList();
  }
}

extension on _FakeReportStorage {
  bool get integrityClean => cloud.integrity().issues.isEmpty;
}
