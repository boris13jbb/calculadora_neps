import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/export_column_selector.dart';
import '../../models/nep_record.dart';
import '../../models/record_filters.dart';
import '../../models/saved_report.dart';
import '../../providers/app_state.dart';
import '../../utils/record_filter_helper.dart';
import '../../utils/report_share_helper.dart';
import '../../widgets/record_filters_panel.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportShareHelper shareHelper;
  List<SavedReport> reports = [];
  final Set<String> selectedReportIds = {};
  RecordFilters reportFilters = RecordFilters();
  bool isLoading = true;
  bool isWorking = false;

  @override
  void initState() {
    super.initState();
    shareHelper =
        ReportShareHelper(context.read<AppState>().reportExportService);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => isLoading = true);
    try {
      final appState = context.read<AppState>();
      reports = await appState.reportStorageService.loadReports();
      selectedReportIds.removeWhere(
        (id) => !reports.any((report) => report.id == id),
      );
    } catch (error) {
      reports = [];
      debugPrint('Error al cargar informes: $error');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<SavedReport> get visibleReports {
    if (!reportFilters.hasActiveFilters) return reports;
    return reports.where((report) {
      final search = reportFilters.searchText.trim().toLowerCase();
      if (search.isNotEmpty &&
          !report.name.toLowerCase().contains(search) &&
          !report.records.any((record) {
            final haystack = [
              record.tela,
              record.loteTrama,
              record.telar,
            ].join(' ').toLowerCase();
            return haystack.contains(search);
          })) {
        return false;
      }

      if (reportFilters.dateFrom != null &&
          report.createdAt.isBefore(reportFilters.dateFrom!)) {
        return false;
      }

      if (reportFilters.dateTo != null) {
        final to = DateTime(
          reportFilters.dateTo!.year,
          reportFilters.dateTo!.month,
          reportFilters.dateTo!.day,
          23,
          59,
          59,
        );
        if (report.createdAt.isAfter(to)) return false;
      }

      if (reportFilters.tela != null ||
          reportFilters.loteTrama != null ||
          reportFilters.telar != null ||
          reportFilters.nepsMin != null ||
          reportFilters.nepsMax != null ||
          reportFilters.mtsMin != null ||
          reportFilters.mtsMax != null) {
        final filteredRecords =
            RecordFilterHelper.apply(report.records, reportFilters);
        return filteredRecords.isNotEmpty;
      }

      return true;
    }).toList();
  }

  List<SavedReport> get selectedReports => visibleReports
      .where((report) => selectedReportIds.contains(report.id))
      .toList();

  List<NepRecord> get _filterSourceRecords =>
      reports.expand((report) => report.records).toList();

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
      for (final report in visibleReports) {
        selectedReportIds.add(report.id);
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

  Future<void> _deleteReport(SavedReport report) async {
    final storage = context.read<AppState>().reportStorageService;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar informe'),
        content: Text('Desea eliminar "${report.name}"?'),
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
    await storage.deleteReport(report.id);
    selectedReportIds.remove(report.id);
    await _loadReports();
    _showMessage('Informe eliminado.');
  }

  Future<void> _openReportsFolder() async {
    final dir = await context
        .read<AppState>()
        .reportStorageService
        .getReportsDirectory();
    _showMessage('Carpeta de informes: ${dir.path}');
  }

  Future<void> _shareReports(
    List<SavedReport> reportsToShare, {
    required Set<ReportShareFormat> formats,
  }) async {
    if (reportsToShare.isEmpty) {
      _showMessage('Seleccione al menos un informe para compartir.');
      return;
    }

    setState(() => isWorking = true);
    try {
      final appState = context.read<AppState>();
      final files = await shareHelper.buildShareFiles(
        reports: reportsToShare,
        formats: formats,
        columns: appState.exportColumns,
      );

      if (files.isEmpty) {
        _showMessage('No se pudieron generar archivos para compartir.');
        return;
      }

      final formatLabel = _formatLabel(formats);
      final countLabel = reportsToShare.length == 1
          ? reportsToShare.first.name
          : '${reportsToShare.length} informes';

      await Share.shareXFiles(
        files,
        text: 'Informes VICUNHA - $countLabel ($formatLabel)',
        subject: 'Informes VICUNHA',
      );
    } catch (e) {
      _showMessage('Error al compartir informes: $e');
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
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

  Future<void> _shareSingle(SavedReport report, String action) async {
    switch (action) {
      case 'csv':
        await _shareReports([report], formats: {ReportShareFormat.csv});
      case 'excel':
        await _shareReports([report], formats: {ReportShareFormat.excel});
      case 'pdf':
        await _shareReports([report], formats: {ReportShareFormat.pdf});
      case 'all':
        await _shareReports(
          [report],
          formats: {
            ReportShareFormat.csv,
            ReportShareFormat.excel,
            ReportShareFormat.pdf,
          },
        );
    }
  }

  Future<void> _shareBatch(String action) async {
    final targets = selectedReports;
    switch (action) {
      case 'csv':
        await _shareReports(targets, formats: {ReportShareFormat.csv});
      case 'excel':
        await _shareReports(targets, formats: {ReportShareFormat.excel});
      case 'pdf':
        await _shareReports(targets, formats: {ReportShareFormat.pdf});
      case 'all':
        await _shareReports(
          targets,
          formats: {
            ReportShareFormat.csv,
            ReportShareFormat.excel,
            ReportShareFormat.pdf,
          },
        );
      case 'filtered_csv':
        await _shareReports(
          visibleReports,
          formats: {ReportShareFormat.csv},
        );
      case 'filtered_excel':
        await _shareReports(
          visibleReports,
          formats: {ReportShareFormat.excel},
        );
      case 'filtered_pdf':
        await _shareReports(
          visibleReports,
          formats: {ReportShareFormat.pdf},
        );
      case 'filtered_all':
        await _shareReports(
          visibleReports,
          formats: {
            ReportShareFormat.csv,
            ReportShareFormat.excel,
            ReportShareFormat.pdf,
          },
        );
    }
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _batchShareBar({required bool phone}) {
    final selectedCount = selectedReports.length;
    final filteredCount = visibleReports.length;

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
                        visibleReports.isEmpty ? null : _selectAllVisible,
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
    required List<SavedReport> filtered,
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
          ? const Center(
              child: Text(
                'No hay informes guardados.',
                style: TextStyle(fontSize: 12),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = filtered[index];
                final isSelected = selectedReportIds.contains(report.id);

                return ListTile(
                  dense: phone,
                  visualDensity: phone ? VisualDensity.compact : null,
                  leading: Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: isSelected,
                    onChanged: isWorking
                        ? null
                        : (value) => _toggleSelection(report.id, value),
                  ),
                  title: Text(
                    report.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: phone ? 13 : 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatDate(report.createdAt)} · ${report.records.length} reg.',
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
                            if (value == 'load') {
                              await appState.loadReport(report);
                            } else if (value == 'delete') {
                              await _deleteReport(report);
                            } else {
                              await _shareSingle(report, value);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'load',
                              child: Text('Cargar en registros'),
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
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = visibleReports;

    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);

    if (isLoading) {
      return AppPage(
        title: 'Informes guardados',
        subtitle: phone ? null : 'Historial de informes exportados',
        denseOnPhone: true,
        compactPadding: true,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AppPage(
      title: 'Informes guardados',
      subtitle: phone ? null : 'Cargar, compartir y administrar informes',
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
                _reportsToolsSection(
                  appState: appState,
                  spacing: spacing,
                  phone: phone,
                ),
                SizedBox(height: spacing - 2),
                Expanded(
                  child: _reportsListPanel(filtered: filtered, phone: phone),
                ),
              ],
            ),
    );
  }
}
