import '../models/analytics_period.dart';
import '../models/record_filters.dart';
import 'filter_description_helper.dart';

/// Describe filtros activos en pantalla de gráficas (periodo + filtros de registro).
class AnalyticsFilterDescription {
  AnalyticsFilterDescription._();

  static String describe({
    required AnalyticsPeriod period,
    required RecordFilters filters,
  }) {
    final parts = <String>['Agrupación: ${period.label}'];
    final filterText = FilterDescriptionHelper.describe(filters);
    if (filterText.isNotEmpty) {
      parts.add(filterText);
    }
    return parts.join(' | ');
  }
}

/// Valida rangos de fecha para el periodo personalizado.
class AnalyticsDateValidator {
  AnalyticsDateValidator._();

  static String? validateCustomRange(RecordFilters filters) {
    if (filters.dateFrom == null || filters.dateTo == null) {
      return 'Seleccione un rango de fechas válido (desde y hasta).';
    }
    if (filters.dateFrom!.isAfter(filters.dateTo!)) {
      return 'La fecha inicial no puede ser posterior a la fecha final.';
    }
    return null;
  }
}
