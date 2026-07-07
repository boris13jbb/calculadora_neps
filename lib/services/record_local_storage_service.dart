import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nep_record.dart';

/// Almacenamiento local de registros con Hive (Web, Android, Windows).
///
/// En tests de Flutter usa SharedPreferences como respaldo.
class RecordLocalStorageService {
  RecordLocalStorageService();

  Box<String>? _box;
  bool _initialized = false;
  bool _usePrefsFallback = false;

  static bool _isRunningInWidgetTest() {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgets');
  }

  Future<void> init() async {
    if (_initialized) return;

    if (_isRunningInWidgetTest()) {
      _usePrefsFallback = true;
      _initialized = true;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final migrationDone = prefs.getBool(recordsHiveMigrationKey) == true;

    // Sin migración completada: usar prefs y abrir Hive en segundo plano.
    if (!migrationDone) {
      _usePrefsFallback = true;
      _initialized = true;
      return;
    }

    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(recordsHiveBoxName);
      _initialized = true;
    } catch (_) {
      _usePrefsFallback = true;
      _initialized = true;
    }
  }

  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    if (_usePrefsFallback) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(recordsHiveMigrationKey) == true) return;

    final savedData = prefs.getString(storageKey);
    if (savedData != null && savedData.isNotEmpty) {
      try {
        final List decoded = jsonDecode(savedData);
        final records = decoded
            .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        await saveAll(records);
      } catch (_) {
        // Datos legacy corruptos: no bloquear arranque.
      }
    }

    await prefs.setBool(recordsHiveMigrationKey, true);
  }

  Future<List<NepRecord>> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(storageKey);
    if (savedData == null || savedData.isEmpty) return [];

    try {
      final List decoded = jsonDecode(savedData);
      final records = decoded
          .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (error) {
      throw FormatException('Datos locales corruptos: $error');
    }
  }

  Future<void> _saveToPrefs(List<NepRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(records.map((record) => record.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  Future<List<NepRecord>> loadAll() async {
    await init();
    if (_usePrefsFallback) return _loadFromPrefs();

    final box = _box!;
    final records = <NepRecord>[];
    for (final raw in box.values) {
      try {
        records.add(
          NepRecord.fromJson(Map<String, dynamic>.from(jsonDecode(raw))),
        );
      } catch (_) {
        continue;
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<List<NepRecord>> loadRecent({
    int limit = recordsInitialPageSize,
  }) async {
    await init();

    final prefs = await SharedPreferences.getInstance();
    final migrationDone = prefs.getBool(recordsHiveMigrationKey) == true;

    if (_usePrefsFallback || !migrationDone) {
      final records = await _loadFromPrefs();
      if (!migrationDone && !_usePrefsFallback) {
        unawaited(_migrateFromSharedPreferencesIfNeeded());
      }
      if (records.length <= limit) return records;
      return records.take(limit).toList(growable: false);
    }

    return _loadRecentFromHive(limit);
  }

  Future<List<NepRecord>> _loadRecentFromHive(int limit) async {
    final box = _box!;
    if (box.isEmpty) return [];

    final records = <NepRecord>[];
    for (final raw in box.values) {
      try {
        records.add(
          NepRecord.fromJson(Map<String, dynamic>.from(jsonDecode(raw))),
        );
      } catch (_) {
        continue;
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (records.length <= limit) return records;
    return records.take(limit).toList(growable: false);
  }

  Future<void> saveAll(List<NepRecord> records) async {
    await init();
    if (_usePrefsFallback) {
      await _saveToPrefs(records);
      return;
    }

    final box = _box!;
    await box.clear();
    for (final record in records) {
      await box.put(record.id, jsonEncode(record.toJson()));
    }
  }

  Future<void> upsert(NepRecord record) async {
    await init();
    if (_usePrefsFallback) {
      final all = await _loadFromPrefs();
      final index = all.indexWhere((item) => item.id == record.id);
      if (index >= 0) {
        all[index] = record;
      } else {
        all.insert(0, record);
      }
      await _saveToPrefs(all);
      return;
    }

    await _box!.put(record.id, jsonEncode(record.toJson()));
  }

  Future<void> upsertMany(List<NepRecord> records) async {
    for (final record in records) {
      await upsert(record);
    }
  }

  Future<void> deleteById(String recordId) async {
    await init();
    if (_usePrefsFallback) {
      final all = await _loadFromPrefs();
      all.removeWhere((record) => record.id == recordId);
      await _saveToPrefs(all);
      return;
    }
    await _box!.delete(recordId);
  }

  Future<void> clear() async {
    await init();
    if (_usePrefsFallback) {
      await _saveToPrefs([]);
      return;
    }
    await _box!.clear();
  }
}

final RecordLocalStorageService recordLocalStorageService =
    RecordLocalStorageService();
