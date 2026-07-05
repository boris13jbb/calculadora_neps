import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/vicunha_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Etiquetas de navegación equivalentes a [AppNavigation.all], usadas para
/// validar el sidebar profesional de escritorio de forma aislada (sin depender
/// de Firebase ni del `AuthGate`, que en pruebas siempre muestra el login).
const _labels = <String>[
  'Inicio',
  'Gráficas',
  'Captura',
  'Registros',
  'Alertas',
  'Telas',
  'Informes',
  'Exportar',
  'Usuarios',
  'Config',
];

List<VicunhaNavDestination> _buildDestinations({int alertsBadge = 0}) {
  return [
    for (final label in _labels)
      VicunhaNavDestination(
        label: label,
        icon: Icons.circle_outlined,
        selectedIcon: Icons.circle,
        badgeCount: label == 'Alertas' ? alertsBadge : 0,
      ),
  ];
}

Future<void> _pumpSidebar(
  WidgetTester tester, {
  required int selectedIndex,
  required ValueChanged<int> onSelected,
  bool extended = true,
  int alertsBadge = 0,
  VoidCallback? onToggle,
  VoidCallback? onSignOut,
}) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: Row(
          children: [
            VicunhaSidebar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: _buildDestinations(alertsBadge: alertsBadge),
              extended: extended,
              onToggleExtended: onToggle,
              userName: 'Ana Gómez',
              userRole: 'Supervisor',
              onSignOut: onSignOut,
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VicunhaSidebar (navegación escritorio)', () {
    testWidgets('expandido muestra marca, etiquetas y usuario/rol',
        (WidgetTester tester) async {
      await _pumpSidebar(
        tester,
        selectedIndex: 0,
        onSelected: (_) {},
      );

      expect(find.text('VICUNHA'), findsOneWidget);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Supervisor'), findsOneWidget);
    });

    testWidgets('tocar un destino notifica el índice correcto',
        (WidgetTester tester) async {
      int? selected;
      await _pumpSidebar(
        tester,
        selectedIndex: 0,
        onSelected: (index) => selected = index,
      );

      await tester.tap(find.text('Registros'));
      await tester.pumpAndSettle();
      expect(selected, _labels.indexOf('Registros'));

      await tester.tap(find.text('Exportar'));
      await tester.pumpAndSettle();
      expect(selected, _labels.indexOf('Exportar'));
    });

    testWidgets('colapsado oculta etiquetas de texto y muestra solo iconos',
        (WidgetTester tester) async {
      await _pumpSidebar(
        tester,
        selectedIndex: 0,
        onSelected: (_) {},
        extended: false,
      );

      expect(find.text('VICUNHA'), findsNothing);
      for (final label in _labels) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('badge de alertas críticas muestra el contador',
        (WidgetTester tester) async {
      await _pumpSidebar(
        tester,
        selectedIndex: 0,
        onSelected: (_) {},
        alertsBadge: 3,
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('el botón de colapsar y cerrar sesión invocan sus callbacks',
        (WidgetTester tester) async {
      var toggled = false;
      var signedOut = false;
      await _pumpSidebar(
        tester,
        selectedIndex: 0,
        onSelected: (_) {},
        onToggle: () => toggled = true,
        onSignOut: () => signedOut = true,
      );

      await tester.tap(find.byTooltip('Colapsar menú'));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
    });
  });
}
