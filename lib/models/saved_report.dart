import 'nep_record.dart';
import 'record_filters.dart';

class SavedReport {
  String id;
  String name;
  DateTime createdAt;
  List<NepRecord> records;
  RecordFilters? appliedFilters;

  /// Propietario del informe (quién lo guardó). Obligatorio para aislamiento local.
  String? createdByUid;

  SavedReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.records,
    this.appliedFilters,
    this.createdByUid,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'records': records.map((e) => e.toJson()).toList(),
      if (createdByUid != null && createdByUid!.isNotEmpty)
        'createdByUid': createdByUid,
      'appliedFilters': appliedFilters == null
          ? null
          : {
              'tela': appliedFilters!.tela,
              'loteTrama': appliedFilters!.loteTrama,
              'telar': appliedFilters!.telar,
              'nepsMin': appliedFilters!.nepsMin,
              'nepsMax': appliedFilters!.nepsMax,
              'mtsMin': appliedFilters!.mtsMin,
              'mtsMax': appliedFilters!.mtsMax,
              'dateFrom': appliedFilters!.dateFrom?.toIso8601String(),
              'dateTo': appliedFilters!.dateTo?.toIso8601String(),
              'searchText': appliedFilters!.searchText,
            },
    };
  }

  factory SavedReport.fromJson(Map<String, dynamic> json) {
    RecordFilters? filters;
    final rawFilters = json['appliedFilters'];
    if (rawFilters is Map) {
      try {
        final map = Map<String, dynamic>.from(rawFilters);
        filters = RecordFilters()
          ..tela = map['tela']?.toString()
          ..loteTrama = map['loteTrama']?.toString()
          ..telar = map['telar']?.toString()
          ..nepsMin = _toDouble(map['nepsMin'])
          ..nepsMax = _toDouble(map['nepsMax'])
          ..mtsMin = _toDouble(map['mtsMin'])
          ..mtsMax = _toDouble(map['mtsMax'])
          ..dateFrom = _toDate(map['dateFrom'])
          ..dateTo = _toDate(map['dateTo'])
          ..searchText = map['searchText']?.toString() ?? '';
      } catch (_) {
        filters = null;
      }
    }

    final records = <NepRecord>[];
    final rawRecords = json['records'];
    if (rawRecords is List) {
      for (final item in rawRecords) {
        if (item is! Map) continue;
        try {
          records.add(
            NepRecord.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Registro defectuoso: se omite; el informe sigue siendo usable.
        }
      }
    }

    return SavedReport(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Informe',
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      records: records,
      appliedFilters: filters,
      createdByUid: json['createdByUid']?.toString(),
    );
  }

  /// Parseo tolerante: null si el documento no es recuperable.
  static SavedReport? tryFromJson(Map<String, dynamic> json) {
    try {
      final report = SavedReport.fromJson(json);
      if (report.id.trim().isEmpty) return null;
      return report;
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
