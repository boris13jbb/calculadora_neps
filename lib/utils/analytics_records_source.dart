import '../models/analytics_period.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../models/saved_report.dart';
import '../services/analytics_service.dart';
import 'record_filter_helper.dart';

/// Origen de datos unificado para la pantalla de gráficas.
class AnalyticsRecordsSource {
  const AnalyticsRecordsSource({
    required this.records,
    required this.liveRecordCount,
    required this.savedReportCount,
    required this.savedReportRecordCount,
  });

  final List<NepRecord> records;
  final int liveRecordCount;
  final int savedReportCount;
  final int savedReportRecordCount;

  int get totalSourceRecords => liveRecordCount + savedReportRecordCount;

  bool get hasAnyData => records.isNotEmpty;

  String describe() {
    if (savedReportCount == 0 && liveRecordCount == 0) {
      return 'Sin registros ni informes guardados';
    }
    if (savedReportCount == 0) {
      return '$liveRecordCount registros actuales';
    }
    if (liveRecordCount == 0) {
      return '${records.length} registros de $savedReportCount informes guardados';
    }
    return '${records.length} registros '
        '($liveRecordCount actuales + $savedReportRecordCount en informes)';
  }
}

/// Combina registros en vivo con los de todos los informes guardados (sin duplicar por id).
AnalyticsRecordsSource buildAnalyticsRecordsSource({
  required List<NepRecord> liveRecords,
  required List<SavedReport> savedReports,
}) {
  final byId = <String, NepRecord>{};
  var savedReportRecordCount = 0;

  for (final record in liveRecords) {
    byId[record.id] = record;
  }

  for (final report in savedReports) {
    for (final record in report.records) {
      savedReportRecordCount++;
      byId.putIfAbsent(record.id, () => record);
    }
  }

  final merged = byId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return AnalyticsRecordsSource(
    records: merged,
    liveRecordCount: liveRecords.length,
    savedReportCount: savedReports.length,
    savedReportRecordCount: savedReportRecordCount,
  );
}

/// Aplica filtros de registro y el periodo analítico de forma coherente.
List<NepRecord> applyAnalyticsFilters({
  required List<NepRecord> records,
  required RecordFilters filters,
  required AnalyticsPeriod period,
  AnalyticsService? analytics,
}) {
  if (records.isEmpty) return const [];

  final service = analytics ?? analyticsService;
  final effectiveFilters = filters.copy();

  if (period != AnalyticsPeriod.custom) {
    effectiveFilters.dateFrom = null;
    effectiveFilters.dateTo = null;
    effectiveFilters.quickRange = null;
  }

  var filtered = RecordFilterHelper.apply(records, effectiveFilters);

  if (period != AnalyticsPeriod.custom) {
    filtered = service.filterRecordsForCurrentPeriod(filtered, period);
  }

  return filtered;
}
