import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../models/analytics_period.dart';
import '../../../models/nep_record.dart';
import '../models/chart_config.dart';
import '../services/chart_data_builder.dart';

/// Constructor de gráfica personalizada con validación de combinaciones.
class CustomChartBuilder extends StatefulWidget {
  const CustomChartBuilder({
    super.key,
    required this.records,
    required this.formatDecimal,
    required this.period,
    this.compact = false,
    this.initialConfig = const ChartConfig(),
    this.onConfigChanged,
  });

  final List<NepRecord> records;
  final String Function(double) formatDecimal;
  final AnalyticsPeriod period;
  final bool compact;
  final ChartConfig initialConfig;
  final ValueChanged<ChartConfig>? onConfigChanged;

  @override
  State<CustomChartBuilder> createState() => _CustomChartBuilderState();
}

class _CustomChartBuilderState extends State<CustomChartBuilder> {
  late ChartConfig _config = ChartConfigRules.normalize(widget.initialConfig);

  void _updateConfig(ChartConfig next) {
    final normalized = ChartConfigRules.normalize(next);
    setState(() => _config = normalized);
    widget.onConfigChanged?.call(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final result = chartDataBuilder.build(
      widget.records,
      _config,
      periodOverride: widget.period,
    );
    final allowedGroups = ChartConfigRules.allowedGroupings(_config.metric);
    final allowedVisuals =
        ChartConfigRules.allowedVisualTypes(_config.metric, _config.groupBy);

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Tres selectores en fila requieren ~200 px cada uno para evitar overflow.
              const minSelectorWidth = 200.0;
              const selectorGap = 12.0;
              final rowMinWidth = minSelectorWidth * 3 + selectorGap * 2;
              final stacked = constraints.maxWidth < rowMinWidth;

              final metricField = _SelectorField<ChartMetric>(
                label: 'Métrica',
                value: _config.metric,
                items: ChartMetric.values,
                labelFor: (m) => m.label,
                onChanged: (metric) =>
                    _updateConfig(_config.copyWith(metric: metric)),
              );
              final groupField = _SelectorField<ChartGroupBy>(
                label: 'Agrupación',
                value: _config.groupBy,
                items: allowedGroups,
                labelFor: (g) => g.label,
                onChanged: (groupBy) =>
                    _updateConfig(_config.copyWith(groupBy: groupBy)),
              );
              final visualField = _SelectorField<ChartVisualType>(
                label: 'Tipo de gráfica',
                value: _config.visualType,
                items: allowedVisuals,
                labelFor: (t) => t.label,
                onChanged: (visualType) =>
                    _updateConfig(_config.copyWith(visualType: visualType)),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    metricField,
                    const SizedBox(height: 12),
                    groupField,
                    const SizedBox(height: 12),
                    visualField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: metricField),
                  const SizedBox(width: 12),
                  Expanded(child: groupField),
                  const SizedBox(width: 12),
                  Expanded(child: visualField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!result.isValid)
            EmptyState(
              compact: widget.compact,
              icon: Icons.tune_outlined,
              title: 'Sin datos o combinación inválida',
              message: result.validationMessage ??
                  'Ajuste la métrica, agrupación o filtros.',
            )
          else
            _CustomChartPreview(
              result: result,
              visualType: _config.visualType,
              formatDecimal: widget.formatDecimal,
              height: widget.compact ? 220 : 280,
            ),
        ],
      ),
    );
  }
}

