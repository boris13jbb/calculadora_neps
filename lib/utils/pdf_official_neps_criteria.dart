import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/neps_quality_criteria.dart';
import '../models/neps_classification.dart';

/// Fila informativa de la leyenda oficial de calificación NEPS para PDFs.
///
/// Los textos visibles salen de [NepsClassification.displayLabel] y los
/// umbrales de [NepsQualityCriteria] (fuente centralizada, no editable).
class OfficialNepsCriteriaRow {
  const OfficialNepsCriteriaRow({
    required this.calificacion,
    required this.puntaje,
    required this.nepsPerM2,
  });

  final String calificacion;
  final String puntaje;
  final String nepsPerM2;
}

/// Leyenda fija de criterios oficiales para encabezados de informes PDF.
class PdfOfficialNepsCriteria {
  PdfOfficialNepsCriteria._();

  static const String legendTitle = 'CRITERIOS OFICIALES DE CALIFICACIÓN';

  /// Filas canónicas (OK / Mención / Crítico — Realizar Ajuste / 2da Calidad).
  static List<OfficialNepsCriteriaRow> rows() {
    const okMax = NepsQualityCriteria.okMaxScore;
    const mencionMax = NepsQualityCriteria.mencionMaxScore;
    const criticoMax = NepsQualityCriteria.criticoMaxScore;
    final okNeps = NepsQualityCriteria.okMaxNepsPerM2.round();
    final mencionNeps = NepsQualityCriteria.mencionMaxNepsPerM2.round();
    final criticoNeps = NepsQualityCriteria.criticoMaxNepsPerM2.round();

    return [
      OfficialNepsCriteriaRow(
        calificacion: NepsClassification.ok.displayLabel,
        puntaje: '0 – $okMax',
        nepsPerM2: '≤ $okNeps',
      ),
      OfficialNepsCriteriaRow(
        calificacion: NepsClassification.mencion.displayLabel,
        puntaje: '${okMax + 1} – $mencionMax',
        nepsPerM2: '> $okNeps y ≤ $mencionNeps',
      ),
      OfficialNepsCriteriaRow(
        calificacion: NepsClassification.critico.displayLabel,
        puntaje: '${mencionMax + 1} – $criticoMax',
        nepsPerM2: '> $mencionNeps y ≤ $criticoNeps',
      ),
      OfficialNepsCriteriaRow(
        calificacion: NepsClassification.segundaCalidad.displayLabel,
        puntaje: '≥ ${criticoMax + 1}',
        nepsPerM2: '> $criticoNeps',
      ),
    ];
  }

  /// Bloque visual compacto para el encabezado de PDFs de informes.
  ///
  /// Se inserta una sola vez en el cuerpo (junto al encabezado principal),
  /// no en el callback `header` repetido por página, para evitar ocupar
  /// espacio innecesario en informes multipágina.
  static pw.Widget buildLegend({
    PdfColor? borderColor,
    PdfColor? headerColor,
    PdfColor? titleColor,
  }) {
    final border = borderColor ?? PdfColor.fromHex('#C5B89A');
    final headBg = headerColor ?? PdfColor.fromHex('#1F2A2E');
    final titleFg = titleColor ?? PdfColor.fromHex('#1F2A2E');
    final data = rows();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FBF7EF'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            legendTitle,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: titleFg,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Calificación', 'Puntaje', 'NEPS/m²'],
            data: [
              for (final row in data)
                [row.calificacion, row.puntaje, row.nepsPerM2],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: headBg),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#D9D0BC'),
              width: 0.4,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.4),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.6),
            },
          ),
        ],
      ),
    );
  }
}
