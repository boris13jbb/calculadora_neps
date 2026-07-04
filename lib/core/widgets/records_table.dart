import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import 'alert_status_badge.dart';
import 'app_material_list_tile.dart';
import 'confirm_dialogs.dart';
import 'corrective_action_dialog.dart';
import 'empty_state.dart';

class RecordsTable extends StatelessWidget {
  const RecordsTable({
    super.key,
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
    this.totalSourceCount,
    this.onClearFilters,
    this.onGoToCapture,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileList = constraints.maxWidth < AppBreakpoints.phone;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(useMobileList ? 10 : 18),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(useMobileList ? 10 : 18),
            child: useMobileList
                ? _MobileRecordsList(
                    appState: appState,
                    records: records,
                    onDelete: onDelete,
                    onEdit: onEdit,
                    totalSourceCount: totalSourceCount,
                    onClearFilters: onClearFilters,
                    onGoToCapture: onGoToCapture,
                  )
                : _DesktopRecordsTable(
                    appState: appState,
                    records: records,
                    onDelete: onDelete,
                    onEdit: onEdit,
                    totalSourceCount: totalSourceCount,
                    onClearFilters: onClearFilters,
                    onGoToCapture: onGoToCapture,
                  ),
          ),
        );
      },
    );
  }
}

