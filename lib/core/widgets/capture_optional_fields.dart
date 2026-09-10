import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../providers/app_state.dart';
import 'app_input_decoration.dart';

/// Campos opcionales de producción para captura de registros.
///
/// Se agrupan en «Datos adicionales» para no competir visualmente con
/// Tela, Lote, Telar y Neps. Los controladores viven en [AppState], así que
/// los valores se conservan al colapsar la sección.
///
/// No usa [ExpansionTile]: al combinarlo con setState/teclado provocaba
/// dispose de campos y asserts `_dependents.isEmpty` en móvil.
class CaptureOptionalFields extends StatefulWidget {
  const CaptureOptionalFields({
    super.key,
    required this.appState,
    this.ultraCompact = false,
    this.collapsible = true,
    this.initiallyExpanded = false,
  });

  final AppState appState;
  final bool ultraCompact;

  /// Si es true, muestra un bloque colapsable «Datos adicionales».
  final bool collapsible;

  final bool initiallyExpanded;

  @override
  State<CaptureOptionalFields> createState() => CaptureOptionalFieldsState();
}

class CaptureOptionalFieldsState extends State<CaptureOptionalFields> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  /// Abre la sección (p. ej. si un campo oculto tiene error).
  void expandAndFocus() {
    if (!_expanded) {
      setState(() => _expanded = true);
    }
  }

  bool get isExpanded => _expanded;

  void _toggle() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _buildFieldsColumn();

    if (!widget.collapsible) {
      return fields;
    }

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Datos adicionales',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Turno, operario, línea, observación y acción',
                            style: TextStyle(
                              fontSize: widget.ultraCompact ? 11 : 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textDark,
                    ),
                  ],
                ),
              ),
            ),
            // Controllers viven en AppState: al colapsar se pierde el TextField,
            // no el valor. Se hace unfocus antes para no chocar con el IME.
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: fields,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsColumn() {
    final specs = [
      _FieldSpec('Turno', widget.appState.turnoController, 'Ej: A'),
      _FieldSpec('Operario', widget.appState.operarioController, 'Nombre'),
      _FieldSpec('Línea', widget.appState.lineaProduccionController, 'Línea'),
      _FieldSpec(
        'Observación',
        widget.appState.observacionController,
        'Notas',
      ),
      _FieldSpec(
        'Acción inmediata',
        widget.appState.accionInmediataController,
        'Acción tomada',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) SizedBox(height: widget.ultraCompact ? 10 : 14),
          _buildField(specs[i]),
        ],
      ],
    );
  }

  Widget _buildField(_FieldSpec spec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CaptureFieldLabel(spec.label),
        TextField(
          controller: spec.controller,
          style: TextStyle(
            fontSize: widget.ultraCompact ? 14 : 16,
            color: AppColors.textDark,
          ),
          decoration: appInputDecoration(
            spec.hint,
            size: AppInputSize.comfortable,
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.label, this.controller, this.hint);

  final String label;
  final TextEditingController controller;
  final String hint;
}

Future<bool> confirmHighNepsValue(
  BuildContext context, {
  required double neps,
  required String telar,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Valor de neps muy alto'),
      content: Text(
        'El telar $telar registrará $neps neps.\n\n'
        'Este valor es muy alto. ¿Está seguro de guardar el registro?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí, guardar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmDuplicateRecord(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Registro duplicado'),
      content: const Text(
        'Ya existe un registro idéntico reciente (mismo telar, tela, lote y neps). '
        '¿Desea guardarlo de todos modos?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Guardar igual'),
        ),
      ],
    ),
  );
  return result ?? false;
}
