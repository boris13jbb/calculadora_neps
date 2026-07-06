import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/alert_level.dart';
import '../../models/nep_record.dart';
import '../../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Identificadores de cada gráfica del catálogo de calidad.
enum QualityChartKind {
  topTelarsNeps,
  statusDistribution,
  telarStackedAlerts,
  criticalityGauge,
  nepsByFabric,
  nepsByLot,
  dailyNepsTrend,
  dailyCriticalTrend,
  avgNepsByTelar,
}

/// Subconjuntos reutilizables del catálogo de gráficas.
class QualityChartsCatalog {
  const QualityChartsCatalog._();

  static const List<QualityChartKind> full = [
    QualityChartKind.topTelarsNeps,
    QualityChartKind.statusDistribution,
    QualityChartKind.telarStackedAlerts,
    QualityChartKind.criticalityGauge,
    QualityChartKind.nepsByFabric,
    QualityChartKind.nepsByLot,
    QualityChartKind.dailyNepsTrend,
    QualityChartKind.dailyCriticalTrend,
    QualityChartKind.avgNepsByTelar,
  ];

  /// Resumen rápido para el panel principal (3 gráficas fijas).
  static const List<QualityChartKind> dashboardSummary = [
    QualityChartKind.statusDistribution,
    QualityChartKind.criticalityGauge,
    QualityChartKind.dailyNepsTrend,
  ];
}

/// Sección de gráficas analíticas reutilizable en Inicio y Análisis gráfico.
///
/// Usa el ancho disponible del contenido (no el lado corto de la pantalla)
/// para decidir columnas, de modo que en web con sidebar se muestren todas
/// las gráficas aunque la ventana no sea muy alta.
class QualityChartsSection extends StatelessWidget {
  const QualityChartsSection({
    super.key,
    required this.records,
    required this.formatDecimal,
    this.include = QualityChartsCatalog.full,
    this.compact = false,
    this.onGoToCapture,
    this.onGoToRecords,
  });

  final List<NepRecord> records;
  final String Function(double) formatDecimal;
  final List<QualityChartKind> include;
  final bool compact;
  final VoidCallback? onGoToCapture;
  final VoidCallback? onGoToRecords;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
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
        child: EmptyState(
          compact: compact,
          icon: Icons.bar_chart_outlined,
          title: 'Sin datos para gráficas',
          message: 'Importe o capture registros para ver el análisis visual.',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoColumns = width >= 680;
        final chartHeight = width < 480 ? 210.0 : (twoColumns ? 280.0 : 250.0);

        final topTelars =
            analyticsService.topTelaresPorNeps(records, limit: 10);
        final topTelas = analyticsService.topTelasPorNeps(records, limit: 8);
        final topLotes = analyticsService.topLotesPorNeps(records, limit: 8);
        final trend = analyticsService.tendenciaDiaria(records);
        final criticalTrend = analyticsService.tendenciaCriticosDiaria(records);
        final avgByTelar =
            analyticsService.promedioPorTelar(records).take(10).toList();
        final distribution = analyticsService.distribucionPorEstado(records);
        final telarAlerts =
            analyticsService.topTelaresConAlertas(records, limit: 6);
        final pctCritical = analyticsService.porcentajeCriticos(records);

        Widget row(Widget left, Widget? right) {
          if (!twoColumns || right == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                left,
                if (right != null) ...[const SizedBox(height: 12), right]
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          );
        }

        final data = _QualityChartData(
          topTelars: topTelars,
          topTelas: topTelas,
          topLotes: topLotes,
          trend: trend,
          criticalTrend: criticalTrend,
          avgByTelar: avgByTelar,
          distribution: distribution,
          telarAlerts: telarAlerts,
          pctCritical: pctCritical,
        );

        final cards = <Widget>[
          for (final kind in include)
            _buildChartCard(
              kind: kind,
              data: data,
              chartHeight: chartHeight,
              formatDecimal: formatDecimal,
            ),
        ];

        if (cards.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _layoutChartRows(cards, twoColumns, row),
        );
      },
    );
  }
}

