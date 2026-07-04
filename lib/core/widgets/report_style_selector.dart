import 'package:flutter/material.dart';

import '../../models/pdf_report_style.dart';
import '../theme/app_theme.dart';

/// Selector responsive del modo de reporte (Completo / Clásico).
class ReportStyleSelector extends StatelessWidget {
  const ReportStyleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
    this.showTitle = true,
    this.showDescription = true,
    this.titleStyle,
  });

  final PdfReportStyle selected;
  final ValueChanged<PdfReportStyle> onChanged;
  final bool compact;
  final bool showTitle;
  final bool showDescription;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useChips = constraints.maxWidth < 380;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle) ...[
              Text(
                'Modo de reporte (PDF, CSV, Excel)',
                style: titleStyle ??
                    TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 13 : 15,
                    ),
              ),
              SizedBox(height: compact ? 6 : 10),
            ],
            if (useChips)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PdfReportStyle.values.map((style) {
                  final isSelected = selected == style;
                  return ChoiceChip(
                    label: Text(style.label),
                    selected: isSelected,
                    onSelected: (_) => onChanged(style),
                    selectedColor:
                        AppColors.primaryGreen.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primaryGreen,
                  );
                }).toList(),
              )
            else
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PdfReportStyle>(
                  segments: PdfReportStyle.values
                      .map(
                        (style) => ButtonSegment<PdfReportStyle>(
                          value: style,
                          label: Text(style.label),
                          icon: Icon(
                            style == PdfReportStyle.completo
                                ? Icons.analytics_outlined
                                : Icons.description_outlined,
                          ),
                        ),
                      )
                      .toList(),
                  selected: {selected},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => onChanged(selection.first),
                ),
              ),
            if (showDescription) ...[
              SizedBox(height: compact ? 4 : 6),
              Text(
                selected.description,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
