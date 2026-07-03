import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../providers/app_state.dart';

/// Campos opcionales de producción para captura de registros.
class CaptureOptionalFields extends StatelessWidget {
  const CaptureOptionalFields({
    super.key,
    required this.appState,
    this.ultraCompact = false,
  });

  final AppState appState;
  final bool ultraCompact;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: ultraCompact ? 8 : 10,
      ),
    );

    final fields = [
      _FieldSpec('Turno', appState.turnoController, 'Ej: A'),
      _FieldSpec('Operario', appState.operarioController, 'Nombre'),
      _FieldSpec('Línea', appState.lineaProduccionController, 'Línea'),
      _FieldSpec('Observación', appState.observacionController, 'Notas'),
      _FieldSpec(
        'Acción inmediata',
        appState.accionInmediataController,
        'Acción tomada',
      ),
    ];

    if (ultraCompact) {
      return Column(
        children: [
          for (var i = 0; i < fields.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildField(fields[i], decoration)),
                if (i + 1 < fields.length) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _buildField(fields[i + 1], decoration)),
                ],
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      children: fields
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildField(f, decoration),
            ),
          )
          .toList(),
    );
  }

  Widget _buildField(_FieldSpec spec, InputDecoration decoration) {
    return TextField(
      controller: spec.controller,
      style: TextStyle(fontSize: ultraCompact ? 12 : 14),
      decoration: decoration.copyWith(
        labelText: spec.label,
        hintText: spec.hint,
      ),
      textInputAction: TextInputAction.next,
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
