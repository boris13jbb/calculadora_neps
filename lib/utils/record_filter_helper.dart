import '../core/constants.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';

class RecordFilterHelper {
  static List<NepRecord> apply(List<NepRecord> records, RecordFilters filters) {
    return records.where((record) => _matches(record, filters)).toList();
  }

  static List<String> uniqueTelas(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.tela));
  }

  static List<String> uniqueLotes(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.loteTrama));
  }

  static List<String> uniqueTelares(List<NepRecord> records) {
    return _uniqueValues(records.map((r) => r.telar));
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

    if (filters.dateFrom != null) {
      final from = DateTime(
        filters.dateFrom!.year,
        filters.dateFrom!.month,
        filters.dateFrom!.day,
      );
      final created = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      if (created.isBefore(from)) return false;
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
      if (record.createdAt.isAfter(to)) return false;
    }

    final search = filters.searchText.trim().toLowerCase();
    if (search.isNotEmpty) {
      final haystack = [
        record.tela,
        record.loteTrama,
        record.telar,
        record.neps.toString(),
        mts.round().toString(),
      ].join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }

    return true;
  }
}
