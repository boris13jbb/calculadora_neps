import 'package:flutter/material.dart';

import '../theme/app_styles.dart';
import '../theme/app_theme.dart';

class SummaryCards extends StatelessWidget {
  const SummaryCards({
    super.key,
    required this.totalRecords,
    required this.totalNeps,
    required this.averageNeps,
  });

  final int totalRecords;
  final String totalNeps;
  final String averageNeps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 500;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isPhone ? 1 : 3,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: isPhone ? 2.3 : 2.5,
          children: [
            _SummaryCard(
              title: 'Total registros',
              value: '$totalRecords',
              subtitle: 'registros capturados',
              icon: Icons.assignment_outlined,
            ),
            _SummaryCard(
              title: 'Total neps',
              value: totalNeps,
              subtitle: 'neps en total',
              icon: Icons.scatter_plot_outlined,
            ),
            _SummaryCard(
              title: 'Promedio neps',
              value: averageNeps,
              subtitle: 'promedio calculado',
              icon: Icons.show_chart_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 88;
        final valueSize = compact ? 22.0 : 28.0;
        final padding = compact ? 12.0 : 16.0;
        final iconSize = compact ? 40.0 : 48.0;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: AppDecorations.card(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: valueSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.accentDark,
                  size: iconSize * 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
