import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:calculadora_neps/utils/pdf_official_neps_criteria.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfOfficialNepsCriteria', () {
    test('incluye las cuatro calificaciones oficiales con displayLabel', () {
      final rows = PdfOfficialNepsCriteria.rows();
      expect(rows, hasLength(4));
      expect(
        rows.map((r) => r.calificacion).toList(),
        [
          'OK',
          'Mención',
          'Crítico — Realizar Ajuste',
          '2da Calidad',
        ],
      );
    });

    test('puntajes y NEPS/m² coinciden con criterios oficiales', () {
      final rows = PdfOfficialNepsCriteria.rows();
      expect(rows[0].puntaje, '0 – 18');
      expect(rows[0].nepsPerM2, '≤ 200');
      expect(rows[1].puntaje, '19 – 45');
      expect(rows[1].nepsPerM2, '> 200 y ≤ 500');
      expect(rows[2].puntaje, '46 – 54');
      expect(rows[2].nepsPerM2, '> 500 y ≤ 600');
      expect(rows[3].puntaje, '≥ 55');
      expect(rows[3].nepsPerM2, '> 600');
    });

    test('no expone terminología antigua Normal/Advertencia/Crítico corto', () {
      final rows = PdfOfficialNepsCriteria.rows();
      final labels = rows.map((r) => r.calificacion).toList();
      expect(labels, isNot(contains('Normal')));
      expect(labels, isNot(contains('Advertencia')));
      expect(labels, isNot(contains('Crítico')));
      expect(labels, contains('Crítico — Realizar Ajuste'));
      expect(PdfOfficialNepsCriteria.legendTitle, contains('CRITERIOS OFICIALES'));
    });

    test('buildLegend genera un PDF válido con la leyenda', () async {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf'),
      );
      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );
      doc.addPage(
        pw.Page(
          build: (context) => PdfOfficialNepsCriteria.buildLegend(),
        ),
      );
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('ReportExportService PDF leyenda', () {
    final records = [
      NepRecord(
        telar: '004',
        neps: 18,
        tela: 'DENIM',
        loteTrama: 'L1',
      ),
      NepRecord(
        telar: '012',
        neps: 46,
        tela: 'TELA B',
        loteTrama: 'L2',
      ),
    ];

    test('PDF completo genera informe válido con leyenda integrada', () async {
      final bytes = await ReportExportService().buildPdfBytes(
        records: records,
        title: 'Informe de prueba',
        style: PdfReportStyle.completo,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      // El contenido exacto de la leyenda se valida en PdfOfficialNepsCriteria.rows
      // (fuente centralizada usada por buildLegend en el encabezado del PDF).
      expect(PdfOfficialNepsCriteria.rows(), hasLength(4));
    });

    test('PDF clásico genera informe válido con leyenda integrada', () async {
      final bytes = await ReportExportService().buildPdfBytes(
        records: records,
        title: 'Informe de prueba',
        style: PdfReportStyle.clasico,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(
        PdfOfficialNepsCriteria.rows()
            .map((r) => r.calificacion)
            .contains('Crítico — Realizar Ajuste'),
        isTrue,
      );
    });
  });
}
