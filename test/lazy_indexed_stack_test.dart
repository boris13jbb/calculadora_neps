import 'package:calculadora_neps/core/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contador de montajes para verificar lazy initState.
class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.id, required this.onMount});

  final String id;
  final void Function(String id) onMount;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount(widget.id);
  }

  @override
  Widget build(BuildContext context) => Text(widget.id);
}

void main() {
  testWidgets('solo monta la pestaña inicial al arrancar', (tester) async {
    final mounted = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          index: 0,
          children: [
            _MountProbe(id: 'inicio', onMount: mounted.add),
            _MountProbe(id: 'informes', onMount: mounted.add),
            _MountProbe(id: 'analytics', onMount: mounted.add),
          ],
        ),
      ),
    );

    expect(mounted, ['inicio']);
    expect(find.text('inicio'), findsOneWidget);
    expect(find.text('informes'), findsNothing);
    expect(find.text('analytics'), findsNothing);
  });

  testWidgets('monta Informes solo al navegar y conserva Inicio',
      (tester) async {
    final mounted = <String>[];
    var index = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => index = 1),
                  child: const Text('ir-informes'),
                ),
                Expanded(
                  child: LazyIndexedStack(
                    index: index,
                    children: [
                      _MountProbe(id: 'inicio', onMount: mounted.add),
                      _MountProbe(id: 'informes', onMount: mounted.add),
                      _MountProbe(id: 'analytics', onMount: mounted.add),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(mounted, ['inicio']);

    await tester.tap(find.text('ir-informes'));
    await tester.pumpAndSettle();

    expect(mounted, ['inicio', 'informes']);
    expect(find.text('informes'), findsOneWidget);
    // Inicio permanece montado (estado preservado offstage).
    expect(mounted.where((id) => id == 'inicio').length, 1);
  });

  testWidgets('Analíticas no se monta hasta visitarla', (tester) async {
    final mounted = <String>[];
    var index = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => index = 2),
                  child: const Text('ir-analytics'),
                ),
                Expanded(
                  child: LazyIndexedStack(
                    index: index,
                    children: [
                      _MountProbe(id: 'inicio', onMount: mounted.add),
                      _MountProbe(id: 'informes', onMount: mounted.add),
                      _MountProbe(id: 'analytics', onMount: mounted.add),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(mounted, isNot(contains('analytics')));
    expect(mounted, isNot(contains('informes')));

    await tester.tap(find.text('ir-analytics'));
    await tester.pumpAndSettle();

    expect(mounted, contains('analytics'));
    expect(mounted, isNot(contains('informes')));
  });
}
