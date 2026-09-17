import 'package:flutter/material.dart';

import '../../models/export_column.dart';
import '../../models/nep_record.dart';
import '../../models/pdf_report_style.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'export_column_selector.dart';
import 'report_style_selector.dart';

/// Guarda un informe desde Exportar / Registros usando [AppState.visibleRecords].
Future<void> promptSaveReport(
  BuildContext context,
  AppState appState, {
  List<NepRecord>? recordsOverride,
}) async {
  final source = List<NepRecord>.from(
    recordsOverride ?? appState.visibleRecords,
  );
  if (source.isEmpty) {
    appState.showMessage('No hay registros para guardar como informe.');
    return;
  }

  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SaveReportDialog(
      initialName: 'Informe ${appState.timestamp}',
      style: appState.pdfReportStyle,
      recordCount: source.length,
    ),
  );

  if (name != null && name.trim().isNotEmpty && context.mounted) {
    await appState.saveCurrentReport(
      name.trim(),
      recordsOverride: recordsOverride,
    );
  }
}

/// Guarda un informe solo con pendientes de la sesión de Captura activa.
///
/// Cada guardado crea un informe independiente con exactamente la selección
/// del usuario. Tras éxito marca esos IDs; no mezcla historial ni workspace.
Future<void> promptSaveCaptureSessionReport(
  BuildContext context,
  AppState appState,
) async {
  final eligible = List<NepRecord>.from(appState.pendingCaptureSessionRecords);
  if (eligible.isEmpty) {
    appState
        .showMessage('No hay registros pendientes de guardar en esta sesión.');
    return;
  }
  if (appState.isExporting) return;

  final result = await showDialog<_SaveSessionReportResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SaveCaptureSessionReportDialog(
      eligibleRecords: eligible,
      initialName: 'Informe ${appState.timestamp}',
      style: appState.pdfReportStyle,
      formatDateTime: appState.formatDateTime,
      formatNeps: appState.formatDecimal,
    ),
  );

  if (!context.mounted || result == null) return;
  if (result.selectedRecords.isEmpty) {
    appState.showMessage('Seleccione al menos un registro.');
    return;
  }

  await appState.saveCaptureReport(
    result.name,
    sourceRecords: result.selectedRecords,
  );
}

class _SaveSessionReportResult {
  const _SaveSessionReportResult({
    required this.name,
    required this.selectedRecords,
  });

  final String name;
  final List<NepRecord> selectedRecords;
}

/// Diálogo: nombre + selección explícita de registros pendientes de la sesión.
class SaveCaptureSessionReportDialog extends StatefulWidget {
  const SaveCaptureSessionReportDialog({
    super.key,
    required this.eligibleRecords,
    required this.initialName,
    required this.style,
    required this.formatDateTime,
    required this.formatNeps,
  });

  final List<NepRecord> eligibleRecords;
  final String initialName;
  final PdfReportStyle style;
  final String Function(DateTime date) formatDateTime;
  final String Function(double neps) formatNeps;

  @override
  State<SaveCaptureSessionReportDialog> createState() =>
      SaveCaptureSessionReportDialogState();
}

