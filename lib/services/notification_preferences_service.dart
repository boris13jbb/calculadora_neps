import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Preferencias de notificaciones de alertas críticas.
class NotificationPreferencesService {
  bool _criticalAlertsEnabled = true;

  bool get criticalAlertsEnabled => _criticalAlertsEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(notificationPrefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _criticalAlertsEnabled = map['criticalAlerts'] as bool? ?? true;
    } catch (_) {
      _criticalAlertsEnabled = true;
    }
  }

  Future<void> setCriticalAlertsEnabled(bool enabled) async {
    _criticalAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      notificationPrefsKey,
      jsonEncode({'criticalAlerts': enabled}),
    );
  }
}

final NotificationPreferencesService notificationPreferencesService =
    NotificationPreferencesService();
