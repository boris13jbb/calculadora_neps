import 'package:flutter/material.dart';

import '../theme/app_styles.dart';
import '../theme/app_theme.dart';

class FormulaBox extends StatelessWidget {
  const FormulaBox({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.soft,
      ),
      child: compact
          ? _buildCompactContent()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return _buildCompactContent();
                }
                return Row(
                  children: [
                    Expanded(child: _buildFormulaSide()),
                    Container(
                      width: 1,
                      height: 72,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.border,
                    ),
                    Expanded(child: _buildExampleSide()),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCompactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormulaSide(),
        const SizedBox(height: 10),
        _buildExampleSide(),
      ],
    );
  }

  Widget _buildFormulaSide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.calculate_outlined,
            color: AppColors.accentDark,
            size: compact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formula de calculo',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 13,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mts calculados = Neps / 0.09',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 14 : 16,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExampleSide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ejemplo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 13,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '51 / 0.09 = 566.667',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 14 : 16,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
