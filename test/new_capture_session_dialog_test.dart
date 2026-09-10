import 'package:calculadora_neps/core/widgets/confirm_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<NewCaptureSessionChoice?> openNewSessionDialog(
    WidgetTester tester, {
    double width = 800,
  }) async {
    NewCaptureSessionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  choice = await confirmSaveBeforeNewCaptureSession(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return choice;
  }

  testWidgets('Cancelar del diálogo de nueva sesión no confirma acción',
      (tester) async {
    NewCaptureSessionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                choice = await confirmSaveBeforeNewCaptureSession(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(choice, NewCaptureSessionChoice.cancel);
  });

  testWidgets('Guardar y crear nueva sesión devuelve save', (tester) async {
    NewCaptureSessionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                choice = await confirmSaveBeforeNewCaptureSession(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y crear nueva sesión'));
    await tester.pumpAndSettle();
    expect(choice, NewCaptureSessionChoice.save);
  });

  testWidgets(
    'Descartar sin guardar pide segunda confirmación y puede cancelarse',
    (tester) async {
      var discardConfirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final first =
                      await confirmSaveBeforeNewCaptureSession(context);
                  if (first != NewCaptureSessionChoice.discard) return;
                  discardConfirmed =
                      await confirmDiscardUnsavedCaptureSession(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar sin guardar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(discardConfirmed, isFalse);
    },
  );

  testWidgets('Sí, descartar confirma el descarte', (tester) async {
    var discardConfirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                discardConfirmed =
                    await confirmDiscardUnsavedCaptureSession(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, descartar'));
    await tester.pumpAndSettle();
    expect(discardConfirmed, isTrue);
  });

  testWidgets('en pantallas estrechas muestra las tres acciones',
      (tester) async {
    await openNewSessionDialog(tester, width: 360);
    expect(find.text('Guardar y crear nueva sesión'), findsOneWidget);
    expect(find.text('Descartar sin guardar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}
