import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Metadatos locales de sync por UID: última huella confirmada en cloud.
///
/// No almacena tokens ni registros; solo `reportId → fingerprint`.
class ReportSyncMetaStore {
  ReportSyncMetaStore();

  Future<Map<String, String>> _loadMap(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(reportSyncMetaKeyForUid(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, String>{};
      decoded.forEach((key, value) {
        final id = key.toString().trim();
        final fp = value?.toString().trim() ?? '';
        if (id.isNotEmpty && fp.isNotEmpty) out[id] = fp;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveMap(String uid, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    final key = reportSyncMetaKeyForUid(uid);
    final encoded = jsonEncode(map);
    final ok = await prefs.setString(key, encoded);
    if (!ok) {
      throw StateError('No se pudo persistir metadatos de sync de informes');
    }
    final readBack = prefs.getString(key);
    if (readBack != encoded) {
      throw StateError('Verificación de metadatos de sync falló tras escribir');
    }
  }

  Future<String?> lastSyncedFingerprint(String uid, String reportId) async {
    final id = reportId.trim();
    if (uid.trim().isEmpty || id.isEmpty) return null;
    final map = await _loadMap(uid);
    return map[id];
  }

  Future<void> setLastSyncedFingerprint({
    required String uid,
    required String reportId,
    required String fingerprint,
  }) async {
    final owner = uid.trim();
    final id = reportId.trim();
    final fp = fingerprint.trim();
    if (owner.isEmpty || id.isEmpty || fp.isEmpty) return;
    final map = await _loadMap(owner);
    map[id] = fp;
    await _saveMap(owner, map);
  }

  Future<void> clearReport(String uid, String reportId) async {
    final owner = uid.trim();
    final id = reportId.trim();
    if (owner.isEmpty || id.isEmpty) return;
    final map = await _loadMap(owner);
    if (!map.containsKey(id)) return;
    map.remove(id);
    await _saveMap(owner, map);
  }
}

final ReportSyncMetaStore reportSyncMetaStore = ReportSyncMetaStore();
