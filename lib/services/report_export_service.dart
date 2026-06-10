import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';

class ReportExportService {
  double calculateMts(double neps) => neps / testLengthM;

  String formatNumber(double value) {
    if (decimals == 0) return value.round().toString();
    return value.toStringAsFixed(decimals);
  }

  String formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(3);
  }

  String escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Map<String, double> summarize(List<NepRecord> records) {
    final totalNeps = records.fold<double>(0, (sum, item) => sum + item.neps);
    final averageNeps = records.isEmpty ? 0.0 : totalNeps / records.length;
    return {
      'totalNeps': totalNeps,
      'averageNeps': averageNeps,
    };
  }

  List<ExportColumn> _columns(Set<ExportColumn> selected) {
    final columns = ExportColumn.resolveSelection(selected);
    if (columns.isEmpty) return ExportColumn.ordered;
    return columns;
  }

  String _cellValue(ExportColumn column, NepRecord item, int index) {
    return switch (column) {
      ExportColumn.nro => (index + 1).toString(),
      ExportColumn.fecha => _formatDate(item.createdAt),
      ExportColumn.loteTrama => item.loteTrama,
      ExportColumn.tela => item.tela,
      ExportColumn.telar => item.telar,
      ExportColumn.neps => formatDecimal(item.neps),
      ExportColumn.mts => formatNumber(calculateMts(item.neps)),
    };
  }

  List<String> _dataRow(
    NepRecord item,
    int index,
    List<ExportColumn> columns,
  ) =>
      columns.map((c) => _cellValue(c, item, index)).toList();

  List<List<String>> _summaryFooterRows(
    List<ExportColumn> columns,
    Map<String, double> summary,
    int recordCount,
  ) {
    if (!columns.contains(ExportColumn.neps)) return const [];

    return [
      _summaryRow(
        columns,
        label: 'TOTAL REGISTROS',
        valueColumn:
            columns.contains(ExportColumn.nro) ? ExportColumn.nro : null,
        value: recordCount.toString(),
      ),
      _summaryRow(
        columns,
        label: 'TOTAL NEPS',
        valueColumn: ExportColumn.neps,
        value: formatDecimal(summary['totalNeps']!),
      ),
      _summaryRow(
        columns,
        label: 'PROMEDIO NEPS',
        valueColumn: ExportColumn.neps,
        value: formatDecimal(summary['averageNeps']!),
      ),
    ];
  }

  List<String> _summaryRow(
    List<ExportColumn> columns, {
    required String label,
    required ExportColumn? valueColumn,
    required String value,
  }) {
    var labelPlaced = false;
    return columns.map((column) {
      if (column == valueColumn) return value;
      if (!labelPlaced) {
        labelPlaced = true;
        return valueColumn == null ? '$label: $value' : label;
      }
      return '';
    }).toList();
  }

  String buildCsvText(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
  }) {
    final selected = _columns(columns ?? ExportColumn.defaultSelection());
    final summary = summarize(records);
    final buffer = StringBuffer();
    buffer.writeln(selected.map((c) => c.label).join(','));

    for (int i = 0; i < records.length; i++) {
      buffer.writeln(
        _dataRow(records[i], i, selected).map(escapeCsv).join(','),
      );
    }

    for (final row in _summaryFooterRows(selected, summary, records.length)) {
      buffer.writeln(row.map(escapeCsv).join(','));
    }

    return buffer.toString();
  }

  Uint8List? buildExcelBytes(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
  }) {
    if (records.isEmpty) return null;

    final selected = _columns(columns ?? ExportColumn.defaultSelection());
    final summary = summarize(records);
    final excel = xls.Excel.createExcel();
    const sheetName = 'Reporte Neps';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow(
      selected.map((c) => xls.TextCellValue(c.label)).toList(),
    );

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      sheet.appendRow(
        selected.map((column) {
          return switch (column) {
            ExportColumn.nro => xls.IntCellValue(i + 1),
            ExportColumn.fecha =>
              xls.TextCellValue(_formatDate(item.createdAt)),
            ExportColumn.loteTrama => xls.TextCellValue(item.loteTrama),
            ExportColumn.tela => xls.TextCellValue(item.tela),
            ExportColumn.telar => xls.TextCellValue(item.telar),
            ExportColumn.neps => xls.DoubleCellValue(item.neps),
            ExportColumn.mts => xls.DoubleCellValue(calculateMts(item.neps)),
          };
        }).toList(),
      );
    }

    for (final row in _summaryFooterRows(selected, summary, records.length)) {
      sheet.appendRow(row.map(_excelCellFromString).toList());
    }

    final bytes = excel.encode();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  xls.CellValue _excelCellFromString(String value) {
    if (value.isEmpty) return xls.TextCellValue('');
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null) return xls.DoubleCellValue(parsed);
    return xls.TextCellValue(value);
  }

  Future<Uint8List> buildPdfBytes({
    required List<NepRecord> records,
    String title = 'Reporte Neps VICUNHA',
    String? filtersDescription,
    Set<ExportColumn>? columns,
  }) async {
    final selected = _columns(columns ?? ExportColumn.defaultSelection());
    final summary = summarize(records);
    final doc = pw.Document();

    final tableData = records.asMap().entries.map((entry) {
      return _dataRow(entry.value, entry.key, selected);
    }).toList();

    tableData.addAll(
      _summaryFooterRows(selected, summary, records.length),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1F2A2E'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VICUNHA  jeansidentity',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#F7EAC5'),
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#CFD8C5'),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Formula utilizada: Mts calculados = Neps / 0.09',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (filtersDescription != null &&
                filtersDescription.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Filtros: $filtersDescription',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: selected.map((c) => c.label).toList(),
              data: tableData,
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1F2A2E'),
              ),
              headerStyle: pw.TextStyle(
                color: PdfColor.fromHex('#F7EAC5'),
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EBDFC3'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total registros: ${records.length}'),
                  if (selected.contains(ExportColumn.neps)) ...[
                    pw.Text(
                      'Total neps: ${formatDecimal(summary['totalNeps']!)}',
                    ),
                    pw.Text(
                      'Promedio neps: ${formatDecimal(summary['averageNeps']!)}',
                    ),
                  ],
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  String buildTabText(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
  }) {
    final selected = _columns(columns ?? ExportColumn.defaultSelection());
    final buffer = StringBuffer();
    buffer.writeln(selected.map((c) => c.label).join('\t'));

    for (int i = 0; i < records.length; i++) {
      buffer.writeln(_dataRow(records[i], i, selected).join('\t'));
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}
