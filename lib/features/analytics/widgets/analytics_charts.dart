import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../models/alert_level.dart';
import '../../../models/analytics_summary.dart';
import '../../../models/time_series_point.dart';
import '../../../services/analytics_service.dart';

/// Tarjetas KPI para la pantalla de gráficas.
class AnalyticsKpiSection extends StatelessWidget {
  const AnalyticsKpiSection({
    super.key,
    required this.summary,
    required this.formatDecimal,
    required this.formatNumber,
    this.compact = false,
  });

  final AnalyticsSummary summary;
  final String Function(double) formatDecimal;
  final String Function(double) formatNumber;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return KpiStrip(
      compact: compact,
      minCardWidth: compact ? 160 : 200,
      cards: [
        KpiCard(
          compact: compact,
          label: 'Total registros',
          value: '${summary.totalRecords}',
          icon: Icons.list_alt,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          compact: compact,
          label: 'Promedio neps',
          value: formatNumber(summary.averageNeps),
          icon: Icons.show_chart,
          color: AppColors.primaryGreen,
        ),
        KpiCard(
          compact: compact,
          label: 'Total neps',
          value: formatDecimal(summary.totalNeps),
          icon: Icons.stacked_line_chart,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          compact: compact,
          label: 'Total mts calc.',
          value: formatDecimal(summary.totalMts),
          icon: Icons.straighten,
          color: AppColors.accentDark,
          subtitle: 'Neps / 0.09',
        ),
        KpiCard(
          compact: compact,
          label: 'Mínimo neps',
          value: formatDecimal(summary.minNeps),
          icon: Icons.arrow_downward,
          color: AppColors.statusNormal,
        ),
        KpiCard(
          compact: compact,
          label: 'Máximo neps',
          value: formatDecimal(summary.maxNeps),
          icon: Icons.arrow_upward,
          color: AppColors.statusWarning,
        ),
        KpiCard(
          compact: compact,
          label: 'Advertencias',
          value: '${summary.warningCount}',
          icon: Icons.warning_amber_outlined,
          color: AppColors.statusWarning,
        ),
        KpiCard(
          compact: compact,
          label: 'Críticos',
          value: '${summary.criticalCount}',
          icon: Icons.error_outline,
          color: AppColors.statusCritical,
          subtitle:
              '${summary.criticalPercentage.toStringAsFixed(1)}% del total',
        ),
        KpiCard(
          compact: compact,
          label: '% normales',
          value: '${summary.normalPercentage.toStringAsFixed(1)}%',
          icon: Icons.check_circle_outline,
          color: AppColors.statusNormal,
          subtitle: '${summary.normalCount} registros',
        ),
        if (summary.averageNepsPerTelar != null)
          KpiCard(
            compact: compact,
            label: 'Prom. por telar',
            value: formatNumber(summary.averageNepsPerTelar!),
            icon: Icons.precision_manufacturing_outlined,
            color: AppColors.primaryBlue,
            subtitle: '${summary.byTelar.length} telares',
          ),
        if (summary.averageNepsPerTurno != null)
          KpiCard(
            compact: compact,
            label: 'Prom. por turno',
            value: formatNumber(summary.averageNepsPerTurno!),
            icon: Icons.schedule_outlined,
            color: AppColors.accentDark,
            subtitle: '${summary.byTurno.length} turnos',
          ),
      ],
    );
  }
}

/// Gráfica de línea para tendencia temporal.
class AnalyticsLineChart extends StatelessWidget {
  const AnalyticsLineChart({
    super.key,
    required this.points,
    required this.formatDecimal,
    this.height = 260,
    this.lineColor = AppColors.primaryBlue,
    this.emptyMessage = 'Sin datos para el periodo seleccionado.',
  });

  final List<TimeSeriesPoint> points;
  final String Function(double) formatDecimal;
  final double height;
  final Color lineColor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Tendencia de neps',
      icon: Icons.timeline,
      height: height,
      child: points.isEmpty
          ? _emptyMessage(emptyMessage)
          : _LineChartBody(
              points: points,
              formatDecimal: formatDecimal,
              lineColor: lineColor,
            ),
    );
  }
}

