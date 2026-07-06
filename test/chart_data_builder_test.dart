import 'package:calculadora_neps/features/analytics/models/chart_config.dart';
import 'package:calculadora_neps/features/analytics/services/chart_data_builder.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:flutter_test/flutter_test.dart';

NepRecord _record({
  required double neps,
  String telar = '1',
  String tela = 'Tela A',
  String lote = 'L1',
}) {
  return NepRecord(
    telar: telar,
    neps: neps,
    tela: tela,
    loteTrama: lote,
    turno: 'A',
    operario: 'Op1',
    createdAt: DateTime(2026, 1, 15),
  );
}

void main() {
  final builder = ChartDataBuilder();

  group('ChartConfigRules', () {
    test('normaliza agrupación incompatible con distribución de estados', () {
      final normalized = ChartConfigRules.normalize(
        const ChartConfig(
          metric: ChartMetric.statusDistribution,
          groupBy: ChartGroupBy.telar,
          visualType: ChartVisualType.line,
        ),
      );
      expect(normalized.groupBy, ChartGroupBy.none);
      expect(normalized.visualType, ChartVisualType.donut);
    });

    test('normaliza gauge para criticidad sin agrupación', () {
      final normalized = ChartConfigRules.normalize(
        const ChartConfig(
          metric: ChartMetric.criticalityPercent,
          groupBy: ChartGroupBy.month,
          visualType: ChartVisualType.line,
        ),
      );
      expect(normalized.groupBy, ChartGroupBy.none);
      expect(normalized.visualType, ChartVisualType.gauge);
    });
  });

  group('ChartDataBuilder', () {
    final records = [
      _record(neps: 5, telar: '1'),
      _record(neps: 80, telar: '2'),
      _record(neps: 120, telar: '2', tela: 'Tela B', lote: 'L2'),
    ];

    test('devuelve distribución de estados', () {
      final result = builder.build(
        records,
        const ChartConfig(metric: ChartMetric.statusDistribution),
      );
      expect(result.isValid, isTrue);
      expect(result.labels, ['Normal', 'Advertencia', 'Crítico']);
      expect(result.values.length, 3);
    });

    test('devuelve gauge de criticidad', () {
      final result = builder.build(
        records,
        const ChartConfig(
          metric: ChartMetric.criticalityPercent,
          groupBy: ChartGroupBy.none,
          visualType: ChartVisualType.gauge,
        ),
      );
      expect(result.isValid, isTrue);
      expect(result.singleValue, isNotNull);
    });

    test('agrupa neps por telar', () {
      final result = builder.build(
        records,
        const ChartConfig(
          metric: ChartMetric.nepsTotal,
          groupBy: ChartGroupBy.telar,
          visualType: ChartVisualType.verticalBar,
        ),
      );
      expect(result.isValid, isTrue);
      expect(result.labels, contains('T2'));
      expect(result.values.any((v) => v > 100), isTrue);
    });

    test('sin registros devuelve mensaje controlado', () {
      final result = builder.build(
        const [],
        const ChartConfig(),
      );
      expect(result.isValid, isFalse);
      expect(result.validationMessage, isNotNull);
    });
  });
}
