import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FormulaBox extends StatelessWidget {
  const FormulaBox({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(compact ? 10 : 18),
        border: Border(
          left: BorderSide(
            color: AppColors.accentDark,
            width: compact ? 5 : 8,
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Formula: '),
            TextSpan(
              text: compact
                  ? 'Mts = Neps / 0.09'
                  : 'Mts calculados = Neps / 0.09\n',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (!compact) ...[
              const TextSpan(text: 'Ejemplo: '),
              const TextSpan(
                text: '51 / 0.09 = 566.667',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ],
        ),
        style: TextStyle(
          color: const Color(0xFF3B2F1C),
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }
}
