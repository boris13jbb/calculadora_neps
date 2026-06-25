import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildPdfBytes usa fuentes Unicode y genera PDF válido', () async {
    final service = ReportExportService();
    final records = [
      NepRecord(
        telar: '004',
        neps: 49,
        tela: 'DENIM CLARO — algodón índigo',
        loteTrama: '63E264H15F',
      ),
      NepRecord(
        telar: '012',
        neps: 33.5,
        tela: 'Tela con ñ y acentos: operación',
        loteTrama: 'LOTE-Ñ-01',
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
