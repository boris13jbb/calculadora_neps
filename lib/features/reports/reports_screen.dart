import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_handler.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_material_list_tile.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/widgets/nav_permission_gate.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/export_column_selector.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../models/nep_record.dart';
import '../../models/pdf_report_style.dart';
import '../../models/record_filters.dart';
import '../../models/report_list_metrics.dart';
import '../../models/saved_report.dart';
import '../../models/saved_report_summary.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_share_helper.dart';
import '../../utils/report_share_helper.dart';
import '../../utils/report_summary_filters.dart';
import '../../core/widgets/record_filters_panel.dart';

/// Formatos CSV+Excel+PDF usados por «Compartir completo/clásico».
@visibleForTesting
const Set<ReportShareFormat> kSavedReportAllShareFormats = {
  ReportShareFormat.csv,
  ReportShareFormat.excel,
  ReportShareFormat.pdf,
};

/// Ítems del menú de acciones por informe (fuente única para UI y tests).
@visibleForTesting
List<PopupMenuEntry<String>> buildSavedReportRowMenuItems() {
  return const [
    PopupMenuItem(
      value: 'view',
      child: Text('Ver informe'),
    ),
    PopupMenuItem(
      value: 'csv',
      child: Text('Compartir CSV'),
    ),
    PopupMenuItem(
      value: 'excel',
      child: Text('Compartir Excel'),
    ),
    PopupMenuItem(
      value: 'pdf',
      child: Text('Compartir PDF'),
    ),
    PopupMenuItem(
      value: 'all',
      child: Text('Compartir completo'),
    ),
    PopupMenuItem(
      value: 'classic',
      child: Text('Compartir clásico'),
    ),
    PopupMenuItem(
      value: 'delete',
      child: Text('Eliminar'),
    ),
  ];
}

