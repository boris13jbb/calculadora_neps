import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/analytics_service.dart';

NepRecord _record({
  required String telar,
  required double neps,
  String tela = 'A',
  String lote = 'L1',
  DateTime? createdAt,
}) {
  return NepRecord(
    telar: telar,
    neps: neps,
    tela: tela,
    loteTrama: lote,
    createdAt: createdAt ?? DateTime(2026, 6, 29),
  );
}

void main() {
  group('AnalyticsService', () {
    final analytics = AnalyticsService();

    final records = [
      _record(telar: '1', neps: 10, tela: 'T1', lote: 'L1'),
      _record(telar: '2', neps: 50, tela: 'T2', lote: 'L2'),
      _record(
        telar: '1',
        neps: 30,
        tela: 'T1',
        lote: 'L1',
        createdAt: DateTime(2026, 6, 30),
      ),
    ];

    test('calcula totales y promedios', () {
      expect(analytics.totalRegistros(records), 3);
      expect(analytics.totalNeps(records), 90);
      expect(analytics.promedioNeps(records), closeTo(30, 0.01));
      expect(analytics.totalTelares(records), 2);
    });

    test('resumen por tela y lote', () {
      final porTela = analytics.resumenPorTela(records);
      expect(porTela.first.key, 'T2');
      expect(porTela.first.totalNeps, 50);

      final porLote = analytics.resumenPorLoteTrama(records);
      expect(porLote.first.totalNeps, 50);
    });

    test('tendencia diaria agrupa por fecha', () {
      final trend = analytics.tendenciaDiaria(records);
      expect(trend.length, 2);
      expect(trend.first.recordCount, 2);
      expect(trend.last.recordCount, 1);
    });

    test('porcentaje de críticos y distribución', () {
      expect(analytics.porcentajeCriticos(records), closeTo(33.33, 0.1));
      final dist = analytics.distribucionPorEstado(records);
      expect(dist.ok, 1);
      expect(dist.mencion, 1);
      expect(dist.critico, 1);
      expect(dist.segundaCalidad, 0);
    });

    test('top telares limita resultados', () {
      final top = analytics.topTelaresPorNeps(records, limit: 1);
      expect(top.length, 1);
      expect(top.first.key, '2');
    });

    test('mejor telar usa menor neps por m2', () {
      final mixed = [
        _record(telar: '1', neps: 90),
        _record(telar: '2', neps: 18),
        _record(telar: '3', neps: 9),
      ];

      final best = analytics.mejorTelarPorNepsM2(mixed);
      expect(best, isNotNull);
      expect(best!.key, '3');
      expect(best.nepsPorM2, closeTo(100, 0.01));
    });

    test('mejores telares ordena ascendente por neps por m2', () {
      final mixed = [
        _record(telar: '1', neps: 90),
        _record(telar: '2', neps: 18),
        _record(telar: '3', neps: 9),
      ];

      final ranking = analytics.mejoresTelaresPorNepsM2(mixed);
      expect(ranking.map((item) => item.key).toList(), ['3', '2', '1']);
    });
  });
}
