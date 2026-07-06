import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_level.dart';
import '../models/analytics_period.dart';
import '../models/record_filters.dart';
import '../features/analytics/models/chart_config.dart';

/// Persiste periodo y filtros de la pantalla Gráficas entre sesiones.
class AnalyticsPreferencesService {
  AnalyticsPreferencesService({SharedPreferences? prefs}) : _prefs = prefs;

  static const storageKey = 'vicunha_analytics_prefs_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> save({
    required AnalyticsPeriod period,
    required RecordFilters filters,
    ChartConfig? chartConfig,
  }) async {
    final prefs = await _ensurePrefs();
    final payload = jsonEncode({
      'period': period.name,
      'filters': _filtersToMap(filters),
      if (chartConfig != null) 'chartConfig': chartConfig.toJson(),
    });
    await prefs.setString(storageKey, payload);
  }

  Future<AnalyticsPreferencesSnapshot?> load() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final periodName = map['period'] as String?;
      final filtersMap = map['filters'] as Map<String, dynamic>?;
      if (periodName == null || filtersMap == null) return null;

      AnalyticsPeriod? period;
      for (final candidate in AnalyticsPeriod.values) {
        if (candidate.name == periodName) {
          period = candidate;
          break;
        }
      }
      if (period == null) return null;

      ChartConfig? chartConfig;
      final chartMap = map['chartConfig'];
      if (chartMap is Map<String, dynamic>) {
        chartConfig = ChartConfig.fromJson(chartMap);
      }

      return AnalyticsPreferencesSnapshot(
        period: period,
        filters: _filtersFromMap(filtersMap),
        chartConfig: chartConfig,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(storageKey);
  }

  Map<String, dynamic> _filtersToMap(RecordFilters filters) {
    return {
      'tela': filters.tela,
      'loteTrama': filters.loteTrama,
      'telar': filters.telar,
      'nepsMin': filters.nepsMin,
      'nepsMax': filters.nepsMax,
      'mtsMin': filters.mtsMin,
      'mtsMax': filters.mtsMax,
      'dateFrom': filters.dateFrom?.toIso8601String(),
      'dateTo': filters.dateTo?.toIso8601String(),
      'searchText': filters.searchText,
      'alertLevel': filters.alertLevel?.name,
      'turno': filters.turno,
      'operario': filters.operario,
      'lineaProduccion': filters.lineaProduccion,
      'soloNoRevisados': filters.soloNoRevisados,
      'soloConAccionCorrectiva': filters.soloConAccionCorrectiva,
      'quickRange': filters.quickRange?.name,
    };
  }

  RecordFilters _filtersFromMap(Map<String, dynamic> map) {
    final filters = RecordFilters();
    filters.tela = map['tela'] as String?;
    filters.loteTrama = map['loteTrama'] as String?;
    filters.telar = map['telar'] as String?;
    filters.nepsMin = (map['nepsMin'] as num?)?.toDouble();
    filters.nepsMax = (map['nepsMax'] as num?)?.toDouble();
    filters.mtsMin = (map['mtsMin'] as num?)?.toDouble();
    filters.mtsMax = (map['mtsMax'] as num?)?.toDouble();
    filters.dateFrom = _parseDate(map['dateFrom']);
    filters.dateTo = _parseDate(map['dateTo']);
    filters.searchText = map['searchText'] as String? ?? '';
    filters.alertLevel = _parseAlertLevel(map['alertLevel']);
    filters.turno = map['turno'] as String?;
    filters.operario = map['operario'] as String?;
    filters.lineaProduccion = map['lineaProduccion'] as String?;
    filters.soloNoRevisados = map['soloNoRevisados'] == true;
    filters.soloConAccionCorrectiva = map['soloConAccionCorrectiva'] == true;
    filters.quickRange = _parseQuickRange(map['quickRange']);
    return filters;
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  AlertLevel? _parseAlertLevel(Object? value) {
    if (value is! String) return null;
    for (final level in AlertLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  DateQuickRange? _parseQuickRange(Object? value) {
    if (value is! String) return null;
    for (final range in DateQuickRange.values) {
      if (range.name == value) return range;
    }
    return null;
  }
}

class AnalyticsPreferencesSnapshot {
  const AnalyticsPreferencesSnapshot({
    required this.period,
    required this.filters,
    this.chartConfig,
  });

  final AnalyticsPeriod period;
  final RecordFilters filters;
  final ChartConfig? chartConfig;
}

final AnalyticsPreferencesService analyticsPreferencesService =
    AnalyticsPreferencesService();
