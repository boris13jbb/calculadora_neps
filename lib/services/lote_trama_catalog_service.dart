import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class LoteTramaCatalogService {
  Future<List<String>> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(loteTramaCatalogStorageKey);

    if (saved == null || saved.isEmpty) {
      final defaults = _normalizeList(defaultLoteTramaPresets);
      await savePresets(defaults);
      return defaults;
    }

    try {
      final List decoded = jsonDecode(saved);
      final loaded = decoded
          .map((item) => LoteTramaCatalogService.normalize(item.toString()))
          .where((value) => value.isNotEmpty)
          .toList();
      if (loaded.isEmpty) {
        final defaults = _normalizeList(defaultLoteTramaPresets);
        await savePresets(defaults);
        return defaults;
      }
      return _normalizeList(loaded);
    } catch (_) {
      final defaults = _normalizeList(defaultLoteTramaPresets);
      await savePresets(defaults);
      return defaults;
    }
  }

  Future<void> savePresets(List<String> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      loteTramaCatalogStorageKey,
      jsonEncode(_normalizeList(presets)),
    );
  }

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  List<String> _normalizeList(List<String> presets) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in presets) {
      final value = normalize(raw);
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        result.add(value);
      }
    }

    result.sort((a, b) => a.compareTo(b));
    return result;
  }
}
