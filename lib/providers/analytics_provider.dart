import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/analytics_period.dart';
import '../models/analytics_summary.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../services/analytics_service.dart';

/// Caché de cálculos analíticos para evitar recomputar en cada build.
class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider({AnalyticsService? service})
      : _service = service ?? analyticsService;

  final AnalyticsService _service;
  Timer? _debounce;

  String? _summaryKey;
  AnalyticsSummary? _cachedSummary;

  AnalyticsSummary buildSummary(
    List<NepRecord> records,
    AnalyticsPeriod period, {
    RecordFilters? filters,
  }) {
    final key = _buildKey(records, period, filters);
    if (_summaryKey == key && _cachedSummary != null) {
      return _cachedSummary!;
    }
    _summaryKey = key;
    _cachedSummary = _service.buildSummary(records, period);
    return _cachedSummary!;
  }

  /// Invalida caché tras cambio de filtros con debounce.
  void scheduleInvalidate(
      {Duration delay = const Duration(milliseconds: 300)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, invalidate);
  }

  void invalidate() {
    _summaryKey = null;
    _cachedSummary = null;
    notifyListeners();
  }

  String _buildKey(
    List<NepRecord> records,
    AnalyticsPeriod period,
    RecordFilters? filters,
  ) {
    if (records.isEmpty) return 'empty_${period.name}';
    final newest = records
        .map((r) => r.createdAt.millisecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
    final filterHash = filters?.activeFilterCount ?? 0;
    return '${records.length}_${newest}_${period.name}_$filterHash';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
