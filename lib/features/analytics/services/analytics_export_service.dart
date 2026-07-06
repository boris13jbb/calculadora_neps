import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/alert_level.dart';
import '../../../models/analytics_period.dart';
import '../../../models/analytics_summary.dart';
import '../../../models/nep_record.dart';
import '../../../models/record_filters.dart';
import '../../../models/time_series_point.dart';
import '../../../services/report_export_service.dart';
import '../../../utils/analytics_filter_description.dart';
import '../../../utils/file_share_helper.dart';
import '../../../utils/record_filter_helper.dart';

/// Exportación de informes gráficos (CSV, Excel, PDF).
class AnalyticsExportService {
  AnalyticsExportService({
    ReportExportService? reportExport,
  }) : _reportExport = reportExport ?? ReportExportService();

  final ReportExportService _reportExport;

  String buildCsvText({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
  }) {
    final buffer = StringBuffer();
    final generatedAt = DateTime.now();
    final filterDesc = AnalyticsFilterDescription.describe(
      period: period,
      filters: filters,
    );

    buffer.writeln('Informe gráfico VICUNHA — Neps');
    buffer.writeln('Generado: ${_formatDateTime(generatedAt)}');
    buffer.writeln('Filtros: $filterDesc');
    buffer.writeln('Formula: Mts calculados = Neps / $testLengthM');
    buffer.writeln();

    buffer.writeln('RESUMEN KPI');
    buffer.writeln('Metrica,Valor');
    buffer.writeln('Total registros,${summary.totalRecords}');
    buffer.writeln(
        'Total neps,${_reportExport.formatDecimal(summary.totalNeps)}');
    buffer.writeln(
      'Promedio neps,${_reportExport.formatNumber(summary.averageNeps)}',
    );
    buffer
        .writeln('Minimo neps,${_reportExport.formatDecimal(summary.minNeps)}');
    buffer
        .writeln('Maximo neps,${_reportExport.formatDecimal(summary.maxNeps)}');
    buffer.writeln(
      'Total mts calculados,${_reportExport.formatDecimal(summary.totalMts)}',
    );
    buffer.writeln('Alertas normales,${summary.normalCount}');
    buffer.writeln('Advertencias,${summary.warningCount}');
    buffer.writeln('Criticos,${summary.criticalCount}');
    buffer.writeln(
      'Porcentaje normales,${summary.normalPercentage.toStringAsFixed(1)}%',
    );
    buffer.writeln(
      'Porcentaje criticos,${summary.criticalPercentage.toStringAsFixed(1)}%',
    );
    if (summary.averageNepsPerTelar != null) {
      buffer.writeln(
        'Promedio neps por telar,${_reportExport.formatNumber(summary.averageNepsPerTelar!)}',
      );
    }
    if (summary.averageNepsPerTurno != null) {
      buffer.writeln(
        'Promedio neps por turno,${_reportExport.formatNumber(summary.averageNepsPerTurno!)}',
      );
    }
    buffer.writeln();

    _writeSeriesCsv(buffer, 'TENDENCIA (${period.label})', summary.timeSeries);
    _writeGroupCsv(buffer, 'POR TELAR', summary.byTelar);
    _writeGroupCsv(buffer, 'POR TURNO', summary.byTurno);
    _writeGroupCsv(buffer, 'POR OPERARIO', summary.byOperario);

    buffer.writeln();
    buffer.writeln('REGISTROS BASE');
    buffer.writeln(_reportExport.buildCsvText(records));

    return buffer.toString();
  }

  void _writeSeriesCsv(
    StringBuffer buffer,
    String title,
    List<TimeSeriesPoint> series,
  ) {
    buffer.writeln(title);
    buffer.writeln('Periodo,Registros,Total neps,Promedio neps,Total mts');
    for (final point in series) {
      buffer.writeln(
        '${_reportExport.escapeCsv(point.label)},'
        '${point.recordCount},'
        '${_reportExport.formatDecimal(point.totalNeps)},'
        '${_reportExport.formatNumber(point.averageNeps)},'
        '${_reportExport.formatDecimal(point.totalMts)}',
      );
    }
    buffer.writeln();
  }

