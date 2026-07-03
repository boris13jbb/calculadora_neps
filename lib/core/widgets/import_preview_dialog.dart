import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/import_row_result.dart';
import '../../models/record_import_result.dart';

/// Vista previa de importación con resumen por fila antes de confirmar.
Future<bool> showImportPreviewDialog({
  required BuildContext context,
  required RecordImportResult preview,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ImportPreviewDialog(preview: preview),
  );
  return result ?? false;
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.preview});

  final RecordImportResult preview;

  Color _statusColor(ImportRowStatus status) {
    return switch (status) {
      ImportRowStatus.valid => AppColors.statusNormal,
      ImportRowStatus.duplicate => AppColors.statusWarning,
      ImportRowStatus.error => AppColors.danger,
      ImportRowStatus.skipped => AppColors.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final importable = preview.importableRecords.length;
    final previewRows = preview.rowResults.take(50).toList();

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Vista previa de importación',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: 'Válidas',
                  value: '${preview.validCount}',
                  color: AppColors.statusNormal,
                ),
                _SummaryChip(
                  label: 'Duplicadas',
                  value: '${preview.duplicateRows}',
                  color: AppColors.statusWarning,
                ),
                _SummaryChip(
                  label: 'Errores',
                  value: '${preview.errorRows}',
                  color: AppColors.danger,
                ),
                _SummaryChip(
                  label: 'Omitidas',
                  value: '${preview.skippedRows}',
                  color: AppColors.muted,
                ),
              ],
            ),
            if (preview.missingColumns.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.statusWarning),
                ),
                child: Text(
                  'Columnas no detectadas: ${preview.missingColumns.join(', ')}. '
                  'Se usarán posiciones por defecto si el archivo no tiene encabezado.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (preview.message != null && importable == 0) ...[
              const SizedBox(height: 10),
              Text(
                preview.message!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 48,
                  headingRowColor: WidgetStateProperty.all(AppColors.header),
                  headingTextStyle: const TextStyle(
                    color: Color(0xFFF7EAC5),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  columns: const [
                    DataColumn(label: Text('Fila')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Telar')),
                    DataColumn(label: Text('Neps')),
                    DataColumn(label: Text('Detalle')),
                  ],
                  rows: previewRows.map((row) {
                    final record = row.record;
                    return DataRow(
                      cells: [
                        DataCell(Text('${row.rowNumber}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(row.status)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              row.status.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _statusColor(row.status),
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(record?.telar ?? '-')),
                        DataCell(
                          Text(
                            record != null ? record.neps.toString() : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            row.message ?? record?.tela ?? '-',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            if (preview.rowResults.length > 50)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Mostrando 50 de ${preview.rowResults.length} filas.',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: importable == 0
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text('Importar $importable registros'),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
