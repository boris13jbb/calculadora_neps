import 'package:flutter/material.dart';

import '../layout/responsive_layout.dart';
import '../theme/app_theme.dart';
import '../../models/alert_level.dart';
import '../../models/nep_record.dart';
import '../../models/record_filters.dart';
import '../../utils/record_filter_helper.dart';

/// Filtros extendidos: alerta, producción y rangos rápidos.
class ExtendedRecordFilterFields extends StatelessWidget {
  const ExtendedRecordFilterFields({
    super.key,
    required this.records,
    required this.filters,
    required this.onChanged,
    this.compact = false,
  });

  final List<NepRecord> records;
  final RecordFilters filters;
  final VoidCallback onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final turnos = RecordFilterHelper.uniqueTurnos(records);
    final operarios = RecordFilterHelper.uniqueOperarios(records);
    final lineas = RecordFilterHelper.uniqueLineas(records);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final phone = isPhoneLayout(context);
        final columns = phone || maxW < 560
            ? 1
            : maxW < 900
                ? 2
                : 4;
        const spacing = 8.0;
        final itemWidth =
            columns == 1 ? maxW : (maxW - spacing * (columns - 1)) / columns;

        Widget fieldBox(Widget child) {
          return SizedBox(
            width: columns == 1 ? double.infinity : itemWidth,
            child: child,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 20),
            Text(
              'Filtros de calidad y producción',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 12,
                color: AppColors.textGreen,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                fieldBox(
                  _AlertLevelDropdown(
                    value: filters.alertLevel,
                    onChanged: (v) {
                      filters.alertLevel = v;
                      onChanged();
                    },
                  ),
                ),
                fieldBox(
                  _StringDropdown(
                    label: 'Turno',
                    value: filters.turno,
                    options: turnos,
                    onChanged: (v) {
                      filters.turno = v;
                      onChanged();
                    },
                  ),
                ),
                fieldBox(
                  _StringDropdown(
                    label: 'Operario',
                    value: filters.operario,
                    options: operarios,
                    onChanged: (v) {
                      filters.operario = v;
                      onChanged();
                    },
                  ),
                ),
                fieldBox(
                  _StringDropdown(
                    label: 'Línea',
                    value: filters.lineaProduccion,
                    options: lineas,
                    onChanged: (v) {
                      filters.lineaProduccion = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: DateQuickRange.values.map((range) {
                final selected = filters.quickRange == range;
                return FilterChip(
                  label:
                      Text(range.label, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (value) {
                    filters.quickRange = value ? range : null;
                    if (value) {
                      filters.dateFrom = null;
                      filters.dateTo = null;
                    }
                    onChanged();
                  },
                );
              }).toList(),
            ),
            _ToggleRow(
              label: 'Solo no revisados',
              value: filters.soloNoRevisados,
              onChanged: (value) {
                filters.soloNoRevisados = value;
                onChanged();
              },
            ),
            _ToggleRow(
              label: 'Solo con acción correctiva',
              value: filters.soloConAccionCorrectiva,
              onChanged: (value) {
                filters.soloConAccionCorrectiva = value;
                onChanged();
              },
            ),
          ],
        );
      },
    );
  }
}

class _AlertLevelDropdown extends StatelessWidget {
  const _AlertLevelDropdown({required this.value, required this.onChanged});

  final AlertLevel? value;
  final ValueChanged<AlertLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AlertLevel?>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: recordFilterDecoration('Estado alerta'),
      items: [
        const DropdownMenuItem<AlertLevel?>(value: null, child: Text('Todos')),
        ...AlertLevel.values.map(
          (l) => DropdownMenuItem(
            value: l,
            child: Text(l.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: recordFilterDecoration(label),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos', overflow: TextOverflow.ellipsis),
        ),
        ...options.map(
          (o) => DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

InputDecoration recordFilterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