  void _writeGroupCsv(
    StringBuffer buffer,
    String title,
    List<dynamic> groups,
  ) {
    if (groups.isEmpty) return;
    buffer.writeln(title);
    buffer.writeln(
        'Grupo,Registros,Total neps,Promedio neps,Criticos,Advertencias');
    for (final group in groups) {
      buffer.writeln(
        '${_reportExport.escapeCsv(group.key)},'
        '${group.recordCount},'
        '${_reportExport.formatDecimal(group.totalNeps)},'
        '${_reportExport.formatNumber(group.averageNeps)},'
        '${group.criticalCount},'
        '${group.warningCount}',
      );
    }
    buffer.writeln();
  }

  Future<Uint8List> buildExcelBytes({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
  }) async {
    final excel = xls.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    _buildSummarySheet(excel, summary, period, filters);
    _buildTrendSheet(excel, summary.timeSeries, period);
    _buildGroupSheet(excel, 'Por telar', summary.byTelar);
    _buildGroupSheet(excel, 'Por turno', summary.byTurno);
    _buildGroupSheet(excel, 'Por operario', summary.byOperario);
    await _buildRecordsSheet(excel, records);

    final bytes = excel.encode();
    if (bytes == null) {
      throw const ExportException('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  void _buildSummarySheet(
    xls.Excel excel,
    AnalyticsSummary summary,
    AnalyticsPeriod period,
    RecordFilters filters,
  ) {
    const name = 'Resumen';
    final sheet = excel[name];
    final filterDesc = AnalyticsFilterDescription.describe(
      period: period,
      filters: filters,
    );
    final rows = <List<String>>[
      ['Informe gráfico VICUNHA — Neps'],
      ['Generado', _formatDateTime(DateTime.now())],
      ['Agrupación', period.label],
      ['Filtros', filterDesc],
      ['Formula', 'Mts calculados = Neps / $testLengthM'],
      [],
      ['Indicador', 'Valor'],
      ['Total registros', '${summary.totalRecords}'],
      ['Total neps', _reportExport.formatDecimal(summary.totalNeps)],
      ['Promedio neps', _reportExport.formatNumber(summary.averageNeps)],
      ['Minimo neps', _reportExport.formatDecimal(summary.minNeps)],
      ['Maximo neps', _reportExport.formatDecimal(summary.maxNeps)],
      ['Total mts calculados', _reportExport.formatDecimal(summary.totalMts)],
      ['Alertas normales', '${summary.normalCount}'],
      ['Advertencias', '${summary.warningCount}'],
      ['Criticos', '${summary.criticalCount}'],
      [
        'Porcentaje normales',
        '${summary.normalPercentage.toStringAsFixed(1)}%',
      ],
      [
        'Porcentaje criticos',
        '${summary.criticalPercentage.toStringAsFixed(1)}%',
      ],
      if (summary.averageNepsPerTelar != null)
        [
          'Promedio neps por telar',
          _reportExport.formatNumber(summary.averageNepsPerTelar!),
        ],
      if (summary.averageNepsPerTurno != null)
        [
          'Promedio neps por turno',
          _reportExport.formatNumber(summary.averageNepsPerTurno!),
        ],
    ];

    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = xls.TextCellValue(rows[r][c]);
      }
    }
  }

