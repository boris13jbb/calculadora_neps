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
}
