import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calculadora_neps/app.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const NepsApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('La app muestra pantalla de login sin sesión',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(1280, 900));

    expect(find.text('VICUNHA Calculadora Neps'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(
        find.text('Recuperar contraseña (solo super admin)'), findsOneWidget);
  });

  testWidgets('Login responsive en móvil', (WidgetTester tester) async {
    await _pumpApp(tester, const Size(390, 844));

    expect(find.textContaining('VICUNHA'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
