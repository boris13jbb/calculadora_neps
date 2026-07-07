import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bootstrap/app_check_init.dart';
import 'bootstrap/firebase_init.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/auth_gate.dart';
import 'providers/analytics_provider.dart';
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';

class NepsApp extends StatefulWidget {
  const NepsApp({super.key});

  @override
  State<NepsApp> createState() => _NepsAppState();
}

class _NepsAppState extends State<NepsApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final AppState _appState;
  late final AnalyticsProvider _analyticsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _appState = AppState();
    _analyticsProvider = AnalyticsProvider();
    _authProvider.addListener(_onAuthChanged);

    if (!DefaultFirebaseOptions.isSupported) {
      _authProvider.initialize();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startupSequence());
    });
  }

  /// Arranque escalonado: UI primero, Firebase y datos después.
  Future<void> _startupSequence() async {
    await Future<void>.delayed(Duration.zero);

    if (DefaultFirebaseOptions.isSupported) {
      try {
        await initializeFirebaseCore();
        unawaited(initializeAppCheck());
        _authProvider.initialize();
      } catch (error, stackTrace) {
        debugPrint('Firebase no disponible al iniciar: $error');
        debugPrint('$stackTrace');
        _authProvider.initialize();
      }
    }

    try {
      await _appState.initialize(launchUri: _launchUri);
    } catch (error, stackTrace) {
      debugPrint('Error al inicializar datos locales: $error');
      debugPrint('$stackTrace');
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
      await _appState.ensureCloudConnected();
      await _appState.initializeNotifications();
    } catch (error, stackTrace) {
      debugPrint('Cloud sync tras login: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_appState.ensureCloudConnected());
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
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_onAuthChanged);
    _authProvider.dispose();
    _analyticsProvider.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _appState),
        ChangeNotifierProvider.value(value: _analyticsProvider),
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
