import '../core/constants.dart';

class LoteTramaParts {
  const LoteTramaParts({
    required this.prefix,
    required this.suffix,
  });

  final String prefix;
  final String suffix;

  String get full => LoteTramaHelper.buildFull(prefix: prefix, suffix: suffix);
}

class LoteTramaHelper {
  static const int defaultPrefixLength = 6;

  static String normalizePrefix(String input) {
    return input.trim().toUpperCase();
  }

  static String normalizeSuffix(String input, {String? knownPrefix}) {
    var text = input.trim().toUpperCase();
    final prefix = knownPrefix == null ? null : normalizePrefix(knownPrefix);
    if (prefix != null && prefix.isNotEmpty && text.startsWith(prefix)) {
      text = text.substring(prefix.length);
    } else if (text.startsWith(loteTramaPrefix)) {
      text = text.substring(loteTramaPrefix.length);
    }
    return text;
  }

  static String normalizeFull(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static LoteTramaParts split(
    String fullLote, {
    String? fallbackPrefix,
  }) {
    final text = normalizeFull(fullLote);
    final preferredPrefix = normalizePrefix(fallbackPrefix ?? loteTramaPrefix);

    if (text.isEmpty) {
      return LoteTramaParts(prefix: preferredPrefix, suffix: '');
    }

    if (preferredPrefix.isNotEmpty && text.startsWith(preferredPrefix)) {
      return LoteTramaParts(
        prefix: preferredPrefix,
        suffix: text.substring(preferredPrefix.length),
      );
    }

    if (text.startsWith(loteTramaPrefix)) {
      return LoteTramaParts(
        prefix: loteTramaPrefix,
        suffix: text.substring(loteTramaPrefix.length),
      );
    }

    if (text.length > defaultPrefixLength) {
      return LoteTramaParts(
        prefix: text.substring(0, defaultPrefixLength),
        suffix: text.substring(defaultPrefixLength),
      );
    }

    return LoteTramaParts(prefix: preferredPrefix, suffix: text);
  }

  static String buildFull({
    required String prefix,
    required String suffix,
  }) {
    final normalizedPrefix = normalizePrefix(prefix);
    final normalizedSuffix = normalizeSuffix(
      suffix,
      knownPrefix: normalizedPrefix,
    );
    return '$normalizedPrefix$normalizedSuffix';
  }

  /// Compatibilidad con el flujo anterior (prefijo por defecto fijo).
  static String buildFullLote(String suffix) {
    return buildFull(prefix: loteTramaPrefix, suffix: suffix);
  }

  static bool isValidParts({
    required String prefix,
    required String suffix,
  }) {
    return normalizePrefix(prefix).isNotEmpty &&
        normalizeSuffix(suffix, knownPrefix: prefix).isNotEmpty;
  }

  static bool isValidFull(String fullLote) {
    final parts = split(fullLote);
    return isValidParts(prefix: parts.prefix, suffix: parts.suffix);
  }

  static bool isValidSuffix(String suffix) {
    return normalizeSuffix(suffix).isNotEmpty;
  }
}
