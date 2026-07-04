import 'package:calculadora_neps/models/export_column.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/services/record_export_coordinator.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordExportCoordinator', () {
    final coordinator = RecordExportCoordinator(
      exportService: ReportExportService(),
    );

    final sampleRecords = [
      NepRecord(
        telar: '004',
        neps: 49,
        tela: 'DENIM',
        loteTrama: '63E264H15F',
        createdAt: DateTime(2026, 6, 5, 7, 9),
      ),
    ];

    test('buildTabText genera texto tabulado', () {
      final text = coordinator.buildTabText(
        records: sampleRecords,
        columns: ExportColumn.defaultSelection(),
      );
      expect(text, contains('004'));
      expect(text, contains('DENIM'));
    });

    test('buildPdfBytes genera PDF no vacío', () async {
      final bytes = await coordinator.buildPdfBytes(
        records: sampleRecords,
        columns: ExportColumn.defaultSelection(),
        style: PdfReportStyle.completo,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
