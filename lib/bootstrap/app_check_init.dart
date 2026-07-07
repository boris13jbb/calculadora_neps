import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb,
        kReleaseMode;

import '../core/constants.dart';
import '../firebase_options.dart';

/// Activa App Check en plataformas soportadas.
///
/// En debug está desactivado por defecto para evitar bloqueos si la API de
/// App Check no está habilitada en Google Cloud.
/// Forzar con: `--dart-define=APP_CHECK_ENABLED=true`
Future<void> initializeAppCheck() async {
  if (!DefaultFirebaseOptions.isSupported) return;
  if (Firebase.apps.isEmpty) return;
  if (!_shouldActivateAppCheck()) {
    if (kDebugMode) {
      debugPrint(
        '[appCheck] Desactivado en debug. '
        'Use --dart-define=APP_CHECK_ENABLED=true para activarlo.',
      );
    }
    return;
  }

  try {
    if (kDebugMode) {
      if (kIsWeb && appCheckRecaptchaSiteKey.isEmpty) {
        debugPrint(
          '[appCheck] Web debug sin site key. '
          'Use --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
        providerWeb: ReCaptchaV3Provider(appCheckRecaptchaSiteKey),
      );
      if (appCheckLogDebugToken) {
        unawaited(_logDebugTokenIfAvailable());
      }
      return;
    }

    if (kIsWeb) {
      if (appCheckRecaptchaSiteKey.isEmpty) {
        debugPrint(
          '[appCheck] Producción web requiere APP_CHECK_RECAPTCHA_SITE_KEY.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(appCheckRecaptchaSiteKey),
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[appCheck] No se pudo activar App Check: $error');
    debugPrint('$stackTrace');
  }
}

bool _shouldActivateAppCheck() {
  const explicitEnable = bool.fromEnvironment(
    'APP_CHECK_ENABLED',
    defaultValue: false,
  );
  if (explicitEnable) return true;
  if (kReleaseMode) return true;
  return false;
}

/// Imprime el token de depuración para registrarlo en Firebase Console.
Future<void> _logDebugTokenIfAvailable() async {
  if (!kDebugMode) return;
  try {
    final token = await FirebaseAppCheck.instance
        .getToken()
        .timeout(const Duration(seconds: 5));
    if (token == null || token.isEmpty) return;
    debugPrint(
      '[appCheck] Token debug (App Check > Manage debug tokens): $token',
    );
  } catch (error) {
    debugPrint('[appCheck] No se pudo obtener token debug: $error');
  }
}
