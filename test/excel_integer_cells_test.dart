import 'dart:io';

import 'package:calculadora_neps/features/reports/professional/models/report_configuration.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_period_preset.dart';
import 'package:calculadora_neps/features/reports/professional/models/report_section_type.dart';
import 'package:calculadora_neps/features/reports/professional/services/professional_report_excel_service.dart';
import 'package:calculadora_neps/features/reports/professional/services/report_data_builder.dart';
import 'package:calculadora_neps/models/export_column.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/services/report_export_service.dart';
import 'package:calculadora_neps/utils/excel_cell_value.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('excelNumericCellValue', () {
    test('entero positivo 32 → IntCellValue(32)', () {
      final cell = excelNumericCellValue(32);
      expect(cell, isA<xls.IntCellValue>());
      expect((cell as xls.IntCellValue).value, 32);
      expect(cell.toString(), '32');
      expect(cell.toString().contains('.'), isFalse);
    });

    test('entero 356 → IntCellValue(356)', () {
      final cell = excelNumericCellValue(356);
      expect(cell, isA<xls.IntCellValue>());
      expect((cell as xls.IntCellValue).value, 356);
    });

    test('cero 0 → IntCellValue(0)', () {
      final cell = excelNumericCellValue(0);
      expect(cell, isA<xls.IntCellValue>());
      expect((cell as xls.IntCellValue).value, 0);
      expect(cell.toString(), '0');
    });

    test('double entero 356.0 → IntCellValue(356) sin .0', () {
      final cell = excelNumericCellValue(356.0);
      expect(cell, isA<xls.IntCellValue>());
      expect(cell.toString(), '356');
      expect(cell.toString().contains('.'), isFalse);
    });

    test('fracción real 33.5 NO se trunca → DoubleCellValue', () {
      final cell = excelNumericCellValue(33.5);
      expect(cell, isA<xls.DoubleCellValue>());
      expect((cell as xls.DoubleCellValue).value, 33.5);
      expect(cell.toString(), '33.5');
    });

    test('porcentaje fraccionario 12.34 conserva decimales', () {
      final cell = excelNumericCellValue(12.34);
      expect(cell, isA<xls.DoubleCellValue>());
      expect((cell as xls.DoubleCellValue).value, closeTo(12.34, 1e-9));
    });

    test('NaN e infinito no lanzan y no usan IntCellValue', () {
      expect(excelNumericCellValue(double.nan), isA<xls.TextCellValue>());
      expect(excelNumericCellValue(double.infinity), isA<xls.TextCellValue>());
    });
  });

  group('ReportExportService Excel clásico', () {
    late ReportExportService service;

    setUp(() {
      service = ReportExportService();
    });

    test('Neps y Mts salen como enteros sin ceros decimales', () {
      final records = [
        NepRecord(
          telar: '003',
          neps: 32,
          tela: 'Tela A',
          loteTrama: 'LOTE-1',
          createdAt: DateTime(2026, 10, 1, 17, 15),
        ),
        NepRecord(
          telar: '004',
          neps: 2,
          tela: 'Tela B',
          loteTrama: 'LOTE-2',
          createdAt: DateTime(2026, 10, 1, 17, 16),
        ),
      ];

      final bytes = service.buildExcelBytes(
        records,
        style: PdfReportStyle.clasico,
      );
      expect(bytes, isNotNull);

      final sheet = xls.Excel.decodeBytes(bytes!)['Informe'];
      const columns = ExportColumn.ordered;
      final nepsCol = columns.indexOf(ExportColumn.neps);
      final mtsCol = columns.indexOf(ExportColumn.mts);

      // Fila de cabecera en índice 3; primer dato en 4.
      final nepsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: nepsCol, rowIndex: 4),
          )
          .value;
      final mtsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: mtsCol, rowIndex: 4),
          )
          .value;

      expect(nepsCell, isA<xls.IntCellValue>());
      expect(nepsCell.toString(), '32');
      expect(mtsCell, isA<xls.IntCellValue>());
      expect(mtsCell.toString(), '356');
      expect(nepsCell.toString().contains('.'), isFalse);
      expect(mtsCell.toString().contains('.'), isFalse);
    });

    test('TOTAL REGISTROS etiqueta en A y conteo en B; totales enteros', () {
      final records = [
        NepRecord(telar: '003', neps: 32, createdAt: DateTime(2026, 10, 1)),
        NepRecord(telar: '004', neps: 10, createdAt: DateTime(2026, 10, 1)),
      ];

      final bytes = service.buildExcelBytes(
        records,
        style: PdfReportStyle.clasico,
      );
      final sheet = xls.Excel.decodeBytes(bytes!)['Informe'];
      const columns = ExportColumn.ordered;
      final nepsCol = columns.indexOf(ExportColumn.neps);

      // 2 datos + TOTAL REGISTROS + TOTAL NEPS + PROMEDIO NEPS → filas 4..8
      const totalRegistrosRow = 6;
      expect(
        sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: totalRegistrosRow,
              ),
            )
            .value
            ?.toString(),
        'TOTAL REGISTROS',
      );
      expect(
        sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: totalRegistrosRow,
              ),
            )
            .value
            ?.toString(),
        '2',
      );

      final totalNepsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: nepsCol,
              rowIndex: totalRegistrosRow + 1,
            ),
          )
          .value;
      final promedioCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: nepsCol,
              rowIndex: totalRegistrosRow + 2,
            ),
          )
          .value;

      expect(totalNepsCell, isA<xls.IntCellValue>());
      expect(totalNepsCell.toString(), '42');
      expect(promedioCell, isA<xls.IntCellValue>());
      expect(promedioCell.toString(), '21');
    });

    test('neps fraccionario 33.5 se conserva en Excel clásico', () {
      final bytes = service.buildExcelBytes(
        [
          NepRecord(
            telar: '010',
            neps: 33.5,
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
        style: PdfReportStyle.clasico,
      );
      final sheet = xls.Excel.decodeBytes(bytes!)['Informe'];
      final nepsCol = ExportColumn.ordered.indexOf(ExportColumn.neps);
      final nepsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: nepsCol, rowIndex: 4),
          )
          .value;

      expect(nepsCell, isA<xls.DoubleCellValue>());
      expect(nepsCell.toString(), '33.5');
    });

    test('fechas y textos no se convierten a número', () {
      final bytes = service.buildExcelBytes(
        [
          NepRecord(
            telar: '003',
            neps: 8,
            tela: 'DENIM',
            loteTrama: '63E264H15F',
            observacion: 'nota',
            createdAt: DateTime(2026, 10, 1, 17, 15),
          ),
        ],
        style: PdfReportStyle.clasico,
      );
      final sheet = xls.Excel.decodeBytes(bytes!)['Informe'];
      const columns = ExportColumn.ordered;

      final fecha = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: columns.indexOf(ExportColumn.fecha),
              rowIndex: 4,
            ),
          )
          .value;
      final telar = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: columns.indexOf(ExportColumn.telar),
              rowIndex: 4,
            ),
          )
          .value;
      final titulo = sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value;

      expect(fecha, isA<xls.TextCellValue>());
      expect(fecha.toString(), contains('01/10/2026'));
      expect(telar, isA<xls.TextCellValue>());
      expect(telar.toString(), '003');
      expect(titulo.toString(), 'VICUNHA jeansidentity');
    });

    test('encabezados clásicos conservan labels oficiales', () {
      final bytes = service.buildExcelBytes(
        [NepRecord(telar: '001', neps: 1, createdAt: DateTime(2026, 10, 1))],
        style: PdfReportStyle.clasico,
      );
      final sheet = xls.Excel.decodeBytes(bytes!)['Informe'];
      final labels = ExportColumn.ordered.map((c) => c.label).toList();
      for (var i = 0; i < labels.length; i++) {
        expect(
          sheet
              .cell(
                xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
              )
              .value
              ?.toString(),
          labels[i],
        );
      }
    });
  });

  group('ReportExportService Excel completo', () {
    test('Neps/Mts/totales/promedio sin .0 artificial', () {
      final service = ReportExportService();
      final bytes = service.buildExcelBytes(
        [
          NepRecord(telar: '003', neps: 32, createdAt: DateTime(2026, 10, 1)),
          NepRecord(telar: '004', neps: 10, createdAt: DateTime(2026, 10, 1)),
        ],
        style: PdfReportStyle.completo,
      );
      expect(bytes, isNotNull);

      final sheet = xls.Excel.decodeBytes(bytes!)['Registros'];
      const columns = ExportColumn.ordered;
      final nepsCol = columns.indexOf(ExportColumn.neps);
      final mtsCol = columns.indexOf(ExportColumn.mts);

      final nepsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: nepsCol, rowIndex: 1),
          )
          .value;
      final mtsCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: mtsCol, rowIndex: 1),
          )
          .value;
      expect(nepsCell, isA<xls.IntCellValue>());
      expect(nepsCell.toString(), '32');
      expect(mtsCell, isA<xls.IntCellValue>());
      expect(mtsCell.toString(), '356');

      // 2 filas de datos → totales en fila 3, promedio en 4
      final totalCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: nepsCol, rowIndex: 3),
          )
          .value;
      final avgCell = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(columnIndex: nepsCol, rowIndex: 4),
          )
          .value;
      expect(totalCell, isA<xls.IntCellValue>());
      expect(totalCell.toString(), '42');
      expect(avgCell, isA<xls.IntCellValue>());
      expect(avgCell.toString(), '21');
    });
  });

  group('ProfessionalReportExcelService', () {
    test('mts enteros y neps fraccionario no se truncan mal', () {
      final records = [
        NepRecord(
          id: 'r1',
          telar: '003',
          neps: 32,
          createdAt: DateTime(2026, 10, 1),
        ),
        NepRecord(
          id: 'r2',
          telar: '004',
          neps: 33.5,
          createdAt: DateTime(2026, 10, 1),
        ),
      ];
      final config = ReportConfiguration(
        periodPreset: ReportPeriodPreset.todos,
      );
      config.sections
        ..clear()
        ..add(ReportSectionType.tablaDetallada);
      final data = ReportDataBuilder().build(
        config: config,
        sourceRecords: records,
      );
      final bytes = ProfessionalReportExcelService().buildExcel(data);
      expect(bytes, isNotNull);

      final sheet = xls.Excel.decodeBytes(bytes!)['Registros base'];
      // Cabecera fila 0; datos desde 1. Columnas dependen de resolvedColumns.
      // Buscar celdas Int 32 / 356 y Double 33.5 en la hoja.
      final texts = <String>[];
      final types = <String>[];
      for (var r = 1; r <= 2; r++) {
        for (var c = 0; c < 20; c++) {
          final v = sheet
              .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
              .value;
          if (v == null) continue;
          texts.add(v.toString());
          types.add(v.runtimeType.toString());
        }
      }
      expect(texts, contains('32'));
      expect(texts, contains('356'));
      expect(texts, contains('33.5'));
      expect(types, contains('IntCellValue'));
      expect(types, contains('DoubleCellValue'));
    });
  });

  group('Archivos XLSX reales en disco', () {
    test('genera clásico/completo y valida celdas sin .0', () async {
      final outDir = Directory('build/excel_visual_validation');
      if (outDir.existsSync()) {
        outDir.deleteSync(recursive: true);
      }
      outDir.createSync(recursive: true);

      final service = ReportExportService();
      final records = [
        for (var i = 0; i < 11; i++)
          NepRecord(
            telar: (i + 1).toString().padLeft(3, '0'),
            neps: [32, 2, 43, 8, 15, 27, 41, 19, 55, 36, 36][i].toDouble(),
            tela: 'Tela ${i % 3}',
            loteTrama: 'LOTE-$i',
            createdAt: DateTime(2026, 10, 1, 17, 15 + i),
          ),
      ];

      final classic = service.buildExcelBytes(
        records,
        style: PdfReportStyle.clasico,
      );
      final completo = service.buildExcelBytes(
        records,
        style: PdfReportStyle.completo,
      );
      expect(classic, isNotNull);
      expect(completo, isNotNull);

      final classicPath = '${outDir.path}/informe_clasico.xlsx';
      final completoPath = '${outDir.path}/informe_completo.xlsx';
      File(classicPath).writeAsBytesSync(classic!);
      File(completoPath).writeAsBytesSync(completo!);

      expect(File(classicPath).existsSync(), isTrue);
      expect(File(completoPath).existsSync(), isTrue);
      expect(File(classicPath).lengthSync(), greaterThan(1000));

      final sheet = xls.Excel.decodeBytes(classic)['Informe'];
      const columns = ExportColumn.ordered;
      final nepsCol = columns.indexOf(ExportColumn.neps);
      final mtsCol = columns.indexOf(ExportColumn.mts);

      for (var row = 4; row < 15; row++) {
        final neps = sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: nepsCol,
                rowIndex: row,
              ),
            )
            .value;
        final mts = sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: mtsCol,
                rowIndex: row,
              ),
            )
            .value;
        expect(neps, isA<xls.IntCellValue>(), reason: 'neps row $row');
        expect(mts, isA<xls.IntCellValue>(), reason: 'mts row $row');
        expect(neps.toString().contains('.'), isFalse);
        expect(mts.toString().contains('.'), isFalse);
      }

      // TOTAL REGISTROS tras 11 filas de datos → fila 15
      expect(
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 15))
            .value
            ?.toString(),
        'TOTAL REGISTROS',
      );
      expect(
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 15))
            .value
            ?.toString(),
        '11',
      );

      final promedio = sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: nepsCol,
              rowIndex: 17,
            ),
          )
          .value;
      expect(promedio, isA<xls.IntCellValue>());
      expect(promedio.toString().contains('.'), isFalse);
    });
  });
}
