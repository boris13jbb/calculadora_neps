import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'providers/app_state.dart';

class NepsApp extends StatefulWidget {
  const NepsApp({super.key});

  @override
  State<NepsApp> createState() => _NepsAppState();
}

class _NepsAppState extends State<NepsApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState()..initialize(launchUri: _launchUri);
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
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp(
        title: 'VICUNHA Calculadora Neps',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        scaffoldMessengerKey: AppState.messengerKey,
        home: const AppShell(),
      ),
    );
  }
}
