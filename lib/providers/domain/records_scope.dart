import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../models/nep_record.dart';
import '../../models/record_filters.dart';
import '../../services/firestore_record_query_builder.dart';
import '../../services/record_local_storage_service.dart';
import '../../utils/record_filter_helper.dart';

/// Estado de registros locales, filtros y paginación.
class RecordsScope extends ChangeNotifier {
  RecordsScope({RecordLocalStorageService? localStorage})
      : _localStorage = localStorage ?? recordLocalStorageService;

  final RecordLocalStorageService _localStorage;

  List<NepRecord> items = [];
  final RecordFilters filters = RecordFilters();
  int filterPanelKey = 0;

  int queryLimit = recordsInitialPageSize;
  bool hasMoreFromCloud = false;
  bool isLoadingMore = false;
  int totalLoadedHint = 0;

  bool remoteFiltersActive = false;

  /// Registros visibles tras filtros.
  List<NepRecord> get visible {
    if (remoteFiltersActive && usesRemoteFilters) {
      return RecordFilterHelper.applyInMemoryOnly(items, filters);
    }
    return RecordFilterHelper.apply(items, filters);
  }

  /// Subconjunto ligero para el panel principal (últimos N o 30 días).
  List<NepRecord> get dashboardRecords {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent =
        items.where((r) => r.createdAt.isAfter(cutoff)).toList(growable: false);
    if (recent.length >= dashboardRecordsLimit) {
      return recent.take(dashboardRecordsLimit).toList(growable: false);
    }
    if (items.length <= dashboardRecordsLimit) return items;
    return items.take(dashboardRecordsLimit).toList(growable: false);
  }

  bool get usesRemoteFilters =>
      FirestoreRecordQueryBuilder.hasRemoteFilters(filters);

  void replaceAll(List<NepRecord> next) {
    items = next;
    notifyListeners();
  }

  void applyPageResult(List<NepRecord> records, {required bool hasMore}) {
    items = records;
    hasMoreFromCloud = hasMore;
    totalLoadedHint = records.length;
    isLoadingMore = false;
    notifyListeners();
  }

  /// Fusiona registros remotos sin borrar los que solo existen en local.
  void mergePageResult(List<NepRecord> records, {required bool hasMore}) {
    if (records.isEmpty) {
      hasMoreFromCloud = hasMore;
      isLoadingMore = false;
      notifyListeners();
      return;
    }

    final byId = {for (final record in items) record.id: record};
    for (final record in records) {
      byId[record.id] = record;
    }
    items = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    hasMoreFromCloud = hasMore;
    totalLoadedHint = items.length;
    isLoadingMore = false;
    notifyListeners();
  }

  void upsert(NepRecord record) {
    final index = items.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      items[index] = record;
    } else {
      items.insert(0, record);
    }
    notifyListeners();
  }

  void removeById(String recordId) {
    items.removeWhere((record) => record.id == recordId);
    notifyListeners();
  }

  void clear() {
    items = [];
    hasMoreFromCloud = false;
    totalLoadedHint = 0;
    notifyListeners();
  }

  NepRecord? findById(String recordId) {
    final index = items.indexWhere((record) => record.id == recordId);
    if (index < 0) return null;
    return items[index];
  }

  void clearFilters() {
    filters.clear();
    filterPanelKey++;
    queryLimit = recordsInitialPageSize;
    notifyListeners();
  }

  void applyNavigationFilters({
    String? telar,
    String? tela,
    String? loteTrama,
    DateQuickRange? quickRange,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    filters.clear();
    filters.telar = telar;
    filters.tela = tela;
    filters.loteTrama = loteTrama;
    filters.quickRange = quickRange;
    filters.dateFrom = dateFrom;
    filters.dateTo = dateTo;
    filterPanelKey++;
    queryLimit = recordsInitialPageSize;
    notifyListeners();
  }

  void onFiltersChanged() {
    queryLimit = recordsInitialPageSize;
    notifyListeners();
  }

  Future<void> requestLoadMore() async {
    if (isLoadingMore || !hasMoreFromCloud) return;
    if (queryLimit >= recordsMaxPageSize) return;
    isLoadingMore = true;
    queryLimit = (queryLimit + recordsPageSizeIncrement).clamp(
      recordsInitialPageSize,
      recordsMaxPageSize,
    );
    notifyListeners();
  }

  Future<List<NepRecord>> loadFromPreferences() async {
    return _localStorage.loadAll();
  }

  Future<List<NepRecord>> loadAllLocal() async {
    return _localStorage.loadAll();
  }

  Future<void> persistLocally() async {
    await _localStorage.saveAll(items);
  }

  Future<void> persistRecord(NepRecord record) async {
    await _localStorage.upsert(record);
  }

  Future<void> persistMerged(List<NepRecord> records) async {
    await _localStorage.upsertMany(records);
  }
}
