/// Documentos de la cola de creación de usuarios (sin I/O).
///
/// Separa el payload del request (sin contraseña) del secreto temporal,
/// para poder verificar el contrato en tests unitarios.
class UserCreationQueuePayload {
  UserCreationQueuePayload._();

  /// Metadatos públicos de la solicitud. Nunca incluye password/newPassword.
  static Map<String, dynamic> buildRequestData({
    required String username,
    String? displayName,
    required String roleCode,
    required bool isActive,
    required String requestedByUid,
    required String requestedByUsername,
    Object? createdAt,
  }) {
    return <String, dynamic>{
      'type': 'create',
      'username': username,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'role': roleCode,
      'isActive': isActive,
      'status': 'pending',
      'requestedByUid': requestedByUid,
      'requestedByUsername': requestedByUsername,
      'createdAt': createdAt,
    };
  }

  /// Secreto temporal: solo password + auditoría mínima.
  static Map<String, dynamic> buildSecretData({
    required String password,
    required String requestedByUid,
    Object? createdAt,
  }) {
    return <String, dynamic>{
      'password': password,
      'requestedByUid': requestedByUid,
      'createdAt': createdAt,
    };
  }

  /// True si el mapa del request contiene campos de contraseña (no permitido).
  static bool requestContainsPassword(Map<String, dynamic> request) {
    return request.containsKey('password') ||
        request.containsKey('newPassword');
  }
}