  void _buildTrendSheet(
    xls.Excel excel,
    List<TimeSeriesPoint> series,
    AnalyticsPeriod period,
  ) {
    final sheet = excel['Datos agrupados'];
    final headers = [
      'Periodo (${period.label})',
      'Registros',
      'Total neps',
      'Promedio neps',
      'Total mts',
    ];
    _writeExcelHeader(sheet, headers);

    for (var i = 0; i < series.length; i++) {
      final point = series[i];
      final row = i + 1;
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = xls.TextCellValue(point.label);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = xls.IntCellValue(point.recordCount);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = xls.DoubleCellValue(point.totalNeps);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = xls.DoubleCellValue(point.averageNeps);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = xls.DoubleCellValue(point.totalMts);
    }
  }

  void _buildGroupSheet(
    xls.Excel excel,
    String name,
    List<dynamic> groups,
  ) {
    if (groups.isEmpty) return;
    final sheet = excel[name];
    const headers = [
      'Grupo',
      'Registros',
      'Total neps',
      'Promedio neps',
      'Criticos',
      'Advertencias',
    ];
    _writeExcelHeader(sheet, headers);

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final row = i + 1;
      final values = [
        group.key,
        group.recordCount,
        group.totalNeps,
        group.averageNeps,
        group.criticalCount,
        group.warningCount,
      ];
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
        );
        final value = values[c];
        if (value is num) {
          cell.value = xls.DoubleCellValue(value.toDouble());
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
      }
    }
  }

  Future<void> _buildRecordsSheet(
    xls.Excel excel,
    List<NepRecord> records,
  ) async {
    final sheet = excel['Registros base'];
    final sorted = RecordFilterHelper.sortForReport(records);
    const headers = [
      'Fecha',
      'Telar',
      'Tela',
      'Lote/trama',
      'Neps',
      'Mts calculados',
      'Turno',
      'Operario',
    ];
    _writeExcelHeader(sheet, headers);
    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final row = i + 1;
      final values = [
        _formatDateTime(item.createdAt),
        item.telar,
        item.tela,
        item.loteTrama,
        item.neps,
        item.mtsCalculados,
        item.turno,
        item.operario,
      ];
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
        );
        final value = values[c];
        if (value is num) {
          cell.value = xls.DoubleCellValue(value.toDouble());
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
      }
    }
  }

  void _writeExcelHeader(xls.Sheet sheet, List<String> headers) {
    final style = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#1F2A2E'),
      fontColorHex: xls.ExcelColor.fromHexString('#F7EAC5'),
    );
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = xls.TextCellValue(headers[i]);
      cell.cellStyle = style;
    }
  }

  Future<Uint8List> buildPdfBytes({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
    Uint8List? chartsImagePng,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/OpenSans-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final doc = pw.Document(theme: theme);
    final generatedAt = DateTime.now();
    final filterDesc = AnalyticsFilterDescription.describe(
      period: period,
      filters: filters,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Informe gráfico — Control de Neps VICUNHA',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Generado: ${_formatDateTime(generatedAt)}'),
          pw.Text('Agrupación: ${period.label}'),
          pw.Text('Filtros: $filterDesc'),
          pw.Text('Formula: Mts calculados = Neps / $testLengthM'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Indicadores clave',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Indicador', 'Valor'],
            data: [
              ['Total registros', '${summary.totalRecords}'],
              ['Total neps', _reportExport.formatDecimal(summary.totalNeps)],
              [
                'Promedio neps',
                _reportExport.formatNumber(summary.averageNeps),
              ],
              ['Minimo neps', _reportExport.formatDecimal(summary.minNeps)],
              ['Maximo neps', _reportExport.formatDecimal(summary.maxNeps)],
              [
                'Total mts calculados',
                _reportExport.formatDecimal(summary.totalMts),
              ],
              ['Alertas normales', '${summary.normalCount}'],
              ['Advertencias', '${summary.warningCount}'],
              ['Criticos', '${summary.criticalCount}'],
              [
                'Porcentaje normales',
                '${summary.normalPercentage.toStringAsFixed(1)}%',
              ],
              [
                'Porcentaje criticos',
                '${summary.criticalPercentage.toStringAsFixed(1)}%',
              ],
              if (summary.averageNepsPerTelar != null)
                [
                  'Promedio neps por telar',
                  _reportExport.formatNumber(summary.averageNepsPerTelar!),
                ],
              if (summary.averageNepsPerTurno != null)
                [
                  'Promedio neps por turno',
                  _reportExport.formatNumber(summary.averageNepsPerTurno!),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          if (chartsImagePng != null && chartsImagePng.isNotEmpty) ...[
            pw.Text(
              'Visualización gráfica',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(chartsImagePng),
                fit: pw.BoxFit.contain,
                height: 280,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Text(
            'Tendencia (${period.label})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (summary.timeSeries.isEmpty)
            pw.Text('Sin datos para el periodo seleccionado.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Periodo',
                'Registros',
                'Total neps',
                'Promedio',
                'Total mts',
              ],
              data: summary.timeSeries
                  .map(
                    (p) => [
                      p.label,
                      '${p.recordCount}',
                      _reportExport.formatDecimal(p.totalNeps),
                      _reportExport.formatNumber(p.averageNeps),
                      _reportExport.formatDecimal(p.totalMts),
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Distribución de alertas',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Estado', 'Cantidad', 'Porcentaje'],
            data: [
              [
                'Normal',
                '${summary.normalCount}',
                '${summary.normalPercentage.toStringAsFixed(1)}%',
              ],
              [
                'Advertencia',
                '${summary.warningCount}',
                '${summary.alertDistribution.percentage(AlertLevel.advertencia).toStringAsFixed(1)}%',
              ],
              [
                'Critico',
                '${summary.criticalCount}',
                '${summary.criticalPercentage.toStringAsFixed(1)}%',
              ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Observaciones',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Informe generado desde la pantalla de Gráficas. '
            'Los metros calculados aplican la formula oficial Neps / $testLengthM. '
            'Revise telares y turnos con mayor concentración de neps para acciones correctivas.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareCsv({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
    required String fileTimestamp,
  }) async {
    final text = buildCsvText(
      summary: summary,
      records: records,
      period: period,
      filters: filters,
    );
    await FileShareHelper.shareTextContent(
      content: text,
      fileName: 'graficas_neps_$fileTimestamp.csv',
      mimeType: 'text/csv',
      shareText: 'Informe gráfico CSV — Neps VICUNHA',
      bom: true,
    );
  }

  Future<void> shareExcel({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
    required String fileTimestamp,
  }) async {
    final bytes = await buildExcelBytes(
      summary: summary,
      records: records,
      period: period,
      filters: filters,
    );
    await FileShareHelper.shareBytes(
      bytes: bytes,
      fileName: 'graficas_neps_$fileTimestamp.xlsx',
      mimeType: FileShareHelper.excelMimeType,
    );
  }

  Future<void> sharePdf({
    required AnalyticsSummary summary,
    required List<NepRecord> records,
    required AnalyticsPeriod period,
    required RecordFilters filters,
    required String fileTimestamp,
    Uint8List? chartsImagePng,
  }) async {
    final bytes = await buildPdfBytes(
      summary: summary,
      records: records,
      period: period,
      filters: filters,
      chartsImagePng: chartsImagePng,
    );
    await FileShareHelper.shareBytes(
      bytes: bytes,
      fileName: 'graficas_neps_$fileTimestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  Future<void> shareChartsPng({
    required Uint8List pngBytes,
    required String fileTimestamp,
  }) async {
    if (pngBytes.isEmpty) {
      throw const ExportException(
        'No se pudo capturar la imagen de las gráficas.',
      );
    }
    await FileShareHelper.shareBytes(
      bytes: pngBytes,
      fileName: 'graficas_neps_$fileTimestamp.png',
      mimeType: 'image/png',
      shareText: 'Gráficas Neps VICUNHA',
    );
  }

  String _formatDateTime(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

final AnalyticsExportService analyticsExportService = AnalyticsExportService();
