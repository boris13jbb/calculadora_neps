import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../theme/app_styles.dart';
import '../theme/app_theme.dart';
import 'confirm_dialogs.dart';

class CompactRecordsPanel extends StatelessWidget {
  const CompactRecordsPanel({
    super.key,
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
    this.onClearAll,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final sorted = List<NepRecord>.from(records)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalNeps = records.fold<double>(0, (sum, item) => sum + item.neps);
    final totalMts = records.fold<double>(
      0,
      (sum, item) => sum + appState.calculateMts(item.neps),
    );

    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordsHeader(
            count: records.length,
            totalNeps: appState.formatDecimal(totalNeps),
            totalMts: appState.formatNumber(totalMts),
            onClearAll: records.isEmpty ? null : onClearAll,
          ),
          const Divider(height: 1),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 48,
                            color: AppColors.muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Aun no hay registros.',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Agregue el primer registro usando el formulario para comenzar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 520;
                      if (wide) {
                        return Scrollbar(
                          thumbVisibility: true,
                          child: ListView(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: _CompactDataTable(
                                    appState: appState,
                                    records: sorted,
                                    onDelete: onDelete,
                                    onEdit: onEdit,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 12, endIndent: 12),
                        itemBuilder: (context, index) {
                          final item = sorted[index];
                          return _CompactRecordTile(
                            index: sorted.length - index,
                            item: item,
                            appState: appState,
                            onDelete: onDelete,
                            onEdit: onEdit,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordsHeader extends StatelessWidget {
  const _RecordsHeader({
    required this.count,
    required this.totalNeps,
    required this.totalMts,
    this.onClearAll,
  });

  final int count;
  final String totalNeps;
  final String totalMts;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 420;
          final titleRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_rows, size: 18, color: AppColors.textDark),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Registros ($count)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClearAll != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Vaciar registros',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onClearAll,
                  icon: const Icon(
                    Icons.delete_sweep,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          );
          final stats = Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MiniStat(label: 'Neps', value: totalNeps),
              _MiniStat(label: 'Mts', value: totalMts),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleRow,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: stats),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleRow),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _CompactDataTable extends StatelessWidget {
  const _CompactDataTable({
    required this.appState,
    required this.records,
    required this.onDelete,
    this.onEdit,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowHeight: 34,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 40,
      columnSpacing: 16,
      horizontalMargin: 12,
      headingRowColor: WidgetStateProperty.all(AppColors.header),
      headingTextStyle: const TextStyle(
        color: Color(0xFFF7EAC5),
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('HORA')),
        DataColumn(label: Text('TELAR')),
        DataColumn(label: Text('NEPS')),
        DataColumn(label: Text('MTS')),
        DataColumn(label: Text('LOTE')),
        DataColumn(label: Text('')),
      ],
      rows: List.generate(records.length, (index) {
        final item = records[index];
        final time = appState.formatDateTime(item.createdAt).split(' ').last;
        return DataRow(
          cells: [
            DataCell(Text('${records.length - index}')),
            DataCell(Text(time)),
            DataCell(Text(item.telar)),
            DataCell(Text(appState.formatDecimal(item.neps))),
            DataCell(
              Text(
                appState.formatNumber(appState.calculateMts(item.neps)),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            DataCell(
              Text(
                item.loteTrama,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Editar',
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                      onPressed: () => onEdit!(item),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Eliminar',
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    onPressed: () async {
                      if (await confirmDeleteRecord(context)) {
                        await onDelete(item.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CompactRecordTile extends StatelessWidget {
  const _CompactRecordTile({
    required this.index,
    required this.item,
    required this.appState,
    required this.onDelete,
    this.onEdit,
  });

  final int index;
  final NepRecord item;
  final AppState appState;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      minVerticalPadding: 0,
      onTap: onEdit != null ? () => onEdit!(item) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: AppColors.formulaBg,
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
      ),
      title: Text(
        'T${item.telar} · ${appState.formatDecimal(item.neps)} neps · ${appState.formatNumber(appState.calculateMts(item.neps))} mts',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item.tela} · ${item.loteTrama}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
            onPressed: () async {
              if (await confirmDeleteRecord(context)) {
                await onDelete(item.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
