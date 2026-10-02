import 'package:flutter/material.dart';

/// [IndexedStack] que solo monta hijos la primera vez que se visitan.
///
/// Evita que pantallas pesadas (Informes, Analíticas) ejecuten `initState`
/// y consultas Firestore al login. Una vez activado, el hijo permanece en el
/// árbol (offstage) para conservar estado de filtros/scroll.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.sizing = StackFit.loose,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
  });

  final int index;
  final List<Widget> children;
  final StackFit sizing;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  @override
  State<LazyIndexedStack> createState() => LazyIndexedStackState();
}

@visibleForTesting
class LazyIndexedStackState extends State<LazyIndexedStack> {
  late Set<int> _activated;

  /// Índices ya montados (para pruebas).
  @visibleForTesting
  Set<int> get activatedIndexes => Set<int>.unmodifiable(_activated);

  @override
  void initState() {
    super.initState();
    _activated = {_safeIndex(widget.index, widget.children.length)};
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lengthChanged =
        oldWidget.children.length != widget.children.length;
    if (lengthChanged) {
      // Nueva lista de destinos (p. ej. cambio de permisos): solo tab actual.
      _activated = {_safeIndex(widget.index, widget.children.length)};
      return;
    }
    final next = _safeIndex(widget.index, widget.children.length);
    if (!_activated.contains(next)) {
      setState(() => _activated.add(next));
    }
  }

  static int _safeIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return length - 1;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _safeIndex(widget.index, widget.children.length);
    return IndexedStack(
      index: safeIndex,
      sizing: widget.sizing,
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      children: List<Widget>.generate(widget.children.length, (i) {
        if (!_activated.contains(i)) {
          return const SizedBox.shrink();
        }
        return widget.children[i];
      }),
    );
  }
}