/// Alias de compatibilidad con el nombre original del panel.
typedef DashboardChartsSection = QualityChartsSection;

class _QualityChartData {
  const _QualityChartData({
    required this.topTelars,
    required this.topTelas,
    required this.topLotes,
    required this.trend,
    required this.criticalTrend,
    required this.avgByTelar,
    required this.distribution,
    required this.telarAlerts,
    required this.pctCritical,
  });

  final List<GroupNepsSummary> topTelars;
  final List<GroupNepsSummary> topTelas;
  final List<GroupNepsSummary> topLotes;
  final List<DailyNepsPoint> trend;
  final List<DailyNepsPoint> criticalTrend;
  final List<GroupNepsSummary> avgByTelar;
  final AlertDistribution distribution;
  final List<TelarAlertSummary> telarAlerts;
  final double pctCritical;
}

List<Widget> _layoutChartRows(
  List<Widget> cards,
  bool twoColumns,
  Widget Function(Widget left, Widget? right) row,
) {
  if (!twoColumns) {
    return [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        cards[i],
      ],
    ];
  }

  final rows = <Widget>[];
  for (var i = 0; i < cards.length; i += 2) {
    if (i > 0) rows.add(const SizedBox(height: 14));
    rows.add(row(cards[i], i + 1 < cards.length ? cards[i + 1] : null));
  }
  return rows;
}

