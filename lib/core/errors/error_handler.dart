import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'app_exception.dart';

/// Convierte errores técnicos en mensajes seguros para UI y depuración controlada.
class ErrorHandler {
  ErrorHandler._();

  /// Mensaje entendible para el usuario final.
  static String userMessage(Object error) {
    if (error is AppException) return error.message;

    if (error is FirebaseAuthException) {
      return _authMessage(error);
    }

    if (error is FirebaseException) {
      return _firebaseMessage(error);
    }

    if (error is StateError) {
      return error.message;
    }

    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return switch (error.code) {
        'permission-denied' => 'No tiene permisos para realizar esta acción.',
        'unauthenticated' => 'Debe iniciar sesión nuevamente.',
        'invalid-argument' => 'Los datos enviados no son válidos.',
        'already-exists' => 'El recurso ya existe.',
        _ => 'Error del servidor (${error.code}).',
      };
    }

    final text = error.toString().toLowerCase();
    if (text.contains('failed to fetch') ||
        text.contains('clientexception') ||
        text.contains('network') ||
        text.contains('socketexception')) {
      return 'No se pudo conectar. Verifique su conexión e intente de nuevo.';
    }

    if (text.contains('permission') || text.contains('denied')) {
      return 'No tiene permisos para realizar esta acción.';
    }

    return 'Ocurrió un error inesperado. Intente nuevamente.';
  }

  /// Registra el error para depuración sin imprimir credenciales ni tokens.
  static void log(Object error, [StackTrace? stackTrace, String? context]) {
    if (!kDebugMode) return;
    final prefix = context != null ? '[$context] ' : '';
    debugPrint('${prefix}Error: ${_sanitizeForLog(error)}');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  static String _firebaseMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'No tiene permisos para acceder a los datos en la nube.',
      'unavailable' => 'Servicio de Firebase no disponible. Intente más tarde.',
      'unauthenticated' => 'Debe iniciar sesión nuevamente.',
      _ => error.message ?? 'Error de Firebase (${error.code}).',
    };
  }

  static String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'El usuario o correo no es válido.',
      'user-disabled' => 'Usuario desactivado. Contacte al administrador.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Usuario o contraseña incorrectos.',
      'too-many-requests' => 'Demasiados intentos. Intente más tarde.',
      _ => error.message ?? 'No se pudo completar la autenticación.',
    };
  }

  static String _sanitizeForLog(Object error) {
    final raw = error.toString();
    return raw.replaceAll(
      RegExp(r'(password|token|secret|apikey|api_key)[^\s,}]*',
          caseSensitive: false),
      r'$1=***',
    );
  }
}
