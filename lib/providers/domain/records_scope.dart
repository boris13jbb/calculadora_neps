import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../models/nep_record.dart';
import '../../models/record_filters.dart';
import '../../utils/record_filter_helper.dart';

/// Estado de registros locales y filtros de tabla.
class RecordsScope extends ChangeNotifier {
  RecordsScope();

  List<NepRecord> items = [];
  final RecordFilters filters = RecordFilters();
  int filterPanelKey = 0;

  List<NepRecord> get visible => RecordFilterHelper.apply(items, filters);

  void replaceAll(List<NepRecord> next) {
    items = next;
    notifyListeners();
  }

  void upsert(NepRecord record) {
    final index = items.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      items[index] = record;
    } else {
      items.add(record);
    }
    notifyListeners();
  }

  void removeById(String recordId) {
    items.removeWhere((record) => record.id == recordId);
    notifyListeners();
  }

  void clear() {
    items = [];
    notifyListeners();
  }

  NepRecord? findById(String recordId) {
    final index = items.indexWhere((record) => record.id == recordId);
    if (index < 0) return null;
    return items[index];
  }

  void clearFilters() {
    filters.clear();
    filterPanelKey++;
    notifyListeners();
  }

  void applyNavigationFilters({
    String? telar,
    String? tela,
    String? loteTrama,
  }) {
    filters.clear();
    filters.telar = telar;
    filters.tela = tela;
    filters.loteTrama = loteTrama;
    filterPanelKey++;
    notifyListeners();
  }

  Future<List<NepRecord>> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(storageKey);
    if (savedData == null || savedData.isEmpty) return [];

    try {
      final List decoded = jsonDecode(savedData);
      return decoded
          .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      throw FormatException('Datos locales corruptos: $error');
    }
  }

  Future<void> persistLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((record) => record.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