Widget _buildChartCard({
  required QualityChartKind kind,
  required _QualityChartData data,
  required double chartHeight,
  required String Function(double) formatDecimal,
}) {
  final horizontalHeight = chartHeight - 20;

  return switch (kind) {
    QualityChartKind.topTelarsNeps => _ChartCard(
        icon: Icons.leaderboard_outlined,
        title: 'Top 10 telares con más neps',
        subtitle: 'Acumulado por telar',
        height: chartHeight,
        child: _VerticalBarChart(
          labels: data.topTelars.map((e) => e.key).toList(),
          values: data.topTelars.map((e) => e.totalNeps).toList(),
          barColor: AppColors.statusCritical,
          formatValue: formatDecimal,
        ),
      ),
    QualityChartKind.statusDistribution => _ChartCard(
        icon: Icons.donut_large_outlined,
        title: 'Distribución de estados',
        subtitle: '${data.distribution.total} registros',
        height: chartHeight,
        child: _DonutChart(distribution: data.distribution),
      ),
    QualityChartKind.telarStackedAlerts => _ChartCard(
        icon: Icons.stacked_bar_chart_outlined,
        title: 'Alertas por telar (Top 6)',
        subtitle: 'Normal · Advertencia · Crítico',
        height: chartHeight,
        child: _StackedAlertBarChart(summaries: data.telarAlerts),
      ),
    QualityChartKind.criticalityGauge => _ChartCard(
        icon: Icons.speed_outlined,
        title: 'Índice de criticidad',
        subtitle: 'Porcentaje de registros críticos',
        height: chartHeight,
        child: _CriticalGauge(percentage: data.pctCritical),
      ),
    QualityChartKind.nepsByFabric => _ChartCard(
        icon: Icons.texture_outlined,
        title: 'Neps por tela',
        subtitle: 'Top 8 telas',
        height: horizontalHeight,
        child: _HorizontalBarChart(
          labels: data.topTelas.map((e) => e.key).toList(),
          values: data.topTelas.map((e) => e.totalNeps).toList(),
          barColor: AppColors.primaryBlue,
          formatValue: formatDecimal,
        ),
      ),
    QualityChartKind.nepsByLot => _ChartCard(
        icon: Icons.inventory_2_outlined,
        title: 'Neps por lote/trama',
        subtitle: 'Top 8 lotes',
        height: horizontalHeight,
        child: _HorizontalBarChart(
          labels: data.topLotes.map((e) => e.key).toList(),
          values: data.topLotes.map((e) => e.totalNeps).toList(),
          barColor: AppColors.statusWarning,
          formatValue: formatDecimal,
        ),
      ),
    QualityChartKind.dailyNepsTrend => _ChartCard(
        icon: Icons.show_chart_outlined,
        title: 'Tendencia diaria de neps',
        subtitle: 'Total acumulado por día',
        height: chartHeight,
        child: _LineChartWidget(
          points: data.trend,
          formatDecimal: formatDecimal,
          lineColor: AppColors.primaryBlue,
          fillColor: AppColors.primaryBlue.withValues(alpha: 0.12),
        ),
      ),
    QualityChartKind.dailyCriticalTrend => _ChartCard(
        icon: Icons.warning_amber_outlined,
        title: 'Tendencia de críticos',
        subtitle: 'Neps críticos por día',
        height: chartHeight,
        child: _LineChartWidget(
          points: data.criticalTrend,
          formatDecimal: formatDecimal,
          lineColor: AppColors.statusCritical,
          fillColor: AppColors.statusCritical.withValues(alpha: 0.12),
          emptyMessage: 'Sin críticos en el periodo',
        ),
      ),
    QualityChartKind.avgNepsByTelar => _ChartCard(
        icon: Icons.equalizer_outlined,
        title: 'Promedio de neps por telar',
        subtitle: 'Top 10 telares',
        height: chartHeight,
        child: _VerticalBarChart(
          labels: data.avgByTelar.map((e) => e.key).toList(),
          values: data.avgByTelar.map((e) => e.averageNeps).toList(),
          barColor: AppColors.statusNormal,
          formatValue: formatDecimal,
        ),
      ),
  };
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.icon,
    required this.title,
    required this.height,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textGreen,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
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

class _VerticalBarChart extends StatelessWidget {
  const _VerticalBarChart({
    required this.labels,
    required this.values,
    required this.barColor,
    required this.formatValue,
  });

  final List<String> labels;
  final List<double> values;
  final Color barColor;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return _emptyChart();

    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m) * 1.2;
    final safeMax = maxY <= 0 ? 1.0 : maxY;
    final barWidth =
        labels.length <= 5 ? 28.0 : (labels.length <= 8 ? 20.0 : 14.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMax,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'T${labels[group.x.toInt()]}\n${formatValue(rod.toY)} neps',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
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
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(labels.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                width: barWidth,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    barColor.withValues(alpha: 0.75),
                    barColor,
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({
    required this.labels,
    required this.values,
    required this.barColor,
    required this.formatValue,
  });

  final List<String> labels;
  final List<double> values;
  final Color barColor;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return _emptyChart();

    final maxVal = values.fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: labels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final fraction = (values[index] / safeMax).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _shortLabel(labels[index], max: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatValue(values[index]),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    backgroundColor: AppColors.borderLight,
                    color: barColor,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _shortLabel(String value, {int max = 12}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}…';
  }
}

class _StackedAlertBarChart extends StatelessWidget {
  const _StackedAlertBarChart({required this.summaries});

  final List<TelarAlertSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return _emptyChart();

    final maxY = summaries.fold<double>(0, (m, s) {
          final total = s.recordCount.toDouble();
          return total > m ? total : m;
        }) *
        1.2;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return BarChart(
      BarChartData(
        maxY: safeMax,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= summaries.length) return const SizedBox();
                return Text(
                  summaries[i].telar,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
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
              FlLine(color: AppColors.border, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(summaries.length, (i) {
          final s = summaries[i];
          final normal = (s.recordCount - s.criticalCount - s.warningCount)
              .clamp(0, s.recordCount);
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.recordCount.toDouble(),
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                rodStackItems: [
                  if (normal > 0)
                    BarChartRodStackItem(
                        0, normal.toDouble(), AppColors.statusNormal),
                  if (s.warningCount > 0)
                    BarChartRodStackItem(
                      normal.toDouble(),
                      (normal + s.warningCount).toDouble(),
                      AppColors.statusWarning,
                    ),
                  if (s.criticalCount > 0)
                    BarChartRodStackItem(
                      (normal + s.warningCount).toDouble(),
                      s.recordCount.toDouble(),
                      AppColors.statusCritical,
                    ),
                ],
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _CriticalGauge extends StatelessWidget {
  const _CriticalGauge({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final safePct = percentage.clamp(0, 100);
    final color = safePct >= 50
        ? AppColors.statusCritical
        : (safePct >= 25 ? AppColors.statusWarning : AppColors.statusNormal);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 52,
              sections: [
                PieChartSectionData(
                  value: safePct.toDouble(),
                  color: color,
                  radius: 40,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (100 - safePct).toDouble(),
                  color: AppColors.borderLight,
                  radius: 40,
                  showTitle: false,
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
              Text(
                '${safePct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'registros críticos',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _LegendDot(
                  color: AppColors.statusNormal, label: 'Objetivo < 25%'),
              _LegendDot(
                  color: AppColors.statusWarning, label: 'Atención 25–50%'),
              _LegendDot(
                  color: AppColors.statusCritical, label: 'Riesgo > 50%'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.distribution});

  final AlertDistribution distribution;

  @override
  Widget build(BuildContext context) {
    if (distribution.total == 0) return _emptyChart();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 44,
                  sections: [
                    PieChartSectionData(
                      value: distribution.normal.toDouble(),
                      color: AppColors.statusNormal,
                      title: distribution.normal > 0
                          ? '${distribution.normal}'
                          : '',
                      radius: 52,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: distribution.advertencia.toDouble(),
                      color: AppColors.statusWarning,
                      title: distribution.advertencia > 0
                          ? '${distribution.advertencia}'
                          : '',
                      radius: 52,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: distribution.critico.toDouble(),
                      color: AppColors.statusCritical,
                      title: distribution.critico > 0
                          ? '${distribution.critico}'
                          : '',
                      radius: 52,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${distribution.total}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textGreen,
                    ),
                  ),
                  const Text(
                    'total',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ],
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
                label: 'Normal',
                count: distribution.normal,
                pct: distribution.percentage(AlertLevel.normal),
              ),
              _LegendItem(
                color: AppColors.statusWarning,
                label: 'Advertencia',
                count: distribution.advertencia,
                pct: distribution.percentage(AlertLevel.advertencia),
              ),
              _LegendItem(
                color: AppColors.statusCritical,
                label: 'Crítico',
                count: distribution.critico,
                pct: distribution.percentage(AlertLevel.critico),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.pct,
  });

  final Color color;
  final String label;
  final int count;
  final double pct;

  @override
  Widget build(BuildContext context) {
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

class _LineChartWidget extends StatelessWidget {
  const _LineChartWidget({
    required this.points,
    required this.formatDecimal,
    required this.lineColor,
    required this.fillColor,
    this.emptyMessage = 'Sin datos',
  });

  final List<DailyNepsPoint> points;
  final String Function(double) formatDecimal;
  final Color lineColor;
  final Color fillColor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }

    final spots = <FlSpot>[
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
            getTooltipItems: (touched) {
              return touched.map((spot) {
                final i = spot.x.toInt();
                if (i < 0 || i >= points.length) return null;
                final p = points[i];
                return LineTooltipItem(
                  '${p.date.day}/${p.date.month}\n${formatDecimal(p.totalNeps)} neps\n${p.recordCount} reg.',
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
              reservedSize: 26,
              interval: points.length > 8 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                final d = points[i].date;
                return Text(
                  '${d.day}/${d.month}',
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
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
              FlLine(color: AppColors.border, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(show: true, color: fillColor),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

Widget _emptyChart() {
  return const Center(
    child: Text('Sin datos', style: TextStyle(color: AppColors.muted)),
  );
}
