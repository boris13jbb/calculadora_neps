import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'app_check_init.dart';

/// Inicializa Firebase Core sin bloquear la UI con App Check.
Future<void> initializeFirebaseCore() async {
  if (!DefaultFirebaseOptions.isSupported) return;
  if (Firebase.apps.isNotEmpty) return;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Inicializa Firebase y activa App Check en segundo plano.
Future<void> initializeFirebaseApp() async {
  await initializeFirebaseCore();
  unawaited(initializeAppCheck());
}
