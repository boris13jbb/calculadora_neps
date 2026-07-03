import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../models/alert_level.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../services/alert_service.dart';
import '../services/analytics_service.dart';

/// Generación profesional de reportes CSV, Excel y PDF.
class ReportExportService {
  final AlertService _alerts;
  final AnalyticsService _analytics;

  ReportExportService({
    AlertService? alerts,
    AnalyticsService? analytics,
  })  : _alerts = alerts ?? alertService,
        _analytics = analytics ?? analyticsService;

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

  List<ExportColumn> _columns(Set<ExportColumn>? selected) {
    final columns = ExportColumn.resolveSelection(
      selected ?? ExportColumn.defaultSelection(),
    );
    if (columns.isEmpty) return ExportColumn.ordered;
    return columns;
  }

  String _recommendationFor(NepRecord record, List<NepRecord> all) {
    final recs = _alerts.generateRecommendations(record, all);
    return recs.isEmpty ? '' : recs.join(' ');
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
      ExportColumn.estadoAlerta => item.estadoAlerta,
      ExportColumn.recomendacion => '',
    };
  }

  List<String> _dataRow(
    NepRecord item,
    int index,
    List<ExportColumn> columns,
    List<NepRecord> allRecords,
  ) =>
      columns.map((column) {
        if (column == ExportColumn.recomendacion) {
          return _recommendationFor(item, allRecords);
        }
        return _cellValue(column, item, index);
      }).toList();

  dynamic _excelRawValue(
    ExportColumn column,
    NepRecord item,
    int index,
    List<NepRecord> all,
  ) =>
      switch (column) {
        ExportColumn.nro => index + 1,
        ExportColumn.fecha => _formatDate(item.createdAt),
        ExportColumn.loteTrama => item.loteTrama,
        ExportColumn.tela => item.tela,
        ExportColumn.telar => item.telar,
        ExportColumn.neps => item.neps,
        ExportColumn.mts => calculateMts(item.neps),
        ExportColumn.estadoAlerta => item.estadoAlerta,
        ExportColumn.recomendacion => _recommendationFor(item, all),
      };

  List<String> _classicTotalRegistrosRow(
    int count,
    List<ExportColumn> columns,
  ) {
    final row = List<String>.filled(columns.length, '');
    final nroIdx = columns.indexOf(ExportColumn.nro);
    final fechaIdx = columns.indexOf(ExportColumn.fecha);
    if (nroIdx >= 0) row[nroIdx] = '$count';
    if (fechaIdx >= 0) {
      row[fechaIdx] = 'TOTAL REGISTROS';
    } else if (columns.isNotEmpty) {
      row[0] = 'TOTAL REGISTROS: $count';
    }
    return row;
  }

  List<String> _classicMetricRow(
    String label,
    String value,
    List<ExportColumn> columns,
  ) {
    final row = List<String>.filled(columns.length, '');
    if (columns.isEmpty) return row;
    row[0] = label;
    final nepsIdx = columns.indexOf(ExportColumn.neps);
    if (nepsIdx >= 0) {
      row[nepsIdx] = value;
    }
    return row;
  }

  List<List<String>> _classicTableRows(
    List<NepRecord> records,
    Map<String, double> summary,
    List<ExportColumn> columns,
  ) {
    final data = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      data.add(_dataRow(records[i], i, columns, records));
    }

    if (columns.contains(ExportColumn.neps)) {
      data.add(_classicTotalRegistrosRow(records.length, columns));
      data.add(
        _classicMetricRow(
          'TOTAL NEPS',
          formatDecimal(summary['totalNeps']!),
          columns,
        ),
      );
      data.add(
        _classicMetricRow(
          'PROMEDIO NEPS',
          formatNumber(summary['averageNeps']!),
          columns,
        ),
      );
    }

    return data;
  }

  String buildCsvText(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
    PdfReportStyle style = PdfReportStyle.completo,
  }) {
    if (style == PdfReportStyle.clasico) {
      return _buildClassicCsvText(records, columns: columns);
    }

    final selected = _columns(columns);
    final summary = summarize(records);
    final buffer = StringBuffer();
    buffer.writeln(selected.map((c) => c.label).join(','));

    for (int i = 0; i < records.length; i++) {
      buffer.writeln(
        _dataRow(records[i], i, selected, records)
            .map(escapeCsv)
            .join(','),
      );
    }

    if (selected.contains(ExportColumn.neps)) {
      buffer.writeln(
        escapeCsv('TOTAL REGISTROS,${records.length}'),
      );
      buffer.writeln(
        escapeCsv('TOTAL NEPS,${formatDecimal(summary['totalNeps']!)}'),
      );
      buffer.writeln(
        escapeCsv('PROMEDIO NEPS,${formatNumber(summary['averageNeps']!)}'),
      );
    }

    return buffer.toString();
  }

  String _buildClassicCsvText(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
  }) {
    final selected = _columns(columns);
    final summary = summarize(records);
    final buffer = StringBuffer();
    buffer.writeln(
      escapeCsv('Formula utilizada: Mts calculados = Neps / $testLengthM'),
    );
    buffer.writeln();
    buffer.writeln(selected.map((c) => c.label).map(escapeCsv).join(','));

    for (final row in _classicTableRows(records, summary, selected)) {
      buffer.writeln(row.map(escapeCsv).join(','));
    }

    return buffer.toString();
  }

  Uint8List? buildExcelBytes(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
    PdfReportStyle style = PdfReportStyle.completo,
  }) {
    if (records.isEmpty) return null;

    final selected = _columns(columns);
    final excel = xls.Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    if (style == PdfReportStyle.clasico) {
      _buildClassicExcelSheet(excel, records, selected);
      excel.setDefaultSheet('Informe');
    } else {
      _buildRegistrosSheet(excel, records, selected);
      _buildGroupSheet(
        excel,
        'Resumen por telar',
        _analytics.resumenPorTelar(records),
      );
      _buildGroupSheet(
        excel,
        'Resumen por tela',
        _analytics.resumenPorTela(records),
      );
      _buildGroupSheet(
        excel,
        'Resumen por lote',
        _analytics.resumenPorLoteTrama(records),
      );
      _buildAlertSheet(
        excel,
        'Alertas críticas',
        _alerts.detectCriticalRecords(records),
        records,
      );
      _buildAlertSheet(
        excel,
        'Advertencias',
        _alerts.detectWarningRecords(records),
        records,
      );
      _buildTrendSheet(excel, records);
      excel.setDefaultSheet('Registros');
    }

    final bytes = excel.encode();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  void _buildClassicExcelSheet(
    xls.Excel excel,
    List<NepRecord> records,
    List<ExportColumn> columns,
  ) {
    const name = 'Informe';
    final sheet = excel[name];
    final summary = summarize(records);
    const headerRow = 3;

    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = xls.TextCellValue('VICUNHA jeansidentity');
    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = xls.TextCellValue(
      'Formula utilizada: Mts calculados = Neps / $testLengthM',
    );

    _writeHeaderRow(
      sheet,
      columns.map((column) => column.label).toList(),
      rowIndex: headerRow,
    );

    var rowIndex = headerRow + 1;
    for (final row in _classicTableRows(records, summary, columns)) {
      for (var col = 0; col < row.length; col++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: rowIndex,
          ),
        );
        final value = row[col];
        final column = columns[col];
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null &&
            (column == ExportColumn.neps || column == ExportColumn.mts)) {
          cell.value = xls.DoubleCellValue(parsed);
        } else {
          cell.value = xls.TextCellValue(value);
        }
      }
      rowIndex++;
    }

    final summaryRow = rowIndex + 1;
    sheet
        .cell(xls.CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: summaryRow))
        .value = xls.TextCellValue('Total registros: ${records.length}');
    sheet
        .cell(xls.CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: summaryRow + 1))
        .value = xls.TextCellValue(
      'Total neps: ${formatDecimal(summary['totalNeps']!)}',
    );
    sheet
        .cell(xls.CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: summaryRow + 2))
        .value = xls.TextCellValue(
      'Promedio neps: ${formatNumber(summary['averageNeps']!)}',
    );

    _autoColumnWidths(sheet, columns.length, summaryRow + 3);
  }

  void _buildRegistrosSheet(
    xls.Excel excel,
    List<NepRecord> records,
    List<ExportColumn> columns,
  ) {
    const name = 'Registros';
    final sheet = excel[name];
    final headers = columns.map((column) => column.label).toList();

    _writeHeaderRow(sheet, headers);

    for (var i = 0; i < records.length; i++) {
      final item = records[i];
      final level = _alerts.getAlertLevel(item.neps);
      final rowIndex = i + 1;

      for (var col = 0; col < columns.length; col++) {
        final column = columns[col];
        final value = _excelRawValue(column, item, i, records);
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
        );
        if (value is num) {
          cell.value = xls.DoubleCellValue(value.toDouble());
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
        if (column == ExportColumn.estadoAlerta ||
            column == ExportColumn.recomendacion) {
          cell.cellStyle = _excelAlertStyle(level, bold: false);
        }
      }
    }

    final nepsColIndex = columns.indexOf(ExportColumn.neps);
    if (nepsColIndex >= 0) {
      final totalRow = records.length + 1;
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: totalRow))
          .value = xls.TextCellValue('TOTALES');
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
              columnIndex: nepsColIndex, rowIndex: totalRow))
          .value = xls.DoubleCellValue(_analytics.totalNeps(records));
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: totalRow + 1))
          .value = xls.TextCellValue('PROMEDIO NEPS');
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
              columnIndex: nepsColIndex, rowIndex: totalRow + 1))
          .value = xls.DoubleCellValue(
        _analytics.promedioNeps(records).roundToDouble(),
      );
    }

    _autoColumnWidths(sheet, headers.length, records.length + 2);
  }

  void _buildGroupSheet(
    xls.Excel excel,
    String name,
    List<GroupNepsSummary> summaries,
  ) {
    final sheet = excel[name];
    final headers = [
      'Clave',
      'Registros',
      'Total neps',
      'Promedio neps',
      'Críticos',
      'Advertencias',
    ];
    _writeHeaderRow(sheet, headers);

    for (var i = 0; i < summaries.length; i++) {
      final s = summaries[i];
      final row = i + 1;
      final values = [
        s.key,
        s.recordCount,
        s.totalNeps,
        s.averageNeps.roundToDouble(),
        s.criticalCount,
        s.warningCount,
      ];
      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        final value = values[col];
        if (value is num) {
          cell.value = xls.DoubleCellValue(value.toDouble());
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
      }
    }
    _autoColumnWidths(sheet, headers.length, summaries.length + 1);
  }

  void _buildAlertSheet(
    xls.Excel excel,
    String name,
    List<NepRecord> alerts,
    List<NepRecord> all,
  ) {
    final sheet = excel[name];
    final headers = [
      'Fecha',
      'Telar',
      'Tela',
      'Lote/trama',
      'Neps',
      'Estado',
      'Recomendación',
    ];
    _writeHeaderRow(sheet, headers);

    for (var i = 0; i < alerts.length; i++) {
      final item = alerts[i];
      final level = _alerts.getAlertLevel(item.neps);
      final row = i + 1;
      final values = [
        _formatDate(item.createdAt),
        item.telar,
        item.tela,
        item.loteTrama,
        item.neps,
        level.label,
        _recommendationFor(item, all),
      ];
      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        final value = values[col];
        if (value is num) {
          cell.value = xls.DoubleCellValue(value.toDouble());
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
        cell.cellStyle = _excelAlertStyle(level);
      }
    }
    _autoColumnWidths(sheet, headers.length, alerts.length + 1);
  }

  void _buildTrendSheet(xls.Excel excel, List<NepRecord> records) {
    const name = 'Tendencia diaria';
    final sheet = excel[name];
    final trend = _analytics.tendenciaDiaria(records);
    final headers = ['Fecha', 'Registros', 'Total neps', 'Promedio neps'];
    _writeHeaderRow(sheet, headers);

    for (var i = 0; i < trend.length; i++) {
      final point = trend[i];
      final row = i + 1;
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = xls.TextCellValue(_formatDateOnly(point.date));
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = xls.IntCellValue(point.recordCount);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = xls.DoubleCellValue(point.totalNeps);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = xls.DoubleCellValue(point.averageNeps.roundToDouble());
    }
    _autoColumnWidths(sheet, headers.length, trend.length + 1);
  }

  void _writeHeaderRow(
    xls.Sheet sheet,
    List<String> headers, {
    int rowIndex = 0,
  }) {
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#1F2A2E'),
      fontColorHex: xls.ExcelColor.fromHexString('#F7EAC5'),
    );
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
      );
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
  }

  xls.CellStyle _excelAlertStyle(AlertLevel level, {bool bold = false}) {
    final bgHex = switch (level) {
      AlertLevel.normal => '#C8E6C9',
      AlertLevel.advertencia => '#FFE0B2',
      AlertLevel.critico => '#FFCDD2',
    };
    return xls.CellStyle(
      bold: bold,
      backgroundColorHex: xls.ExcelColor.fromHexString(bgHex),
    );
  }

  void _autoColumnWidths(xls.Sheet sheet, int cols, int rows) {
    for (var c = 0; c < cols; c++) {
      sheet.setColumnWidth(c, c == 0 ? 8 : 16);
    }
  }

  Future<Uint8List> buildPdfBytes({
    required List<NepRecord> records,
    String title = 'Reporte de Control de Calidad — Neps VICUNHA',
    String? filtersDescription,
    Set<ExportColumn>? columns,
    PdfReportStyle style = PdfReportStyle.completo,
  }) async {
    return switch (style) {
      PdfReportStyle.completo => _buildCompletePdf(
          records: records,
          title: title,
          filtersDescription: filtersDescription,
          columns: columns,
        ),
      PdfReportStyle.clasico => _buildClassicPdf(
          records: records,
          title: title,
          filtersDescription: filtersDescription,
          columns: columns,
        ),
    };
  }

  /// Modo actual: reporte ejecutivo con análisis, alertas y rankings.
  Future<Uint8List> _buildCompletePdf({
    required List<NepRecord> records,
    required String title,
    String? filtersDescription,
    Set<ExportColumn>? columns,
  }) async {
    final selected = _columns(columns);
    final summary = summarize(records);
    final critical = _alerts.detectCriticalRecords(records);
    final topTelars = _analytics.topTelaresPorNeps(records, limit: 10);
    final porTela = _analytics.resumenPorTela(records).take(10).toList();
    final porLote = _analytics.resumenPorLoteTrama(records).take(10).toList();
    final worstTela = _alerts.mostProblematicTela(records);
    final worstLote = _alerts.mostProblematicLote(records);
    final recommendations = <String>{};
    for (final record in critical.take(15)) {
      recommendations.addAll(_alerts.generateRecommendations(record, records));
    }

    final doc = pw.Document();
    final generatedAt = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _pdfHeader(title, generatedAt),
          pw.SizedBox(height: 12),
          pw.Text(
            'Fórmula utilizada: Mts calculados = Neps / 0.09',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          if (filtersDescription != null && filtersDescription.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Filtros aplicados: $filtersDescription',
                style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.SizedBox(height: 12),
          _pdfExecutiveSummary(
            records: records,
            summary: summary,
            criticalTelars: _analytics.countTelaresCriticos(records),
            worstTela: worstTela?.key,
            worstLote: worstLote?.key,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Tabla principal de registros',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 6),
          _pdfRecordsTable(records, selected),
          if (critical.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Alertas críticas',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            _pdfAlertTable(critical, records),
          ],
          if (topTelars.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Top 10 telares con más neps',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            _pdfGroupTable(
              ['Telar', 'Total neps', 'Promedio', 'Registros'],
              topTelars
                  .map(
                    (e) => [
                      e.key,
                      formatDecimal(e.totalNeps),
                      formatNumber(e.averageNeps),
                      '${e.recordCount}',
                    ],
                  )
                  .toList(),
            ),
          ],
          if (porTela.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Resumen por tela',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            _pdfGroupTable(
              ['Tela', 'Total neps', 'Promedio', 'Registros'],
              porTela
                  .map(
                    (e) => [
                      e.key,
                      formatDecimal(e.totalNeps),
                      formatNumber(e.averageNeps),
                      '${e.recordCount}',
                    ],
                  )
                  .toList(),
            ),
          ],
          if (porLote.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Resumen por lote/trama',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            _pdfGroupTable(
              ['Lote/trama', 'Total neps', 'Promedio', 'Registros'],
              porLote
                  .map(
                    (e) => [
                      e.key,
                      formatDecimal(e.totalNeps),
                      formatNumber(e.averageNeps),
                      '${e.recordCount}',
                    ],
                  )
                  .toList(),
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Recomendaciones automáticas',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            ...recommendations.map(
              (r) => pw.Bullet(text: r, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
          pw.SizedBox(height: 24),
          _pdfSignatureBlock(),
        ],
      ),
    );

    return doc.save();
  }

  /// Modo antiguo: encabezado, fórmula, tabla de registros y totales.
  Future<Uint8List> _buildClassicPdf({
    required List<NepRecord> records,
    required String title,
    String? filtersDescription,
    Set<ExportColumn>? columns,
  }) async {
    final selected = _columns(columns);
    final summary = summarize(records);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _pdfClassicHeader(title),
          pw.SizedBox(height: 14),
          pw.Text(
            'Formula utilizada: Mts calculados = Neps / $testLengthM',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          if (filtersDescription != null && filtersDescription.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Filtros aplicados: $filtersDescription',
                style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.SizedBox(height: 14),
          _pdfClassicTable(records, summary, selected),
          pw.SizedBox(height: 18),
          _pdfClassicSummaryBox(records, summary),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfClassicHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1F2A2E'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'VICUNHA  ',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TextSpan(
                  text: 'jeansidentity',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#F7EAC5'),
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
                color: PdfColor.fromHex('#CFD8C5'), fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfClassicTable(
    List<NepRecord> records,
    Map<String, double> summary,
    List<ExportColumn> columns,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: columns.map((column) => column.label).toList(),
      data: _classicTableRows(records, summary, columns),
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#9AA0A6'),
        width: 0.5,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#3C4043')),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      headerAlignment: pw.Alignment.center,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      cellAlignments: const {
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _pdfClassicSummaryBox(
    List<NepRecord> records,
    Map<String, double> summary,
  ) {
    return pw.Row(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EBDFC3'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Total registros: ${records.length}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Total neps: ${formatDecimal(summary['totalNeps']!)}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                'Promedio neps: ${formatNumber(summary['averageNeps']!)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        pw.Spacer(),
      ],
    );
  }

  pw.Widget _pdfHeader(String title, DateTime generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1F2A2E'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'VICUNHA — Sistema de Control de Calidad Textil',
            style: pw.TextStyle(
              color: PdfColor.fromHex('#F7EAC5'),
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(
                  color: PdfColor.fromHex('#CFD8C5'), fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado: ${_formatDate(generatedAt)}',
            style: pw.TextStyle(
                color: PdfColor.fromHex('#CFD8C5'), fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfExecutiveSummary({
    required List<NepRecord> records,
    required Map<String, double> summary,
    required int criticalTelars,
    String? worstTela,
    String? worstLote,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EBDFC3'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Resumen ejecutivo',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Text('Total registros: ${records.length}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Total neps: ${formatDecimal(summary['totalNeps']!)}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Promedio neps: ${formatNumber(summary['averageNeps']!)}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Telares críticos: $criticalTelars',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Tela más problemática: ${worstTela ?? '—'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Lote/trama más crítico: ${worstLote ?? '—'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfRecordsTable(
    List<NepRecord> records,
    List<ExportColumn> columns,
  ) {
    final headers = columns.map((c) => c.label).toList();
    final data = records.asMap().entries.map((entry) {
      return _dataRow(entry.value, entry.key, columns, records);
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F2A2E')),
      headerStyle: pw.TextStyle(
        color: PdfColor.fromHex('#F7EAC5'),
        fontWeight: pw.FontWeight.bold,
        fontSize: 7,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromHex('#D6C394'), width: 0.3),
        ),
      ),
    );
  }

  pw.Widget _pdfAlertTable(
    List<NepRecord> critical,
    List<NepRecord> all,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Fecha',
        'Telar',
        'Tela',
        'Lote',
        'Neps',
        'Estado',
        'Recomendación',
      ],
      data: critical
          .map(
            (r) => [
              _formatDate(r.createdAt),
              r.telar,
              r.tela,
              r.loteTrama,
              formatDecimal(r.neps),
              r.estadoAlerta,
              _recommendationFor(r, all),
            ],
          )
          .toList(),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#B94D4D')),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 7,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7),
    );
  }

  pw.Widget _pdfGroupTable(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F4E79')),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
    );
  }

  pw.Widget _pdfSignatureBlock() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 200,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
              height: 40,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Firma del supervisor',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Text(
          'VICUNHA — Control de calidad textil',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  String buildTabText(
    List<NepRecord> records, {
    Set<ExportColumn>? columns,
  }) {
    final selected = _columns(columns);
    final buffer = StringBuffer();
    buffer.writeln(selected.map((c) => c.label).join('\t'));

    for (int i = 0; i < records.length; i++) {
      buffer.writeln(_dataRow(records[i], i, selected, records).join('\t'));
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  String _formatDateOnly(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
