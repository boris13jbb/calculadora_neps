import 'package:flutter/material.dart';

import '../../providers/app_state.dart';
import 'confirm_dialogs.dart';

Future<void> promptNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  if (appState.records.isEmpty) {
    appState.clearCaptureFields();
    appState.showMessage('Sesion lista. Agregue el primer registro.');
    return;
  }

  if (await confirmNewCaptureSession(
        context,
        recordCount: appState.records.length,
      ) &&
      context.mounted) {
    await appState.startNewCaptureSession();
  }
}

Future<void> goToNewCaptureSession(
  BuildContext context,
  AppState appState,
) async {
  if (appState.records.isEmpty) {
    appState.clearCaptureFields();
    appState.setNavigationIndex(1);
    return;
  }

  if (await confirmNewCaptureSession(
        context,
        recordCount: appState.records.length,
      ) &&
      context.mounted) {
    await appState.startNewCaptureSession();
    appState.setNavigationIndex(1);
  }
}
