import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nep_record.dart';
import '../utils/stable_id.dart';

/// Archivo personal de una sesión de captura (operario sin informes de equipo).
class PersonalCaptureSessionArchive {
  PersonalCaptureSessionArchive({
    required this.id,
    required this.ownerUid,
    required this.captureSessionId,
    required this.savedAt,
    required this.records,
    this.name = '',
  });

  final String id;
  final String ownerUid;
  final String captureSessionId;
  final DateTime savedAt;
  final List<NepRecord> records;
  final String name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerUid': ownerUid,
        'captureSessionId': captureSessionId,
        'savedAt': savedAt.toIso8601String(),
        'name': name,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory PersonalCaptureSessionArchive.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'];
    final records = <NepRecord>[];
    if (rawRecords is List) {
      for (final item in rawRecords) {
        if (item is Map) {
          records.add(NepRecord.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return PersonalCaptureSessionArchive(
      id: json['id']?.toString() ?? generateStableId(prefix: 'pses'),
      ownerUid: json['ownerUid']?.toString() ?? '',
      captureSessionId: json['captureSessionId']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
      records: records,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Persistencia de sesiones personales por UID (recuperable tras reinicio).
class PersonalSessionArchiveService {
  PersonalSessionArchiveService();

  Future<List<PersonalCaptureSessionArchive>> loadForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(personalSessionsKeyForUid(uid));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded
          .map((item) => PersonalCaptureSessionArchive.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .where((archive) => archive.ownerUid == uid)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(
    String uid,
    List<PersonalCaptureSessionArchive> archives,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      personalSessionsKeyForUid(uid),
      jsonEncode(archives.map((a) => a.toJson()).toList()),
    );
  }

  /// Upsert idempotente por [id] (reintentos no duplican).
  Future<PersonalCaptureSessionArchive> upsert(
    PersonalCaptureSessionArchive archive,
  ) async {
    final uid = archive.ownerUid;
    final all = List<PersonalCaptureSessionArchive>.from(await loadForUid(uid));
    final index = all.indexWhere((item) => item.id == archive.id);
    if (index >= 0) {
      all[index] = archive;
    } else {
      all.insert(0, archive);
    }
    await _save(uid, all);
    return archive;
  }

  Future<PersonalCaptureSessionArchive?> findBySessionId({
    required String uid,
    required String captureSessionId,
  }) async {
    final all = await loadForUid(uid);
    for (final archive in all) {
      if (archive.captureSessionId == captureSessionId) return archive;
    }
    return null;
  }
}

final PersonalSessionArchiveService personalSessionArchiveService =
    PersonalSessionArchiveService();
