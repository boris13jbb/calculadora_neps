import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompactStatsRow extends StatelessWidget {
  const CompactStatsRow({
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatChip(label: 'Registros', value: '$totalRecords'),
        _StatChip(label: 'Neps', value: totalNeps),
        _StatChip(label: 'Prom. neps', value: averageNeps),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
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
