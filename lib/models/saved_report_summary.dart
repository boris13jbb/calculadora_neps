import 'nep_record.dart';
import 'saved_report.dart';

/// Metadata ligera de un informe guardado (sin `records[]`).
///
/// Persistido en `workspaces/{id}/reportSummaries/{reportId}`.
/// Compatible con documentos parciales/legacy (campos opcionales ausentes).
class SavedReportSummary {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final int recordCount;
  final DateTime? recordsCreatedAtMin;
  final DateTime? recordsCreatedAtMax;

  const SavedReportSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.recordCount,
    this.updatedAt,
    this.createdByUid,
    this.recordsCreatedAtMin,
    this.recordsCreatedAtMax,
  });

  /// Calcula metadata desde [SavedReport.records] (mismo eje temporal: createdAt).
  factory SavedReportSummary.fromSavedReport(
    SavedReport report, {
    DateTime? updatedAt,
  }) {
    final records = report.records;
    if (records.isEmpty) {
      return SavedReportSummary(
        id: report.id,
        name: report.name,
        createdAt: report.createdAt,
        updatedAt: updatedAt,
        createdByUid: report.createdByUid,
        recordCount: 0,
        recordsCreatedAtMin: null,
        recordsCreatedAtMax: null,
      );
    }

    DateTime min = records.first.createdAt;
    DateTime max = records.first.createdAt;
    for (final NepRecord record in records.skip(1)) {
      if (record.createdAt.isBefore(min)) min = record.createdAt;
      if (record.createdAt.isAfter(max)) max = record.createdAt;
    }

    return SavedReportSummary(
      id: report.id,
      name: report.name,
      createdAt: report.createdAt,
      updatedAt: updatedAt,
      createdByUid: report.createdByUid,
      recordCount: records.length,
      recordsCreatedAtMin: min,
      recordsCreatedAtMax: max,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'recordCount': recordCount,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (createdByUid != null && createdByUid!.isNotEmpty)
        'createdByUid': createdByUid,
      if (recordsCreatedAtMin != null)
        'recordsCreatedAtMin': recordsCreatedAtMin!.toIso8601String(),
      if (recordsCreatedAtMax != null)
        'recordsCreatedAtMax': recordsCreatedAtMax!.toIso8601String(),
    };
  }

  factory SavedReportSummary.fromJson(Map<String, dynamic> json) {
    return SavedReportSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Informe',
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(json['updatedAt']),
      createdByUid: json['createdByUid']?.toString(),
      recordCount: _toInt(json['recordCount']) ?? 0,
      recordsCreatedAtMin: _toDate(json['recordsCreatedAtMin']),
      recordsCreatedAtMax: _toDate(json['recordsCreatedAtMax']),
    );
  }

  /// Parseo tolerante: null si el documento no es recuperable.
  static SavedReportSummary? tryFromJson(Map<String, dynamic> json) {
    try {
      final summary = SavedReportSummary.fromJson(json);
      if (summary.id.trim().isEmpty) return null;
      return summary;
    } catch (_) {
      return null;
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
