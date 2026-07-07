import 'package:flutter/material.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_input_decoration.dart';
import '../../../core/widgets/record_filters_panel.dart';
import '../../../models/analytics_period.dart';
import '../../../models/nep_record.dart';
import '../../../models/record_filters.dart';

/// Panel de filtros para la pantalla de gráficas (periodo + filtros de registro).
class AnalyticsFilterPanel extends StatelessWidget {
  const AnalyticsFilterPanel({
    super.key,
    required this.records,
    required this.filters,
    required this.period,
    required this.onFiltersChanged,
    required this.onPeriodChanged,
    required this.onClear,
    this.compact = false,
    this.dateRangeError,
  });

  final List<NepRecord> records;
  final RecordFilters filters;
  final AnalyticsPeriod period;
  final VoidCallback onFiltersChanged;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;
  final VoidCallback onClear;
  final bool compact;
  final String? dateRangeError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agrupar por',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AnalyticsPeriod.values.map((p) {
            final selected = period == p;
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (_) => onPeriodChanged(p),
              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primaryBlue : AppColors.textDark,
              ),
              side: BorderSide(
                color: selected ? AppColors.primaryBlue : AppColors.border,
              ),
            );
          }).toList(),
        ),
        if (period == AnalyticsPeriod.custom) ...[
          SizedBox(height: compact ? 12 : 16),
          Text(
            'Rango de fechas',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          _CustomDateRangeFields(
            filters: filters,
            compact: compact,
            dateRangeError: dateRangeError,
            onChanged: onFiltersChanged,
          ),
        ],
        SizedBox(height: compact ? 12 : 16),
        RecordFiltersPanel(
          records: records,
          filters: filters,
          onChanged: onFiltersChanged,
          onClear: onClear,
          compact: compact,
        ),
      ],
    );
  }
}

/// Selectores de fecha visibles para el periodo personalizado.
class _CustomDateRangeFields extends StatelessWidget {
  const _CustomDateRangeFields({
    required this.filters,
    required this.onChanged,
    required this.compact,
    this.dateRangeError,
  });

  final RecordFilters filters;
  final VoidCallback onChanged;
  final bool compact;
  final String? dateRangeError;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    final borderColor =
        dateRangeError != null ? AppColors.statusCritical : AppColors.border;

    Widget fromField = _DatePickerField(
      label: 'Desde',
      value: filters.dateFrom,
      compact: compact,
      hasError: dateRangeError != null,
      onChanged: (value) {
        filters.dateFrom = value;
        filters.quickRange = null;
        onChanged();
      },
    );

    Widget toField = _DatePickerField(
      label: 'Hasta',
      value: filters.dateTo,
      compact: compact,
      hasError: dateRangeError != null,
      onChanged: (value) {
        filters.dateTo = value == null
            ? null
            : DateTime(value.year, value.month, value.day, 23, 59, 59);
        filters.quickRange = null;
        onChanged();
      },
    );

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phone)
            Column(
              children: [
                fromField,
                SizedBox(height: compact ? 8 : 10),
                toField,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: fromField),
                SizedBox(width: compact ? 10 : 12),
                Expanded(child: toField),
              ],
            ),
          if (dateRangeError != null) ...[
            SizedBox(height: compact ? 8 : 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.statusCritical,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateRangeError!,
                    style: const TextStyle(
                      color: AppColors.statusCritical,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.compact,
    this.hasError = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool compact;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final text = value == null
        ? 'Seleccionar fecha'
        : '${two(value!.day)}/${two(value!.month)}/${value!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              helpText: 'Seleccionar — $label',
            );
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: appInputDecoration(
              'Seleccionar',
              compact: compact,
            ).copyWith(
              errorBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      borderSide: const BorderSide(
                        color: AppColors.statusCritical,
                        width: 1.5,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: compact ? 16 : 18,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color:
                          value == null ? AppColors.muted : AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null)
                  IconButton(
                    icon: Icon(Icons.close, size: compact ? 16 : 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: 'Quitar fecha',
                    onPressed: () => onChanged(null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Aplica fechas por defecto al activar rango personalizado.
void ensureAnalyticsCustomDateDefaults(RecordFilters filters) {
  filters.quickRange = null;
  if (filters.dateFrom != null && filters.dateTo != null) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  filters.dateFrom ??= DateTime(now.year, now.month, 1);
  filters.dateTo ??= DateTime(
    today.year,
    today.month,
    today.day,
    23,
    59,
    59,
  );
}
