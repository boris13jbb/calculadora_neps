import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState muestra título, mensaje y acción', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin datos',
            message: 'Mensaje de prueba',
            actions: [
              EmptyStateAction(
                label: 'Acción',
                onPressed: () => tapped = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Mensaje de prueba'), findsOneWidget);
    expect(find.text('Acción'), findsOneWidget);

    await tester.tap(find.text('Acción'));
    expect(tapped, isTrue);
  });
}
