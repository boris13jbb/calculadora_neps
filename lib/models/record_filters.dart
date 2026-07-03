import '../models/alert_level.dart';

/// Rangos rápidos de fecha para filtros.
enum DateQuickRange {
  hoy('Hoy'),
  ayer('Ayer'),
  estaSemana('Esta semana'),
  esteMes('Este mes');

  const DateQuickRange(this.label);

  final String label;
}

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
  AlertLevel? alertLevel;
  String? turno;
  String? operario;
  String? lineaProduccion;
  bool soloNoRevisados = false;
  bool soloConAccionCorrectiva = false;
  DateQuickRange? quickRange;

  bool get hasActiveFilters => activeFilterCount > 0;

  int get activeFilterCount {
    var count = 0;
    if (tela != null) count++;
    if (loteTrama != null) count++;
    if (telar != null) count++;
    if (nepsMin != null || nepsMax != null) count++;
    if (mtsMin != null || mtsMax != null) count++;
    if (dateFrom != null || dateTo != null || quickRange != null) count++;
    if (searchText.trim().isNotEmpty) count++;
    if (alertLevel != null) count++;
    if (turno != null) count++;
    if (operario != null) count++;
    if (lineaProduccion != null) count++;
    if (soloNoRevisados) count++;
    if (soloConAccionCorrectiva) count++;
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
    alertLevel = null;
    turno = null;
    operario = null;
    lineaProduccion = null;
    soloNoRevisados = false;
    soloConAccionCorrectiva = false;
    quickRange = null;
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
      ..searchText = searchText
      ..alertLevel = alertLevel
      ..turno = turno
      ..operario = operario
      ..lineaProduccion = lineaProduccion
      ..soloNoRevisados = soloNoRevisados
      ..soloConAccionCorrectiva = soloConAccionCorrectiva
      ..quickRange = quickRange;
  }
}
