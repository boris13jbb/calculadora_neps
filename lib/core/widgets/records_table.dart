import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../models/record_delete_outcome.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../../utils/records_multi_selection.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import 'alert_status_badge.dart';
import 'app_material_list_tile.dart';
import 'confirm_dialogs.dart';
import 'corrective_action_dialog.dart';
import 'empty_state.dart';

class RecordsTable extends StatefulWidget {
  const RecordsTable({
    super.key,
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
    this.totalSourceCount,
    this.onClearFilters,
    this.onGoToCapture,
    this.onGoToImport,
    this.selectionResetToken = 0,
    this.userContextKey = '',
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<RecordDeleteOutcome> Function(String id) onDelete;
  final Future<bool> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToImport;

  /// Cambia al modificar filtros → limpia selección.
  final int selectionResetToken;

  /// Cambia con usuario/logout → limpia selección.
  final String userContextKey;

  @override
  State<RecordsTable> createState() => _RecordsTableState();
}

class _RecordsTableState extends State<RecordsTable> {
  final RecordsMultiSelection _selection = RecordsMultiSelection();
  bool _busy = false;

  bool get _canSelect =>
      widget.appState.canDeleteRecords || widget.appState.canEditRecords;

  @override
  void didUpdateWidget(covariant RecordsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    if (widget.selectionResetToken != oldWidget.selectionResetToken) {
      _selection.onFilterContextChanged();
      changed = true;
    }
    if (widget.userContextKey != oldWidget.userContextKey) {
      _selection.onUserContextChanged();
      changed = true;
    }
    final before = _selection.count;
    _selection.pruneToExisting(widget.records.map((r) => r.id));
    if (changed || before != _selection.count) {
      // Rebuild para reflejar selección limpia/pruned.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _notifySelection() => setState(() {});

  Future<void> _onUpdateSelected() async {
    if (_busy || widget.onEdit == null) return;
    setState(() => _busy = true);
    try {
      await runUpdateSelectedRecord(
        selection: _selection,
        records: widget.records,
        canEditRecords: widget.appState.canEditRecords,
        openEditor: widget.onEdit!,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onBulkDelete() async {
    if (_busy ||
        !_selection.canBulkDelete(
          canDeleteRecords: widget.appState.canDeleteRecords,
        )) {
      return;
    }

    final count = _selection.count;
    final confirmed = await confirmDeleteSelectedRecords(
      context,
      count: count,
    );
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final summary = await runBulkDeleteSelected(
        selectedIds: _selection.selectedRecordIds,
        canDeleteRecords: widget.appState.canDeleteRecords,
        confirmed: confirmed,
        deleteRecord: widget.onDelete,
      );

      _selection
        ..clear()
        ..selectedRecordIds.addAll(summary.remainingSelectedIds);
      // Solo IDs que aún existen en el dataset visible (desktop poda a página).
      _selection.pruneToExisting(widget.records.map((r) => r.id));

      if (summary.message.isNotEmpty) {
        widget.appState.showMessage(summary.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selection.isNotEmpty && _canSelect)
                  _RecordsSelectionBar(
                    count: _selection.count,
                    compact: useMobileList,
                    busy: _busy,
                    showUpdate: _selection.canUpdate(
                      canEditRecords: widget.appState.canEditRecords,
                    ),
                    showDelete: _selection.canBulkDelete(
                      canDeleteRecords: widget.appState.canDeleteRecords,
                    ),
                    onUpdate: _onUpdateSelected,
                    onDelete: _onBulkDelete,
                    onClear: () => setState(_selection.clear),
                  ),
                Expanded(
                  child: useMobileList
                      ? _MobileRecordsList(
                          appState: widget.appState,
                          records: widget.records,
                          onDelete: widget.onDelete,
                          onEdit: widget.onEdit,
                          totalSourceCount: widget.totalSourceCount,
                          onClearFilters: widget.onClearFilters,
                          onGoToCapture: widget.onGoToCapture,
                          onGoToImport: widget.onGoToImport,
                          selection: _selection,
                          canSelect: _canSelect,
                          onSelectionChanged: _notifySelection,
                        )
                      : _DesktopRecordsTable(
                          appState: widget.appState,
                          records: widget.records,
                          onDelete: widget.onDelete,
                          onEdit: widget.onEdit,
                          totalSourceCount: widget.totalSourceCount,
                          onClearFilters: widget.onClearFilters,
                          onGoToCapture: widget.onGoToCapture,
                          onGoToImport: widget.onGoToImport,
                          selection: _selection,
                          canSelect: _canSelect,
                          onSelectionChanged: _notifySelection,
                          onPageContextChanged: () {
                            _selection.onPageContextChanged();
                            _notifySelection();
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecordsSelectionBar extends StatelessWidget {
  const _RecordsSelectionBar({
    required this.count,
    required this.compact,
    required this.busy,
    required this.showUpdate,
    required this.showDelete,
    required this.onUpdate,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final bool compact;
  final bool busy;
  final bool showUpdate;
  final bool showDelete;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 seleccionado' : '$count seleccionados';
    final updateLabel = compact ? 'Actualizar' : 'Actualizar registro';
    final deleteLabel = count == 1
        ? (compact ? 'Eliminar' : 'Eliminar seleccionado')
        : (compact ? 'Eliminar' : 'Eliminar seleccionados');
    final clearLabel = compact ? 'Limpiar' : 'Limpiar selección';

    final actions = <Widget>[
      if (showUpdate)
        FilledButton.tonal(
          onPressed: busy ? null : onUpdate,
          child: Text(updateLabel),
        ),
      if (showDelete)
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: busy ? null : onDelete,
          child: Text(deleteLabel),
        ),
      TextButton(
        onPressed: busy ? null : onClear,
        child: Text(clearLabel),
      ),
    ];

    return Material(
      color: AppColors.surface,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 13,
              ),
            ),
            ...actions,
          ],
        ),
      ),
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
    this.onGoToImport,
    required this.selection,
    required this.canSelect,
    required this.onSelectionChanged,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<RecordDeleteOutcome> Function(String id) onDelete;
  final Future<bool> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToImport;
  final RecordsMultiSelection selection;
  final bool canSelect;
  final VoidCallback onSelectionChanged;

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
        onGoToImport: onGoToImport,
        compact: true,
      );
    }

    final pageIds = records.map((r) => r.id).toList(growable: false);

    return Column(
      children: [
        if (canSelect)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 8, 0),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: selection.isPageNoneSelected(pageIds)
                      ? false
                      : selection.isPageFullySelected(pageIds)
                          ? true
                          : null,
                  onChanged: (_) {
                    selection.toggleSelectAllOnPage(pageIds);
                    onSelectionChanged();
                  },
                ),
                const Expanded(
                  child: Text(
                    'Seleccionar visibles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: records.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 10, endIndent: 10),
            itemBuilder: (context, index) {
              final item = records[index];
              final level = alertService.getAlertLevel(item.neps);
              final bgColor = alertService.getAlertBackgroundColor(level);
              final selected = selection.selectedRecordIds.contains(item.id);
              final tile = AppMaterialListTile(
                backgroundColor: bgColor,
                dense: true,
                visualDensity:
                    const VisualDensity(horizontal: -2, vertical: -3),
                minVerticalPadding: 0,
                onTap: onEdit != null ? () => onEdit!(item) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AlertLevelDot(level: level, size: 8),
                    const SizedBox(width: 4),
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
                    if (item.requiereSeguimiento &&
                        appState.canApplyCorrectiveAction)
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
                    _DeleteRecordIconButton(
                      canDelete: appState.canDeleteRecords,
                      compact: true,
                      onConfirmDelete: () async {
                        if (await confirmDeleteRecord(context)) {
                          await onDelete(item.id);
                        }
                      },
                    ),
                  ],
                ),
              );

              if (!canSelect) return tile;

              return ColoredBox(
                color: bgColor,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: selected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) {
                        selection.setSelected(item.id, value ?? false);
                        onSelectionChanged();
                      },
                    ),
                    Expanded(child: tile),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
    this.onGoToImport,
    required this.selection,
    required this.canSelect,
    required this.onSelectionChanged,
    required this.onPageContextChanged,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<RecordDeleteOutcome> Function(String id) onDelete;
  final Future<bool> Function(NepRecord record)? onEdit;
  final int? totalSourceCount;
  final VoidCallback? onClearFilters;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToImport;
  final RecordsMultiSelection selection;
  final bool canSelect;
  final VoidCallback onSelectionChanged;
  final VoidCallback onPageContextChanged;

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
  void initState() {
    super.initState();
    _scheduleSyncSelection();
  }

  @override
  void didUpdateWidget(covariant _DesktopRecordsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSyncSelection();
  }

  void _scheduleSyncSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSelectionWithCurrentPage();
    });
  }

  /// Mantiene selectedRecordIds ⊆ currentPageIds (página efectiva).
  void _syncSelectionWithCurrentPage() {
    if (!widget.canSelect) return;
    final records = widget.records;
    if (records.isEmpty) {
      if (widget.selection.isNotEmpty) {
        widget.selection.clear();
        widget.onSelectionChanged();
      }
      return;
    }
    final pageCount = _pageCount(records.length);
    final effectivePage = _page.clamp(0, pageCount - 1);
    final changed = syncSelectionToCurrentPage(
      selection: widget.selection,
      records: records,
      page: effectivePage,
      rowsPerPage: _rowsPerPage,
    );
    if (changed) widget.onSelectionChanged();
  }

  void _changePage(void Function() mutate) {
    mutate();
    widget.onPageContextChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final records = widget.records;
    final selection = widget.selection;

    if (records.isEmpty) {
      return _RecordsEmptyState(
        isFiltered: _isFilteredEmpty,
        onClearFilters: widget.onClearFilters,
        onGoToCapture: widget.onGoToCapture,
        onGoToImport: widget.onGoToImport,
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
    final pageIds = pageRecords.map((r) => r.id).toList(growable: false);

    final columns = <DataColumn>[
      if (widget.canSelect)
        DataColumn(
          label: Checkbox(
            tristate: true,
            value: selection.isPageNoneSelected(pageIds)
                ? false
                : selection.isPageFullySelected(pageIds)
                    ? true
                    : null,
            onChanged: (_) {
              selection.toggleSelectAllOnPage(pageIds);
              widget.onSelectionChanged();
            },
          ),
        ),
      const DataColumn(label: Text('#')),
      const DataColumn(label: Text('FECHA')),
      const DataColumn(label: Text('LOTE DE\nTRAMA')),
      const DataColumn(label: Text('TELA')),
      const DataColumn(label: Text('TELAR')),
      const DataColumn(label: Text('NEPS')),
      const DataColumn(label: Text('MTS CALCULADOS\nNEPS / 0.09')),
      const DataColumn(label: Text('ESTADO')),
      const DataColumn(label: Text('ACCION')),
    ];

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
                constraints: BoxConstraints(
                  minWidth: widget.canSelect ? 1280 : 1240,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.header),
                  headingTextStyle: const TextStyle(
                    color: AppColors.headerText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  columns: columns,
                  rows: List.generate(pageRecords.length, (index) {
                    final item = pageRecords[index];
                    final globalIndex = start + index;
                    final level = alertService.getAlertLevel(item.neps);
                    final rowColor =
                        alertService.getAlertBackgroundColor(level);
                    final selected =
                        selection.selectedRecordIds.contains(item.id);
                    return DataRow(
                      color: WidgetStateProperty.all(rowColor),
                      cells: [
                        if (widget.canSelect)
                          DataCell(
                            Checkbox(
                              value: selected,
                              onChanged: (value) {
                                selection.setSelected(item.id, value ?? false);
                                widget.onSelectionChanged();
                              },
                            ),
                          ),
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
                              _DeleteRecordIconButton(
                                canDelete: appState.canDeleteRecords,
                                onConfirmDelete: () async {
                                  if (await confirmDeleteRecord(context)) {
                                    await widget.onDelete(item.id);
                                  }
                                },
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
            _changePage(() {
              _rowsPerPage = value;
              _page = 0;
            });
          },
          onFirst: page > 0 ? () => _changePage(() => _page = 0) : null,
          onPrevious:
              page > 0 ? () => _changePage(() => _page = page - 1) : null,
          onNext: page < pageCount - 1
              ? () => _changePage(() => _page = page + 1)
              : null,
          onLast: page < pageCount - 1
              ? () => _changePage(() => _page = pageCount - 1)
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

/// Papelera con estado visual coherente: rojo solo si hay permiso de borrar.
class _DeleteRecordIconButton extends StatelessWidget {
  const _DeleteRecordIconButton({
    required this.canDelete,
    required this.onConfirmDelete,
    this.compact = false,
  });

  final bool canDelete;
  final Future<void> Function() onConfirmDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    return IconButton(
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? EdgeInsets.zero : null,
      constraints:
          compact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      tooltip: canDelete ? 'Eliminar' : 'Sin permiso para eliminar',
      onPressed: canDelete ? () => onConfirmDelete() : null,
      icon: Icon(
        compact ? Icons.delete_outline : Icons.delete,
        size: compact ? 18 : null,
        color: canDelete ? AppColors.danger : disabledColor,
      ),
    );
  }
}
