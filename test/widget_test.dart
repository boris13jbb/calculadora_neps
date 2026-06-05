import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/main.dart';

void main() {
  testWidgets('La app carga la pantalla principal', (WidgetTester tester) async {
    await tester.pumpWidget(const NepsApp());
    await tester.pumpAndSettle();

    expect(find.text('VICUNHA'), findsOneWidget);
    expect(find.text('Numero de Telar'), findsOneWidget);
    expect(find.text('Cantidad de Neps'), findsOneWidget);
  });
}
