import '../core/constants.dart';

/// Utilidades para login con usuario visible y email interno oculto en Firebase Auth.
class UsernameAuthHelper {
  UsernameAuthHelper._();

  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

  /// Indica si el valor parece un correo electrónico (contiene @).
  static bool isEmail(String value) {
    final trimmed = value.trim();
    if (!trimmed.contains('@')) return false;
    final parts = trimmed.split('@');
    if (parts.length != 2) return false;
    return parts.first.isNotEmpty && parts.last.contains('.');
  }

  /// Normaliza username: trim, minúsculas, sin espacios.
  static String normalizeUsername(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Valida formato de username permitido.
  static bool isValidUsername(String value) {
    final normalized = normalizeUsername(value);
    if (normalized.isEmpty || normalized.length > 64) return false;
    return _usernamePattern.hasMatch(normalized);
  }

  /// Construye el email interno usado por Firebase Auth.
  static String buildInternalEmail(String username) {
    final normalized = normalizeUsername(username);
    return '$normalized@$internalAuthEmailDomain';
  }

  /// Resuelve el email de Firebase Auth a partir de usuario o correo real.
  ///
  /// - Si contiene `@`, se usa como correo (super_admin con email real).
  /// - Si no, se convierte a `[username]@vicunha.local`.
  static String resolveSignInEmail(String usernameOrEmail) {
    final trimmed = usernameOrEmail.trim();
    if (isEmail(trimmed)) {
      return trimmed.toLowerCase();
    }
    final username = normalizeUsername(trimmed);
    if (!isValidUsername(username)) {
      throw const FormatException('Usuario no válido.');
    }
    return buildInternalEmail(username);
  }

  /// Mensaje de error amigable para username inválido.
  static String? validateUsernameOrEmailInput(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Ingrese su usuario.';

    if (isEmail(input)) {
      if (!input.contains('.') || input.startsWith('@') || input.endsWith('@')) {
        return 'Correo no válido.';
      }
      return null;
    }

    if (!isValidUsername(input)) {
      return 'Usuario no válido. Use letras, números, punto, guion o guion bajo.';
    }
    return null;
  }

  /// Extrae username desde email interno o correo real.
  static String deriveUsername({
    String? username,
    String? internalEmail,
    String? realEmail,
    String? legacyEmail,
  }) {
    if (username != null && username.trim().isNotEmpty) {
      return normalizeUsername(username);
    }
    if (internalEmail != null && internalEmail.contains('@')) {
      return internalEmail.split('@').first;
    }
    if (realEmail != null && realEmail.contains('@')) {
      return realEmail.split('@').first;
    }
    if (legacyEmail != null && legacyEmail.contains('@')) {
      return legacyEmail.split('@').first;
    }
    return '';
  }

}
