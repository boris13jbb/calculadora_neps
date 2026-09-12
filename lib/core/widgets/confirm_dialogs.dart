import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';

/// Resultado del diálogo antes de iniciar una nueva sesión de captura.
enum NewCaptureSessionChoice {
  /// Cierra sin modificar datos ni sesión.
  cancel,

  /// Guarda el trabajo pendiente y abre sesión vacía.
  save,

  /// Descarta solo el borrador no guardado y abre sesión vacía.
  discard,
}

Future<bool> confirmDeleteRecord(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar registro'),
      content: const Text(
        '¿Desea eliminar este registro?\n'
        'Esta acción eliminará el registro sincronizado y no se puede deshacer.',
      ),
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

/// Diálogo con tres opciones: guardar, descartar borrador o cancelar.
///
/// Cerrar con Atrás o tocando fuera equivale a [NewCaptureSessionChoice.cancel].
Future<NewCaptureSessionChoice> confirmSaveBeforeNewCaptureSession(
  BuildContext context,
) async {
  final result = await showDialog<NewCaptureSessionChoice>(
    context: context,
    builder: (context) {
      final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.phone;
      var busy = false;

      return StatefulBuilder(
        builder: (context, setState) {
          void choose(NewCaptureSessionChoice choice) {
            if (busy) return;
            setState(() => busy = true);
            Navigator.pop(context, choice);
          }

          final saveButton = FilledButton(
            onPressed: busy ? null : () => choose(NewCaptureSessionChoice.save),
            child: const Text('Guardar y crear nueva sesión'),
          );
          final discardButton = TextButton(
            onPressed:
                busy ? null : () => choose(NewCaptureSessionChoice.discard),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Descartar sin guardar'),
          );
          final cancelButton = TextButton(
            onPressed:
                busy ? null : () => choose(NewCaptureSessionChoice.cancel),
            child: const Text('Cancelar'),
          );

          return AlertDialog(
            title: const Text('Guardar antes de iniciar una nueva sesión'),
            content: const Text(
              '¿Deseas guardar los registros y los datos pendientes de esta '
              'sesión antes de comenzar una nueva? Después de guardar, todos '
              'los campos quedarán vacíos.',
            ),
            actionsAlignment:
                narrow ? MainAxisAlignment.center : MainAxisAlignment.end,
            actions: narrow
                ? [
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          saveButton,
                          const SizedBox(height: 8),
                          discardButton,
                          cancelButton,
                        ],
                      ),
                    ),
                  ]
                : [
                    cancelButton,
                    discardButton,
                    saveButton,
                  ],
          );
        },
      );
    },
  );
  return result ?? NewCaptureSessionChoice.cancel;
}

/// Segunda confirmación antes de descartar el borrador sin guardar.
Future<bool> confirmDiscardUnsavedCaptureSession(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.phone;
      var busy = false;

      return StatefulBuilder(
        builder: (context, setState) {
          void choose(bool value) {
            if (busy) return;
            setState(() => busy = true);
            Navigator.pop(context, value);
          }

          final keepEditing = TextButton(
            onPressed: busy ? null : () => choose(false),
            child: const Text('Seguir editando'),
          );
          final discard = FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: busy ? null : () => choose(true),
            child: const Text('Sí, descartar'),
          );

          return AlertDialog(
            title: const Text('¿Descartar los cambios sin guardar?'),
            content: const Text(
              'Se descartarán los datos pendientes de esta sesión y se abrirá '
              'una nueva con todos los campos vacíos. Los registros e informes '
              'ya guardados se conservarán.',
            ),
            actionsAlignment:
                narrow ? MainAxisAlignment.center : MainAxisAlignment.end,
            actions: narrow
                ? [
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          discard,
                          const SizedBox(height: 8),
                          keepEditing,
                        ],
                      ),
                    ),
                  ]
                : [
                    keepEditing,
                    discard,
                  ],
          );
        },
      );
    },
  );
  return result == true;
}

@Deprecated('Usar confirmSaveBeforeNewCaptureSession')
Future<bool> confirmNewCaptureSession(
  BuildContext context, {
  required int recordCount,
}) async {
  final choice = await confirmSaveBeforeNewCaptureSession(context);
  return choice == NewCaptureSessionChoice.save;
}
