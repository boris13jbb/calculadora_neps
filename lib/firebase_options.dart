import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions solo esta configurado para web.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'FirebaseOptions no esta configurado para Fuchsia.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDXX4MxQtESuyX5UF-WHB7g6Wcln5tOp48',
    appId: '1:1000803867579:web:24746bde769fd8ec86429e',
    messagingSenderId: '1000803867579',
    projectId: 'vicunha-calculadora-neps',
    authDomain: 'vicunha-calculadora-neps.firebaseapp.com',
    storageBucket: 'vicunha-calculadora-neps.firebasestorage.app',
  );
}
