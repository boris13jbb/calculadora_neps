import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/widgets/kpi_card.dart';

void main() {
  // Regresión: la barra de acento de KpiCard es un ColoredBox sin altura dentro
  // de un Row con CrossAxisAlignment.stretch. En un contexto de altura no
  // acotada (como el Dashboard, que usa SingleChildScrollView) esto provocaba
  // "RenderBox was not laid out: _RenderColoredBox" y dejaba la pantalla en
  // blanco. IntrinsicHeight debe acotar la altura y permitir el render.
  testWidgets(
    'KpiStrip se renderiza dentro de altura no acotada sin excepciones',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  KpiStrip(
                    cards: [
                      KpiCard(
                        label: 'Total registros',
                        value: '128',
                        icon: Icons.list_alt,
                      ),
                      KpiCard(
                        compact: true,
                        label: 'Total neps',
                        value: '1.234,5',
                        icon: Icons.analytics_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Si el layout fallara, tester registraría una excepción y el test caería.
      expect(tester.takeException(), isNull);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('1.234,5'), findsOneWidget);
    },
  );

  testWidgets(
    'KpiStrip compacto usa 2 columnas en ancho de teléfono',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: KpiStrip(
                compact: true,
                minCardWidth: 148,
                spacing: 6,
                cards: const [
                  KpiCard(
                    compact: true,
                    label: 'Visibles',
                    value: '24',
                    icon: Icons.list_alt,
                  ),
                  KpiCard(
                    compact: true,
                    label: 'Total neps',
                    value: '821',
                    icon: Icons.analytics_outlined,
                  ),
                  KpiCard(
                    compact: true,
                    label: 'Promedio',
                    value: '34',
                    icon: Icons.trending_up,
                  ),
                  KpiCard(
                    compact: true,
                    label: 'Críticos',
                    value: '0',
                    icon: Icons.error_outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final stripSize = tester.getSize(find.byType(KpiStrip));
      // Con 2×2 la altura debe quedar claramente por debajo de 4 tarjetas apiladas.
      expect(stripSize.height, lessThan(220));
    },
  );
}
