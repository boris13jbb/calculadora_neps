import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool> confirmDeleteRecord(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar registro'),
      content: const Text('Desea eliminar este registro?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmClearTable(
  BuildContext context, {
  required int recordCount,
}) async {
  final firstStep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Vaciar tabla personal'),
      content: Text(
        'Esta accion eliminara $recordCount registro(s) de su tabla '
        'personal de captura.\n\n'
        'Los demas usuarios del equipo conservan sus propios registros.\n\n'
        'Los informes guardados son visibles para todo el equipo y '
        'no se eliminan con esta accion.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (firstStep != true || !context.mounted) return false;

  final secondStep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmacion final'),
      content: const Text(
        'Si estos datos deben quedar disponibles para todo el equipo, '
        'guarde un informe antes de continuar.\n\n'
        'Confirma que desea vaciar su tabla personal? '
        'Esta accion no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Si, vaciar mi tabla'),
        ),
      ],
    ),
  );
  return secondStep == true;
}

Future<bool> confirmNewCaptureSession(
  BuildContext context, {
  required int recordCount,
}) async {
  final firstStep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nueva sesion'),
      content: Text(
        'Se eliminaran $recordCount registro(s) de su tabla personal '
        'y se limpiaran los campos de captura.\n\n'
        'La tela y el lote configurados se conservaran. '
        'Los informes guardados del equipo no se modifican.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (firstStep != true || !context.mounted) return false;

  final secondStep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmacion final'),
      content: const Text(
        'Si necesita compartir estos datos con el equipo, guarde un '
        'informe antes de iniciar una sesion vacia.\n\n'
        'Confirma iniciar una nueva sesion personal?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Si, iniciar vacia'),
        ),
      ],
    ),
  );
  return secondStep == true;
}
