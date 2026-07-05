import '../core/navigation/app_navigation.dart';

/// Parámetros de URL compatibles con Atajos de iOS (Siri Shortcuts).
///
/// Ejemplos:
/// - `/?pantalla=captura`
/// - `/?pantalla=graficas`
/// - `/?pantalla=captura&telar=12&neps=150&lote=ABC&tela=ALGODON`
/// - `/?accion=agregar&telar=12&neps=150&lote=ABC&tela=ALGODON`
class SiriShortcutService {
  static const Map<String, AppNavId> _screenIdByName = {
    'inicio': AppNavId.dashboard,
    'graficas': AppNavId.analytics,
    'analytics': AppNavId.analytics,
    'captura': AppNavId.capture,
    'registros': AppNavId.records,
    'alertas': AppNavId.alerts,
    'telas': AppNavId.fabrics,
    'informes': AppNavId.reports,
    'exportar': AppNavId.export,
    'usuarios': AppNavId.users,
    'configuracion': AppNavId.settings,
    'config': AppNavId.settings,
  };

  /// Resuelve el id de pantalla desde parámetro de URL (respeta permisos vía
  /// [AppState.requestNavigation] + [AppShell.applyPendingNavigation]).
  static AppNavId? resolveScreenId(String? screen) {
    if (screen == null || screen.trim().isEmpty) return null;
    return _screenIdByName[screen.trim().toLowerCase()];
  }

  static bool shouldAutoAdd(Map<String, String> params) {
    final action = params['accion']?.trim().toLowerCase();
    return action == 'agregar' || action == 'add';
  }

  static String? readParam(Map<String, String> params, String key) {
    final value = params[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
