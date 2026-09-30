import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/alert_config.dart';
import '../core/constants.dart';

/// Persistencia local de parámetros operativos de alerta.
///
/// Los umbrales de calificación oficial ya no se configuran aquí; se ignoran
/// claves legacy (`limiteNormalMax`, `limiteAdvertenciaMax`) si existen.
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
        'diasParaReincidencia': config.diasParaReincidencia,
        'cantidadReincidenciasCriticas': config.cantidadReincidenciasCriticas,
        'alertasActivas': config.alertasActivas,
        // Criterios oficiales fijos (documentación en almacenamiento).
        'limiteOkMaxScore': config.limiteOkMaxScore,
        'limiteMencionMaxScore': config.limiteMencionMaxScore,
        'limiteCriticoMaxScore': config.limiteCriticoMaxScore,
      }),
    );
  }

  Future<void> reset() => save(defaultAlertConfig);

  Map<String, dynamic> toFirestoreMap() => {
        'diasParaReincidencia': _config.diasParaReincidencia,
        'cantidadReincidenciasCriticas': _config.cantidadReincidenciasCriticas,
        'alertasActivas': _config.alertasActivas,
        'limiteOkMaxScore': _config.limiteOkMaxScore,
        'limiteMencionMaxScore': _config.limiteMencionMaxScore,
        'limiteCriticoMaxScore': _config.limiteCriticoMaxScore,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  void applyFromFirestore(Map<String, dynamic>? data) {
    if (data == null) return;
    _config = AlertConfig(
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
