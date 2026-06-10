import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app.dart';
import 'platform/platform_init.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      registerPlatformPlugins();

      if (kIsWeb) {
        SemanticsBinding.instance.ensureSemantics();

        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          debugPrint('FlutterError: ${details.exceptionAsString()}');
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          debugPrint('Error de plataforma: $error');
          debugPrint('$stack');
          return true;
        };

        ErrorWidget.builder = (details) {
          return Material(
            color: const Color(0xFFF4F6F8),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al cargar la interfaz.\n${details.exception}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF1F2933)),
                ),
              ),
            ),
          );
        };
      }

      runApp(const NepsApp());
    },
    (error, stackTrace) {
      debugPrint('Error no controlado: $error');
      debugPrint('$stackTrace');
    },
  );
}
