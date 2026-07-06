import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Indica si Firebase está inicializado y hay un usuario autenticado.
bool get isFirebaseSessionActive {
  if (Firebase.apps.isEmpty) return false;
  return FirebaseAuth.instance.currentUser != null;
}

/// Espera brevemente a que Firebase Auth restaure la sesión (p. ej. al recargar web).
Future<bool> waitForFirebaseSession({
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  if (Firebase.apps.isEmpty) return false;
  if (FirebaseAuth.instance.currentUser != null) return true;

  try {
    final user = await FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((user) => user != null)
        .timeout(timeout);
    return user != null;
  } catch (_) {
    return FirebaseAuth.instance.currentUser != null;
  }
}

bool isCloudAuthSkipError(Object error) {
  if (error is StateError) {
    final message = error.message.toLowerCase();
    return message.contains('no autenticado') ||
        message.contains('inicie sesión');
  }

  if (error is FirebaseAuthException && error.code == 'unauthenticated') {
    return true;
  }

  return false;
}
