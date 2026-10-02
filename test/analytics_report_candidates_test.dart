import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/utils/analytics_report_candidates.dart';
import 'package:flutter_test/flutter_test.dart';

SavedReportSummary _summary({
  required String id,
  required DateTime createdAt,
  required int recordCount,
  DateTime? min,
  DateTime? max,
  String? uid,
}) {
  return SavedReportSummary(
    id: id,
    name: id,
    createdAt: createdAt,
    recordCount: recordCount,
    recordsCreatedAtMin: min,
    recordsCreatedAtMax: max,
    createdByUid: uid ?? 'u1',
  );
}

void main() {
  final periodStart = DateTime(2026, 3, 1);
  final periodEnd = DateTime(2026, 3, 31, 23, 59, 59, 999);

  group('summaryIntersectsAnalyticsPeriod', () {
    test('Caso 1: records dentro del período → include', () {
      final s = _summary(
        id: 'in',
        createdAt: DateTime(2025, 1, 1),
        recordCount: 2,
        min: DateTime(2026, 3, 10),
        max: DateTime(2026, 3, 20),
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isTrue,
      );
    });

    test('Caso 2: report creado dentro pero records fuera → exclude', () {
      final s = _summary(
        id: 'created-in',
        createdAt: DateTime(2026, 3, 15),
        recordCount: 3,
        min: DateTime(2026, 1, 1),
        max: DateTime(2026, 1, 31),
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isFalse,
      );
    });

    test('Caso 3: report creado antes pero records dentro → include', () {
      final s = _summary(
        id: 'old-report',
        createdAt: DateTime(2025, 6, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 5),
        max: DateTime(2026, 3, 5),
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isTrue,
      );
    });

    test('Caso 4: cruce de frontera → include', () {
      final s = _summary(
        id: 'border',
        createdAt: DateTime(2026, 2, 1),
        recordCount: 4,
        min: DateTime(2026, 2, 20),
        max: DateTime(2026, 3, 2),
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isTrue,
      );
    });

    test('Caso 5: recordCount == 0 → exclude', () {
      final s = _summary(
        id: 'empty',
        createdAt: DateTime(2026, 3, 10),
        recordCount: 0,
        min: null,
        max: null,
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isFalse,
      );
    });

    test('Caso 6: recordCount > 0 + min/max null → include conservador', () {
      final s = _summary(
        id: 'partial-meta',
        createdAt: DateTime(2020, 1, 1),
        recordCount: 5,
        min: null,
        max: null,
      );
      expect(
        summaryIntersectsAnalyticsPeriod(
          s,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        isTrue,
      );
    });
  });

  group('selectAnalyticsReportCandidateIds', () {
    test('Caso 7: summary duplicado → un solo ID', () {
      final a = _summary(
        id: 'dup',
        createdAt: DateTime(2026, 3, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 10),
        max: DateTime(2026, 3, 10),
      );
      final ids = selectAnalyticsReportCandidateIds(
        summaries: [a, a],
        periodStart: periodStart,
        periodEnd: periodEnd,
        viewerUid: 'u1',
        canViewTeamReports: true,
      );
      expect(ids, ['dup']);
    });

    test('respeta visibilidad: operario no ve reports ajenos', () {
      final own = _summary(
        id: 'own',
        createdAt: DateTime(2026, 3, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 10),
        max: DateTime(2026, 3, 10),
        uid: 'op-1',
      );
      final other = _summary(
        id: 'other',
        createdAt: DateTime(2026, 3, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 10),
        max: DateTime(2026, 3, 10),
        uid: 'admin',
      );
      final ids = selectAnalyticsReportCandidateIds(
        summaries: [own, other],
        periodStart: periodStart,
        periodEnd: periodEnd,
        viewerUid: 'op-1',
        canViewTeamReports: false,
      );
      expect(ids, ['own']);
    });

    test('super admin / team ve todos los visibles del período', () {
      final a = _summary(
        id: 'a',
        createdAt: DateTime(2026, 3, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 10),
        max: DateTime(2026, 3, 10),
        uid: 'op-1',
      );
      final b = _summary(
        id: 'b',
        createdAt: DateTime(2026, 3, 1),
        recordCount: 1,
        min: DateTime(2026, 3, 11),
        max: DateTime(2026, 3, 11),
        uid: 'op-2',
      );
      final ids = selectAnalyticsReportCandidateIds(
        summaries: [a, b],
        periodStart: periodStart,
        periodEnd: periodEnd,
        viewerUid: 'sa',
        canViewTeamReports: true,
      );
      expect(ids, ['a', 'b']);
    });
  });
}
