class RecordFilters {
  String? tela;
  String? loteTrama;
  String? telar;
  double? nepsMin;
  double? nepsMax;
  double? mtsMin;
  double? mtsMax;
  DateTime? dateFrom;
  DateTime? dateTo;
  String searchText = '';

  bool get hasActiveFilters => activeFilterCount > 0;

  int get activeFilterCount {
    var count = 0;
    if (tela != null) count++;
    if (loteTrama != null) count++;
    if (telar != null) count++;
    if (nepsMin != null || nepsMax != null) count++;
    if (mtsMin != null || mtsMax != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    if (searchText.trim().isNotEmpty) count++;
    return count;
  }

  void clear() {
    tela = null;
    loteTrama = null;
    telar = null;
    nepsMin = null;
    nepsMax = null;
    mtsMin = null;
    mtsMax = null;
    dateFrom = null;
    dateTo = null;
    searchText = '';
  }

  RecordFilters copy() {
    return RecordFilters()
      ..tela = tela
      ..loteTrama = loteTrama
      ..telar = telar
      ..nepsMin = nepsMin
      ..nepsMax = nepsMax
      ..mtsMin = mtsMin
      ..mtsMax = mtsMax
      ..dateFrom = dateFrom
      ..dateTo = dateTo
      ..searchText = searchText;
  }
}
