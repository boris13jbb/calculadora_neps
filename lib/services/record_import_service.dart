import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../core/constants.dart';
import '../models/nep_record.dart';
import '../models/record_import_result.dart';
import '../utils/lote_trama_helper.dart';

class RecordImportService {
  RecordImportResult importFromBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.csv')) {
      final content = utf8.decode(bytes, allowMalformed: true);
      return importFromCsv(content);
    }

    if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      return importFromExcel(bytes);
    }

    if (_looksLikeCsv(bytes)) {
      final content = utf8.decode(bytes, allowMalformed: true);
      return importFromCsv(content);
    }

    return importFromExcel(bytes);
  }

  RecordImportResult importFromCsv(String content) {
    final normalized = content.replaceFirst('\uFEFF', '');
    final rows = <List<String>>[];

    for (final line in const LineSplitter().convert(normalized)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      rows.add(_parseCsvLine(trimmed));
    }

    return _buildResult(rows);
  }

  RecordImportResult importFromExcel(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    final rows = <List<String>>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      for (final row in sheet.rows) {
        final values = row.map(_excelCellToString).toList();
        if (values.every((value) => value.trim().isEmpty)) continue;
        rows.add(values);
      }
    }

    return _buildResult(rows);
  }

  RecordImportResult _buildResult(List<List<String>> rows) {
    if (rows.isEmpty) {
      return const RecordImportResult(
        records: [],
        message: 'El archivo no contiene filas de datos.',
      );
    }

    final columnMap = _detectColumns(rows.first);
    final dataStartRow = columnMap == null ? 0 : 1;
    final records = <NepRecord>[];
    var skipped = 0;

    for (var index = dataStartRow; index < rows.length; index++) {
      final row = rows[index];
      if (_isSummaryRow(row)) {
        skipped++;
        continue;
      }

      final record = _parseRecordRow(row, columnMap);
      if (record == null) {
        skipped++;
        continue;
      }

      records.add(record);
    }

    if (records.isEmpty) {
      return RecordImportResult(
        records: const [],
        skippedRows: skipped,
        message:
            'No se encontraron registros validos. Revise telar, neps, tela y lote.',
      );
    }

    return RecordImportResult(records: records, skippedRows: skipped);
  }

  Map<_ImportField, int>? _detectColumns(List<String> headerRow) {
    final map = <_ImportField, int>{};

    for (var index = 0; index < headerRow.length; index++) {
      final field = _matchHeader(headerRow[index]);
      if (field != null) {
        map[field] = index;
      }
    }

    final hasDataHeaders = map.containsKey(_ImportField.telar) ||
        map.containsKey(_ImportField.neps) ||
        map.containsKey(_ImportField.tela);

    if (!hasDataHeaders) return null;
    return map;
  }

  NepRecord? _parseRecordRow(
    List<String> row,
    Map<_ImportField, int>? columnMap,
  ) {
    String read(_ImportField field, int fallbackIndex) {
      final index = columnMap?[field] ?? fallbackIndex;
      if (index < 0 || index >= row.length) return '';
      return row[index].trim();
    }

    final telar = read(_ImportField.telar, 4);
    final tela = read(_ImportField.tela, 3);
    final loteRaw = read(_ImportField.loteTrama, 2);
    final nepsText = read(_ImportField.neps, 5);
    final mtsText = read(_ImportField.mts, 6);
    final fechaText = read(_ImportField.fecha, 1);

    if (telar.isEmpty) return null;

    final neps = _resolveNeps(nepsText, mtsText);
    if (neps == null || neps <= 0) return null;

    if (tela.isEmpty) return null;

    final loteSuffix = LoteTramaHelper.normalizeSuffix(loteRaw);
    if (loteSuffix.isEmpty) return null;

    return NepRecord(
      telar: telar,
      neps: neps,
      tela: tela,
      loteTrama: LoteTramaHelper.buildFullLote(loteSuffix),
      createdAt: _parseDate(fechaText) ?? DateTime.now(),
    );
  }

  double? _resolveNeps(String nepsText, String mtsText) {
    final neps = _parseNumber(nepsText);
    if (neps != null && neps > 0) return neps;

    final mts = _parseNumber(mtsText);
    if (mts != null && mts > 0) {
      return mts * testLengthM;
    }

    return null;
  }

  double? _parseNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final match = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{1,2}))?$',
    ).firstMatch(trimmed);

    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '0') ?? 0;

    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day, hour, minute);
  }

  _ImportField? _matchHeader(String raw) {
    final normalized =
        raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (normalized.isEmpty) return null;

    if (normalized == 'NRO' || normalized == 'NO') return _ImportField.nro;
    if (normalized.contains('FECHA')) return _ImportField.fecha;
    if (normalized.contains('LOTETRAMA') || normalized == 'LOTE') {
      return _ImportField.loteTrama;
    }
    if (normalized.contains('TELAR')) return _ImportField.telar;
    if (normalized.contains('TELA') || normalized.contains('TEJIDO')) {
      return _ImportField.tela;
    }
    if (normalized.contains('NEPS')) return _ImportField.neps;
    if (normalized.contains('MTS')) return _ImportField.mts;

    return null;
  }

  bool _isSummaryRow(List<String> row) {
    if (row.isEmpty) return true;

    final joined = row
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .join(' ');

    if (joined.isEmpty) return true;

    return joined.contains('TOTAL') || joined.contains('PROMEDIO');
  }

  bool _looksLikeCsv(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final sample = utf8.decode(bytes.take(512).toList(), allowMalformed: true);
    return sample.contains(',') || sample.contains(';');
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index++) {
      final char = line[index];

      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString().trim());
    return result;
  }

  String _excelCellToString(xls.Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }
}

enum _ImportField {
  nro,
  fecha,
  loteTrama,
  tela,
  telar,
  neps,
  mts,
}
