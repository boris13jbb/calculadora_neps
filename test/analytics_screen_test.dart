import 'package:calculadora_neps/core/navigation/app_navigation.dart';
import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/features/analytics/analytics_screen.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AnalyticsScreen muestra titulo y filtros con datos',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appState = AppState();
    appState.isLoading = false;
    appState.records = [
      NepRecord(
        telar: '1',
        neps: 40,
        tela: 'T1',
        loteTrama: 'L1',
        createdAt: DateTime(2026, 6, 1),
      ),
    ];

    final auth = AuthProvider();
    auth.profile = AppUser(
      uid: 'u1',
      username: 'admin',
      role: AppUserRole.admin,
    );
    auth.status = AuthStatus.authenticated;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: AnalyticsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gráficas'), findsWidgets);
    expect(find.text('Agrupar por'), findsOneWidget);
    expect(find.text('Indicadores clave'), findsOneWidget);
    expect(find.text('Exportar PDF'), findsOneWidget);
    expect(find.text('Descargar gráfico'), findsOneWidget);

    appState.dispose();
  });
}
