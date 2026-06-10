import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/compact_stats_row.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../core/widgets/edit_record_sheet.dart';
import '../../core/widgets/records_table.dart';
import '../../models/nep_record.dart';
import '../../core/widgets/summary_cards.dart';
import '../../providers/app_state.dart';
import '../../widgets/record_filters_panel.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool isImporting = false;

  Future<void> _importRecords(AppState appState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      dialogTitle: 'Importar registros (CSV o Excel)',
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    setState(() => isImporting = true);

    try {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        appState.showMessage(
          'No se pudo leer el archivo. Intente nuevamente o use CSV/Excel.',
        );
        return;
      }

      await appState.importRecords(
        bytes: bytes,
        fileName: picked.name,
      );
    } catch (e) {
      appState.showMessage('Error al importar registros: $e');
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _clearTable(AppState appState) async {
    if (!await confirmClearTable(context)) return;
    await appState.clearTable();
  }

  Future<void> _editRecord(AppState appState, NepRecord record) async {
    await showEditRecordDialog(
      context: context,
      appState: appState,
      record: record,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);

    return AppPage(
      title: 'Registros',
      subtitle: phone ? null : 'Tabla, filtros, importacion y resumen de datos',
      fillViewport: true,
      maxContentWidth: 1400,
      compactPadding: true,
      denseOnPhone: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionChip(
                compact: phone,
                color: AppColors.primaryBlue,
                onPressed: isImporting ? null : () => _importRecords(appState),
                icon: isImporting ? null : Icons.upload_file,
                loading: isImporting,
                label: phone ? 'Importar' : 'Importar CSV/Excel',
              ),
              _ActionChip(
                compact: phone,
                color: AppColors.danger,
                onPressed: appState.records.isEmpty
                    ? null
                    : () => _clearTable(appState),
                icon: Icons.delete_sweep,
                label: phone ? 'Vaciar' : 'Vaciar tabla',
              ),
            ],
          ),
          SizedBox(height: spacing),
          if (phone)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RecordFiltersPanel(
                            key: ValueKey(appState.filterPanelKey),
                            records: appState.records,
                            filters: appState.filters,
                            onChanged: appState.onFiltersChanged,
                            onClear: appState.clearFilters,
                            compact: true,
                          ),
                          if (appState.filters.hasActiveFilters)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Mostrando ${appState.visibleRecords.length} de ${appState.records.length}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CompactStatsRow(
                    totalRecords: appState.visibleRecords.length,
                    totalNeps: appState.formatDecimal(appState.totalNeps),
                    averageNeps: appState.formatDecimal(appState.averageNeps),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: RecordsTable(
                      appState: appState,
                      records: appState.visibleRecords,
                      onDelete: appState.deleteRecord,
                      onEdit: (record) => _editRecord(appState, record),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecordFiltersPanel(
                    key: ValueKey(appState.filterPanelKey),
                    records: appState.records,
                    filters: appState.filters,
                    onChanged: appState.onFiltersChanged,
                    onClear: appState.clearFilters,
                    compact: true,
                  ),
                  if (appState.filters.hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mostrando ${appState.visibleRecords.length} de ${appState.records.length}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: RecordsTable(
                      appState: appState,
                      records: appState.visibleRecords,
                      onDelete: appState.deleteRecord,
                      onEdit: (record) => _editRecord(appState, record),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SummaryCards(
                    totalRecords: appState.visibleRecords.length,
                    totalNeps: appState.formatDecimal(appState.totalNeps),
                    averageNeps: appState.formatDecimal(appState.averageNeps),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.onPressed,
    required this.label,
    this.icon,
    this.color,
    this.compact = false,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.circle, size: 18),
        label: Text(
          loading ? 'Importando...' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.circle),
      label: Text(loading ? 'Importando...' : label),
    );
  }
}
