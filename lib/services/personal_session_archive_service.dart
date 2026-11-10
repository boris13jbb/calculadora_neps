import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/errors/error_handler.dart';
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

/// Copia en la nube de las sesiones personales de una cuenta.
///
/// Solo el UID dueño lee y escribe su colección. No es el archivo de equipo.
abstract class PersonalSessionCloudPort {
  Future<List<PersonalCaptureSessionArchive>> fetchForUid(String uid);

  Future<void> upsert(PersonalCaptureSessionArchive archive);
}

/// Une archivos del mismo usuario. Por id gana el `savedAt` más reciente.
///
/// Descarta archivos de otro UID: la nube no puede reasignar sesiones.
List<PersonalCaptureSessionArchive> mergePersonalSessionArchives({
  required String uid,
  required List<PersonalCaptureSessionArchive> local,
  required List<PersonalCaptureSessionArchive> remote,
}) {
  final byId = <String, PersonalCaptureSessionArchive>{};

  void consider(PersonalCaptureSessionArchive archive) {
    if (archive.ownerUid != uid) return;
    final id = archive.id.trim();
    if (id.isEmpty) return;
    final current = byId[id];
    if (current == null || _isNewerSavedAt(archive.savedAt, current.savedAt)) {
      byId[id] = archive;
    }
  }

  for (final archive in local) {
    consider(archive);
  }
  for (final archive in remote) {
    consider(archive);
  }

  final merged = byId.values.toList(growable: false)
    ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return merged;
}

/// Archivos locales/fusionados que la nube aún no tiene o tiene más viejos.
List<PersonalCaptureSessionArchive> personalArchivesPendingUpload({
  required List<PersonalCaptureSessionArchive> merged,
  required List<PersonalCaptureSessionArchive> remote,
}) {
  final remoteById = {for (final archive in remote) archive.id: archive};
  return [
    for (final archive in merged)
      if (_needsCloudUpload(archive, remoteById[archive.id])) archive,
  ];
}

bool _needsCloudUpload(
  PersonalCaptureSessionArchive archive,
  PersonalCaptureSessionArchive? remote,
) {
  if (remote == null) return true;
  return _isNewerSavedAt(archive.savedAt, remote.savedAt);
}

bool _isNewerSavedAt(DateTime candidate, DateTime current) {
  return candidate.toUtc().millisecondsSinceEpoch >
      current.toUtc().millisecondsSinceEpoch;
}

/// Persistencia de sesiones personales por UID.
///
/// El dispositivo guarda siempre en local. Si hay [cloud], la misma cuenta
/// ve esas sesiones en el teléfono y en la web.
class PersonalSessionArchiveService {
  PersonalSessionArchiveService({PersonalSessionCloudPort? cloud})
      : _cloud = cloud;

  PersonalSessionCloudPort? _cloud;

  /// True si el último guardado local no pudo subirse. No indica éxito.
  bool lastCloudPushFailed = false;

  /// Enlaza la nube una vez que Firebase está disponible (no en tests).
  void attachCloud(PersonalSessionCloudPort? cloud) {
    _cloud = cloud;
  }

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
    if (_cloud == null) {
      lastCloudPushFailed = false;
      return archive;
    }
    lastCloudPushFailed = !await _pushToCloud(archive);
    return archive;
  }

  /// Local + nube del mismo UID. Si la nube falla, conserva lo local.
  ///
  /// Sube las sesiones que solo existen en este dispositivo para que la web
  /// (u otro teléfono de la misma cuenta) las recupere al entrar.
  Future<List<PersonalCaptureSessionArchive>> loadSynced(String uid) async {
    final local = await loadForUid(uid);
    final cloud = _cloud;
    if (cloud == null || uid.trim().isEmpty) return local;

    final List<PersonalCaptureSessionArchive> remote;
    try {
      remote = await cloud.fetchForUid(uid);
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'personalSessions.fetch');
      return local;
    }

    final merged = mergePersonalSessionArchives(
      uid: uid,
      local: local,
      remote: remote,
    );
    await _save(uid, merged);

    final pending = personalArchivesPendingUpload(
      merged: merged,
      remote: remote,
    );
    for (final archive in pending) {
      await _pushToCloud(archive);
    }
    return merged;
  }

  Future<bool> _pushToCloud(PersonalCaptureSessionArchive archive) async {
    final cloud = _cloud;
    if (cloud == null) return true;
    try {
      await cloud.upsert(archive);
      return true;
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'personalSessions.upsert');
      return false;
    }
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