/// Lifecycle del visor: tras apertura exitosa, [clearViewingSavedReport] en
/// `finally` aunque el flujo no llegue al diálogo (p. ej. widget desmontado).
@visibleForTesting
Future<void> runSavedReportViewLifecycle({
  required AppState appState,
  required SavedReport report,
  required bool Function() isMounted,
  required Future<void> Function(SavedReport viewed) present,
}) async {
  final opened = await appState.openSavedReportView(report);
  if (!opened) return;

  try {
    if (!isMounted()) return;
    final viewed = appState.viewingSavedReport ?? report;
    await present(viewed);
  } finally {
    appState.clearViewingSavedReport();
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportShareHelper shareHelper;
  List<SavedReportSummary> summaries = [];
  Map<String, SavedReport> _localFullById = {};
  ReportListMetrics? lastListMetrics;
  int cloudFullFetchCount = 0;
  final Set<String> selectedReportIds = {};
  RecordFilters reportFilters = RecordFilters();
  bool isLoading = true;
  bool isWorking = false;
  String? loadError;
  int? _lastSeenNavIndex;
  bool _cloudWasReady = false;

  @override
  void initState() {
    super.initState();
    shareHelper =
        ReportShareHelper(context.read<AppState>().reportExportService);
    _loadReports();
  }

  void _scheduleReloadIfNeeded(AppState appState) {
    final navIndex = appState.navigationIndex;
    final reportsIndex = AppNavigation.indexOf(
      context.read<AuthProvider>().profile,
      AppNavId.reports,
    );
    final enteringTab = reportsIndex != null &&
        navIndex == reportsIndex &&
        _lastSeenNavIndex != reportsIndex;
    final cloudJustReady = appState.cloudSyncEnabled && !_cloudWasReady;

    if (reportsIndex != null &&
        navIndex == reportsIndex &&
        (enteringTab || cloudJustReady)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadReports(showLoader: !isLoading);
      });
    }

    _lastSeenNavIndex = navIndex;
    _cloudWasReady = appState.cloudSyncEnabled;
  }

  Future<void> _loadReports({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => isLoading = true);
    }
    try {
      final appState = context.read<AppState>();
      final loaded = await appState.refreshReportSummariesResult();
      final localFulls =
          await appState.reportStorageService.loadLocalReportsById();
      selectedReportIds.removeWhere(
        (id) => !loaded.summaries.any((summary) => summary.id == id),
      );
      if (mounted) {
        setState(() {
          summaries = loaded.summaries;
          _localFullById = localFulls;
          lastListMetrics = loaded.metrics;
          loadError = loaded.summaries.isEmpty ? loaded.cloudError : null;
          if (loaded.cloudError != null && loaded.summaries.isNotEmpty) {
            // Parcial usable: no bloquea la lista.
            loadError = null;
          }
        });
      }
      assert(
        loaded.metrics.usedFetchReportsForList == false,
        'PR2 no debe usar fetchReports para el listado',
      );
      assert(
        loaded.metrics.cloudRecordsDeserializedOnList == 0,
        'PR2 no debe deserializar records[] cloud al listar',
      );
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'loadReportSummaries');
      if (mounted) {
        final syncError = context.read<AppState>().cloudSyncError;
        setState(() {
          summaries = [];
          loadError = syncError ?? ErrorHandler.userMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<SavedReportSummary> get visibleSummaries => filterVisibleReportSummaries(
        summaries,
        reportFilters,
        fullById: _localFullById,
      );

  List<SavedReportSummary> get selectedSummaries => visibleSummaries
      .where((summary) => selectedReportIds.contains(summary.id))
      .toList();

  /// Solo fulls locales: panel de filtros no dispara fetch masivo.
  List<NepRecord> get _filterSourceRecords =>
      _localFullById.values.expand((report) => report.records).toList();

  Future<SavedReport?> _resolveFullReport(String id) async {
    final cached = _localFullById[id];
    if (cached != null) return cached;

    final appState = context.read<AppState>();
    final remote = await appState.resolveFullSavedReport(id);
    cloudFullFetchCount++;
    if (remote != null && mounted) {
      setState(() => _localFullById[id] = remote);
    }
    return remote;
  }

  Future<List<SavedReport>> _resolveFullReports(
    Iterable<SavedReportSummary> items,
  ) async {
    final resolved = <SavedReport>[];
    for (final summary in items) {
      final full = await _resolveFullReport(summary.id);
      if (full != null) {
        resolved.add(full);
      } else if (mounted) {
        _showMessage(
          'No se pudo cargar el informe "${summary.name}".',
        );
      }
    }
    return resolved;
  }

  void _toggleSelection(String reportId, bool? value) {
    setState(() {
      if (value == true) {
        selectedReportIds.add(reportId);
      } else {
        selectedReportIds.remove(reportId);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final summary in visibleSummaries) {
        selectedReportIds.add(summary.id);
      }
    });
  }

  void _clearSelection() => setState(selectedReportIds.clear);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _deleteReport(SavedReportSummary summary) async {
    final storage = context.read<AppState>().reportStorageService;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar informe'),
        content: Text('Desea eliminar "${summary.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await storage.deleteReport(summary.id);
    selectedReportIds.remove(summary.id);
    _localFullById.remove(summary.id);
    await _loadReports();
    _showMessage('Informe eliminado.');
  }

  Future<void> _openReportsFolder() async {
    final dir = await context
        .read<AppState>()
        .reportStorageService
        .getReportsDirectory();
    if (!kIsWeb) {
      await FileShareHelper.openDirectoryInShell(dir);
    }
    _showMessage('Carpeta de informes: ${dir.path}');
  }

  Future<void> _shareReports(
    List<SavedReport> reportsToShare, {
    required Set<ReportShareFormat> formats,
    PdfReportStyle? reportStyle,
  }) async {
    if (reportsToShare.isEmpty) {
      _showMessage('Seleccione al menos un informe para compartir.');
      return;
    }

    setState(() => isWorking = true);
    final shareOrigin = _shareOrigin(context);
    try {
      final appState = context.read<AppState>();
      // Estilo explícito (Completo/Clásico) o el activo en AppState para CSV/Excel/PDF.
      final style = reportStyle ?? appState.pdfReportStyle;
      final files = await shareHelper.buildShareFiles(
        reports: reportsToShare,
        formats: formats,
        columns: appState.exportColumns,
        reportStyle: style,
      );

      if (files.isEmpty) {
        _showMessage('No se pudieron generar archivos para compartir.');
        return;
      }

      final formatLabel = _formatLabel(formats);
      final countLabel = reportsToShare.length == 1
          ? reportsToShare.first.name
          : '${reportsToShare.length} informes';

      await FileShareHelper.deliverPreparedFiles(
        files: files,
        text: 'Informes VICUNHA - $countLabel ($formatLabel)',
        subject: 'Informes VICUNHA',
        sharePositionOrigin: shareOrigin,
      ).then((desktopMessage) {
        if (desktopMessage != null && mounted) {
          _showMessage(desktopMessage);
        }
      });
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'shareReports');
      _showMessage(
        'Error al compartir informes: ${ErrorHandler.userMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String _formatLabel(Set<ReportShareFormat> formats) {
    if (formats.length == 3) return 'CSV, Excel y PDF';
    return formats.map((format) {
      switch (format) {
        case ReportShareFormat.csv:
          return 'CSV';
        case ReportShareFormat.excel:
          return 'Excel';
        case ReportShareFormat.pdf:
          return 'PDF';
      }
    }).join(', ');
  }

  Future<void> _shareSingle(SavedReportSummary summary, String action) async {
    final reports = await _resolveFullReports([summary]);
    if (reports.isEmpty) return;
    final report = reports.first;
    switch (action) {
      case 'csv':
        await _shareReports([report], formats: {ReportShareFormat.csv});
      case 'excel':
        await _shareReports([report], formats: {ReportShareFormat.excel});
      case 'pdf':
        await _shareReports([report], formats: {ReportShareFormat.pdf});
      case 'all':
        // Equivalente a Registros → modo Completo (tres formatos).
        await _shareReports(
          [report],
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.completo,
        );
      case 'classic':
        // Equivalente a Registros → modo Clásico (tres formatos).
        await _shareReports(
          [report],
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.clasico,
        );
    }
  }

  /// Vista read-only del informe histórico (no toca registros operativos).
  Future<void> _viewSavedReport(SavedReportSummary summary) async {
    final report = await _resolveFullReport(summary.id);
    if (report == null) {
      _showMessage('No se pudo cargar el informe "${summary.name}".');
      return;
    }
    if (!mounted) return;
    final appState = context.read<AppState>();
    await runSavedReportViewLifecycle(
      appState: appState,
      report: report,
      isMounted: () => mounted,
      present: (viewed) async {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            final phone = MediaQuery.sizeOf(dialogContext).width < 600;
            return AlertDialog(
              title: Text(viewed.name),
              content: SizedBox(
                width: phone ? double.maxFinite : 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(viewed.createdAt)} · ${viewed.records.length} reg.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: phone ? 320 : 420,
                      ),
                      child: viewed.records.isEmpty
                          ? const Text('Este informe no contiene registros.')
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: viewed.records.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final record = viewed.records[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${record.tela} · Telar ${record.telar}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Neps ${appState.formatDecimal(record.neps)} · '
                                    'Lote ${record.loteTrama} · '
                                    '${_formatDate(record.createdAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _shareReports(
                      [viewed],
                      formats: {ReportShareFormat.csv},
                    );
                  },
                  child: const Text('CSV'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _shareReports(
                      [viewed],
                      formats: {ReportShareFormat.excel},
                    );
                  },
                  child: const Text('Excel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _shareReports(
                      [viewed],
                      formats: {ReportShareFormat.pdf},
                    );
                  },
                  child: const Text('PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareBatch(String action) async {
    final selected = selectedSummaries;
    final visible = visibleSummaries;
    switch (action) {
      case 'csv':
        await _shareReports(
          await _resolveFullReports(selected),
          formats: {ReportShareFormat.csv},
        );
      case 'excel':
        await _shareReports(
          await _resolveFullReports(selected),
          formats: {ReportShareFormat.excel},
        );
      case 'pdf':
        await _shareReports(
          await _resolveFullReports(selected),
          formats: {ReportShareFormat.pdf},
        );
      case 'all':
        await _shareReports(
          await _resolveFullReports(selected),
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.completo,
        );
      case 'classic':
        await _shareReports(
          await _resolveFullReports(selected),
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.clasico,
        );
      case 'filtered_csv':
        await _shareReports(
          await _resolveFullReports(visible),
          formats: {ReportShareFormat.csv},
        );
      case 'filtered_excel':
        await _shareReports(
          await _resolveFullReports(visible),
          formats: {ReportShareFormat.excel},
        );
      case 'filtered_pdf':
        await _shareReports(
          await _resolveFullReports(visible),
          formats: {ReportShareFormat.pdf},
        );
      case 'filtered_all':
        await _shareReports(
          await _resolveFullReports(visible),
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.completo,
        );
      case 'filtered_classic':
        await _shareReports(
          await _resolveFullReports(visible),
          formats: kSavedReportAllShareFormats,
          reportStyle: PdfReportStyle.clasico,
        );
    }
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _batchShareBar({required bool phone}) {
    final selectedCount = selectedSummaries.length;
    final filteredCount = visibleSummaries.length;

    return Container(
      padding: EdgeInsets.all(phone ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final selectionText = Text(
                selectedCount == 0
                    ? 'Seleccione informes para compartir por lote'
                    : '$selectedCount informe(s) seleccionado(s)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              );
              final actionButtons = Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed:
                        visibleSummaries.isEmpty ? null : _selectAllVisible,
                    child: const Text('Seleccionar visibles'),
                  ),
                  TextButton(
                    onPressed: selectedCount == 0 ? null : _clearSelection,
                    child: const Text('Limpiar'),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    selectionText,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: actionButtons,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: selectionText),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: phone ? 6 : 8,
            runSpacing: phone ? 6 : 8,
            children: [
              _shareChip(
                label: 'Lote CSV',
                enabled: selectedCount > 0 && !isWorking,
                compact: phone,
                onPressed: () => _shareBatch('csv'),
              ),
              _shareChip(
                label: 'Lote Excel',
                enabled: selectedCount > 0 && !isWorking,
                compact: phone,
                onPressed: () => _shareBatch('excel'),
              ),
              _shareChip(
                label: 'Lote PDF',
                enabled: selectedCount > 0 && !isWorking,
                compact: phone,
                onPressed: () => _shareBatch('pdf'),
              ),
              _shareChip(
                label: 'Lote completo',
                enabled: selectedCount > 0 && !isWorking,
                compact: phone,
                onPressed: () => _shareBatch('all'),
              ),
              _shareChip(
                label: 'Lote clásico',
                enabled: selectedCount > 0 && !isWorking,
                compact: phone,
                onPressed: () => _shareBatch('classic'),
              ),
              if (reportFilters.hasActiveFilters && filteredCount > 0) ...[
                _shareChip(
                  label: 'Filtrados CSV ($filteredCount)',
                  enabled: !isWorking,
                  compact: phone,
                  color: AppColors.primaryBlue,
                  onPressed: () => _shareBatch('filtered_csv'),
                ),
                _shareChip(
                  label: 'Filtrados Excel ($filteredCount)',
                  enabled: !isWorking,
                  compact: phone,
                  color: AppColors.primaryBlue,
                  onPressed: () => _shareBatch('filtered_excel'),
                ),
                _shareChip(
                  label: 'Filtrados PDF ($filteredCount)',
                  enabled: !isWorking,
                  compact: phone,
                  color: AppColors.primaryBlue,
                  onPressed: () => _shareBatch('filtered_pdf'),
                ),
                _shareChip(
                  label: 'Filtrados completo ($filteredCount)',
                  enabled: !isWorking,
                  compact: phone,
                  color: AppColors.primaryBlue,
                  onPressed: () => _shareBatch('filtered_all'),
                ),
                _shareChip(
                  label: 'Filtrados clásico ($filteredCount)',
                  enabled: !isWorking,
                  compact: phone,
                  color: AppColors.primaryBlue,
                  onPressed: () => _shareBatch('filtered_classic'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareChip({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    Color color = AppColors.primaryGreen,
    bool compact = false,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        textStyle: TextStyle(fontSize: compact ? 12 : 14),
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }

  Widget _reportsToolsSection({
    required AppState appState,
    required double spacing,
    required bool phone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RecordFiltersPanel(
          records: _filterSourceRecords,
          filters: reportFilters,
          onChanged: () => setState(() {}),
          onClear: () => setState(reportFilters.clear),
          compact: true,
        ),
        SizedBox(height: spacing),
        Container(
          padding: sectionPadding(context),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(sectionRadius(context)),
            border: Border.all(color: AppColors.border),
          ),
          child: ExportColumnSelector(
            compact: true,
            selected: appState.exportColumns,
            onChanged: appState.setExportColumns,
          ),
        ),
        SizedBox(height: spacing),
        _batchShareBar(phone: phone),
        SizedBox(height: phone ? spacing - 4 : spacing - 2),
        if (!kIsWeb)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openReportsFolder,
              icon: Icon(Icons.folder_open, size: phone ? 18 : 24),
              label: Text(
                phone
                    ? 'Carpeta informes'
                    : 'Ver carpeta de informes guardados',
                style: TextStyle(fontSize: phone ? 12 : 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reportsListPanel({
    required List<SavedReportSummary> filtered,
    required bool phone,
  }) {
    final appState = context.read<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(sectionRadius(context)),
        border: Border.all(color: AppColors.border),
      ),
      child: filtered.isEmpty
          ? EmptyState(
              compact: phone,
              icon: loadError != null
                  ? Icons.error_outline
                  : Icons.folder_open_outlined,
              title: loadError != null
                  ? 'Error al cargar informes'
                  : (summaries.isEmpty
                      ? 'Sin informes guardados'
                      : 'Sin coincidencias'),
              message: loadError ??
                  (summaries.isEmpty
                      ? 'Guarde un informe desde Captura o Exportar para compartirlo con el equipo.'
                      : 'Ningún informe coincide con los filtros activos.'),
              iconColor: loadError != null ? AppColors.danger : AppColors.muted,
              actions: [
                if (loadError != null)
                  EmptyStateAction(
                    label: 'Reintentar',
                    icon: Icons.refresh,
                    onPressed: _loadReports,
                  )
                else if (summaries.isNotEmpty)
                  EmptyStateAction(
                    label: 'Limpiar filtros',
                    icon: Icons.clear_all,
                    filled: false,
                    onPressed: () => setState(reportFilters.clear),
                  )
                else
                  EmptyStateAction(
                    label: 'Ir a Exportar',
                    icon: Icons.ios_share,
                    onPressed: () => appState.setNavigationIndex(6),
                  ),
              ],
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final summary = filtered[index];
                final isSelected = selectedReportIds.contains(summary.id);

                return AppMaterialListTile(
                  dense: phone,
                  visualDensity: phone ? VisualDensity.compact : null,
                  leading: Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: isSelected,
                    onChanged: isWorking
                        ? null
                        : (value) => _toggleSelection(summary.id, value),
                  ),
                  title: Text(
                    summary.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: phone ? 13 : 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatDate(summary.createdAt)} · ${summary.recordCount} reg.',
                    style: TextStyle(fontSize: phone ? 11 : 13),
                  ),
                  trailing: isWorking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'view') {
                              await _viewSavedReport(summary);
                            } else if (value == 'delete') {
                              await _deleteReport(summary);
                            } else {
                              await _shareSingle(summary, value);
                            }
                          },
                          itemBuilder: (context) =>
                              buildSavedReportRowMenuItems(),
                        ),
                );
              },
            ),
    );
  }

  /// Resumen superior de la biblioteca de informes.
  Widget _reportsKpis(List<SavedReportSummary> filtered) {
    final totalRecords =
        summaries.fold<int>(0, (sum, item) => sum + item.recordCount);
    return KpiStrip(
      minCardWidth: 180,
      compact: true,
      cards: [
        KpiCard(
          compact: true,
          label: 'Informes',
          value: '${summaries.length}',
          icon: Icons.folder_special_outlined,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          compact: true,
          label: reportFilters.hasActiveFilters ? 'Filtrados' : 'Visibles',
          value: '${filtered.length}',
          icon: Icons.filter_alt_outlined,
          color: AppColors.accentDark,
        ),
        KpiCard(
          compact: true,
          label: 'Seleccionados',
          value: '${selectedSummaries.length}',
          icon: Icons.check_box_outlined,
          color: AppColors.primaryGreen,
        ),
        KpiCard(
          compact: true,
          label: 'Registros totales',
          value: '$totalRecords',
          icon: Icons.table_rows_outlined,
          color: AppColors.statusNormal,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _scheduleReloadIfNeeded(appState);
    final filtered = visibleSummaries;

    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);

    if (isLoading) {
      return NavPermissionGate(
        navId: AppNavId.reports,
        child: AppPage(
          title: 'Informes guardados',
          subtitle: phone
              ? 'Gestiona y comparte informes'
              : 'Gestiona y comparte tus informes de produccion',
          breadcrumb: const ['Inicio', 'Informes guardados'],
          denseOnPhone: true,
          compactPadding: true,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return NavPermissionGate(
      navId: AppNavId.reports,
      child: AppPage(
        title: 'Informes guardados',
        subtitle: phone
            ? 'Compartidos con el equipo'
            : 'Gestiona y comparte tus informes de produccion',
        breadcrumb: const ['Inicio', 'Informes guardados'],
        fillViewport: true,
        compactPadding: true,
        denseOnPhone: true,
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: phone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!appState.cloudSyncEnabled) ...[
                    StatusBanner(
                      type: appState.cloudSyncError != null
                          ? StatusBannerType.warning
                          : StatusBannerType.info,
                      message: appState.cloudSyncError != null
                          ? 'Firebase no disponible: ${appState.cloudSyncError}'
                          : 'Conectando con Firebase para sincronizar informes…',
                    ),
                    SizedBox(height: spacing),
                  ],
                  Flexible(
                    child: SingleChildScrollView(
                      child: _reportsToolsSection(
                        appState: appState,
                        spacing: spacing,
                        phone: phone,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _reportsListPanel(filtered: filtered, phone: phone),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!appState.cloudSyncEnabled) ...[
                    StatusBanner(
                      type: appState.cloudSyncError != null
                          ? StatusBannerType.warning
                          : StatusBannerType.info,
                      message: appState.cloudSyncError != null
                          ? 'Firebase no disponible: ${appState.cloudSyncError}'
                          : 'Conectando con Firebase para sincronizar informes…',
                    ),
                    SizedBox(height: spacing),
                  ],
                  _reportsKpis(filtered),
                  SizedBox(height: spacing),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(
                            child: _reportsToolsSection(
                              appState: appState,
                              spacing: spacing,
                              phone: phone,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AppSectionHeader(
                                title: 'Informes guardados',
                                icon: Icons.folder_special_outlined,
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _reportsListPanel(
                                  filtered: filtered,
                                  phone: phone,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
