import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/nep_record.dart';
import '../../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Sección de gráficas analíticas del dashboard.
class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({
    super.key,
    required this.records,
    required this.formatDecimal,
    this.compact = false,
    this.onGoToCapture,
    this.onGoToRecords,
  });

  final List<NepRecord> records;
  final String Function(double) formatDecimal;
  final bool compact;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToRecords;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: EmptyState(
          compact: compact,
          icon: Icons.bar_chart_outlined,
          title: 'Sin datos para gráficas',
          message: 'Importe o capture registros para ver gráficas.',
          iconColor: AppColors.primaryGreen,
          actions: [
            if (onGoToCapture != null)
              EmptyStateAction(
                label: 'Capturar registro',
                icon: Icons.add_circle_outline,
                onPressed: onGoToCapture!,
              ),
            if (onGoToRecords != null)
              EmptyStateAction(
                label: 'Importar datos',
                icon: Icons.upload_file,
                filled: false,
                onPressed: onGoToRecords!,
              ),
          ],
        ),
      );
    }

    final topTelars = analyticsService.topTelaresPorNeps(records, limit: 10);
    final topTelas = analyticsService.topTelasPorNeps(records, limit: 8);
    final topLotes = analyticsService.topLotesPorNeps(records, limit: 8);
    final trend = analyticsService.tendenciaDiaria(records);
    final avgByTelar =
        analyticsService.promedioPorTelar(records).take(10).toList();
    final distribution = analyticsService.distribucionPorEstado(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          _ChartCard(
            title: 'Top 10 telares con más neps',
            height: 220,
            child: _BarChartWidget(
              labels: topTelars.map((e) => e.key).toList(),
              values: topTelars.map((e) => e.totalNeps).toList(),
              barColor: AppColors.statusCritical,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Distribución de estados',
            height: 200,
            child: _PieChartWidget(distribution: distribution),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChartCard(
                  title: 'Top 10 telares con más neps',
                  height: 260,
                  child: _BarChartWidget(
                    labels: topTelars.map((e) => e.key).toList(),
                    values: topTelars.map((e) => e.totalNeps).toList(),
                    barColor: AppColors.statusCritical,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChartCard(
                  title: 'Distribución de estados',
                  height: 260,
                  child: _PieChartWidget(distribution: distribution),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChartCard(
                  title: 'Neps por tela',
                  height: 240,
                  child: _BarChartWidget(
                    labels: topTelas.map((e) => _shortLabel(e.key)).toList(),
                    values: topTelas.map((e) => e.totalNeps).toList(),
                    barColor: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChartCard(
                  title: 'Neps por lote/trama',
                  height: 240,
                  child: _BarChartWidget(
                    labels: topLotes.map((e) => _shortLabel(e.key)).toList(),
                    values: topLotes.map((e) => e.totalNeps).toList(),
                    barColor: AppColors.statusWarning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChartCard(
                  title: 'Tendencia diaria de neps',
                  height: 240,
                  child: _LineChartWidget(
                    points: trend,
                    formatDecimal: formatDecimal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChartCard(
                  title: 'Promedio de neps por telar',
                  height: 240,
                  child: _BarChartWidget(
                    labels: avgByTelar.map((e) => e.key).toList(),
                    values: avgByTelar.map((e) => e.averageNeps).toList(),
                    barColor: AppColors.statusNormal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _shortLabel(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 10)}…';
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.height,
    required this.child,
  });

  final String title;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.textGreen,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class _BarChartWidget extends StatelessWidget {
  const _BarChartWidget({
    required this.labels,
    required this.values,
    required this.barColor,
  });

  final List<String> labels;
  final List<double> values;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m) * 1.15;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMax,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[i],
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMax / 4,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(labels.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: barColor,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _LineChartWidget extends StatelessWidget {
  const _LineChartWidget({
    required this.points,
    required this.formatDecimal,
  });

  final List<DailyNepsPoint> points;
  final String Function(double) formatDecimal;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('Sin datos'));

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].totalNeps));
    }

    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m) * 1.15;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMax,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((spot) {
                final i = spot.x.toInt();
                if (i < 0 || i >= points.length) return null;
                final p = points[i];
                return LineTooltipItem(
                  '${p.date.day}/${p.date.month}\n${formatDecimal(p.totalNeps)} neps',
                  const TextStyle(fontSize: 11, color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                final d = points[i].date;
                return Text(
                  '${d.day}/${d.month}',
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMax / 4,
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primaryBlue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  const _PieChartWidget({required this.distribution});

  final AlertDistribution distribution;

  @override
  Widget build(BuildContext context) {
    if (distribution.total == 0) {
      return const Center(child: Text('Sin datos'));
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                PieChartSectionData(
                  value: distribution.normal.toDouble(),
                  color: AppColors.statusNormal,
                  title: '${distribution.normal}',
                  radius: 48,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: distribution.advertencia.toDouble(),
                  color: AppColors.statusWarning,
                  title: '${distribution.advertencia}',
                  radius: 48,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: distribution.critico.toDouble(),
                  color: AppColors.statusCritical,
                  title: '${distribution.critico}',
                  radius: 48,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: AppColors.statusNormal,
                label: 'Normal (${distribution.normal})',
              ),
              _LegendItem(
                color: AppColors.statusWarning,
                label: 'Advertencia (${distribution.advertencia})',
              ),
              _LegendItem(
                color: AppColors.statusCritical,
                label: 'Crítico (${distribution.critico})',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
