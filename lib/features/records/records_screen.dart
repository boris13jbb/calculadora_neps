import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_handler.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/widgets/nav_permission_gate.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../core/widgets/edit_record_sheet.dart';
import '../../core/widgets/import_preview_dialog.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/records_table.dart';
import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../../core/widgets/record_filters_panel.dart';

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

      final preview = appState.previewImport(
        bytes: bytes,
        fileName: picked.name,
      );

      if (!mounted) return;

      final confirmed = await showImportPreviewDialog(
        context: context,
        preview: preview,
      );

      if (!confirmed || !mounted) return;

      await appState.confirmImportRecords(preview.importableRecords);
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'importRecords');
      appState.showMessage(
        'Error al importar registros: ${ErrorHandler.userMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _downloadTemplate(AppState appState) async {
    await appState.downloadImportTemplate();
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
    final spacing = screenSpacing(context);
    final visible = appState.visibleRecords;
    final criticalCount = alertService.detectCriticalRecords(visible).length;

    return NavPermissionGate(
      navId: AppNavId.records,
      child: AppPage(
        title: 'Registros',
        subtitle: phone
            ? 'Su tabla personal'
            : 'Su tabla personal: filtros, importación y resumen',
        fillViewport: true,
        compactPadding: true,
        denseOnPhone: true,
        actions: [
          _ActionChip(
            compact: phone,
            color: AppColors.primaryGreen,
            onPressed: () => _downloadTemplate(appState),
            icon: Icons.download,
            label: phone ? 'Plantilla' : 'Descargar plantilla',
          ),
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
            onPressed: !appState.canClearAllRecords || appState.records.isEmpty
                ? null
                : () => _clearTable(appState),
            icon: Icons.delete_sweep,
            label: phone ? 'Vaciar' : 'Vaciar tabla',
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen fuera de la tabla, aprovechando el ancho.
            KpiStrip(
              compact: phone,
              minCardWidth: 220,
              cards: [
                KpiCard(
                  compact: phone,
                  label: 'Registros visibles',
                  value: '${visible.length}',
                  subtitle: appState.filters.hasActiveFilters
                      ? 'de ${appState.records.length} en total'
                      : null,
                  icon: Icons.list_alt,
                  color: AppColors.primaryGreen,
                ),
                KpiCard(
                  compact: phone,
                  label: 'Total neps',
                  value: appState.formatDecimal(appState.totalNeps),
                  icon: Icons.analytics_outlined,
                  color: AppColors.primaryBlue,
                ),
                KpiCard(
                  compact: phone,
                  label: 'Promedio neps',
                  value: appState.formatNumber(appState.averageNeps),
                  icon: Icons.trending_up,
                  color: AppColors.accentDark,
                ),
                KpiCard(
                  compact: phone,
                  label: 'Registros críticos',
                  value: '$criticalCount',
                  icon: Icons.error_outline,
                  color: AppColors.statusCritical,
                ),
              ],
            ),
            SizedBox(height: spacing),
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
                  'Mostrando ${visible.length} de ${appState.records.length}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SizedBox(height: spacing),
            Expanded(
              child: RecordsTable(
                appState: appState,
                records: visible,
                onDelete: appState.deleteRecord,
                onEdit: (record) => _editRecord(appState, record),
                totalSourceCount: appState.records.length,
                onClearFilters: appState.clearFilters,
                onGoToCapture: () => appState.setNavigationIndex(1),
              ),
            ),
          ],
        ),
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
