import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../core/errors/app_exception.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../utils/file_share_helper.dart';
import 'report_export_service.dart';

/// Orquesta exportación e impresión de registros de neps.
///
/// Centraliza CSV, Excel, PDF e impresión. Permisos, estado de carga y
/// selección de columnas permanecen en [AppState].
class RecordExportCoordinator {
  RecordExportCoordinator({ReportExportService? exportService})
      : _exportService = exportService ?? ReportExportService();

  final ReportExportService _exportService;

  Future<void> shareCsv({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
  }) async {
    await FileShareHelper.shareTextContent(
      content: _exportService.buildCsvText(
        records,
        columns: columns,
        style: style,
      ),
      fileName: 'reporte_neps_$fileTimestamp.csv',
      mimeType: 'text/csv',
      shareText: 'Reporte CSV de Neps',
      bom: true,
    );
  }

  Future<void> shareExcel({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
  }) async {
    final bytes = _exportService.buildExcelBytes(
      records,
      columns: columns,
      style: style,
    );
    if (bytes == null) {
      throw const ExportException('No se pudo generar el archivo Excel.');
    }
    await FileShareHelper.shareBytes(
      bytes: bytes,
      fileName: 'reporte_neps_$fileTimestamp.xlsx',
      mimeType: FileShareHelper.excelMimeType,
      shareText: 'Reporte Excel de Neps',
    );
  }

  Future<Uint8List> buildPdfBytes({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    String? filtersDescription,
  }) {
    return _exportService.buildPdfBytes(
      records: records,
      columns: columns,
      style: style,
      filtersDescription: filtersDescription,
    );
  }

  Future<void> sharePdf({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    required String fileTimestamp,
    String? filtersDescription,
  }) async {
    final bytes = await buildPdfBytes(
      records: records,
      columns: columns,
      style: style,
      filtersDescription: filtersDescription,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'reporte_neps_$fileTimestamp.pdf',
    );
  }

  Future<void> printPdf({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
    required PdfReportStyle style,
    String? filtersDescription,
  }) async {
    await Printing.layoutPdf(
      name: 'Reporte Neps VICUNHA',
      onLayout: (_) => buildPdfBytes(
        records: records,
        columns: columns,
        style: style,
        filtersDescription: filtersDescription,
      ),
    );
  }

  String buildTabText({
    required List<NepRecord> records,
    required Set<ExportColumn> columns,
  }) {
    return _exportService.buildTabText(records, columns: columns);
  }
}
