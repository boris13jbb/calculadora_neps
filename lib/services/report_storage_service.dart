import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/errors/error_handler.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../models/record_filters.dart';
import '../models/saved_report.dart';
import '../utils/firebase_session_helper.dart';
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
    final local = await _loadReportsLocally();
    final cloudSync = _cloudSync;
    if (cloudSync == null || !isFirebaseSessionActive) return local;

    try {
      await cloudSync.bootstrap();
      await migrateLocalReportsIfNeeded();
      final remote = await cloudSync.fetchReports();
      final merged = _mergeReports(local, remote);
      await _persistReportsLocally(merged);
      return merged;
    } catch (error, stackTrace) {
      if (!isCloudAuthSkipError(error)) {
        ErrorHandler.log(error, stackTrace, 'loadReportsFirebase');
      }
      if (local.isEmpty) rethrow;
    }

    return local;
  }

  /// Sube informes locales a Firestore la primera vez que hay nube disponible.
  Future<void> migrateLocalReportsIfNeeded() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(cloudReportsMigrationKey) == true) return;

    final local = await _loadReportsLocally();
    if (local.isEmpty) {
      await prefs.setBool(cloudReportsMigrationKey, true);
      return;
    }

    for (final report in local) {
      try {
        await cloudSync.saveReport(report);
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'migrateReport');
        return;
      }
    }

    await prefs.setBool(cloudReportsMigrationKey, true);
  }

  List<SavedReport> _mergeReports(
    List<SavedReport> local,
    List<SavedReport> remote,
  ) {
    final byId = <String, SavedReport>{};
    for (final report in local) {
      byId[report.id] = report;
    }
    for (final report in remote) {
      final existing = byId[report.id];
      if (existing == null || !report.createdAt.isBefore(existing.createdAt)) {
        byId[report.id] = report;
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<SavedReport>> _loadReportsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(savedReportsStorageKey);
    if (saved == null || saved.isEmpty) return [];

    try {
      final List decoded = jsonDecode(saved);
      return decoded
          .map((item) => SavedReport.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'loadReportsLocally');
      return [];
    }
  }

  Future<void> _persistReportsLocally(List<SavedReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final data = reports.map((report) => report.toJson()).toList();
    await prefs.setString(savedReportsStorageKey, jsonEncode(data));
  }

  Future<void> _upsertReportLocally(SavedReport report) async {
    final reports = await _loadReportsLocally();
    reports.removeWhere((item) => item.id == report.id);
    reports.insert(0, report);
    await _persistReportsLocally(reports);
  }

  Future<void> _removeReportLocally(String id) async {
    final reports = await _loadReportsLocally();
    reports.removeWhere((report) => report.id == id);
    await _persistReportsLocally(reports);
  }

  Future<SavedReport> saveReport({
    required String name,
    required List<NepRecord> records,
    RecordFilters? appliedFilters,
    bool saveFiles = true,
    PdfReportStyle exportStyle = PdfReportStyle.completo,
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
      try {
        final saved = await cloudSync.saveReport(report);
        await _upsertReportLocally(saved);
        return saved;
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'saveReportFirebase');
      }
    }

    await _upsertReportLocally(report);

    if (saveFiles && !kIsWeb) {
      await _saveReportFiles(report, exportStyle: exportStyle);
    }

    return report;
  }

  Future<void> deleteReport(String id) async {
    final cloudSync = _cloudSync;
    if (cloudSync != null) {
      try {
        await cloudSync.deleteReport(id);
        await _removeReportLocally(id);
        return;
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'deleteReportFirebase');
      }
    }

    await _removeReportLocally(id);
  }

  Future<Directory> getReportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/informes');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  Future<void> _saveReportFiles(
    SavedReport report, {
    PdfReportStyle exportStyle = PdfReportStyle.completo,
  }) async {
    final dir = await getReportsDirectory();
    final safeName = _safeFileName(report.name);
    final stamp = _fileStamp(report.createdAt);

    final excelBytes = exportService.buildExcelBytes(
      report.records,
      style: exportStyle,
    );
    if (excelBytes != null) {
      final excelFile = File('${dir.path}/${safeName}_$stamp.xlsx');
      await excelFile.writeAsBytes(excelBytes, flush: true);
    }

    final csvFile = File('${dir.path}/${safeName}_$stamp.csv');
    await csvFile.writeAsString(
      '\uFEFF${exportService.buildCsvText(report.records, style: exportStyle)}',
      encoding: utf8,
    );

    final pdfBytes = await exportService.buildPdfBytes(
      records: report.records,
      title: report.name,
      style: exportStyle,
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
