import 'package:flutter/material.dart';

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
        final isPhone = constraints.maxWidth < 400;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isPhone ? 2 : 3,
          mainAxisSpacing: isPhone ? 6 : 10,
          crossAxisSpacing: isPhone ? 6 : 10,
          childAspectRatio: isPhone ? 2.8 : 2.4,
          children: [
            _SummaryCard(title: 'Total registros', value: '$totalRecords'),
            _SummaryCard(title: 'Total neps', value: totalNeps),
            _SummaryCard(title: 'Promedio neps', value: averageNeps),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.accentDark, width: 5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B4C2C),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
