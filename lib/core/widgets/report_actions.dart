import 'package:flutter/material.dart';

import '../../models/export_column.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'export_column_selector.dart';

Future<void> promptSaveReport(BuildContext context, AppState appState) async {
  if (appState.records.isEmpty) {
    appState.showMessage('No hay registros para guardar como informe.');
    return;
  }

  final nameController = TextEditingController(
    text: 'Informe ${appState.timestamp}',
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Guardar informe'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Nombre del informe',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  final name = nameController.text;
  nameController.dispose();

  if (confirmed == true && context.mounted) {
    await appState.saveCurrentReport(name);
  }
}

class _ShareReportResult {
  const _ShareReportResult({
    required this.format,
    required this.columns,
  });

  final String format;
  final Set<ExportColumn> columns;
}

Future<void> showShareReportMenu(
  BuildContext context,
  AppState appState,
) async {
  if (appState.visibleRecords.isEmpty) {
    appState.showMessage('No hay datos para compartir.');
    return;
  }

  if (appState.isExporting) return;

  final result = await showDialog<_ShareReportResult>(
    context: context,
    builder: (context) => _ShareReportDialog(
      recordCount: appState.visibleRecords.length,
      initialColumns: appState.exportColumns,
    ),
  );

  if (!context.mounted || result == null) return;

  appState.setExportColumns(result.columns);

  switch (result.format) {
    case 'csv':
      await appState.exportCsv(columns: result.columns);
    case 'excel':
      await appState.exportExcel(columns: result.columns);
    case 'pdf':
      await appState.exportPdf(columns: result.columns);
  }
}

bool captureActionsEnabled(AppState appState) =>
    appState.records.isNotEmpty && !appState.isExporting;

class _ShareReportDialog extends StatefulWidget {
  const _ShareReportDialog({
    required this.recordCount,
    required this.initialColumns,
  });

  final int recordCount;
  final Set<ExportColumn> initialColumns;

  @override
  State<_ShareReportDialog> createState() => _ShareReportDialogState();
}

class _ShareReportDialogState extends State<_ShareReportDialog> {
  late Set<ExportColumn> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<ExportColumn>.from(widget.initialColumns);
  }

  void _share(String format) {
    if (!ExportColumn.isValidSelection(_selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos una columna.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _ShareReportResult(format: format, columns: _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compartir registros'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Compartir ${widget.recordCount} registro(s). '
                'Elija las columnas y el formato.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              ExportColumnSelector(
                compact: true,
                selected: _selected,
                onChanged: (columns) => setState(() => _selected = columns),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          onPressed: () => _share('csv'),
          child: const Text('CSV'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          onPressed: () => _share('excel'),
          child: const Text('Excel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textDark,
          ),
          onPressed: () => _share('pdf'),
          child: const Text('PDF'),
        ),
      ],
    );
  }
}
