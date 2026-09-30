import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/neps_quality_criteria.dart';
import 'package:calculadora_neps/models/neps_classification.dart';

void main() {
  group('NepsQualityCriteria límites inclusivos', () {
    test('puntaje ↔ NEPS/m² en fronteras oficiales', () {
      expect(NepsQualityCriteria.nepsPerM2FromScore(18), closeTo(200, 0.001));
      expect(NepsQualityCriteria.nepsPerM2FromScore(45), closeTo(500, 0.001));
      expect(NepsQualityCriteria.nepsPerM2FromScore(54), closeTo(600, 0.001));
      expect(NepsQualityCriteria.scoreFromNepsPerM2(200), 18);
      expect(NepsQualityCriteria.scoreFromNepsPerM2(500), 45);
      expect(NepsQualityCriteria.scoreFromNepsPerM2(600), 54);
    });
  });

  group('classifyNepsByNepsPerM2', () {
    test('199.99 → OK', () {
      expect(
        classifyNepsByNepsPerM2(199.99),
        NepsClassification.ok,
      );
    });

    test('200 (límite inclusivo) → OK', () {
      expect(classifyNepsByNepsPerM2(200), NepsClassification.ok);
    });

    test('200.01 → Mención', () {
      expect(classifyNepsByNepsPerM2(200.01), NepsClassification.mencion);
    });

    test('499.99 → Mención', () {
      expect(classifyNepsByNepsPerM2(499.99), NepsClassification.mencion);
    });

    test('500 (límite inclusivo) → Mención', () {
      expect(classifyNepsByNepsPerM2(500), NepsClassification.mencion);
    });

    test('500.01 → Crítico', () {
      expect(classifyNepsByNepsPerM2(500.01), NepsClassification.critico);
    });

    test('599.99 → Crítico', () {
      expect(classifyNepsByNepsPerM2(599.99), NepsClassification.critico);
    });

    test('600 (límite inclusivo) → Crítico', () {
      expect(classifyNepsByNepsPerM2(600), NepsClassification.critico);
    });

    test('600.01 → 2da Calidad', () {
      expect(
        classifyNepsByNepsPerM2(600.01),
        NepsClassification.segundaCalidad,
      );
    });

    test('valores extremos y cero', () {
      expect(classifyNepsByNepsPerM2(0), NepsClassification.ok);
      expect(classifyNepsByNepsPerM2(-10), NepsClassification.ok);
      expect(
        classifyNepsByNepsPerM2(10000),
        NepsClassification.segundaCalidad,
      );
    });
  });

  group('classifyNepsByScore', () {
    test('0 y 18 → OK', () {
      expect(classifyNepsByScore(0), NepsClassification.ok);
      expect(classifyNepsByScore(18), NepsClassification.ok);
    });

    test('19 y 45 → Mención', () {
      expect(classifyNepsByScore(19), NepsClassification.mencion);
      expect(classifyNepsByScore(45), NepsClassification.mencion);
    });

    test('46 y 54 → Crítico', () {
      expect(classifyNepsByScore(46), NepsClassification.critico);
      expect(classifyNepsByScore(54), NepsClassification.critico);
    });

    test('55 → 2da Calidad', () {
      expect(classifyNepsByScore(55), NepsClassification.segundaCalidad);
    });

    test('negativos, cero y muy altos', () {
      expect(classifyNepsByScore(-1), NepsClassification.ok);
      expect(classifyNepsByScore(0), NepsClassification.ok);
      expect(classifyNepsByScore(999), NepsClassification.segundaCalidad);
    });
  });

  group('classifyNeps prioridad score', () {
    test('si score y nepsPerM2 discrepan, gana score', () {
      // score 18 = OK; nepsPerM2 501 sería Crítico si se usara solo.
      expect(
        classifyNeps(score: 18, nepsPerM2: 501),
        NepsClassification.ok,
      );
    });

    test('etiquetas visibles oficiales', () {
      expect(NepsClassification.ok.label, 'OK');
      expect(NepsClassification.mencion.label, 'Mención');
      expect(NepsClassification.critico.label, 'Crítico');
      expect(
        NepsClassification.critico.displayLabel,
        'Crítico — Realizar Ajuste',
      );
      expect(NepsClassification.critico.recommendation, 'Realizar Ajuste');
      expect(NepsClassification.segundaCalidad.label, '2da Calidad');
    });
  });
}