/// Gráfica de barras para comparación por periodo o grupo.
class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({
    super.key,
    required this.title,
    required this.items,
    required this.labelFor,
    required this.valueFor,
    this.height = 260,
    this.barColor = AppColors.primaryGreen,
    this.emptyMessage = 'Sin datos para comparar.',
  });

  final String title;
  final List<dynamic> items;
  final String Function(dynamic item) labelFor;
  final double Function(dynamic item) valueFor;
  final double height;
  final Color barColor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: title,
      icon: Icons.bar_chart,
      height: height,
      child: items.isEmpty
          ? _emptyMessage(emptyMessage)
          : _BarChartBody(
              items: items,
              labelFor: labelFor,
              valueFor: valueFor,
              barColor: barColor,
            ),
    );
  }
}

/// Gráfica circular de distribución de alertas.
class AnalyticsAlertPieChart extends StatelessWidget {
  const AnalyticsAlertPieChart({
    super.key,
    required this.distribution,
    this.height = 260,
  });

  final AlertDistribution distribution;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Distribución de alertas',
      icon: Icons.pie_chart_outline,
      height: height,
      child: distribution.total == 0
          ? _emptyMessage('Sin alertas en el periodo.')
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: [
                        _pieSection(
                          distribution.normal,
                          AppColors.statusNormal,
                          'Normal',
                        ),
                        _pieSection(
                          distribution.advertencia,
                          AppColors.statusWarning,
                          'Adv.',
                        ),
                        _pieSection(
                          distribution.critico,
                          AppColors.statusCritical,
                          'Crit.',
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
                      _legendRow(
                        AppColors.statusNormal,
                        'Normal',
                        distribution.normal,
                        distribution.percentage(AlertLevel.normal),
                      ),
                      _legendRow(
                        AppColors.statusWarning,
                        'Advertencia',
                        distribution.advertencia,
                        distribution.percentage(AlertLevel.advertencia),
                      ),
                      _legendRow(
                        AppColors.statusCritical,
                        'Crítico',
                        distribution.critico,
                        distribution.percentage(AlertLevel.critico),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PieChartSectionData _pieSection(int count, Color color, String title) {
    return PieChartSectionData(
      value: count.toDouble(),
      color: color,
      title: count > 0 ? '$count' : '',
      radius: 52,
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count (${pct.toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.height = 260,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class _LineChartBody extends StatelessWidget {
  const _LineChartBody({
    required this.points,
    required this.formatDecimal,
    required this.lineColor,
  });

  final List<TimeSeriesPoint> points;
  final String Function(double) formatDecimal;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].totalNeps),
    ];
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m) * 1.2;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMax,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((spot) {
              final i = spot.x.toInt();
              if (i < 0 || i >= points.length) return null;
              final p = points[i];
              return LineTooltipItem(
                '${p.label}\n${formatDecimal(p.totalNeps)} neps\n${p.recordCount} reg.',
                const TextStyle(fontSize: 11, color: Colors.white),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: points.length > 8 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].label,
                    style: const TextStyle(fontSize: 8, color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMax / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

class _BarChartBody extends StatelessWidget {
  const _BarChartBody({
    required this.items,
    required this.labelFor,
    required this.valueFor,
    required this.barColor,
  });

  final List<dynamic> items;
  final String Function(dynamic item) labelFor;
  final double Function(dynamic item) valueFor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final display = items.take(10).toList();
    final maxY = display.fold<double>(
          0,
          (m, item) {
            final v = valueFor(item);
            return v > m ? v : m;
          },
        ) *
        1.15;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMax,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = display[group.x.toInt()];
              return BarTooltipItem(
                '${labelFor(item)}\n${valueFor(item).toStringAsFixed(1)}',
                const TextStyle(fontSize: 11, color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= display.length) return const SizedBox();
                final label = labelFor(display[i]);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 7)}…' : label,
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
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
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < display.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: valueFor(display[i]),
                  color: barColor,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

Widget _emptyMessage(String message) {
  return Center(
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted, fontSize: 12),
    ),
  );
}
