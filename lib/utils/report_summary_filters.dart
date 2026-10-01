import '../models/record_filters.dart';
import '../models/saved_report.dart';
import '../models/saved_report_summary.dart';
import 'record_filter_helper.dart';

/// True si el filtro exige inspeccionar `records[]` del informe.
bool requiresReportContentFilters(RecordFilters filters) {
  if (filters.tela != null ||
      filters.loteTrama != null ||
      filters.telar != null ||
      filters.nepsMin != null ||
      filters.nepsMax != null ||
      filters.mtsMin != null ||
      filters.mtsMax != null) {
    return true;
  }
  // searchText puede matchear nombre (liviano) o campos de records (contenido).
  return false;
}

/// Fecha del informe (`createdAt` del summary). El search se resuelve aparte.
bool matchesReportSummaryDateFilters(
  SavedReportSummary summary,
  RecordFilters filters,
) {
  if (filters.dateFrom != null &&
      summary.createdAt.isBefore(filters.dateFrom!)) {
    return false;
  }

  if (filters.dateTo != null) {
    final to = DateTime(
      filters.dateTo!.year,
      filters.dateTo!.month,
      filters.dateTo!.day,
      23,
      59,
      59,
    );
    if (summary.createdAt.isAfter(to)) return false;
  }

  return true;
}

/// Filtra summaries con política PR2:
/// - nombre + fecha sobre metadata;
/// - filtros de contenido solo si hay [fullById] local (sin fetch masivo).
List<SavedReportSummary> filterVisibleReportSummaries(
  Iterable<SavedReportSummary> summaries,
  RecordFilters filters, {
  Map<String, SavedReport> fullById = const {},
}) {
  if (!filters.hasActiveFilters) return summaries.toList(growable: false);

  final search = filters.searchText.trim().toLowerCase();
  final needsContent = requiresReportContentFilters(filters);

  return summaries.where((summary) {
    if (!matchesReportSummaryDateFilters(summary, filters)) return false;

    if (search.isNotEmpty) {
      final nameMatch = summary.name.toLowerCase().contains(search);
      if (!nameMatch) {
        final full = fullById[summary.id];
        if (full == null) return false;
        final haystackMatch = full.records.any((record) {
          final haystack = [
            record.tela,
            record.loteTrama,
            record.telar,
          ].join(' ').toLowerCase();
          return haystack.contains(search);
        });
        if (!haystackMatch) return false;
      }
    }

    if (needsContent) {
      final full = fullById[summary.id];
      if (full == null) return false;
      final filteredRecords = RecordFilterHelper.apply(full.records, filters);
      return filteredRecords.isNotEmpty;
    }

    return true;
  }).toList(growable: false);
}