class _MobileRecordsList extends StatelessWidget {
  const _MobileRecordsList({
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
    this.totalSourceCount,
    this.onClearFilters,
    this.onGoToCapture,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;

  bool get _isFilteredEmpty {
    final total = totalSourceCount;
    return records.isEmpty && total != null && total > 0;
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _RecordsEmptyState(
        isFiltered: _isFilteredEmpty,
        onClearFilters: onClearFilters,
        onGoToCapture: onGoToCapture,
        onGoToImport: () => appState.setNavigationIndex(2),
        compact: true,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: records.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 10, endIndent: 10),
      itemBuilder: (context, index) {
        final item = records[index];
        final level = alertService.getAlertLevel(item.neps);
        final bgColor = alertService.getAlertBackgroundColor(level);
        return AppMaterialListTile(
          backgroundColor: bgColor,
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
          minVerticalPadding: 0,
          onTap: onEdit != null ? () => onEdit!(item) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AlertLevelDot(level: level, size: 8),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.formulaBg,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'T${item.telar} · ${appState.formatNumber(appState.calculateMts(item.neps))} mts',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AlertNepsText(
                nepsText: '${appState.formatDecimal(item.neps)} neps',
                level: level,
                fontSize: 12,
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${appState.formatDateTime(item.createdAt)}\n'
                '${item.tela} · ${item.loteTrama}',
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              AlertStatusBadge(level: level, compact: true),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.requiereSeguimiento && appState.canApplyCorrectiveAction)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Seguimiento / acción correctiva',
                  icon: const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.statusCritical,
                    size: 18,
                  ),
                  onPressed: () => showCorrectiveActionDialog(
                    context: context,
                    appState: appState,
                    record: item,
                  ),
                ),
              if (onEdit != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Editar',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                  onPressed: () => onEdit!(item),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Eliminar',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 18,
                ),
                onPressed: appState.canDeleteRecords
                    ? () async {
                        if (await confirmDeleteRecord(context)) {
                          await onDelete(item.id);
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopRecordsTable extends StatefulWidget {
  const _DesktopRecordsTable({
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
    this.totalSourceCount,
    this.onClearFilters,
    this.onGoToCapture,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;

  @override
  State<_DesktopRecordsTable> createState() => _DesktopRecordsTableState();
}

class _DesktopRecordsTableState extends State<_DesktopRecordsTable> {
  static const List<int> _rowsPerPageOptions = [25, 50, 100];
  int _rowsPerPage = 50;
  int _page = 0;

  bool get _isFilteredEmpty {
    final total = widget.totalSourceCount;
    return widget.records.isEmpty && total != null && total > 0;
  }

  int _pageCount(int total) =>
      total == 0 ? 1 : ((total + _rowsPerPage - 1) ~/ _rowsPerPage);

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final records = widget.records;

    if (records.isEmpty) {
      return _RecordsEmptyState(
        isFiltered: _isFilteredEmpty,
        onClearFilters: widget.onClearFilters,
        onGoToCapture: widget.onGoToCapture,
        onGoToImport: () => appState.setNavigationIndex(2),
      );
    }

    final total = records.length;
    final pageCount = _pageCount(total);
    // El índice de página puede quedar fuera de rango si los filtros reducen
    // los resultados; se ajusta localmente sin mutar el estado en build.
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _rowsPerPage;
    final end = (start + _rowsPerPage) > total ? total : (start + _rowsPerPage);
    final pageRecords = records.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            primary: false,
            child: SingleChildScrollView(
              primary: false,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1240),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.header),
                  headingTextStyle: const TextStyle(
                    color: AppColors.headerText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('FECHA')),
                    DataColumn(label: Text('LOTE DE\nTRAMA')),
                    DataColumn(label: Text('TELA')),
                    DataColumn(label: Text('TELAR')),
                    DataColumn(label: Text('NEPS')),
                    DataColumn(label: Text('MTS CALCULADOS\nNEPS / 0.09')),
                    DataColumn(label: Text('ESTADO')),
                    DataColumn(label: Text('ACCION')),
                  ],
                  rows: List.generate(pageRecords.length, (index) {
                    final item = pageRecords[index];
                    final globalIndex = start + index;
                    final level = alertService.getAlertLevel(item.neps);
                    final rowColor =
                        alertService.getAlertBackgroundColor(level);
                    return DataRow(
                      color: WidgetStateProperty.all(rowColor),
                      cells: [
                        DataCell(Text('${globalIndex + 1}')),
                        DataCell(
                          Text(appState.formatDateTime(item.createdAt)),
                        ),
                        DataCell(
                          Text(
                            item.loteTrama,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        DataCell(Text(item.tela)),
                        DataCell(Text(item.telar)),
                        DataCell(
                          AlertNepsText(
                            nepsText: appState.formatDecimal(item.neps),
                            level: level,
                            fontSize: 14,
                          ),
                        ),
                        DataCell(
                          Text(
                            appState.formatNumber(
                              appState.calculateMts(item.neps),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              fontSize: 15,
                            ),
                          ),
                        ),
                        DataCell(
                          AlertStatusBadge(level: level, compact: true),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.requiereSeguimiento &&
                                  appState.canApplyCorrectiveAction)
                                IconButton(
                                  tooltip: 'Seguimiento / acción correctiva',
                                  onPressed: () => showCorrectiveActionDialog(
                                    context: context,
                                    appState: appState,
                                    record: item,
                                  ),
                                  icon: const Icon(
                                    Icons.fact_check_outlined,
                                    color: AppColors.statusCritical,
                                  ),
                                ),
                              if (widget.onEdit != null)
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => widget.onEdit!(item),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: appState.canDeleteRecords
                                    ? () async {
                                        if (await confirmDeleteRecord(
                                          context,
                                        )) {
                                          await widget.onDelete(item.id);
                                        }
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        _RecordsPaginationBar(
          rangeStart: start + 1,
          rangeEnd: end,
          total: total,
          page: page,
          pageCount: pageCount,
          rowsPerPage: _rowsPerPage,
          rowsPerPageOptions: _rowsPerPageOptions,
          onRowsPerPageChanged: (value) {
            setState(() {
              _rowsPerPage = value;
              _page = 0;
            });
          },
          onFirst: page > 0 ? () => setState(() => _page = 0) : null,
          onPrevious: page > 0 ? () => setState(() => _page = page - 1) : null,
          onNext: page < pageCount - 1
              ? () => setState(() => _page = page + 1)
              : null,
          onLast: page < pageCount - 1
              ? () => setState(() => _page = pageCount - 1)
              : null,
        ),
      ],
    );
  }
}

/// Barra de paginación de la tabla de registros de escritorio.
///
/// Evita renderizar todas las filas a la vez (rendimiento en tablas grandes)
/// mostrando solo la página actual con controles de navegación claros.
class _RecordsPaginationBar extends StatelessWidget {
  const _RecordsPaginationBar({
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.onRowsPerPageChanged,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final int rangeStart;
  final int rangeEnd;
  final int total;
  final int page;
  final int pageCount;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final ValueChanged<int> onRowsPerPageChanged;
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$rangeStart–$rangeEnd de $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Text(
            'Filas por página:',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: rowsPerPage,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            items: [
              for (final option in rowsPerPageOptions)
                DropdownMenuItem(value: option, child: Text('$option')),
            ],
            onChanged: (value) {
              if (value != null) onRowsPerPageChanged(value);
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Primera página',
            visualDensity: VisualDensity.compact,
            onPressed: onFirst,
            icon: const Icon(Icons.first_page, size: 20),
          ),
          IconButton(
            tooltip: 'Anterior',
            visualDensity: VisualDensity.compact,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Text(
            '${page + 1} / $pageCount',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            visualDensity: VisualDensity.compact,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
          IconButton(
            tooltip: 'Última página',
            visualDensity: VisualDensity.compact,
            onPressed: onLast,
            icon: const Icon(Icons.last_page, size: 20),
          ),
        ],
      ),
    );
  }
}

class _RecordsEmptyState extends StatelessWidget {
  const _RecordsEmptyState({
    required this.isFiltered,
    this.onClearFilters,
    this.onGoToCapture,
    this.onGoToImport,
    this.compact = false,
  });

  final bool isFiltered;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToImport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isFiltered) {
      return EmptyState(
        compact: compact,
        icon: Icons.filter_alt_off_outlined,
        title: 'Sin coincidencias',
        message: 'Ningún registro coincide con los filtros activos.',
        actions: [
          if (onClearFilters != null)
            EmptyStateAction(
              label: 'Limpiar filtros',
              icon: Icons.clear_all,
              onPressed: onClearFilters!,
            ),
        ],
      );
    }

    return EmptyState(
      compact: compact,
      icon: Icons.table_chart_outlined,
      title: 'Sin registros',
      message:
          'Capture mediciones o importe un archivo CSV/Excel para comenzar.',
      actions: [
        if (onGoToCapture != null)
          EmptyStateAction(
            label: 'Ir a Captura',
            icon: Icons.add_circle_outline,
            onPressed: onGoToCapture!,
          ),
        if (onGoToImport != null)
          EmptyStateAction(
            label: 'Importar datos',
            icon: Icons.upload_file,
            filled: false,
            onPressed: onGoToImport!,
          ),
      ],
    );
  }
}