class SaveCaptureSessionReportDialogState
    extends State<SaveCaptureSessionReportDialog> {
  late final TextEditingController _nameController;
  final _focusNode = FocusNode();
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    final latest = _latestEligible();
    _selectedIds = latest == null ? <String>{} : {latest.id};
  }

  NepRecord? _latestEligible() {
    if (widget.eligibleRecords.isEmpty) return null;
    return widget.eligibleRecords.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<NepRecord> get selectedRecords => widget.eligibleRecords
      .where((record) => _selectedIds.contains(record.id))
      .toList(growable: false);

  int get selectedCount => _selectedIds.length;

  bool get canSave =>
      selectedCount > 0 && _nameController.text.trim().isNotEmpty;

  void selectPending() {
    setState(() {
      _selectedIds = widget.eligibleRecords.map((r) => r.id).toSet();
    });
  }

  void clearSelection() {
    setState(() => _selectedIds = <String>{});
  }

  void toggleRecord(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.pop(context);
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indique un nombre para el informe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un registro.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _focusNode.unfocus();
    Navigator.pop(
      context,
      _SaveSessionReportResult(
        name: name,
        selectedRecords: selectedRecords,
      ),
    );
  }

  String _countLabel() {
    if (selectedCount == 1) return 'Guardar 1 registro';
    return 'Guardar $selectedCount registros';
  }

  String _rowLabel(NepRecord record) {
    final time = widget.formatDateTime(record.createdAt).split(' ').last;
    return '$time | Telar ${record.telar} | Tela ${record.tela} | '
        'Lote ${record.loteTrama} | Neps ${widget.formatNeps(record.neps)}';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final maxListHeight = (media.height * 0.32).clamp(120.0, 260.0);

    return AlertDialog(
      title: const Text('Guardar informe'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
                decoration: const InputDecoration(
                  labelText: 'Nombre del informe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _countLabel(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Seleccione los registros de esta sesión que desea guardar.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: selectPending,
                    child: const Text('Seleccionar pendientes'),
                  ),
                  OutlinedButton(
                    onPressed: clearSelection,
                    child: const Text('Limpiar selección'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedCount == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Seleccione al menos un registro.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: Material(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.eligibleRecords.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (context, index) {
                      final record = widget.eligibleRecords[index];
                      final checked = _selectedIds.contains(record.id);
                      return CheckboxListTile(
                        dense: true,
                        value: checked,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        title: Text(
                          _rowLabel(record),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) => toggleRecord(record.id, value),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ReportModeSummary(style: widget.style),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canSave ? _confirm : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Diálogo de guardado con controller de ciclo de vida correcto.
///
/// Evita el fallo clásico de crear/dispose un [TextEditingController] fuera
/// del State mientras el IME o la animación de cierre aún lo referencian.
class _SaveReportDialog extends StatefulWidget {
  const _SaveReportDialog({
    required this.initialName,
    required this.style,
    required this.recordCount,
  });

  final String initialName;
  final PdfReportStyle style;
  final int recordCount;

  @override
  State<_SaveReportDialog> createState() => _SaveReportDialogState();
}

class _SaveReportDialogState extends State<_SaveReportDialog> {
  late final TextEditingController _nameController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.pop(context);
  }

  void _confirm() {
    _focusNode.unfocus();
    Navigator.pop(context, _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Guardar informe'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirm(),
                decoration: const InputDecoration(
                  labelText: 'Nombre del informe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.recordCount == 1
                    ? 'Se guardará 1 registro.'
                    : 'Se guardarán ${widget.recordCount} registros.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              _ReportModeSummary(style: widget.style),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ShareReportResult {
  const _ShareReportResult({
    required this.format,
    required this.columns,
    required this.style,
    required this.selectedRecords,
  });

  final String format;
  final Set<ExportColumn> columns;
  final PdfReportStyle style;
  final List<NepRecord> selectedRecords;
}

/// Compartir desde Captura: solo registros de hoy del usuario, por selección.
///
/// [initiallySelectedRecord] fija la selección inicial (p. ej. fila Compartir).
/// Si es null, se selecciona únicamente [AppState.latestTodayCaptureRecord].
Future<void> showShareReportMenu(
  BuildContext context,
  AppState appState, {
  NepRecord? initiallySelectedRecord,
}) async {
  final eligible = appState.todayCaptureRecords;
  if (eligible.isEmpty) {
    appState.showMessage('No hay registros de hoy para compartir.');
    return;
  }

  if (appState.isExporting) return;

  final defaultRecord =
      initiallySelectedRecord ?? appState.latestTodayCaptureRecord;

  final result = await showDialog<_ShareReportResult>(
    context: context,
    builder: (context) => ShareCaptureRecordsDialog(
      eligibleRecords: eligible,
      initialSelectedId: defaultRecord?.id,
      initialColumns: appState.exportColumns,
      initialStyle: appState.pdfReportStyle,
      formatDateTime: appState.formatDateTime,
      formatNeps: appState.formatDecimal,
    ),
  );

  if (!context.mounted || result == null) return;
  if (result.selectedRecords.isEmpty) {
    appState.showMessage('Seleccione al menos un registro.');
    return;
  }

  appState.setExportColumns(result.columns);
  appState.setPdfReportStyle(result.style);

  switch (result.format) {
    case 'csv':
      await appState.exportCsv(
        columns: result.columns,
        style: result.style,
        sourceRecords: result.selectedRecords,
      );
    case 'excel':
      await appState.exportExcel(
        columns: result.columns,
        style: result.style,
        sourceRecords: result.selectedRecords,
      );
    case 'pdf':
      await appState.exportPdf(
        columns: result.columns,
        style: result.style,
        sourceRecords: result.selectedRecords,
      );
  }
}

bool captureActionsEnabled(AppState appState) =>
    appState.captureSessionRecords.isNotEmpty && !appState.isExporting;

/// Captura → Guardar: solo si hay pendientes de la sesión actual.
bool captureSaveEnabled(AppState appState) =>
    appState.pendingCaptureSessionRecords.isNotEmpty && !appState.isExporting;

/// Diálogo de selección explícita para Captura → Compartir.
///
/// Público para pruebas de widget; los checkboxes son solo estado temporal.
class ShareCaptureRecordsDialog extends StatefulWidget {
  const ShareCaptureRecordsDialog({
    super.key,
    required this.eligibleRecords,
    required this.initialColumns,
    required this.initialStyle,
    required this.formatDateTime,
    required this.formatNeps,
    this.initialSelectedId,
  });

  final List<NepRecord> eligibleRecords;
  final String? initialSelectedId;
  final Set<ExportColumn> initialColumns;
  final PdfReportStyle initialStyle;
  final String Function(DateTime date) formatDateTime;
  final String Function(double neps) formatNeps;

  @override
  State<ShareCaptureRecordsDialog> createState() =>
      ShareCaptureRecordsDialogState();
}

class ShareCaptureRecordsDialogState extends State<ShareCaptureRecordsDialog> {
  late Set<String> _selectedIds;
  late Set<ExportColumn> _selectedColumns;
  late PdfReportStyle _style;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialSelectedId;
    final hasInitial = initialId != null &&
        widget.eligibleRecords.any((record) => record.id == initialId);
    _selectedIds = hasInitial ? {initialId!} : <String>{};
    _selectedColumns = Set<ExportColumn>.from(widget.initialColumns);
    _style = widget.initialStyle;
  }

  List<NepRecord> get selectedRecords => widget.eligibleRecords
      .where((record) => _selectedIds.contains(record.id))
      .toList(growable: false);

  int get selectedCount => _selectedIds.length;

  bool get canShare =>
      selectedCount > 0 && ExportColumn.isValidSelection(_selectedColumns);

  void selectAllToday() {
    setState(() {
      _selectedIds = widget.eligibleRecords.map((r) => r.id).toSet();
    });
  }

  void clearSelection() {
    setState(() => _selectedIds = <String>{});
  }

  void toggleRecord(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _share(String format) {
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un registro.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!ExportColumn.isValidSelection(_selectedColumns)) {
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
      _ShareReportResult(
        format: format,
        columns: _selectedColumns,
        style: _style,
        selectedRecords: selectedRecords,
      ),
    );
  }

  String _shareCountLabel() {
    final count = selectedCount;
    if (count == 1) return 'Compartir 1 registro';
    return 'Compartir $count registros';
  }

  String _rowLabel(NepRecord record) {
    final time = widget.formatDateTime(record.createdAt).split(' ').last;
    return '$time | Telar ${record.telar} | Tela ${record.tela} | '
        'Lote ${record.loteTrama} | Neps ${widget.formatNeps(record.neps)}';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final maxListHeight = (media.height * 0.35).clamp(140.0, 280.0);

    return AlertDialog(
      title: const Text('Compartir registros'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _shareCountLabel(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'El registro más reciente está seleccionado.\n'
                'Puedes elegir otros registros de hoy si deseas compartirlos juntos.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: selectAllToday,
                    child: const Text('Seleccionar todos los de hoy'),
                  ),
                  OutlinedButton(
                    onPressed: clearSelection,
                    child: const Text('Limpiar selección'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedCount == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Seleccione al menos un registro.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: Material(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.eligibleRecords.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (context, index) {
                      final record = widget.eligibleRecords[index];
                      final checked = _selectedIds.contains(record.id);
                      return CheckboxListTile(
                        dense: true,
                        value: checked,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        title: Text(
                          _rowLabel(record),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) => toggleRecord(record.id, value),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ExportColumnSelector(
                compact: true,
                selected: _selectedColumns,
                onChanged: (columns) =>
                    setState(() => _selectedColumns = columns),
              ),
              const SizedBox(height: 14),
              ReportStyleSelector(
                compact: true,
                selected: _style,
                onChanged: (style) => setState(() => _style = style),
                titleStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Formato de exportación',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 360;
                  final buttons = [
                    _ShareFormatButton(
                      label: 'CSV',
                      color: AppColors.primaryGreen,
                      onPressed: canShare ? () => _share('csv') : null,
                    ),
                    _ShareFormatButton(
                      label: 'Excel',
                      color: AppColors.primaryGreen,
                      onPressed: canShare ? () => _share('excel') : null,
                    ),
                    _ShareFormatButton(
                      label: 'PDF',
                      color: AppColors.accent,
                      foreground: AppColors.textDark,
                      onPressed: canShare ? () => _share('pdf') : null,
                    ),
                  ];

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          buttons[i],
                        ],
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: buttons,
                  );
                },
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
      ],
    );
  }
}

/// Resumen de solo lectura del modo de reporte activo.
///
/// Muestra en el diálogo de guardado qué estilo (Completo/Clásico) se aplicará,
/// sincronizado con la selección de la pantalla Exportar, para no elegirlo dos
/// veces. El cambio se realiza en el paso "Modo de reporte".
class _ReportModeSummary extends StatelessWidget {
  const _ReportModeSummary({required this.style});

  final PdfReportStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            style == PdfReportStyle.completo
                ? Icons.analytics_outlined
                : Icons.description_outlined,
            size: 20,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo de reporte: ${style.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  style.description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Se cambia en Exportar › Modo de reporte.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFormatButton extends StatelessWidget {
  const _ShareFormatButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.foreground = Colors.white,
  });

  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        disabledBackgroundColor: color.withValues(alpha: 0.35),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
