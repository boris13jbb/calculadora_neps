import '../core/constants.dart';

class LoteTramaHelper {
  static String normalizeSuffix(String input) {
    var text = input.trim().toUpperCase();
    if (text.startsWith(loteTramaPrefix)) {
      text = text.substring(loteTramaPrefix.length);
    }
    return text;
  }

  static String buildFullLote(String suffix) {
    return '$loteTramaPrefix${normalizeSuffix(suffix)}';
  }

  static bool isValidSuffix(String suffix) {
    return normalizeSuffix(suffix).isNotEmpty;
  }
}
