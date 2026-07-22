import '../core/constants.dart';
import '../features/reports/professional/models/report_configuration.dart';
import '../features/reports/professional/services/report_period_resolver.dart';
import '../features/reports/professional/services/report_statistics_service.dart';
import '../models/app_user_role.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../services/cloud_sync_port.dart';
import '../utils/nep_record_merge_helper.dart';
import '../utils/record_filter_helper.dart';

/// Carga registros para un informe consolidado respetando el rango de fechas.
class ReportRecordsLoader {
  ReportRecordsLoader({
    ReportPeriodResolver? periodResolver,
    ReportStatisticsService? statistics,
  })  : _periodResolver = periodResolver ?? reportPeriodResolver,
        _statistics = statistics ?? reportStatisticsService;

  final ReportPeriodResolver _periodResolver;
  final ReportStatisticsService _statistics;

  Future<List<NepRecord>> load({
    required ReportConfiguration config,
    required List<NepRecord> inMemoryRecords,
    required Future<List<NepRecord>> Function() loadAllLocal,
    CloudSyncPort? cloud,
    AppUserRole viewerRole = AppUserRole.operario,
    bool cloudReady = false,
  }) async {
    final range = _periodResolver.resolve(
      config.periodPreset,
      customFrom: config.customDateFrom,
      customTo: config.customDateTo,
    );

    if (range.isAll || range.start == null || range.end == null) {
      final merged = await _mergeWithLocal(inMemoryRecords, loadAllLocal);
      return _filterAndSort(config, merged);
    }

    final fromDay = DateTime(
      range.start!.year,
      range.start!.month,
      range.start!.day,
    );
    final toDay = DateTime(
      range.end!.year,
      range.end!.month,
      range.end!.day,
      23,
      59,
      59,
      999,
    );

    if (fromDay.isAfter(DateTime(toDay.year, toDay.month, toDay.day))) {
      return const [];
    }

    final dateFilters = RecordFilters()
      ..dateFrom = fromDay
      ..dateTo = toDay;

    var ranged = <NepRecord>[];

    if (cloud != null && cloudReady) {
      try {
        final page = await cloud.fetchRecordsByFilters(
          filters: dateFilters,
          viewerRole: viewerRole,
          limit: reportExportRecordLimit,
        );
        ranged = page.records;
      } catch (_) {
        ranged = [];
      }
    }

    final localAll = await loadAllLocal();
    final localInRange = RecordFilterHelper.apply(localAll, dateFilters);
    ranged = NepRecordMergeHelper.mergeById(ranged, localInRange);

    if (ranged.isEmpty) {
      ranged = RecordFilterHelper.apply(inMemoryRecords, dateFilters);
    }

    return _filterAndSort(config, ranged);
  }

  Future<List<NepRecord>> _mergeWithLocal(
    List<NepRecord> inMemory,
    Future<List<NepRecord>> Function() loadAllLocal,
  ) async {
    final local = await loadAllLocal();
    return NepRecordMergeHelper.mergeById(inMemory, local);
  }

  List<NepRecord> _filterAndSort(
    ReportConfiguration config,
    List<NepRecord> source,
  ) {
    var records = _statistics.filterByPeriod(
      source,
      config.periodPreset,
      customFrom: config.customDateFrom,
      customTo: config.customDateTo,
    );
    records = _statistics.applyFilters(records, config.filters);
    return RecordFilterHelper.sortChronological(records);
  }
}

final reportRecordsLoader = ReportRecordsLoader();
