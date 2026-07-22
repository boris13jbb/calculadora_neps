import '../core/constants.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../services/alert_service.dart';

class RecordFilterHelper {
  /// Filtros que solo pueden aplicarse en memoria (neps, mts, búsqueda, etc.).
  static bool needsInMemoryFiltering(RecordFilters filters) {
    return filters.loteTrama != null ||
        filters.nepsMin != null ||
        filters.nepsMax != null ||
        filters.mtsMin != null ||
        filters.mtsMax != null ||
        filters.lineaProduccion != null ||
        filters.soloNoRevisados ||
        filters.soloConAccionCorrectiva ||
        filters.searchText.trim().isNotEmpty;
  }

  /// Aplica únicamente filtros que Firestore no puede resolver.
  static List<NepRecord> applyInMemoryOnly(
    List<NepRecord> records,
    RecordFilters filters,
  ) {
    if (!needsInMemoryFiltering(filters)) return records;
    return records
        .where((record) => _matchesInMemory(record, filters))
        .toList();
  }

  static bool _matchesInMemory(NepRecord record, RecordFilters filters) {
    if (filters.loteTrama != null &&
        record.loteTrama.toLowerCase() != filters.loteTrama!.toLowerCase()) {
      return false;
    }

    if (filters.lineaProduccion != null &&
        record.lineaProduccion.toLowerCase() !=
            filters.lineaProduccion!.toLowerCase()) {
      return false;
    }

    if (filters.soloNoRevisados && record.revisadoPorSupervisor) {
      return false;
    }

    if (filters.soloConAccionCorrectiva &&
        record.accionCorrectiva.trim().isEmpty) {
      return false;
    }

    if (filters.nepsMin != null && record.neps < filters.nepsMin!) {
      return false;
    }

    if (filters.nepsMax != null && record.neps > filters.nepsMax!) {
      return false;
    }

    final mts = record.neps / testLengthM;
    if (filters.mtsMin != null && mts < filters.mtsMin!) {
      return false;
    }

    if (filters.mtsMax != null && mts > filters.mtsMax!) {
      return false;
    }

    final search = filters.searchText.trim().toLowerCase();
    if (search.isNotEmpty) {
      final haystack = [
        record.tela,
        record.loteTrama,
        record.telar,
        record.turno,
        record.operario,
        record.lineaProduccion,
        record.observacion,
        record.accionCorrectiva,
        record.neps.toString(),
        mts.round().toString(),
      ].join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }

    return true;
  }

  static List<NepRecord> apply(List<NepRecord> records, RecordFilters filters) {
    return records.where((record) => _matches(record, filters)).toList();
  }

  static List<String> uniqueTelas(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.tela));
  }

  static List<String> uniqueLotes(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.loteTrama));
  }

  static List<String> uniqueTurnos(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.turno));
  }

  static List<String> uniqueOperarios(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.operario));
  }

  static List<String> uniqueLineas(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.lineaProduccion));
  }

  static List<String> uniqueTelares(List<NepRecord> records) {
    final result = _uniqueValues(records.map((r) => r.telar));
    result.sort(compareTelar);
    return result;
  }

  static List<String> _uniqueValues(Iterable<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  /// Ordena telares numéricamente cuando es posible (004 antes que 012).
  static int compareTelar(String a, String b) {
    final aTrim = a.trim();
    final bTrim = b.trim();
    final aNum = int.tryParse(aTrim);
    final bNum = int.tryParse(bTrim);
    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }
    return aTrim.toLowerCase().compareTo(bTrim.toLowerCase());
  }

  /// Orden estable para reportes: telar ascendente y luego fecha.
  static List<NepRecord> sortForReport(List<NepRecord> records) {
    final sorted = List<NepRecord>.from(records);
    sorted.sort((a, b) {
      final telarCmp = compareTelar(a.telar, b.telar);
      if (telarCmp != 0) return telarCmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  /// Orden cronológico ascendente (informes consolidados por rango).
  static List<NepRecord> sortChronological(List<NepRecord> records) {
    final sorted = List<NepRecord>.from(records);
    sorted.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      if (cmp != 0) return cmp;
      return compareTelar(a.telar, b.telar);
    });
    return sorted;
  }

  static (DateTime?, DateTime?) resolveQuickRange(DateQuickRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (range) {
      DateQuickRange.hoy => (
          today,
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ),
      DateQuickRange.ayer => () {
          final day = today.subtract(const Duration(days: 1));
          return (
            day,
            DateTime(day.year, day.month, day.day, 23, 59, 59),
          );
        }(),
      DateQuickRange.estaSemana => () {
          final weekday = today.weekday;
          final start = today.subtract(Duration(days: weekday - 1));
          return (
            start,
            DateTime(today.year, today.month, today.day, 23, 59, 59),
          );
        }(),
      DateQuickRange.esteMes => (
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ),
      DateQuickRange.esteAno => (
          DateTime(today.year, 1, 1),
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ),
    };
  }

  static bool _matches(NepRecord record, RecordFilters filters) {
    if (filters.tela != null &&
        record.tela.toLowerCase() != filters.tela!.toLowerCase()) {
      return false;
    }

    if (filters.loteTrama != null &&
        record.loteTrama.toLowerCase() != filters.loteTrama!.toLowerCase()) {
      return false;
    }

    if (filters.telar != null &&
        record.telar.toLowerCase() != filters.telar!.toLowerCase()) {
      return false;
    }

    if (filters.turno != null &&
        record.turno.toLowerCase() != filters.turno!.toLowerCase()) {
      return false;
    }

    if (filters.operario != null &&
        record.operario.toLowerCase() != filters.operario!.toLowerCase()) {
      return false;
    }

    if (filters.lineaProduccion != null &&
        record.lineaProduccion.toLowerCase() !=
            filters.lineaProduccion!.toLowerCase()) {
      return false;
    }

    if (filters.alertLevel != null &&
        alertService.getAlertLevel(record.neps) != filters.alertLevel) {
      return false;
    }

    if (filters.soloNoRevisados && record.revisadoPorSupervisor) {
      return false;
    }

    if (filters.soloConAccionCorrectiva &&
        record.accionCorrectiva.trim().isEmpty) {
      return false;
    }

    if (filters.nepsMin != null && record.neps < filters.nepsMin!) {
      return false;
    }

    if (filters.nepsMax != null && record.neps > filters.nepsMax!) {
      return false;
    }

    final mts = record.neps / testLengthM;
    if (filters.mtsMin != null && mts < filters.mtsMin!) {
      return false;
    }

    if (filters.mtsMax != null && mts > filters.mtsMax!) {
      return false;
    }

    DateTime? from = filters.dateFrom;
    DateTime? to = filters.dateTo;
    if (filters.quickRange != null) {
      final (qFrom, qTo) = resolveQuickRange(filters.quickRange!);
      from = qFrom;
      to = qTo;
    }

    if (from != null) {
      final fromDay = DateTime(from.year, from.month, from.day);
      final created = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      if (created.isBefore(fromDay)) return false;
    }

    if (to != null) {
      final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
      if (record.createdAt.isAfter(toEnd)) return false;
    }

    final search = filters.searchText.trim().toLowerCase();
    if (search.isNotEmpty) {
      final haystack = [
        record.tela,
        record.loteTrama,
        record.telar,
        record.turno,
        record.operario,
        record.lineaProduccion,
        record.observacion,
        record.accionCorrectiva,
        record.neps.toString(),
        mts.round().toString(),
      ].join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }

    return true;
  }
}
