import 'package:flutter/material.dart';

import '../../models/export_column.dart';
import '../theme/app_theme.dart';

class ExportColumnSelector extends StatelessWidget {
  const ExportColumnSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final Set<ExportColumn> selected;
  final ValueChanged<Set<ExportColumn>> onChanged;
  final bool compact;

  void _toggle(ExportColumn column, bool? value) {
    final next = Set<ExportColumn>.from(selected);
    if (value == true) {
      next.add(column);
    } else {
      next.remove(column);
    }
    if (ExportColumn.isValidSelection(next)) {
      onChanged(next);
    }
  }

  void _selectAll() => onChanged(ExportColumn.defaultSelection());

  @override
  Widget build(BuildContext context) {
    final chips = ExportColumn.ordered.map((column) {
      return FilterChip(
        label: Text(column.label),
        selected: selected.contains(column),
        onSelected: (isSelected) => _toggle(column, isSelected),
        selectedColor: AppColors.primaryGreen.withValues(alpha: 0.25),
        checkmarkColor: AppColors.primaryGreen,
        labelStyle: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight:
              selected.contains(column) ? FontWeight.w700 : FontWeight.w500,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 0 : 2,
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Columnas del informe',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _selectAll,
              child: const Text('Todas'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Elija que columnas incluir al compartir o exportar.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: compact ? 11 : 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: chips,
        ),
      ],
    );
  }
}
