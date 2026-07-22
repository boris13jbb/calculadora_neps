import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/report_chart_configuration.dart';
import '../models/report_chart_type.dart';
import 'report_data_builder.dart';
import 'report_grouping_service.dart';

/// Construye widgets de gráficas para captura PNG en reportes.
class ReportChartBuilder {
  const ReportChartBuilder();

  static const double chartWidth = 640;
  static const double chartHeight = 300;

  /// Widget listo para capturar (con título y fondo).
  Widget? buildCaptureWidget(
    ProcessedReportData data,
    ReportChartConfiguration config, {
    bool includeOperatorData = true,
  }) {
    if (!config.enabled) return null;
    if (config.type.requiresOperatorPermission && !includeOperatorData) {
      return null;
    }

    final child = _buildChartBody(data, config);
    if (child == null) return null;

    return Container(
      width: chartWidth,
      height: chartHeight,
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            config.effectiveTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          if (config.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                config.subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            )
          else
            const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget? _buildChartBody(
    ProcessedReportData data,
    ReportChartConfiguration config,
  ) {
    return switch (config.type) {
      ReportChartType.tendenciaNeps ||
      ReportChartType.promedioMovil ||
      ReportChartType.dispersionNepsTiempo =>
        _lineChartFromTemporal(data, config),
      ReportChartType.barrasRegistrosPeriodo =>
        _barChartFromTemporal(data, config, (p) => p.recordCount.toDouble()),
      ReportChartType.barrasPromedioTelar ||
      ReportChartType.rankingTelares ||
      ReportChartType.paretoTelaresCriticos =>
        _barChartFromGroups(
          data.byTelar,
          (g) => g.averageNeps,
          config,
          horizontal: config.type == ReportChartType.rankingTelares,
        ),
      ReportChartType.barrasPromedioTela ||
      ReportChartType.rankingTelas =>
        _barChartFromGroups(
          data.byTela,
          (g) => g.averageNeps,
          config,
          horizontal: config.type == ReportChartType.rankingTelas,
        ),
      ReportChartType.barrasPromedioTurno =>
        _barChartFromGroups(data.byTurno, (g) => g.averageNeps, config),
      ReportChartType.barrasPromedioOperario =>
        _barChartFromGroups(data.byOperario, (g) => g.averageNeps, config),
      ReportChartType.barrasPromedioLinea =>
        _barChartFromGroups(data.byLinea, (g) => g.averageNeps, config),
      ReportChartType.barrasAlertasTelar ||
      ReportChartType.barrasApiladasEstadosTelar =>
        _stackedAlertBars(data.byTelar, config),
      ReportChartType.barrasApiladasEstadosPeriodo =>
        _stackedAlertTemporal(data, config),
      ReportChartType.circularAlertas ||
      ReportChartType.donaAlertas =>
        _pieChart(data, donut: config.type == ReportChartType.donaAlertas),
      ReportChartType.histogramaNeps => _histogram(data),
      ReportChartType.revisadosVsPendientes => _reviewBar(data),
      ReportChartType.accionesCorrectivas => _correctiveBar(data),
      ReportChartType.comparacionPeriodos => _comparisonBar(data),
      ReportChartType.rankingLotes => _barChartFromGroups(
          data.byLote,
          (g) => g.averageNeps,
          config,
          horizontal: true,
        ),
      _ => _barChartFromGroups(
          data.byTelar.take(config.maxCategories).toList(),
          (g) => g.averageNeps,
          config,
        ),
    };
  }

  Widget? _lineChartFromTemporal(
    ProcessedReportData data,
    ReportChartConfiguration config,
  ) {
    final points = data.temporalGroups;
    if (points.isEmpty) return _emptyChart();

    final values = points.map((p) => p.averageNeps).toList();
    List<double> plotValues = values;
    if (config.type == ReportChartType.promedioMovil) {
      plotValues = reportGroupingService.movingAverage(
        values,
        config.movingAverageWindow,
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < plotValues.length; i++) {
      spots.add(FlSpot(i.toDouble(), plotValues[i]));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].label,
                    style: const TextStyle(fontSize: 8),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primaryBlue,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget? _barChartFromTemporal(
    ProcessedReportData data,
    ReportChartConfiguration config,
    double Function(TemporalGroupPoint) valueFor,
  ) {
    final points = data.temporalGroups.take(config.maxCategories).toList();
    if (points.isEmpty) return _emptyChart();
    return _simpleBarChart(
      labels: points.map((p) => p.label).toList(),
      values: points.map(valueFor).toList(),
      color: AppColors.primaryGreen,
      horizontal: config.horizontal,
    );
  }

  Widget? _barChartFromGroups(
    List<DimensionGroupStats> groups,
    double Function(DimensionGroupStats) valueFor,
    ReportChartConfiguration config, {
    bool horizontal = false,
  }) {
    final items = groups.take(config.maxCategories).toList();
    if (items.isEmpty) return _emptyChart();
    return _simpleBarChart(
      labels: items.map((g) => g.key).toList(),
      values: items.map(valueFor).toList(),
      color: AppColors.primaryBlue,
      horizontal: horizontal || config.horizontal,
    );
  }

  Widget? _stackedAlertBars(
    List<DimensionGroupStats> groups,
    ReportChartConfiguration config,
  ) {
    final items = groups.take(config.maxCategories).toList();
    if (items.isEmpty) return _emptyChart();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: items
                .map((g) => (g.normalCount + g.warningCount + g.criticalCount)
                    .toDouble())
                .reduce((a, b) => a > b ? a : b) *
            1.2,
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].normalCount.toDouble(),
                  color: AppColors.statusNormal,
                  width: 14,
                ),
                BarChartRodData(
                  fromY: items[i].normalCount.toDouble(),
                  toY:
                      (items[i].normalCount + items[i].warningCount).toDouble(),
                  color: AppColors.statusWarning,
                  width: 14,
                ),
                BarChartRodData(
                  fromY:
                      (items[i].normalCount + items[i].warningCount).toDouble(),
                  toY: (items[i].normalCount +
                          items[i].warningCount +
                          items[i].criticalCount)
                      .toDouble(),
                  color: AppColors.statusCritical,
                  width: 14,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= items.length) return const SizedBox();
                return Text(items[i].key, style: const TextStyle(fontSize: 8));
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget? _stackedAlertTemporal(
    ProcessedReportData data,
    ReportChartConfiguration config,
  ) {
    final points = data.temporalGroups.take(config.maxCategories).toList();
    if (points.isEmpty) return _emptyChart();
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].normalCount.toDouble(),
                  color: AppColors.statusNormal,
                  width: 12,
                ),
                BarChartRodData(
                  fromY: points[i].normalCount.toDouble(),
                  toY: (points[i].normalCount + points[i].warningCount)
                      .toDouble(),
                  color: AppColors.statusWarning,
                  width: 12,
                ),
                BarChartRodData(
                  fromY: (points[i].normalCount + points[i].warningCount)
                      .toDouble(),
                  toY: (points[i].normalCount +
                          points[i].warningCount +
                          points[i].criticalCount)
                      .toDouble(),
                  color: AppColors.statusCritical,
                  width: 12,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox();
                return Text(points[i].label,
                    style: const TextStyle(fontSize: 7));
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 24),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget? _pieChart(ProcessedReportData data, {bool donut = false}) {
    final dist = data.statistics.alertDistribution;
    if (dist.normal + dist.advertencia + dist.critico == 0) {
      return _emptyChart();
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: donut ? 48 : 0,
        sections: [
          _pieSection(dist.normal, AppColors.statusNormal),
          _pieSection(dist.advertencia, AppColors.statusWarning),
          _pieSection(dist.critico, AppColors.statusCritical),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(int count, Color color) {
    return PieChartSectionData(
      value: count.toDouble().clamp(0.001, double.infinity),
      color: color,
      title: count > 0 ? '$count' : '',
      radius: 56,
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget? _histogram(ProcessedReportData data) {
    if (data.records.isEmpty) return _emptyChart();
    final neps = data.records.map((r) => r.neps).toList();
    final max = neps.reduce((a, b) => a > b ? a : b);
    const bins = 8;
    final step = max / bins;
    if (step <= 0) return _emptyChart();

    final counts = List<int>.filled(bins, 0);
    for (final n in neps) {
      var idx = (n / step).floor();
      if (idx >= bins) idx = bins - 1;
      counts[idx]++;
    }

    return _simpleBarChart(
      labels: List.generate(bins, (i) => '${(i * step).round()}'),
      values: counts.map((c) => c.toDouble()).toList(),
      color: AppColors.accentDark,
    );
  }

  Widget? _reviewBar(ProcessedReportData data) {
    final s = data.statistics;
    return _simpleBarChart(
      labels: const ['Revisados', 'Pendientes'],
      values: [s.reviewedCount.toDouble(), s.pendingReviewCount.toDouble()],
      color: AppColors.primaryBlue,
    );
  }

  Widget? _correctiveBar(ProcessedReportData data) {
    final s = data.statistics;
    return _simpleBarChart(
      labels: const ['Con acción', 'Sin acción'],
      values: [
        s.withCorrectiveActionCount.toDouble(),
        s.withoutCorrectiveActionCount.toDouble(),
      ],
      color: AppColors.statusWarning,
    );
  }

  Widget? _comparisonBar(ProcessedReportData data) {
    final c = data.comparison;
    if (c == null) return _emptyChart();
    return _simpleBarChart(
      labels: ['Prom. neps', 'Críticos', 'Mts'],
      values: [c.averageNepsA, c.criticalA.toDouble(), c.totalMtsA],
      color: AppColors.primaryGreen,
    );
  }

  Widget _simpleBarChart({
    required List<String> labels,
    required List<double> values,
    required Color color,
    bool horizontal = false,
  }) {
    if (labels.isEmpty) return _emptyChart();
    final maxY =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b) * 1.15;

    if (horizontal) {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: labels.length.toDouble(),
          barGroups: [
            for (var i = 0; i < labels.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: color,
                    width: 14,
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(labels[i], style: const TextStyle(fontSize: 8));
                },
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: values[i], color: color, width: 16),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[i], style: const TextStyle(fontSize: 8)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Widget _emptyChart() {
    return const Center(
      child: Text(
        'Sin datos para esta gráfica',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

const ReportChartBuilder reportChartBuilder = ReportChartBuilder();
