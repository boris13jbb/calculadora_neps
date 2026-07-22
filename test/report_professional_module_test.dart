import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/features/reports/professional/models/report_chart_configuration.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_chart_type.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_configuration.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_filter_configuration.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_period_preset.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_section_type.dart';
import 'package:calculadora_neps/features/reports/professional/services/professional_report_pdf_service.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_comparison_service.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_conclusion_engine.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_data_builder.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_grouping_service.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_period_resolver.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_statistics_service.dart';
import 'package:calculadora_neps/models/nep_record.dart';

NepRecord _record({
  required String telar,
  required double neps,
  DateTime? createdAt,
  String tela = 'T1',
  String turno = 'A',
}) {
  return NepRecord(
    telar: telar,
    neps: neps,
    tela: tela,
    turno: turno,
    createdAt: createdAt ?? DateTime(2026, 6, 15),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportStatisticsService', () {
    final stats = ReportStatisticsService();
    final records = [
      _record(telar: '1', neps: 10),
      _record(telar: '2', neps: 20),
      _record(telar: '1', neps: 30),
      _record(telar: '3', neps: 40),
      _record(telar: '2', neps: 50),
    ];

    test('calcula mediana', () {
      expect(stats.median([10, 20, 30, 40, 50]), 30);
      expect(stats.median([10, 20, 30, 40]), 25);
    });

    test('calcula moda', () {
      expect(stats.mode([10, 20, 20, 30]), 20);
      expect(stats.mode([10, 20, 30]), isNull);
    });

    test('calcula percentiles', () {
      final values = [10.0, 20.0, 30.0, 40.0, 50.0];
      expect(stats.percentile(values, 50), closeTo(30, 0.01));
      expect(stats.percentile(values, 25), closeTo(20, 0.01));
    });

    test('calcula varianza y desviación estándar', () {
      expect(stats.variance([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(4, 0.01));
      expect(
          stats.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2, 0.01));
    });

    test('coeficiente de variación', () {
      expect(
        stats.coefficientOfVariation([10, 20, 30]),
        greaterThan(0),
      );
    });

    test('compute genera estadísticas completas', () {
      final result = stats.compute(records);
      expect(result.totalRecords, 5);
      expect(result.averageNeps, 30);
      expect(result.medianNeps, 30);
      expect(result.telarCount, 3);
    });
  });

  group('ReportPeriodResolver', () {
    final resolver = ReportPeriodResolver();
    final ref = DateTime(2026, 6, 15, 12);

    test('resuelve este mes', () {
      final range = resolver.resolve(
        ReportPeriodPreset.esteMes,
        reference: ref,
      );
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end!.day, 15);
    });

    test('resuelve todos', () {
      final range = resolver.resolve(ReportPeriodPreset.todos);
      expect(range.isAll, isTrue);
    });

    test('periodo anterior de este mes', () {
      final prev = resolver.previousPeriod(
        ReportPeriodPreset.esteMes,
        reference: ref,
      );
      expect(prev, isNotNull);
      expect(prev!.start, DateTime(2026, 5, 1));
    });
  });

  group('ReportGroupingService', () {
    final grouping = ReportGroupingService();
    final records = [
      _record(telar: '1', neps: 10, createdAt: DateTime(2026, 6, 1)),
      _record(telar: '2', neps: 80, createdAt: DateTime(2026, 6, 2)),
      _record(telar: '1', neps: 40, createdAt: DateTime(2026, 6, 3)),
    ];

    test('agrupa por telar', () {
      final groups = grouping.byTelar(records);
      expect(groups.length, 2);
      expect(groups.firstWhere((g) => g.key == '1').recordCount, 2);
    });

    test('promedio móvil', () {
      final ma = grouping.movingAverage([10, 20, 30, 40], 2);
      expect(ma.length, 4);
      expect(ma.last, closeTo(35, 0.01));
    });
  });

  group('ReportComparisonService', () {
    final comparison = ReportComparisonService();
    final records = [
      _record(telar: '1', neps: 10, createdAt: DateTime(2026, 6, 1)),
      _record(telar: '1', neps: 90, createdAt: DateTime(2026, 5, 1)),
    ];

    test('compara periodos', () {
      final result = comparison.compare(
        records,
        ReportPeriodPreset.esteMes,
      );
      expect(result.periodALabel, isNotEmpty);
    });
  });

  group('ReportConclusionEngine', () {
    final engine = ReportConclusionEngine();
    final stats = ReportStatisticsService();

    test('genera conclusiones con datos', () {
      final records = [
        _record(telar: '1', neps: 90),
        _record(telar: '2', neps: 10),
      ];
      final statistics = stats.compute(records);
      final conclusion = engine.generate(statistics: statistics);
      expect(conclusion.autoSummary, isNotEmpty);
      expect(conclusion.findings, isNotEmpty);
    });

    test('sin datos no inventa resultados', () {
      final conclusion = engine.generate(
        statistics: stats.compute([]),
      );
      expect(conclusion.autoSummary, contains('No existen registros'));
    });
  });

  group('ReportDataBuilder', () {
    final builder = ReportDataBuilder();

    test('valida secciones vacías', () {
      final config = ReportConfiguration()..sections = {};
      expect(builder.validate(config), isNotNull);
    });

    test('valida rango personalizado', () {
      final config = ReportConfiguration(
        periodPreset: ReportPeriodPreset.rangoPersonalizado,
        customDateFrom: DateTime(2026, 6, 10),
        customDateTo: DateTime(2026, 6, 1),
      );
      expect(builder.validate(config), contains('fecha inicial'));
    });

    test('filtros combinados reducen registros', () {
      final records = [
        _record(telar: '1', neps: 10, tela: 'A'),
        _record(telar: '2', neps: 80, tela: 'B'),
      ];
      final config = ReportConfiguration(
        periodPreset: ReportPeriodPreset.todos,
      );
      config.filters = ReportFilterConfiguration(telas: {'A'});
      final data = builder.build(config: config, sourceRecords: records);
      expect(data.records.length, 1);
      expect(data.records.first.tela, 'A');
    });

    test('filtros avanzados por turno y rango neps', () {
      final records = [
        _record(telar: '1', neps: 10, turno: 'A'),
        _record(telar: '2', neps: 50, turno: 'B'),
        _record(telar: '3', neps: 90, turno: 'A'),
      ];
      final config = ReportConfiguration(
        periodPreset: ReportPeriodPreset.todos,
      );
      config.filters = ReportFilterConfiguration(
        turnos: {'A'},
        nepsMin: 20,
        nepsMax: 100,
      );
      final data = builder.build(config: config, sourceRecords: records);
      expect(data.records.length, 1);
      expect(data.records.first.telar, '3');
    });
  });

  group('ProfessionalReportPdfService', () {
    final pdfService = ProfessionalReportPdfService();
    final builder = ReportDataBuilder();

    final tinyPng = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);

    test('buildPdf incrusta imágenes de gráficas cuando se proveen', () async {
      final records = [
        _record(telar: '1', neps: 30),
        _record(telar: '2', neps: 40),
      ];
      final config = ReportConfiguration(
        periodPreset: ReportPeriodPreset.todos,
      );
      config.sections.add(ReportSectionType.graficas);
      config.charts.add(
        ReportChartConfiguration(type: ReportChartType.tendenciaNeps),
      );
      final data = builder.build(config: config, sourceRecords: records);

      final bytes = await pdfService.buildPdf(
        data,
        generatedBy: 'Test',
        userRole: 'admin',
        chartImages: {
          ReportChartType.tendenciaNeps: tinyPng,
        },
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('ReportConfiguration plantillas', () {
    test('plantilla ejecutiva activa secciones esperadas', () {
      final config = ReportConfiguration();
      config.applyTemplate(ReportTemplateKind.ejecutivo);
      expect(config.sections.length, greaterThan(3));
      expect(config.enableComparison, isTrue);
    });
  });
}
