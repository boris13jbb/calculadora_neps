/// Excepciones de dominio de la aplicación.
///
/// Usar subclases concretas para distinguir validación, importación,
/// exportación y errores de Firebase sin exponer detalles sensibles al usuario.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Datos de entrada inválidos o reglas de negocio incumplidas.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Fallo al leer o interpretar CSV/Excel de registros.
class ImportException extends AppException {
  const ImportException(super.message, {super.cause});
}

/// Fallo al generar o compartir CSV, Excel o PDF.
class ExportException extends AppException {
  const ExportException(super.message, {super.cause});
}

/// Error de administración de usuarios (cola Firestore o Cloud Functions).
class UserAdminException extends AppException {
  const UserAdminException(super.message, {super.cause});
}

/// Error de Auth, Firestore o Cloud Functions con contexto de app.
class FirebaseAppException extends AppException {
  const FirebaseAppException(super.message, {super.cause, this.code});

  final String? code;
}
