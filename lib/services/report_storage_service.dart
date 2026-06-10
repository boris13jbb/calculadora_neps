import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../models/saved_report.dart';
import 'cloud_sync_port.dart';
import 'report_export_service.dart';

class ReportStorageService {
  ReportStorageService({
    CloudSyncPort? cloudSync,
    ReportExportService? exportService,
  })  : _cloudSync = cloudSync,
        exportService = exportService ?? ReportExportService();

  CloudSyncPort? _cloudSync;
  final ReportExportService exportService;

  void attachCloudSync(CloudSyncPort? cloudSync) {
    _cloudSync = cloudSync;
  }

  Future<List<SavedReport>> loadReports() async {
    final cloudSync = _cloudSync;
    if (cloudSync != null) {
      return cloudSync.fetchReports();
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(savedReportsStorageKey);
    if (saved == null || saved.isEmpty) return [];

    try {
      final List decoded = jsonDecode(saved);
      return decoded
          .map((item) => SavedReport.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistReportsLocally(List<SavedReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final data = reports.map((report) => report.toJson()).toList();
    await prefs.setString(savedReportsStorageKey, jsonEncode(data));
  }

  Future<SavedReport> saveReport({
    required String name,
    required List<NepRecord> records,
    RecordFilters? appliedFilters,
    bool saveFiles = true,
  }) async {
    final report = SavedReport(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
      records: records
          .map(
            (record) => NepRecord(
              id: record.id,
              telar: record.telar,
              neps: record.neps,
              tela: record.tela,
              loteTrama: record.loteTrama,
              createdAt: record.createdAt,
            ),
          )
          .toList(),
      appliedFilters: appliedFilters?.copy(),
    );

    final cloudSync = _cloudSync;
    if (cloudSync != null) {
      return cloudSync.saveReport(report);
    }

    final reports = await loadReports();
    reports.insert(0, report);
    await _persistReportsLocally(reports);

    if (saveFiles && !kIsWeb) {
      await _saveReportFiles(report);
    }

    return report;
  }

  Future<void> deleteReport(String id) async {
    final cloudSync = _cloudSync;
    if (cloudSync != null) {
      await cloudSync.deleteReport(id);
      return;
    }

    final reports = await loadReports();
    reports.removeWhere((report) => report.id == id);
    await _persistReportsLocally(reports);
  }

  Future<Directory> getReportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/informes');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  Future<void> _saveReportFiles(SavedReport report) async {
    final dir = await getReportsDirectory();
    final safeName = _safeFileName(report.name);
    final stamp = _fileStamp(report.createdAt);

    final excelBytes = exportService.buildExcelBytes(report.records);
    if (excelBytes != null) {
      final excelFile = File('${dir.path}/${safeName}_$stamp.xlsx');
      await excelFile.writeAsBytes(excelBytes, flush: true);
    }

    final csvFile = File('${dir.path}/${safeName}_$stamp.csv');
    await csvFile.writeAsString(
      '\uFEFF${exportService.buildCsvText(report.records)}',
      encoding: utf8,
    );

    final pdfBytes = await exportService.buildPdfBytes(
      records: report.records,
      title: report.name,
    );
    final pdfFile = File('${dir.path}/${safeName}_$stamp.pdf');
    await pdfFile.writeAsBytes(pdfBytes, flush: true);
  }

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'informe' : cleaned;
  }

  String _fileStamp(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_${two(date.hour)}${two(date.minute)}';
  }
}