class _SelectorField<T> extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = items.contains(value) ? value : items.first;

    return DropdownButtonFormField<T>(
      key: ValueKey('$label-$selected-${items.length}'),
      isExpanded: true,
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      selectedItemBuilder: (context) => [
        for (final item in items)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              labelFor(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(
              labelFor(item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _CustomChartPreview extends StatelessWidget {
  const _CustomChartPreview({
    required this.result,
    required this.visualType,
    required this.formatDecimal,
    required this.height,
  });

  final ChartDataResult result;
  final ChartVisualType visualType;
  final String Function(double) formatDecimal;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.title.isNotEmpty)
          Text(
            result.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
        if (result.subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            result.subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: _renderChart(),
        ),
      ],
    );
  }

  Widget _renderChart() {
    return switch (visualType) {
      ChartVisualType.gauge => _GaugePreview(
          percentage: result.singleValue ??
              (result.values.isNotEmpty ? result.values.first : 0),
        ),
      ChartVisualType.kpi => Center(
          child: KpiCard(
            label: result.title,
            value: result.singleValue != null
                ? '${result.singleValue!.toStringAsFixed(1)}%'
                : formatDecimal(
                    result.values.isNotEmpty ? result.values.first : 0,
                  ),
            icon: Icons.insights_outlined,
            color: AppColors.primaryBlue,
            subtitle: result.subtitle,
          ),
        ),
      ChartVisualType.donut => _DonutPreview(
          labels: result.labels,
          values: result.values,
        ),
      ChartVisualType.horizontalBar => _BarPreview(
          labels: result.labels,
          values: result.values,
          horizontal: true,
          formatDecimal: formatDecimal,
        ),
      ChartVisualType.line => _LinePreview(
          labels: result.labels,
          values: result.values,
        ),
      ChartVisualType.verticalBar => _BarPreview(
          labels: result.labels,
          values: result.values,
          horizontal: false,
          formatDecimal: formatDecimal,
        ),
      ChartVisualType.table => _TablePreview(rows: result.tableRows),
    };
  }
}

class _GaugePreview extends StatelessWidget {
  const _GaugePreview({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final safe = percentage.clamp(0, 100);
    final color = safe >= 50
        ? AppColors.statusCritical
        : (safe >= 25 ? AppColors.statusWarning : AppColors.statusNormal);

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
                  value: safe.toDouble(),
                  color: color,
                  radius: 40,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (100 - safe).toDouble(),
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
            children: [
              Text(
                '${safe.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const Text(
                'registros críticos',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPreview extends StatelessWidget {
  const _DonutPreview({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  static const _colors = [
    AppColors.statusNormal,
    AppColors.statusWarning,
    AppColors.statusCritical,
    AppColors.primaryBlue,
    AppColors.accentDark,
  ];

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const Center(
        child: Text('Sin datos', style: TextStyle(color: AppColors.muted)),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 44,
        sections: [
          for (var i = 0; i < labels.length; i++)
            PieChartSectionData(
              value: values[i],
              color: _colors[i % _colors.length],
              radius: 36,
              title: '${values[i].toInt()}',
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarPreview extends StatelessWidget {
  const _BarPreview({
    required this.labels,
    required this.values,
    required this.horizontal,
    required this.formatDecimal,
  });

  final List<String> labels;
  final List<double> values;
  final bool horizontal;
  final String Function(double) formatDecimal;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const Center(
        child: Text('Sin datos', style: TextStyle(color: AppColors.muted)),
      );
    }

    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m) * 1.2;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    if (horizontal) {
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: safeMax,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 80,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 9, color: AppColors.muted),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < labels.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 14,
                    color: AppColors.primaryBlue,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

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
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[i],
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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 18,
                  color: AppColors.primaryGreen,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LinePreview extends StatelessWidget {
  const _LinePreview({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(
        child: Text('Sin datos', style: TextStyle(color: AppColors.muted)),
      );
    }

    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m) * 1.2;
    final safeMax = maxY <= 0 ? 1.0 : maxY;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primaryBlue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: labels.length > 8 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[i],
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
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
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _TablePreview extends StatelessWidget {
  const _TablePreview({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('Sin datos', style: TextStyle(color: AppColors.muted)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Table(
        border: TableBorder.all(color: AppColors.border),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: AppColors.surfaceAlt),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Etiqueta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Valor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(row.first),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(row.length > 1 ? row[1] : ''),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
