import 'package:calculadora_neps/app.dart';
import 'package:calculadora_neps/core/widgets/vicunha_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpDesktopApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const NepsApp());
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> pumpMobileApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const NepsApp());
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> tapSidebar(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(VicunhaSidebar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapBottomNavIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navegacion escritorio', () {
    testWidgets('sidebar navega entre pantallas principales',
        (WidgetTester tester) async {
      await pumpDesktopApp(tester);

      expect(find.text('Inicio / Panel principal'), findsOneWidget);

      await tapSidebar(tester, 'Captura');
      expect(find.text('Captura de registros'), findsOneWidget);

      await tapSidebar(tester, 'Registros');
      expect(find.text('Importar CSV/Excel'), findsOneWidget);

      await tapSidebar(tester, 'Telas');
      expect(find.text('Catalogo de telas'), findsWidgets);

      await tapSidebar(tester, 'Informes');
      expect(find.text('Informes guardados'), findsWidgets);

      await tapSidebar(tester, 'Exportar');
      expect(find.text('Exportar y compartir'), findsWidgets);

      await tapSidebar(tester, 'Inicio');
      expect(find.text('Inicio / Panel principal'), findsOneWidget);
    });

    testWidgets('accesos rapidos navegan correctamente',
        (WidgetTester tester) async {
      await pumpDesktopApp(tester);

      await tester.tap(find.text('Ver registros'));
      await tester.pumpAndSettle();
      expect(find.text('Importar CSV/Excel'), findsOneWidget);

      await tapSidebar(tester, 'Inicio');

      await tester.tap(find.text('Catalogo telas'));
      await tester.pumpAndSettle();
      expect(find.text('Catalogo de telas'), findsWidgets);

      await tapSidebar(tester, 'Inicio');

      await tester.tap(find.text('Exportar').last);
      await tester.pumpAndSettle();
      expect(find.text('Exportar y compartir'), findsWidgets);
    });

    testWidgets('pantalla exportar muestra acciones de exportacion',
        (WidgetTester tester) async {
      await pumpDesktopApp(tester);

      await tapSidebar(tester, 'Exportar');

      expect(find.text('CSV'), findsOneWidget);
      expect(find.text('Excel'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Imprimir'), findsOneWidget);
      expect(find.text('Copiar tabla'), findsOneWidget);
      expect(find.text('Guardar informe actual'), findsOneWidget);
    });

    testWidgets('pantalla registros muestra filtros e importar',
        (WidgetTester tester) async {
      await pumpDesktopApp(tester);

      await tapSidebar(tester, 'Registros');

      expect(find.text('Importar CSV/Excel'), findsOneWidget);
      expect(find.text('Vaciar tabla'), findsOneWidget);
      expect(find.text('Filtrar'), findsOneWidget);
    });
  });

  group('Navegacion movil', () {
    testWidgets('bottom bar navega entre pantallas', (WidgetTester tester) async {
      await pumpMobileApp(tester);

      expect(find.text('Inicio / Panel principal'), findsOneWidget);

      await tapBottomNavIcon(tester, Icons.add_circle_outline);
      expect(find.text('Captura de registros'), findsOneWidget);

      await tapBottomNavIcon(tester, Icons.table_chart_outlined);
      expect(find.text('Importar'), findsOneWidget);

      await tapBottomNavIcon(tester, Icons.texture_outlined);
      expect(find.text('Catalogo de telas'), findsWidgets);
    });
  });

  group('Captura UI', () {
    testWidgets('formulario de captura visible en escritorio',
        (WidgetTester tester) async {
      await pumpDesktopApp(tester);

      await tapSidebar(tester, 'Captura');

      expect(find.text('Nuevo registro'), findsOneWidget);
      expect(find.text('Tela / Tejido'), findsWidgets);
      expect(find.text('Lote de trama'), findsWidgets);
      expect(find.text('Agregar'), findsOneWidget);
      expect(find.text('Limpiar campos'), findsOneWidget);
      expect(find.text('Vaciar registros'), findsOneWidget);
    });
  });
}
