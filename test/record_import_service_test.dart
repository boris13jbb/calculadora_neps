import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/services/record_import_service.dart';

void main() {
  test('importa nombre de tela separado del numero de telar', () {
    const csv = '''
NRO,FECHA,LOTE DE TRAMA,NOMBRE DE TELA,TELAR,NEPS,MTS CALCULADOS
1,05/06/2026 07:09,63E264H15F,DENIM CLARO,004,49,544
''';

    final result = RecordImportService().importFromCsv(csv);

    expect(result.records, hasLength(1));
    expect(result.records.single.tela, 'DENIM CLARO');
    expect(result.records.single.telar, '004');
  });
}
