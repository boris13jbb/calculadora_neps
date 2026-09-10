import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/permissions/record_visibility.dart';
import '../models/nep_record.dart';

/// Almacenamiento local de registros aislado por UID.
///
/// - Escrituras nuevas van siempre al espacio del UID activo.
/// - El store legacy global solo se lee una vez para repartir:
///   · owned → box del UID
///   · ambiguos → [recordsAmbiguousKey] (no se suben a la nube)
///   · ajenos → se dejan en legacy para otros UIDs
class RecordLocalStorageService {
  RecordLocalStorageService();

  Box<String>? _box;
  String? _boundUid;
  bool _initialized = false;
  bool _usePrefsFallback = false;
  bool _hiveReady = false;

  String? get boundUid => _boundUid;

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

    try {
      await Hive.initFlutter();
      _hiveReady = true;
      _initialized = true;
    } catch (_) {
      _usePrefsFallback = true;
      _initialized = true;
    }
  }

  /// Enlaza el almacenamiento al UID autenticado. Cierra el box anterior.
  Future<void> bindUser(String? uid) async {
    await init();
    final next = uid?.trim();
    if (next == null || next.isEmpty) {
      await _closeBox();
      _boundUid = null;
      return;
    }
    if (_boundUid == next && _box != null && !_usePrefsFallback) return;
    if (_boundUid == next && _usePrefsFallback) return;

    await _closeBox();
    _boundUid = next;

    if (!_usePrefsFallback && _hiveReady) {
      try {
        _box = await Hive.openBox<String>(recordsHiveBoxForUid(next));
      } catch (_) {
        _usePrefsFallback = true;
        _box = null;
      }
    }

    await _splitLegacyIntoUserSpaceIfNeeded(next);
  }

  Future<void> _closeBox() async {
    final box = _box;
    _box = null;
    if (box != null && box.isOpen) {
      await box.close();
    }
  }

  /// Una sola vez por dispositivo: reparte el store global sin reasignar dueños.
  Future<void> _splitLegacyIntoUserSpaceIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final flag = '${recordsLegacySplitDoneKey}_$uid';
    if (prefs.getBool(flag) == true) return;

    final legacy = await _loadLegacyGlobalRecords();
    if (legacy.isEmpty) {
      await prefs.setBool(flag, true);
      return;
    }

    final owned = <NepRecord>[];
    final ambiguous = <NepRecord>[];

    for (final record in legacy) {
      if (recordBelongsToUid(record, uid)) {
        owned.add(record);
      } else if (isAmbiguousOwnership(record)) {
        ambiguous.add(record);
      }
      // Ajenos: se dejan en legacy para cuando inicie sesión su dueño.
    }

    for (final record in owned) {
      await upsert(record);
    }

    if (ambiguous.isNotEmpty) {
      await _mergeAmbiguous(ambiguous);
    }

    await prefs.setBool(flag, true);
  }

  Future<List<NepRecord>> _loadLegacyGlobalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(storageKey);
    final collected = <String, NepRecord>{};

    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      try {
        final List decoded = jsonDecode(fromPrefs);
        for (final item in decoded) {
          final record =
              NepRecord.fromJson(Map<String, dynamic>.from(item as Map));
          collected[record.id] = record;
        }
      } catch (_) {}
    }

    if (_hiveReady) {
      try {
        if (Hive.isBoxOpen(recordsHiveBoxName)) {
          final legacyBox = Hive.box<String>(recordsHiveBoxName);
          for (final raw in legacyBox.values) {
            try {
              final record = NepRecord.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map),
              );
              collected[record.id] = record;
            } catch (_) {}
          }
        } else if (await Hive.boxExists(recordsHiveBoxName)) {
          final legacyBox = await Hive.openBox<String>(recordsHiveBoxName);
          for (final raw in legacyBox.values) {
            try {
              final record = NepRecord.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map),
              );
              collected[record.id] = record;
            } catch (_) {}
          }
          await legacyBox.close();
        }
      } catch (_) {}
    }

    return collected.values.toList();
  }

  Future<void> _mergeAmbiguous(List<NepRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAmbiguousRecords();
    final byId = {for (final r in existing) r.id: r};
    for (final record in records) {
      byId.putIfAbsent(record.id, () => record);
    }
    final encoded =
        jsonEncode(byId.values.map((r) => r.toJson()).toList(growable: false));
    await prefs.setString(recordsAmbiguousKey, encoded);
  }

  /// Copia íntegra de registros legacy sin dueño verificable (no migrar a nube).
  Future<List<NepRecord>> loadAmbiguousRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(recordsAmbiguousKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded
          .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _requireBoundUid() {
    if (_boundUid == null || _boundUid!.isEmpty) {
      throw StateError(
        'RecordLocalStorageService sin UID: llame bindUser antes de leer/escribir.',
      );
    }
  }

  Future<List<NepRecord>> _loadFromPrefs() async {
    _requireBoundUid();
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(recordsPrefsKeyForUid(_boundUid!));
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
    _requireBoundUid();
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(records.map((record) => record.toJson()).toList());
    await prefs.setString(recordsPrefsKeyForUid(_boundUid!), encoded);
  }

  Future<List<NepRecord>> loadAll() async {
    await init();
    if (_boundUid == null || _boundUid!.isEmpty) return const [];
    if (_usePrefsFallback || _box == null) return _loadFromPrefs();

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
    final records = await loadAll();
    if (records.length <= limit) return records;
    return records.take(limit).toList(growable: false);
  }

  Future<void> saveAll(List<NepRecord> records) async {
    await init();
    _requireBoundUid();
    if (_usePrefsFallback || _box == null) {
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
    _requireBoundUid();
    if (_usePrefsFallback || _box == null) {
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
    _requireBoundUid();
    if (_usePrefsFallback || _box == null) {
      final all = await _loadFromPrefs();
      all.removeWhere((record) => record.id == recordId);
      await _saveToPrefs(all);
      return;
    }
    await _box!.delete(recordId);
  }

  Future<void> clear() async {
    await init();
    if (_boundUid == null || _boundUid!.isEmpty) return;
    if (_usePrefsFallback || _box == null) {
      await _saveToPrefs([]);
      return;
    }
    await _box!.clear();
  }
}

final RecordLocalStorageService recordLocalStorageService =
    RecordLocalStorageService();
