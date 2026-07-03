import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/export_column.dart';
import '../models/pdf_report_style.dart';
import '../models/saved_report.dart';
import '../services/report_export_service.dart';
import '../utils/file_share_helper.dart';
import '../utils/filter_description_helper.dart';

enum ReportShareFormat { csv, excel, pdf }

class ReportShareHelper {
  ReportShareHelper(this.exportService);

  final ReportExportService exportService;

  Future<List<PreparedShareFile>> buildShareFiles({
    required List<SavedReport> reports,
    required Set<ReportShareFormat> formats,
    Set<ExportColumn>? columns,
    PdfReportStyle reportStyle = PdfReportStyle.completo,
  }) async {
    final selected = columns ?? ExportColumn.defaultSelection();
    final files = <PreparedShareFile>[];

    for (final report in reports) {
      final safeName = _safeFileName(report.name);
      final stamp = report.createdAt.millisecondsSinceEpoch;

      if (formats.contains(ReportShareFormat.csv)) {
        final content = exportService.buildCsvText(
          report.records,
          columns: selected,
          style: reportStyle,
        );
        final fileName = '${safeName}_$stamp.csv';
        files.add(
          PreparedShareFile(
            fileName: fileName,
            file: XFile.fromData(
              Uint8List.fromList(utf8.encode('\uFEFF$content')),
              mimeType: 'text/csv',
              name: fileName,
            ),
          ),
        );
      }

      if (formats.contains(ReportShareFormat.excel)) {
        final bytes = exportService.buildExcelBytes(
          report.records,
          columns: selected,
          style: reportStyle,
        );
        if (bytes != null) {
          final fileName = '${safeName}_$stamp.xlsx';
          files.add(
            PreparedShareFile(
              fileName: fileName,
              file: XFile.fromData(
                bytes,
                mimeType: FileShareHelper.excelMimeType,
                name: fileName,
              ),
            ),
          );
        }
      }

      if (formats.contains(ReportShareFormat.pdf)) {
        final bytes = await exportService.buildPdfBytes(
          records: report.records,
          title: report.name,
          columns: selected,
          style: reportStyle,
          filtersDescription: report.appliedFilters == null
              ? null
              : FilterDescriptionHelper.describe(report.appliedFilters!),
        );
        final fileName = '${safeName}_$stamp.pdf';
        files.add(
          PreparedShareFile(
            fileName: fileName,
            file: XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: fileName,
            ),
          ),
        );
      }
    }

    return files;
  }

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'informe' : cleaned;
  }
}
