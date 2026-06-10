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

Future<bool> confirmClearTable(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Vaciar tabla'),
      content: const Text('Seguro que desea vaciar toda la tabla?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Vaciar'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmNewCaptureSession(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nueva sesion'),
      content: const Text(
        'Se eliminaran todos los registros de la sesion actual '
        'y se limpiaran los campos de captura. '
        'La tela y el lote configurados se conservaran.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Iniciar vacia'),
        ),
      ],
    ),
  );
  return result == true;
}
