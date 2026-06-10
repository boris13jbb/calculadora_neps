import 'nep_record.dart';
import 'record_filters.dart';

class SavedReport {
  String id;
  String name;
  DateTime createdAt;
  List<NepRecord> records;
  RecordFilters? appliedFilters;

  SavedReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.records,
    this.appliedFilters,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'records': records.map((e) => e.toJson()).toList(),
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
      filters = RecordFilters()
        ..tela = rawFilters['tela']?.toString()
        ..loteTrama = rawFilters['loteTrama']?.toString()
        ..telar = rawFilters['telar']?.toString()
        ..nepsMin = _toDouble(rawFilters['nepsMin'])
        ..nepsMax = _toDouble(rawFilters['nepsMax'])
        ..mtsMin = _toDouble(rawFilters['mtsMin'])
        ..mtsMax = _toDouble(rawFilters['mtsMax'])
        ..dateFrom = _toDate(rawFilters['dateFrom'])
        ..dateTo = _toDate(rawFilters['dateTo'])
        ..searchText = rawFilters['searchText']?.toString() ?? '';
    }

    final List recordsJson = json['records'] as List? ?? [];
    return SavedReport(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Informe',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      records: recordsJson
          .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      appliedFilters: filters,
    );
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
