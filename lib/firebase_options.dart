import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions no esta configurado para $defaultTargetPlatform.',
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDNXZYpWDq4ysUOx5P5a5gNJi11q00wGT8',
    appId: '1:1000803867579:android:46394687f9f6983586429e',
    messagingSenderId: '1000803867579',
    projectId: 'vicunha-calculadora-neps',
    storageBucket: 'vicunha-calculadora-neps.firebasestorage.app',
  );
}
