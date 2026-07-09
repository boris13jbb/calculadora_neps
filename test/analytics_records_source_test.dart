import 'package:calculadora_neps/models/analytics_period.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/services/analytics_service.dart';
import 'package:calculadora_neps/utils/analytics_records_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NepRecord record({
    required String id,
    required DateTime createdAt,
    String telar = '1',
    double neps = 40,
  }) {
    return NepRecord(
      id: id,
      telar: telar,
      neps: neps,
      createdAt: createdAt,
    );
  }

  group('buildAnalyticsRecordsSource', () {
    test('fusiona registros actuales e informes sin duplicar por id', () {
      final live = [
        record(id: 'a', createdAt: DateTime(2026, 6, 10)),
      ];
      final reports = [
        SavedReport(
          id: 'r1',
          name: 'Informe 1',
          createdAt: DateTime(2026, 6, 1),
          records: [
            record(id: 'a', createdAt: DateTime(2026, 6, 1)),
            record(id: 'b', createdAt: DateTime(2026, 6, 2)),
          ],
        ),
      ];

      final source = buildAnalyticsRecordsSource(
        liveRecords: live,
        savedReports: reports,
      );

      expect(source.records.length, 2);
      expect(source.records.any((r) => r.id == 'a'), isTrue);
      expect(source.records.any((r) => r.id == 'b'), isTrue);
      expect(source.records.first.id, 'a');
      expect(source.savedReportCount, 1);
    });
  });

  group('applyAnalyticsFilters', () {
    test('en periodo mes ignora fechas guardadas y filtra el mes actual', () {
      final now = DateTime(2026, 7, 9);
      final records = [
        record(id: '1', createdAt: DateTime(2026, 7, 5)),
        record(id: '2', createdAt: DateTime(2026, 5, 1)),
      ];
      final filters = RecordFilters()
        ..dateFrom = DateTime(2026, 5, 1)
        ..dateTo = DateTime(2026, 5, 31);

      final filtered = applyAnalyticsFilters(
        records: records,
        filters: filters,
        period: AnalyticsPeriod.month,
        analytics: _FixedNowAnalytics(now),
      );

      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });

    test('en rango personalizado respeta dateFrom y dateTo', () {
      final records = [
        record(id: '1', createdAt: DateTime(2026, 6, 5)),
        record(id: '2', createdAt: DateTime(2026, 7, 5)),
      ];
      final filters = RecordFilters()
        ..dateFrom = DateTime(2026, 6, 1)
        ..dateTo = DateTime(2026, 6, 30, 23, 59, 59);

      final filtered = applyAnalyticsFilters(
        records: records,
        filters: filters,
        period: AnalyticsPeriod.custom,
      );

      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });
  });
}

class _FixedNowAnalytics extends AnalyticsService {
  _FixedNowAnalytics(this._now);

  final DateTime _now;

  @override
  List<NepRecord> filterRecordsForCurrentPeriod(
    List<NepRecord> records,
    AnalyticsPeriod period, {
    DateTime? reference,
  }) {
    return super.filterRecordsForCurrentPeriod(
      records,
      period,
      reference: _now,
    );
  }
}
