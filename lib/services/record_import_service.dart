import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../core/constants.dart';
import '../core/errors/app_exception.dart';
import '../models/import_row_result.dart';
import '../models/nep_record.dart';
import '../models/record_import_result.dart';
import '../utils/lote_trama_helper.dart';

class RecordImportService {
  static const requiredColumnLabels = [
    'Telar',
    'Tela',
    'Lote de trama',
    'Neps o Mts calculados',
  ];

  RecordImportResult importFromBytes(
    Uint8List bytes, {
    required String fileName,
    List<NepRecord> existingRecords = const [],
  }) {
    try {
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.csv')) {
        final content = utf8.decode(bytes, allowMalformed: true);
        return importFromCsv(content, existingRecords: existingRecords);
      }

      if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
        return importFromExcel(bytes, existingRecords: existingRecords);
      }

      if (_looksLikeCsv(bytes)) {
        final content = utf8.decode(bytes, allowMalformed: true);
        return importFromCsv(content, existingRecords: existingRecords);
      }

      return importFromExcel(bytes, existingRecords: existingRecords);
    } on ImportException {
      rethrow;
    } catch (error) {
      throw ImportException(
        'No se pudo leer el archivo. Verifique que sea CSV o Excel válido.',
        cause: error,
      );
    }
  }

  RecordImportResult importFromCsv(
    String content, {
    List<NepRecord> existingRecords = const [],
  }) {
    final normalized = content.replaceFirst('\uFEFF', '');
    final rows = <List<String>>[];

    for (final line in const LineSplitter().convert(normalized)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      rows.add(_parseCsvLine(trimmed));
    }

    return _buildResult(rows, existingRecords: existingRecords);
  }

  RecordImportResult importFromExcel(
    Uint8List bytes, {
    List<NepRecord> existingRecords = const [],
  }) {
    try {
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

      return _buildResult(rows, existingRecords: existingRecords);
    } catch (error) {
      throw ImportException(
        'El archivo Excel no pudo interpretarse. Compruebe el formato.',
        cause: error,
      );
    }
  }

  RecordImportResult _buildResult(
    List<List<String>> rows, {
    List<NepRecord> existingRecords = const [],
  }) {
    if (rows.isEmpty) {
      return const RecordImportResult(
        records: [],
        message: 'El archivo no contiene filas de datos.',
      );
    }

    final columnMap = _detectColumns(rows.first);
    final hasHeader = columnMap != null;
    final dataStartRow = hasHeader ? 1 : 0;
    final missingColumns = _missingRequiredColumns(columnMap);
    final existingKeys = existingRecords.map(_fingerprint).toSet();
    final seenInFile = <String>{};

    final rowResults = <ImportRowResult>[];
    var duplicateRows = 0;
    var errorRows = 0;
    var skippedRows = 0;

    for (var index = dataStartRow; index < rows.length; index++) {
      final row = rows[index];
      final rowNumber = index + 1;

      if (_isSummaryRow(row)) {
        skippedRows++;
        rowResults.add(
          ImportRowResult(
            rowNumber: rowNumber,
            status: ImportRowStatus.skipped,
            message: 'Fila de resumen omitida',
            rawCells: row,
          ),
        );
        continue;
      }

      final parseResult = _parseRecordRowDetailed(row, columnMap);
      if (parseResult.record == null) {
        errorRows++;
        rowResults.add(
          ImportRowResult(
            rowNumber: rowNumber,
            status: ImportRowStatus.error,
            message: parseResult.error ?? 'Datos incompletos o inválidos',
            rawCells: row,
          ),
        );
        continue;
      }

      final record = parseResult.record!;
      final key = _fingerprint(record);

      if (seenInFile.contains(key)) {
        duplicateRows++;
        rowResults.add(
          ImportRowResult(
            rowNumber: rowNumber,
            status: ImportRowStatus.duplicate,
            record: record,
            message: 'Duplicada dentro del archivo',
            rawCells: row,
          ),
        );
        continue;
      }

      if (existingKeys.contains(key)) {
        duplicateRows++;
        rowResults.add(
          ImportRowResult(
            rowNumber: rowNumber,
            status: ImportRowStatus.duplicate,
            record: record,
            message: 'Ya existe en la tabla actual',
            rawCells: row,
          ),
        );
        continue;
      }

      seenInFile.add(key);
      rowResults.add(
        ImportRowResult(
          rowNumber: rowNumber,
          status: ImportRowStatus.valid,
          record: record,
          rawCells: row,
        ),
      );
    }

    final importable = rowResults
        .where((r) => r.status == ImportRowStatus.valid && r.record != null)
        .map((r) => r.record!)
        .toList();

    if (importable.isEmpty) {
      return RecordImportResult(
        records: const [],
        skippedRows: skippedRows,
        rowResults: rowResults,
        missingColumns: missingColumns,
        hasRecognizedHeader: hasHeader,
        duplicateRows: duplicateRows,
        errorRows: errorRows,
        message: missingColumns.isNotEmpty
            ? 'Faltan columnas obligatorias: ${missingColumns.join(', ')}.'
            : 'No se encontraron registros válidos. Revise telar, neps, tela y lote.',
      );
    }

    return RecordImportResult(
      records: importable,
      skippedRows: skippedRows,
      rowResults: rowResults,
      missingColumns: missingColumns,
      hasRecognizedHeader: hasHeader,
      duplicateRows: duplicateRows,
      errorRows: errorRows,
    );
  }

  List<String> _missingRequiredColumns(Map<_ImportField, int>? columnMap) {
    if (columnMap == null) return List<String>.from(requiredColumnLabels);

    final missing = <String>[];
    if (!columnMap.containsKey(_ImportField.telar)) missing.add('Telar');
    if (!columnMap.containsKey(_ImportField.tela)) missing.add('Tela');
    if (!columnMap.containsKey(_ImportField.loteTrama)) {
      missing.add('Lote de trama');
    }
    if (!columnMap.containsKey(_ImportField.neps) &&
        !columnMap.containsKey(_ImportField.mts)) {
      missing.add('Neps o Mts calculados');
    }
    return missing;
  }

  String _fingerprint(NepRecord record) {
    final date = record.createdAt;
    final dateKey =
        '${date.year}${date.month}${date.day}${date.hour}${date.minute}';
    return '${record.telar}|${record.tela}|${record.loteTrama}|${record.neps}|$dateKey';
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

  ({NepRecord? record, String? error}) _parseRecordRowDetailed(
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
    final turno = read(_ImportField.turno, 7);
    final operario = read(_ImportField.operario, 8);
    final linea = read(_ImportField.lineaProduccion, 9);
    final observacion = read(_ImportField.observacion, 10);

    if (telar.isEmpty) {
      return (record: null, error: 'Telar vacío');
    }

    final neps = _resolveNeps(nepsText, mtsText);
    if (neps == null || neps <= 0) {
      return (record: null, error: 'Neps o mts inválidos');
    }

    if (tela.isEmpty) {
      return (record: null, error: 'Tela vacía');
    }

    final loteSuffix = LoteTramaHelper.normalizeSuffix(loteRaw);
    if (loteSuffix.isEmpty) {
      return (record: null, error: 'Lote de trama inválido');
    }

    return (
      record: NepRecord(
        telar: telar,
        neps: neps,
        tela: tela,
        loteTrama: LoteTramaHelper.buildFullLote(loteSuffix),
        createdAt: _parseDate(fechaText) ?? DateTime.now(),
        turno: turno,
        operario: operario,
        lineaProduccion: linea,
        observacion: observacion,
      ),
      error: null,
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
    if (normalized.contains('TURNO')) return _ImportField.turno;
    if (normalized.contains('OPERARIO')) return _ImportField.operario;
    if (normalized.contains('LINEA') ||
        normalized.contains('LINEAPRODUCCION')) {
      return _ImportField.lineaProduccion;
    }
    if (normalized.contains('OBSERVACION') || normalized.contains('NOTA')) {
      return _ImportField.observacion;
    }

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
  turno,
  operario,
  lineaProduccion,
  observacion,
}
