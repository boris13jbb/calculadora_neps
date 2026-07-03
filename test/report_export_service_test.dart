import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:calculadora_neps/utils/record_filter_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sortForReport ordena telares numéricamente', () {
    final records = [
      NepRecord(telar: '012', neps: 10, createdAt: DateTime(2026, 1, 2)),
      NepRecord(telar: '004', neps: 20, createdAt: DateTime(2026, 1, 1)),
      NepRecord(telar: '100', neps: 5, createdAt: DateTime(2026, 1, 3)),
    ];

    final sorted = RecordFilterHelper.sortForReport(records);
    expect(sorted.map((r) => r.telar).toList(), ['004', '012', '100']);
  });

  test('buildCsvText incluye observaciones y ordena por telar', () {
    final service = ReportExportService();
    final records = [
      NepRecord(
        telar: '012',
        neps: 49,
        tela: 'DENIM',
        loteTrama: '63E264H15F',
        observacion: 'Hilo suelto en orillo',
      ),
      NepRecord(
        telar: '004',
        neps: 33.5,
        tela: 'Tela A',
        loteTrama: 'LOTE-01',
        observacion: 'Revisar tensión',
      ),
    ];

    final csv = service.buildCsvText(records);
    expect(csv, contains('Observación'));
    expect(csv, contains('Hilo suelto en orillo'));
    expect(csv, contains('Revisar tensión'));
    expect(csv.indexOf('004'), lessThan(csv.indexOf('012')));
  });

  test('buildPdfBytes usa fuentes Unicode y genera PDF válido', () async {
    final service = ReportExportService();
    final records = [
      NepRecord(
        telar: '004',
        neps: 49,
        tela: 'DENIM CLARO — algodón índigo',
        loteTrama: '63E264H15F',
        observacion: 'Control de calidad en orillo',
      ),
      NepRecord(
        telar: '012',
        neps: 33.5,
        tela: 'Tela con ñ y acentos: operación',
        loteTrama: 'LOTE-Ñ-01',
        observacion: 'Observación con acentos: revisión',
      ),
    ];

    final bytes = await service.buildPdfBytes(
      records: records,
      title: 'Reporte prueba — Neps VICUNHA',
      filtersDescription: 'Filtro: telar 004, año 2026',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
