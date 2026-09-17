import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Tracking local de IDs ya guardados vía Captura → Guardar.
///
/// Aislado por [uid] + [captureSessionId]. Sobrevive refresh/reinicio/login
/// mientras se restaure la misma sesión.
class SavedCaptureIdsStorageService {
  Future<Set<String>> load({
    required String uid,
    required String captureSessionId,
  }) async {
    if (uid.isEmpty || captureSessionId.isEmpty) return <String>{};
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList(savedCaptureIdsKeyFor(uid, captureSessionId));
    if (list == null || list.isEmpty) return <String>{};
    return list.where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<void> save({
    required String uid,
    required String captureSessionId,
    required Set<String> ids,
  }) async {
    if (uid.isEmpty || captureSessionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = savedCaptureIdsKeyFor(uid, captureSessionId);
    if (ids.isEmpty) {
      await prefs.setStringList(key, const <String>[]);
      return;
    }
    await prefs.setStringList(
      key,
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toList()..sort(),
    );
  }
}

final SavedCaptureIdsStorageService savedCaptureIdsStorageService =
    SavedCaptureIdsStorageService();
