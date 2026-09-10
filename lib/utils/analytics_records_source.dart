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
    this.isPartial = false,
    this.partialMessage,
    this.skippedReportCount = 0,
  });

  final List<NepRecord> records;
  final int liveRecordCount;
  final int savedReportCount;
  final int savedReportRecordCount;
  final bool isPartial;
  final String? partialMessage;
  final int skippedReportCount;

  int get totalSourceRecords => liveRecordCount + savedReportRecordCount;

  bool get hasAnyData => records.isNotEmpty;

  String describe() {
    final base = () {
      if (savedReportCount == 0 && liveRecordCount == 0) {
        return 'Sin registros ni informes guardados';
      }
      if (savedReportCount == 0) {
        return '$liveRecordCount registros actuales';
      }
      if (liveRecordCount == 0) {
        return '${records.length} registros de $savedReportCount informes/sesiones';
      }
      return '${records.length} registros '
          '($liveRecordCount actuales + $savedReportRecordCount en historial)';
    }();

    if (!isPartial) return base;
    final detail = partialMessage?.trim();
    if (detail != null && detail.isNotEmpty) {
      return '$base · Resultados parciales: $detail';
    }
    if (skippedReportCount > 0) {
      return '$base · Resultados parciales ($skippedReportCount omitidos)';
    }
    return '$base · Resultados parciales';
  }
}

/// Combina registros en vivo con los de informes/sesiones (sin duplicar por id).
AnalyticsRecordsSource buildAnalyticsRecordsSource({
  required List<NepRecord> liveRecords,
  required List<SavedReport> savedReports,
  bool isPartial = false,
  String? partialMessage,
  int skippedReportCount = 0,
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
    isPartial: isPartial,
    partialMessage: partialMessage,
    skippedReportCount: skippedReportCount,
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
