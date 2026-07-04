import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/alert_config.dart';
import '../core/constants.dart';

/// Persistencia local de límites de alerta (Fase 11).
class AlertConfigService {
  AlertConfig _config = defaultAlertConfig;

  AlertConfig get config => _config;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(alertConfigStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _config = AlertConfig(
        limiteNormalMax: map['limiteNormalMax'] as int? ?? 30,
        limiteAdvertenciaMax: map['limiteAdvertenciaMax'] as int? ?? 60,
        diasParaReincidencia: map['diasParaReincidencia'] as int? ?? 1,
        cantidadReincidenciasCriticas:
            map['cantidadReincidenciasCriticas'] as int? ?? 3,
        alertasActivas: map['alertasActivas'] as bool? ?? true,
      );
    } catch (_) {
      _config = defaultAlertConfig;
    }
  }

  Future<void> save(AlertConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      alertConfigStorageKey,
      jsonEncode({
        'limiteNormalMax': config.limiteNormalMax,
        'limiteAdvertenciaMax': config.limiteAdvertenciaMax,
        'diasParaReincidencia': config.diasParaReincidencia,
        'cantidadReincidenciasCriticas': config.cantidadReincidenciasCriticas,
        'alertasActivas': config.alertasActivas,
      }),
    );
  }

  Future<void> reset() => save(defaultAlertConfig);

  Map<String, dynamic> toFirestoreMap() => {
        'limiteNormalMax': _config.limiteNormalMax,
        'limiteAdvertenciaMax': _config.limiteAdvertenciaMax,
        'diasParaReincidencia': _config.diasParaReincidencia,
        'cantidadReincidenciasCriticas': _config.cantidadReincidenciasCriticas,
        'alertasActivas': _config.alertasActivas,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  void applyFromFirestore(Map<String, dynamic>? data) {
    if (data == null) return;
    _config = AlertConfig(
      limiteNormalMax:
          data['limiteNormalMax'] as int? ?? _config.limiteNormalMax,
      limiteAdvertenciaMax:
          data['limiteAdvertenciaMax'] as int? ?? _config.limiteAdvertenciaMax,
      diasParaReincidencia:
          data['diasParaReincidencia'] as int? ?? _config.diasParaReincidencia,
      cantidadReincidenciasCriticas:
          data['cantidadReincidenciasCriticas'] as int? ??
              _config.cantidadReincidenciasCriticas,
      alertasActivas: data['alertasActivas'] as bool? ?? _config.alertasActivas,
    );
  }
}

final AlertConfigService alertConfigService = AlertConfigService();
