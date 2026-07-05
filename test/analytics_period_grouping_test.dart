import 'package:calculadora_neps/features/analytics/widgets/analytics_filter_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/models/analytics_period.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/services/analytics_service.dart';
import 'package:calculadora_neps/utils/analytics_filter_description.dart';

NepRecord _record({
  required double neps,
  DateTime? createdAt,
  String telar = '1',
  String turno = 'A',
  String operario = 'Juan',
}) {
  return NepRecord(
    telar: telar,
    neps: neps,
    tela: 'T1',
    loteTrama: 'L1',
    turno: turno,
    operario: operario,
    createdAt: createdAt ?? DateTime(2026, 1, 15),
  );
}

void main() {
  group('AnalyticsService agrupación temporal', () {
    final analytics = AnalyticsService();

    final records = [
      _record(neps: 10, createdAt: DateTime(2026, 1, 1)),
      _record(neps: 20, createdAt: DateTime(2026, 1, 1)),
      _record(neps: 30, createdAt: DateTime(2026, 1, 8)),
      _record(neps: 40, createdAt: DateTime(2026, 2, 10)),
      _record(neps: 50, createdAt: DateTime(2027, 1, 5)),
    ];

    test('agrupa por día', () {
      final series =
          analytics.tendenciaPorPeriodo(records, AnalyticsPeriod.day);
      expect(series.length, 4);
      expect(series.first.recordCount, 2);
      expect(series.first.totalNeps, 30);
    });

    test('agrupa por semana', () {
      final series =
          analytics.tendenciaPorPeriodo(records, AnalyticsPeriod.week);
      expect(series, isNotEmpty);
      expect(series.every((p) => p.label.startsWith('Sem')), isTrue);
    });

    test('agrupa por mes', () {
      final series =
          analytics.tendenciaPorPeriodo(records, AnalyticsPeriod.month);
      expect(series.length, 3);
      expect(series[0].totalNeps, 60);
      expect(series[1].totalNeps, 40);
    });

    test('agrupa por año', () {
      final series =
          analytics.tendenciaPorPeriodo(records, AnalyticsPeriod.year);
      expect(series.length, 2);
      expect(series.first.totalNeps, 100);
      expect(series.last.totalNeps, 50);
    });

    test('calcula mts con formula Neps / 0.09', () {
      final single = [_record(neps: 9)];
      expect(analytics.totalMtsCalculados(single), closeTo(100, 0.01));
    });

    test('buildSummary incluye KPIs y alertas', () {
      final summary = analytics.buildSummary(records, AnalyticsPeriod.month);
      expect(summary.totalRecords, 5);
      expect(summary.minNeps, 10);
      expect(summary.maxNeps, 50);
      expect(summary.alertDistribution.total, 5);
      expect(summary.byTurno, isNotEmpty);
    });

    test('resumen por turno y operario', () {
      final mixed = [
        _record(neps: 10, turno: 'A', operario: 'Ana'),
        _record(neps: 20, turno: 'B', operario: 'Ana'),
      ];
      expect(analytics.resumenPorTurno(mixed).length, 2);
      expect(analytics.resumenPorOperario(mixed).first.key, 'Ana');
    });
  });

  group('AnalyticsDateValidator', () {
    test('valida rango personalizado', () {
      final filters = RecordFilters()
        ..dateFrom = DateTime(2026, 2, 1)
        ..dateTo = DateTime(2026, 1, 1);
      expect(
        AnalyticsDateValidator.validateCustomRange(filters),
        contains('posterior'),
      );
    });

    test('exige fechas en rango personalizado', () {
      final filters = RecordFilters();
      expect(
        AnalyticsDateValidator.validateCustomRange(filters),
        isNotNull,
      );
    });
  });

  group('AnalyticsFilterDescription', () {
    test('describe periodo y filtros', () {
      final filters = RecordFilters()..telar = '12';
      final text = AnalyticsFilterDescription.describe(
        period: AnalyticsPeriod.week,
        filters: filters,
      );
      expect(text, contains('Semana'));
      expect(text, contains('Telar: 12'));
    });
  });

  group('ensureAnalyticsCustomDateDefaults', () {
    test('asigna inicio de mes y hoy si faltan fechas', () {
      final filters = RecordFilters();
      ensureAnalyticsCustomDateDefaults(filters);
      expect(filters.dateFrom, isNotNull);
      expect(filters.dateTo, isNotNull);
      expect(filters.dateFrom!.isBefore(filters.dateTo!), isTrue);
      expect(filters.quickRange, isNull);
    });

    test('no sobrescribe fechas ya definidas', () {
      final filters = RecordFilters()
        ..dateFrom = DateTime(2026, 1, 1)
        ..dateTo = DateTime(2026, 1, 31);
      ensureAnalyticsCustomDateDefaults(filters);
      expect(filters.dateFrom, DateTime(2026, 1, 1));
      expect(filters.dateTo, DateTime(2026, 1, 31));
    });
  });
}
