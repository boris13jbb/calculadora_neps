import 'package:calculadora_neps/features/reports/reports_screen.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:calculadora_neps/utils/report_share_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SavedReport _report({
  required String id,
  List<NepRecord>? records,
}) {
  return SavedReport(
    id: id,
    name: 'Informe $id',
    createdAt: DateTime(2026, 9, 28, 19, 50),
    records: records ??
        [
          NepRecord(
            id: 'r1',
            telar: '004',
            neps: 18,
            tela: 'DENIM',
            loteTrama: 'L1',
          ),
          NepRecord(
            id: 'r2',
            telar: '012',
            neps: 46,
            tela: 'TELA B',
            loteTrama: 'L2',
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Informes guardados — compartir completo/clásico', () {
    test('kSavedReportAllShareFormats incluye CSV, Excel y PDF', () {
      expect(
        kSavedReportAllShareFormats,
        {
          ReportShareFormat.csv,
          ReportShareFormat.excel,
          ReportShareFormat.pdf,
        },
      );
    });

    test('buildShareFiles con estilo completo usa el informe seleccionado',
        () async {
      final report = _report(id: 'rep-completo');
      final helper = ReportShareHelper(ReportExportService());

      final files = await helper.buildShareFiles(
        reports: [report],
        formats: kSavedReportAllShareFormats,
        reportStyle: PdfReportStyle.completo,
      );

      expect(files, hasLength(3));
      expect(files.every((f) => f.fileName.contains('Informe_rep-completo')),
          isTrue);
      expect(files.map((f) => f.fileName.split('.').last).toSet(),
          {'csv', 'xlsx', 'pdf'});
    });

    test('buildShareFiles con estilo clásico genera los tres formatos',
        () async {
      final report = _report(id: 'rep-clasico');
      final helper = ReportShareHelper(ReportExportService());

      final files = await helper.buildShareFiles(
        reports: [report],
        formats: kSavedReportAllShareFormats,
        reportStyle: PdfReportStyle.clasico,
      );

      expect(files, hasLength(3));
      expect(files.every((f) => f.fileName.contains('Informe_rep-clasico')),
          isTrue);
    });

    test('informe vacío no lanza al generar completo ni clásico', () async {
      final empty = _report(id: 'vacio', records: const []);
      final helper = ReportShareHelper(ReportExportService());

      final completo = await helper.buildShareFiles(
        reports: [empty],
        formats: kSavedReportAllShareFormats,
        reportStyle: PdfReportStyle.completo,
      );
      final clasico = await helper.buildShareFiles(
        reports: [empty],
        formats: kSavedReportAllShareFormats,
        reportStyle: PdfReportStyle.clasico,
      );

      expect(completo, isNotEmpty);
      expect(clasico, isNotEmpty);
    });

    test('solo se generan archivos del informe indicado', () async {
      final selected = _report(id: 'solo-este');
      final other = _report(id: 'otro');
      final helper = ReportShareHelper(ReportExportService());

      final files = await helper.buildShareFiles(
        reports: [selected],
        formats: {ReportShareFormat.pdf},
        reportStyle: PdfReportStyle.clasico,
      );

      expect(files, hasLength(1));
      expect(files.single.fileName, contains('solo-este'));
      expect(files.single.fileName, isNot(contains('otro')));
      expect(other.id, isNot(selected.id));
    });

    testWidgets('el menú de informe expone completo y clásico', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              itemBuilder: (context) => buildSavedReportRowMenuItems(),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Compartir completo'), findsOneWidget);
      expect(find.text('Compartir clásico'), findsOneWidget);
      expect(find.text('Compartir CSV'), findsOneWidget);
      expect(find.text('Ver informe'), findsOneWidget);
    });
  });
}
