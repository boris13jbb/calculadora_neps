import '../models/record_filters.dart';

class FilterDescriptionHelper {
  static String describe(RecordFilters filters) {
    final parts = <String>[];

    if (filters.tela != null) parts.add('Tela: ${filters.tela}');
    if (filters.loteTrama != null) parts.add('Lote: ${filters.loteTrama}');
    if (filters.telar != null) parts.add('Telar: ${filters.telar}');
    if (filters.alertLevel != null) {
      parts.add('Estado: ${filters.alertLevel!.label}');
    }
    if (filters.turno != null) parts.add('Turno: ${filters.turno}');
    if (filters.operario != null) parts.add('Operario: ${filters.operario}');
    if (filters.lineaProduccion != null) {
      parts.add('Línea: ${filters.lineaProduccion}');
    }
    if (filters.soloNoRevisados) parts.add('Solo no revisados');
    if (filters.soloConAccionCorrectiva) {
      parts.add('Solo con acción correctiva');
    }
    if (filters.quickRange != null) {
      parts.add('Rango: ${filters.quickRange!.label}');
    }
    if (filters.nepsMin != null) parts.add('Neps min: ${filters.nepsMin}');
    if (filters.nepsMax != null) parts.add('Neps max: ${filters.nepsMax}');
    if (filters.mtsMin != null) parts.add('Mts min: ${filters.mtsMin}');
    if (filters.mtsMax != null) parts.add('Mts max: ${filters.mtsMax}');
    if (filters.dateFrom != null) {
      parts.add('Desde: ${_formatDate(filters.dateFrom!)}');
    }
    if (filters.dateTo != null) {
      parts.add('Hasta: ${_formatDate(filters.dateTo!)}');
    }
    if (filters.searchText.trim().isNotEmpty) {
      parts.add('Busqueda: ${filters.searchText.trim()}');
    }

    return parts.join(' | ');
  }

  static String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
