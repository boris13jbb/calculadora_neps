import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Catálogo persistente de lotes de trama usados en captura.
class LoteTramaCatalogService {
  static const List<String> defaultCatalog = [
    '63E0264H7A',
    '63E0266H15A',
    '63E0266H6A',
    '63E0266H7A',
    '63E0266H7G',
    '63E264H10A',
    '63E264H15F',
    '63E264H16A',
    '63E264H7A',
    '63E2666H10A',
    '63E266H10A',
    '63E266H15A',
    '63EP0266H7A',
    '63EP264H16A',
    '63EP266H10A',
    '6E0266H7A',
  ];

  Future<List<String>> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(loteTramaCatalogStorageKey);
    if (saved == null || saved.isEmpty) {
      return List<String>.from(defaultCatalog);
    }

    try {
      final List decoded = jsonDecode(saved);
      final loaded = decoded
          .map((item) => item.toString().trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toList();
      return loaded.isEmpty ? List<String>.from(defaultCatalog) : loaded;
    } catch (_) {
      return List<String>.from(defaultCatalog);
    }
  }

  Future<List<String>> saveCatalog(List<String> catalog) async {
    final normalized = _normalize(catalog);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(loteTramaCatalogStorageKey, jsonEncode(normalized));
    return normalized;
  }

  Future<List<String>> addLote(List<String> current, String lote) async {
    final value = lote.trim().toUpperCase();
    if (value.isEmpty) return current;
    return saveCatalog([value, ...current]);
  }

  Future<List<String>> removeLote(List<String> current, String lote) async {
    final value = lote.trim().toUpperCase();
    return saveCatalog(
      current.where((item) => item.toUpperCase() != value).toList(),
    );
  }

  List<String> _normalize(List<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in values) {
      final value = raw.trim().toUpperCase();
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        result.add(value);
      }
    }

    return result;
  }
}
