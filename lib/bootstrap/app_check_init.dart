import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;

import '../core/constants.dart';
import '../firebase_options.dart';

/// Activa App Check en plataformas soportadas.
///
/// Web requiere [appCheckRecaptchaSiteKey] configurado en Firebase Console.
/// En debug usa proveedores de depuración para facilitar desarrollo local.
Future<void> initializeAppCheck() async {
  if (!DefaultFirebaseOptions.isSupported) return;
  if (Firebase.apps.isEmpty) return;

  try {
    if (kDebugMode) {
      if (kIsWeb && appCheckRecaptchaSiteKey.isEmpty) {
        debugPrint(
          '[appCheck] Web debug sin site key. '
          'Use --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=... o registre token debug.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
        webProvider: ReCaptchaV3Provider(appCheckRecaptchaSiteKey),
      );
      await _logDebugTokenIfAvailable();
      return;
    }

    if (kIsWeb) {
      if (appCheckRecaptchaSiteKey.isEmpty) {
        debugPrint(
            '[appCheck] Producción web requiere APP_CHECK_RECAPTCHA_SITE_KEY.');
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(appCheckRecaptchaSiteKey),
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[appCheck] No se pudo activar App Check: $error');
    debugPrint('$stackTrace');
  }
}

/// Imprime el token de depuración para registrarlo en Firebase Console.
Future<void> _logDebugTokenIfAvailable() async {
  if (!kDebugMode) return;
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null || token.isEmpty) return;
    debugPrint(
      '[appCheck] Token debug (App Check > Manage debug tokens): $token',
    );
  } catch (error) {
    debugPrint('[appCheck] No se pudo obtener token debug: $error');
  }
}
