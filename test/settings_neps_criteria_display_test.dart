import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/neps_quality_criteria.dart';
import 'package:calculadora_neps/models/neps_classification.dart';
import 'package:calculadora_neps/utils/pdf_official_neps_criteria.dart';

/// Contrato: Settings consume [PdfOfficialNepsCriteria.rows] (umbrales de
/// [NepsQualityCriteria] + [NepsClassification.displayLabel]), sin números
/// mágicos duplicados en la UI.
void main() {
  test(
    'filas oficiales de Settings/PDF alinean displayLabel y umbrales centrales',
    () {
      final rows = PdfOfficialNepsCriteria.rows();

      expect(rows, hasLength(4));
      expect(
        rows.map((r) => r.calificacion).toList(),
        [
          NepsClassification.ok.displayLabel,
          NepsClassification.mencion.displayLabel,
          NepsClassification.critico.displayLabel,
          NepsClassification.segundaCalidad.displayLabel,
        ],
      );

      expect(
        rows[0].puntaje,
        '0 – ${NepsQualityCriteria.okMaxScore}',
      );
      expect(
        rows[1].puntaje,
        '${NepsQualityCriteria.okMaxScore + 1} – '
        '${NepsQualityCriteria.mencionMaxScore}',
      );
      expect(
        rows[2].puntaje,
        '${NepsQualityCriteria.mencionMaxScore + 1} – '
        '${NepsQualityCriteria.criticoMaxScore}',
      );
      expect(
        rows[3].puntaje,
        '≥ ${NepsQualityCriteria.criticoMaxScore + 1}',
      );

      expect(
        rows[0].nepsPerM2,
        '≤ ${NepsQualityCriteria.okMaxNepsPerM2.round()}',
      );
      expect(
        rows[1].nepsPerM2,
        contains('${NepsQualityCriteria.mencionMaxNepsPerM2.round()}'),
      );
      expect(
        rows[2].nepsPerM2,
        contains('${NepsQualityCriteria.criticoMaxNepsPerM2.round()}'),
      );
      expect(
        rows[3].nepsPerM2,
        '> ${NepsQualityCriteria.criticoMaxNepsPerM2.round()}',
      );

      expect(
        NepsClassification.critico.displayLabel,
        'Crítico — Realizar Ajuste',
      );
    },
  );
}
