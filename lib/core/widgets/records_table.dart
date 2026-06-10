import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import 'confirm_dialogs.dart';

class RecordsTable extends StatelessWidget {
  const RecordsTable({
    super.key,
    required this.appState,
    required this.records,
    required this.onDelete,
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;

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
                  )
                : _DesktopRecordsTable(
                    appState: appState,
                    records: records,
                    onDelete: onDelete,
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
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Sin datos para mostrar.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 18),
            onPressed: () async {
              if (await confirmDeleteRecord(context)) {
                await onDelete(item.id);
              }
            },
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
  });

  final AppState appState;
  final List<NepRecord> records;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
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
            rows: records.isEmpty
                ? [
                    const DataRow(
                      cells: [
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('Sin datos')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                        DataCell(Text('-')),
                      ],
                    ),
                  ]
                : List.generate(records.length, (index) {
                    final item = records[index];
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          Text(appState.formatDateTime(item.createdAt)),
                        ),
                        DataCell(Text(item.loteTrama)),
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
