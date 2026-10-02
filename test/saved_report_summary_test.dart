import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/services/report_dual_write_plan.dart';
import 'package:flutter_test/flutter_test.dart';

NepRecord _record({
  required String id,
  required DateTime createdAt,
  double neps = 10,
}) {
  return NepRecord(
    id: id,
    telar: '1',
    tela: 'BOLTON',
    loteTrama: 'L-$id',
    neps: neps,
    createdAt: createdAt,
  );
}

SavedReport _report({
  String id = 'rep-1',
  String name = 'Informe A',
  DateTime? createdAt,
  List<NepRecord>? records,
  String? createdByUid = 'uid-1',
}) {
  return SavedReport(
    id: id,
    name: name,
    createdAt: createdAt ?? DateTime(2026, 1, 15, 10),
    records: records ?? const [],
    createdByUid: createdByUid,
  );
}

void main() {
  group('SavedReportSummary model', () {
    test('summary completo round-trip toJson/fromJson', () {
      final summary = SavedReportSummary(
        id: 'rep-full',
        name: 'Completo',
        createdAt: DateTime(2026, 3, 1, 8, 30),
        updatedAt: DateTime(2026, 3, 2, 9),
        createdByUid: 'uid-x',
        recordCount: 3,
        recordsCreatedAtMin: DateTime(2026, 2, 28, 7),
        recordsCreatedAtMax: DateTime(2026, 3, 1, 18),
      );

      final restored = SavedReportSummary.fromJson(summary.toJson());
      expect(restored.id, summary.id);
      expect(restored.name, summary.name);
      expect(restored.createdAt, summary.createdAt);
      expect(restored.updatedAt, summary.updatedAt);
      expect(restored.createdByUid, summary.createdByUid);
      expect(restored.recordCount, 3);
      expect(restored.recordsCreatedAtMin, summary.recordsCreatedAtMin);
      expect(restored.recordsCreatedAtMax, summary.recordsCreatedAtMax);
      expect(restored.toJson().containsKey('records'), isFalse);
    });

    test('summary con campos opcionales ausentes', () {
      final summary = SavedReportSummary.fromJson({
        'id': 'rep-opt',
        'name': 'Parcial',
        'createdAt': '2026-01-10T12:00:00.000',
        'recordCount': 1,
      });

      expect(summary.id, 'rep-opt');
      expect(summary.updatedAt, isNull);
      expect(summary.createdByUid, isNull);
      expect(summary.recordsCreatedAtMin, isNull);
      expect(summary.recordsCreatedAtMax, isNull);
      expect(summary.recordCount, 1);
    });

    test('summary vacío (recordCount 0, sin min/max)', () {
      final summary = SavedReportSummary.fromSavedReport(_report(records: []));
      expect(summary.recordCount, 0);
      expect(summary.recordsCreatedAtMin, isNull);
      expect(summary.recordsCreatedAtMax, isNull);
      final json = summary.toJson();
      expect(json['recordCount'], 0);
      expect(json.containsKey('recordsCreatedAtMin'), isFalse);
      expect(json.containsKey('recordsCreatedAtMax'), isFalse);
    });

    test('tryFromJson rechaza id vacío', () {
      expect(SavedReportSummary.tryFromJson({'name': 'x'}), isNull);
      expect(SavedReportSummary.tryFromJson({'id': '  '}), isNull);
    });
  });

  group('SavedReportSummary metadata', () {
    test('un record: min = max = createdAt', () {
      final at = DateTime(2026, 4, 1, 14, 22);
      final summary = SavedReportSummary.fromSavedReport(
        _report(
          records: [_record(id: 'r1', createdAt: at)],
        ),
      );
      expect(summary.recordCount, 1);
      expect(summary.recordsCreatedAtMin, at);
      expect(summary.recordsCreatedAtMax, at);
    });

    test('múltiples records: min/max y count correctos', () {
      final early = DateTime(2026, 1, 1, 8);
      final mid = DateTime(2026, 1, 5, 12);
      final late = DateTime(2026, 1, 10, 20);
      final summary = SavedReportSummary.fromSavedReport(
        _report(
          records: [
            _record(id: 'r2', createdAt: mid),
            _record(id: 'r3', createdAt: late),
            _record(id: 'r1', createdAt: early),
          ],
        ),
      );
      expect(summary.recordCount, 3);
      expect(summary.recordsCreatedAtMin, early);
      expect(summary.recordsCreatedAtMax, late);
      expect(summary.name, 'Informe A');
      expect(summary.createdByUid, 'uid-1');
    });
  });

  group('Legacy SavedReport', () {
    test('SavedReport sin summary sigue deserializando', () {
      final report = _report(
        records: [_record(id: 'r1', createdAt: DateTime(2026, 2, 1))],
      );
      final restored = SavedReport.fromJson(report.toJson());
      expect(restored.id, report.id);
      expect(restored.records, hasLength(1));
      expect(restored.toJson().containsKey('recordCount'), isFalse);
    });

    test('informe legacy accesible sin materializar summary', () {
      final report = _report(id: 'legacy-1');
      final store = _InMemoryReportDualStore()..seedLegacyOnly(report);

      expect(store.summaries.containsKey('legacy-1'), isFalse);
      expect(store.fetchReportById('legacy-1')?.id, 'legacy-1');
      expect(store.fetchReportSummaries(), isEmpty);
    });
  });

  group('Dual-write / update / delete', () {
    test('guardar genera reports/{id} y reportSummaries/{id}', () {
      final early = DateTime(2026, 5, 1);
      final late = DateTime(2026, 5, 3);
      final report = _report(
        id: 'rep-dw',
        name: 'Dual',
        records: [
          _record(id: 'a', createdAt: late),
          _record(id: 'b', createdAt: early),
        ],
      );
      final store = _InMemoryReportDualStore()..save(report);

      expect(store.reports.containsKey('rep-dw'), isTrue);
      expect(store.summaries.containsKey('rep-dw'), isTrue);
      expect(store.reports['rep-dw']!['records'], isA<List>());
      expect(store.summaries['rep-dw']!.containsKey('records'), isFalse);
      expect(store.summaries['rep-dw']!['recordCount'], 2);
      expect(
        store.summaries['rep-dw']!['recordsCreatedAtMin'],
        early.toIso8601String(),
      );
      expect(
        store.summaries['rep-dw']!['recordsCreatedAtMax'],
        late.toIso8601String(),
      );
    });

    test('update refleja name y metadata en ambos documentos', () {
      final store = _InMemoryReportDualStore();
      final initial = _report(
        id: 'rep-up',
        name: 'Antes',
        records: [_record(id: 'r1', createdAt: DateTime(2026, 6, 1))],
      );
      store.save(initial);

      final updated = _report(
        id: 'rep-up',
        name: 'Después',
        createdAt: initial.createdAt,
        createdByUid: 'uid-1',
        records: [
          _record(id: 'r1', createdAt: DateTime(2026, 6, 1)),
          _record(id: 'r2', createdAt: DateTime(2026, 6, 8)),
        ],
      );
      store.save(updated);

      expect(store.reports['rep-up']!['name'], 'Después');
      expect(store.summaries['rep-up']!['name'], 'Después');
      expect(store.summaries['rep-up']!['recordCount'], 2);
      expect((store.reports['rep-up']!['records'] as List).length, 2);
    });

    test('delete elimina ambos o uno si el otro falta', () {
      final store = _InMemoryReportDualStore();

      store.save(_report(id: 'both'));
      store.delete('both');
      expect(store.reports.containsKey('both'), isFalse);
      expect(store.summaries.containsKey('both'), isFalse);

      store.seedLegacyOnly(_report(id: 'full-only'));
      store.delete('full-only');
      expect(store.reports.containsKey('full-only'), isFalse);
      expect(store.summaries.containsKey('full-only'), isFalse);

      store.summaries['summary-only'] = {'id': 'summary-only', 'name': 'x'};
      store.delete('summary-only');
      expect(store.summaries.containsKey('summary-only'), isFalse);

      expect(() => store.delete('missing'), returnsNormally);
    });

    test('ReportDualWritePlan no altera estructura de SavedReport.toJson', () {
      final report = _report(
        records: [_record(id: 'r1', createdAt: DateTime(2026, 7, 1))],
      );
      final plan = ReportDualWritePlan.fromReport(report);
      expect(plan.reportData['records'], isA<List>());
      expect(plan.summaryData['recordCount'], 1);
      expect(plan.summaryData.containsKey('records'), isFalse);
      expect(plan.reportId, report.id);
    });
  });
}

/// Almacén en memoria que refleja el contrato dual-write de CloudSyncService.
class _InMemoryReportDualStore {
  final reports = <String, Map<String, dynamic>>{};
  final summaries = <String, Map<String, dynamic>>{};

  void save(SavedReport report) {
    final plan = ReportDualWritePlan.fromReport(report);
    reports[plan.reportId] = plan.reportData;
    summaries[plan.reportId] = plan.summaryData;
  }

  void seedLegacyOnly(SavedReport report) {
    reports[report.id] = Map<String, dynamic>.from(report.toJson());
  }

  void delete(String id) {
    reports.remove(id);
    summaries.remove(id);
  }

  SavedReport? fetchReportById(String id) {
    final data = reports[id];
    if (data == null) return null;
    return SavedReport.tryFromJson(Map<String, dynamic>.from(data));
  }

  List<SavedReportSummary> fetchReportSummaries() {
    return summaries.values
        .map(
          (m) => SavedReportSummary.tryFromJson(Map<String, dynamic>.from(m)),
        )
        .whereType<SavedReportSummary>()
        .toList();
  }
}
