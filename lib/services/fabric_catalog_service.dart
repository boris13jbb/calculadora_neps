import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'fabric_catalog_io.dart'
    if (dart.library.html) 'fabric_catalog_io_stub.dart';

class FabricCatalogService {
  Future<List<String>> loadFabrics() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(fabricCatalogStorageKey);
    if (saved == null || saved.isEmpty) return [];

    try {
      final List decoded = jsonDecode(saved);
      return decoded
          .map((item) => item.toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFabrics(List<String> fabrics) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeList(fabrics);
    await prefs.setString(fabricCatalogStorageKey, jsonEncode(normalized));
  }

  Future<List<String>> importFromPath(String path) async {
    final bytes = await readFileBytes(path);
    return importFromBytes(bytes);
  }

  List<String> importFromBytes(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    final names = <String>{};

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final columnIndex = _detectFabricColumnIndex(sheet);
      final startRow =
          columnIndex == 0 ? 0 : _detectDataStartRow(sheet, columnIndex);

      for (var rowIndex = startRow; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (row.length <= columnIndex) continue;

        final value = _cellToString(row[columnIndex]);
        if (value == null || value.isEmpty) continue;
        if (_isHeaderValue(value)) continue;
        names.add(value);
      }
    }

    return _normalizeList(names.toList());
  }

  List<String> mergeFabrics(List<String> current, List<String> imported) {
    return _normalizeList([...current, ...imported]);
  }

  String buildExportCsv(List<String> fabrics) {
    final normalized = _normalizeList(fabrics);
    final buffer = StringBuffer()..writeln('Tela');

    for (final fabric in normalized) {
      final needsQuotes =
          fabric.contains(',') || fabric.contains('"') || fabric.contains('\n');
      final escaped = fabric.replaceAll('"', '""');
      buffer.writeln(needsQuotes ? '"$escaped"' : escaped);
    }

    return buffer.toString();
  }

  Uint8List? buildExportExcelBytes(List<String> fabrics) {
    final normalized = _normalizeList(fabrics);
    if (normalized.isEmpty) return null;

    final excel = xls.Excel.createExcel();
    const sheetName = 'Telas';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([xls.TextCellValue('Tela')]);
    for (final fabric in normalized) {
      sheet.appendRow([xls.TextCellValue(fabric)]);
    }

    return Uint8List.fromList(excel.encode() ?? []);
  }

  List<String> _normalizeList(List<String> fabrics) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in fabrics) {
      final name = raw.trim();
      if (name.isEmpty) continue;

      final key = name.toUpperCase();
      if (seen.add(key)) {
        result.add(name);
      }
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  int _detectFabricColumnIndex(xls.Sheet sheet) {
    const headerKeywords = ['TELA', 'TELAS', 'TEJIDO', 'TEJIDOS', 'FABRIC'];

    for (var rowIndex = 0;
        rowIndex < sheet.rows.length && rowIndex < 5;
        rowIndex++) {
      final row = sheet.rows[rowIndex];
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final value = _cellToString(row[colIndex])?.toUpperCase() ?? '';
        if (headerKeywords.any(value.contains)) {
          return colIndex;
        }
      }
    }

    return 0;
  }

  int _detectDataStartRow(xls.Sheet sheet, int columnIndex) {
    for (var rowIndex = 0;
        rowIndex < sheet.rows.length && rowIndex < 5;
        rowIndex++) {
      final row = sheet.rows[rowIndex];
      if (row.length <= columnIndex) continue;
      final value = _cellToString(row[columnIndex])?.toUpperCase() ?? '';
      if (_isHeaderValue(value)) {
        return rowIndex + 1;
      }
    }
    return 0;
  }

  bool _isHeaderValue(String value) {
    const headers = ['TELA', 'TELAS', 'TEJIDO', 'TEJIDOS', 'FABRIC', 'NOMBRE'];
    final upper = value.toUpperCase();
    return headers.any((header) => upper == header || upper.contains(header));
  }

  String? _cellToString(xls.Data? cell) {
    if (cell == null || cell.value == null) return null;

    final text = cell.value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
