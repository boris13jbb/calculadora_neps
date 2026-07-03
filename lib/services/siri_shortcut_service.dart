/// Parámetros de URL compatibles con Atajos de iOS (Siri Shortcuts).
///
/// Ejemplos:
/// - `/?pantalla=captura`
/// - `/?pantalla=captura&telar=12&neps=150&lote=ABC&tela=ALGODON`
/// - `/?accion=agregar&telar=12&neps=150&lote=ABC&tela=ALGODON`
class SiriShortcutService {
  static const Map<String, int> _screenIndexByName = {
    'inicio': 0,
    'captura': 1,
    'registros': 2,
    'alertas': 3,
    'telas': 4,
    'informes': 5,
    'exportar': 6,
    'configuracion': 7,
    'config': 7,
  };

  static int? resolveScreenIndex(String? screen) {
    if (screen == null || screen.trim().isEmpty) return null;
    return _screenIndexByName[screen.trim().toLowerCase()];
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
