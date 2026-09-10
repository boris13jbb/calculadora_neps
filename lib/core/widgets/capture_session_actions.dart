import 'package:flutter/material.dart';

import '../../providers/app_state.dart';
import '../../services/personal_session_archive_service.dart';
import 'capture_optional_fields.dart';
import 'confirm_dialogs.dart';

Future<void> promptNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  if (appState.isSessionTransitionBusy) return;

  // Sin trabajo pendiente: abrir sesión vacía sin pedir guardar.
  if (!appState.hasCaptureSessionWork) {
    await appState.startEmptyCaptureSessionIfIdle();
    return;
  }

  final choice = await confirmSaveBeforeNewCaptureSession(context);
  if (!context.mounted) return;

  switch (choice) {
    case NewCaptureSessionChoice.cancel:
      // Cerrar diálogo / Atrás / toque fuera: no modifica nada.
      return;
    case NewCaptureSessionChoice.save:
      await _saveAndOpenNewCaptureSession(context, appState);
      return;
    case NewCaptureSessionChoice.discard:
      await _discardAndOpenNewCaptureSession(context, appState);
      return;
  }
}

/// Abre el historial de sesiones personales (archivo por UID, no informes de equipo).
Future<void> promptOpenPersonalSessionHistory(
  BuildContext context,
  AppState appState,
) async {
  final archives = await appState.loadPersonalSessionArchives();
  if (!context.mounted) return;

  if (archives.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay sesiones personales guardadas en este dispositivo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final selected = await showModalBottomSheet<PersonalCaptureSessionArchive>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: archives.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const ListTile(
                title: Text(
                  'Historial personal',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Sesiones guardadas en este dispositivo (no archivo de equipo).',
                ),
              );
            }
            final archive = archives[index - 1];
            final title = archive.name.trim().isEmpty
                ? 'Sesión ${archive.captureSessionId}'
                : archive.name;
            return ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(title),
              subtitle: Text(
                '${archive.savedAt.toLocal()} · ${archive.records.length} reg.',
              ),
              onTap: () => Navigator.pop(sheetContext, archive),
            );
          },
        ),
      );
    },
  );

  if (selected == null || !context.mounted) return;
  await appState.openPersonalCaptureArchive(selected);
}

Future<void> goToNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  await promptNewCaptureSession(context, appState);
  if (!context.mounted) return;
  appState.setNavigationIndex(1);
}

/// Guarda el trabajo de la sesión (incl. medición pendiente válida) y abre
/// una captura vacía. Si falla, conserva todo para reintentar.
Future<void> _saveAndOpenNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  if (appState.isSessionTransitionBusy) return;

  // 1) Si hay borrador en el formulario, intentar incluirlo una sola vez.
  if (appState.hasCaptureFormDraft) {
    final committed = await _tryCommitPendingMeasurement(context, appState);
    if (!committed) return;
  }

  if (!context.mounted) return;

  // 2) Persistencia durable de la sesión actual (sin borrar historial).
  final saved = await appState.persistActiveCaptureSession();
  if (!saved || !context.mounted) return;

  // 3) Solo tras éxito: rotar sessionId y vaciar campos.
  await appState.openEmptyCaptureSessionAfterSave();
}

/// Descarta solo el borrador / cambios no guardados y abre sesión vacía.
/// Conserva registros ya confirmados localmente, historial e informes.
Future<void> _discardAndOpenNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  if (appState.isSessionTransitionBusy) return;

  if (!await confirmDiscardUnsavedCaptureSession(context) || !context.mounted) {
    return;
  }

  if (appState.isSessionTransitionBusy) return;
  await appState.discardUnsavedDraftAndOpenEmptyCaptureSession();
}

/// Intenta agregar la medición pendiente respetando validaciones y confirmaciones.
/// Devuelve false si está incompleta (conserva datos) o el usuario cancela.
Future<bool> _tryCommitPendingMeasurement(
  BuildContext context,
  AppState appState,
) async {
  final record = appState.buildCaptureRecord();
  if (record == null) {
    // Validación fallida: el mensaje ya se mostró; no se pierden los datos.
    return false;
  }

  if (record.neps > 100) {
    if (!context.mounted) return false;
    if (!await confirmHighNepsValue(
      context,
      neps: record.neps,
      telar: record.telar,
    )) {
      return false;
    }
  }

  if (appState.isRecentDuplicate(record)) {
    if (!context.mounted) return false;
    if (!await confirmDuplicateRecord(context)) return false;
  }

  await appState.submitCaptureRecord(record);
  return true;
}
