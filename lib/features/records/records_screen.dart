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
    if (!await confirmClearTable(
      context,
      recordCount: appState.records.length,
    )) {
      return;
    }
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

    return AppPage(
      title: 'Registros',
      subtitle: phone
          ? 'Gestiona y consulta tus registros'
          : 'Gestiona y consulta los registros de neps y produccion de cada tela.',
      breadcrumb: const ['Inicio', 'Registros'],
      fillViewport: true,
      maxContentWidth: 1400,
      compactPadding: true,
      denseOnPhone: true,
      actions: [
        _ActionChip(
          compact: phone,
          color: AppColors.accent,
          foreground: AppColors.textDark,
          onPressed: isImporting ? null : () => _importRecords(appState),
          icon: isImporting ? null : Icons.upload_file,
          loading: isImporting,
          label: phone ? 'Importar' : 'Importar CSV/Excel',
        ),
        _ActionChip(
          compact: phone,
          color: AppColors.danger,
          outlined: true,
          onPressed: appState.records.isEmpty
              ? null
              : () => _clearTable(appState),
          icon: Icons.delete_sweep,
          label: phone ? 'Vaciar' : 'Vaciar tabla',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
    this.foreground,
    this.compact = false,
    this.loading = false,
    this.outlined = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final bool compact;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.white;

    if (outlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? AppColors.danger,
          side: BorderSide(color: color ?? AppColors.danger),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 10 : 12,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.circle, size: compact ? 18 : 20),
        label: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (compact) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
        onPressed: onPressed,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
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
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
      ),
      onPressed: onPressed,
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            )
          : Icon(icon ?? Icons.circle),
      label: Text(loading ? 'Importando...' : label),
    );
  }
}
