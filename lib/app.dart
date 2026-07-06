import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bootstrap/firebase_init.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/auth_gate.dart';
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';

class NepsApp extends StatefulWidget {
  const NepsApp({super.key});

  @override
  State<NepsApp> createState() => _NepsAppState();
}

class _NepsAppState extends State<NepsApp> {
  late final AuthProvider _authProvider;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _appState = AppState()..initialize(launchUri: _launchUri);
    _authProvider.addListener(_onAuthChanged);

    if (DefaultFirebaseOptions.isSupported) {
      // Tests y arranque en frío: evitar AuthStatus.unknown perpetuo sin Firebase.
      if (Firebase.apps.isEmpty) {
        _authProvider.initialize();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_bootstrapFirebase());
      });
    } else {
      _authProvider.initialize();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_appState.initializeNotifications());
      });
    }
  }

  Future<void> _bootstrapFirebase() async {
    try {
      await initializeFirebaseApp();
      _authProvider.initialize();
    } catch (error, stackTrace) {
      debugPrint('Firebase no disponible al iniciar: $error');
      debugPrint('$stackTrace');
      _authProvider.initialize();
    }
  }

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated && _authProvider.profile != null) {
      _appState.applyAuthProfile(_authProvider.profile!);
      unawaited(_connectCloudAfterAuth());
      return;
    }

    if (_authProvider.status == AuthStatus.unauthenticated) {
      _appState.resetCloudSession();
    }
  }

  Future<void> _connectCloudAfterAuth() async {
    try {
      await _appState.reconnectCloudIfNeeded();
      await _appState.initializeNotifications();
    } catch (error, stackTrace) {
      debugPrint('Cloud sync tras login: $error');
      debugPrint('$stackTrace');
    }
  }

  Uri? get _launchUri {
    if (!kIsWeb || Uri.base.queryParameters.isEmpty) return null;

    const shortcutKeys = {
      'pantalla',
      'screen',
      'telar',
      'neps',
      'lote',
      'lote_trama',
      'tela',
      'accion',
    };

    final hasShortcutParam = Uri.base.queryParameters.keys.any(
      (key) => shortcutKeys.contains(key.toLowerCase()),
    );

    return hasShortcutParam ? Uri.base : null;
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _appState),
      ],
      child: MaterialApp(
        title: 'VICUNHA Calculadora Neps',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        scaffoldMessengerKey: AppState.messengerKey,
        home: const AuthGate(child: AppShell()),
      ),
    );
  }
}
