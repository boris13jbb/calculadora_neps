import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

/// Genera la plantilla Excel para importación de registros.
class ImportTemplateService {
  Uint8List buildExcelTemplate() {
    final excel = xls.Excel.createExcel();
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) {
      excel.delete(defaultName);
    }

    final sheet = excel['Plantilla'];
    final headers = [
      'NRO',
      'FECHA',
      'LOTE DE TRAMA',
      'NOMBRE DE TELA',
      'TELAR',
      'NEPS',
      'MTS CALCULADOS',
      'TURNO',
      'OPERARIO',
      'LINEA PRODUCCION',
      'OBSERVACION',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = xls.TextCellValue(headers[col]);
      cell.cellStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#1B5E20'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final exampleRow = [
      '1',
      '29/06/2026 08:00',
      '63E264H15F',
      'DENIM CLARO',
      '004',
      '49',
      '544',
      'Mañana',
      'Juan Pérez',
      'Línea 1',
      'Ejemplo de observación',
    ];

    for (var col = 0; col < exampleRow.length; col++) {
      sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
          )
          .value = xls.TextCellValue(exampleRow[col]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('No se pudo generar la plantilla Excel.');
    }
    return Uint8List.fromList(encoded);
  }
}
