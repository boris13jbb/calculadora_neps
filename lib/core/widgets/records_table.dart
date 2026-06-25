import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../layout/breakpoints.dart';
import '../theme/app_styles.dart';
import '../theme/app_theme.dart';
import 'confirm_dialogs.dart';

class RecordsTable extends StatelessWidget {
  const RecordsTable({
    super.key,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileList = constraints.maxWidth < AppBreakpoints.phone;

        final tableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : null;

        return SizedBox(
          height: tableHeight,
          width: double.infinity,
          child: Container(
            decoration: AppDecorations.card(color: AppColors.surface),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(useMobileList ? 10 : 18),
              child: useMobileList
                  ? _MobileRecordsList(
                      appState: appState,
                      records: records,
                      onDelete: onDelete,
                      onEdit: onEdit,
                    )
                  : _DesktopRecordsTable(
                      appState: appState,
                      records: records,
                      onDelete: onDelete,
                      onEdit: onEdit,
                    ),
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
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(NepRecord record)? onEdit;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 40,
                color: AppColors.muted.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sin datos para mostrar.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: records.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 10, endIndent: 10),
      itemBuilder: (context, index) {
        final item = records[index];
        return ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
          minVerticalPadding: 0,
          onTap: onEdit != null ? () => onEdit!(item) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: CircleAvatar(
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
          title: Text(
            'T${item.telar} · ${appState.formatDecimal(item.neps)} neps · '
            '${appState.formatNumber(appState.calculateMts(item.neps))} mts',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${appState.formatDateTime(item.createdAt)}\n'
            '${item.tela} · ${item.loteTrama}',
            style: const TextStyle(fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
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
      },
    );
  }
}

class _DesktopRecordsTable extends StatelessWidget {
  const _DesktopRecordsTable({
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
    if (records.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DesktopTableHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 56,
                      color: AppColors.muted.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay registros para mostrar.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aun no se han importado datos.',
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      primary: false,
      child: SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1120),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.header),
            headingTextStyle: const TextStyle(
              color: Color(0xFFF7EAC5),
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
              DataColumn(label: Text('ACCION')),
            ],
            rows: List.generate(records.length, (index) {
                    final item = records[index];
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
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
                        DataCell(Text(appState.formatDecimal(item.neps))),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => onEdit!(item),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () async {
                                  if (await confirmDeleteRecord(context)) {
                                    await onDelete(item.id);
                                  }
                                },
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
    );
  }
}

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: _headerStyle)),
          Expanded(flex: 2, child: Text('FECHA', style: _headerStyle)),
          Expanded(flex: 2, child: Text('LOTE DE TRAMA', style: _headerStyle)),
          Expanded(flex: 2, child: Text('TELA', style: _headerStyle)),
          Expanded(child: Text('TELAR', style: _headerStyle)),
          Expanded(child: Text('NEPS', style: _headerStyle)),
          Expanded(
            flex: 2,
            child: Text('MTS CALCULADOS', style: _headerStyle),
          ),
          SizedBox(width: 88, child: Text('ACCION', style: _headerStyle)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    color: Color(0xFFF7EAC5),
    fontWeight: FontWeight.w900,
    fontSize: 11,
  );
}
