import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/permissions/permission.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/analytics_period.dart';
import '../../../models/analytics_summary.dart';
import '../../../models/nep_record.dart';
import '../../../models/record_filters.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/widget_capture_helper.dart';
import '../services/analytics_export_service.dart';

/// Botones de exportación del informe gráfico.
class AnalyticsExportActions extends StatelessWidget {
  const AnalyticsExportActions({
    super.key,
    required this.summary,
    required this.records,
    required this.period,
    required this.filters,
    required this.isExporting,
    required this.onExportStart,
    required this.onExportEnd,
    required this.onMessage,
    this.chartsCaptureKey,
    this.compact = false,
  });

  final AnalyticsSummary summary;
  final List<NepRecord> records;
  final AnalyticsPeriod period;
  final RecordFilters filters;
  final bool isExporting;
  final VoidCallback onExportStart;
  final VoidCallback onExportEnd;
  final void Function(String message) onMessage;
  final GlobalKey? chartsCaptureKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canExport =
        context.watch<AuthProvider>().hasPermission(Permission.exportReports);

    if (!canExport) {
      return Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Su rol no tiene permiso para exportar informes gráficos.',
          style: TextStyle(fontSize: compact ? 11 : 12, color: AppColors.muted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final buttons = [
          _ExportButton(
            compact: compact,
            icon: Icons.picture_as_pdf_outlined,
            label: 'Exportar PDF',
            onPressed:
                isExporting ? null : () => _runExport(context, _ExportKind.pdf),
          ),
          _ExportButton(
            compact: compact,
            icon: Icons.table_view_outlined,
            label: 'Exportar Excel',
            onPressed: isExporting
                ? null
                : () => _runExport(context, _ExportKind.excel),
          ),
          _ExportButton(
            compact: compact,
            icon: Icons.description_outlined,
            label: 'Exportar CSV',
            onPressed:
                isExporting ? null : () => _runExport(context, _ExportKind.csv),
          ),
          _ExportButton(
            compact: compact,
            icon: Icons.image_outlined,
            label: 'Descargar gráfico',
            filled: false,
            onPressed: isExporting || chartsCaptureKey == null
                ? null
                : () => _runExport(context, _ExportKind.png),
            tooltip: chartsCaptureKey == null
                ? 'Las gráficas aún no están listas para capturar.'
                : 'Guarda la sección de visualizaciones como imagen PNG.',
          ),
        ];

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                buttons[i],
              ],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: buttons,
        );
      },
    );
  }

  Future<Uint8List?> _captureCharts() async {
    final key = chartsCaptureKey;
    if (key == null) return null;
    return WidgetCaptureHelper.capturePng(key);
  }

  Future<void> _runExport(BuildContext context, _ExportKind kind) async {
    if (records.isEmpty) {
      onMessage('No hay datos disponibles para el periodo seleccionado.');
      return;
    }

    onExportStart();
    final timestamp = _fileTimestamp();
    try {
      switch (kind) {
        case _ExportKind.csv:
          await analyticsExportService.shareCsv(
            summary: summary,
            records: records,
            period: period,
            filters: filters,
            fileTimestamp: timestamp,
          );
          onMessage('Informe CSV listo para compartir o descargar.');
        case _ExportKind.excel:
          await analyticsExportService.shareExcel(
            summary: summary,
            records: records,
            period: period,
            filters: filters,
            fileTimestamp: timestamp,
          );
          onMessage('Informe Excel listo para compartir o descargar.');
        case _ExportKind.pdf:
          final chartPng = await _captureCharts();
          await analyticsExportService.sharePdf(
            summary: summary,
            records: records,
            period: period,
            filters: filters,
            fileTimestamp: timestamp,
            chartsImagePng: chartPng,
          );
          onMessage(
            chartPng != null
                ? 'Informe PDF con gráfica listo para compartir o descargar.'
                : 'Informe PDF listo (sin imagen de gráfica).',
          );
        case _ExportKind.png:
          final png = await _captureCharts();
          if (png == null || png.isEmpty) {
            onMessage(
              'No se pudo capturar la imagen de las gráficas. '
              'Intente nuevamente.',
            );
            return;
          }
          await analyticsExportService.shareChartsPng(
            pngBytes: png,
            fileTimestamp: timestamp,
          );
          onMessage('Imagen PNG de gráficas lista para compartir o descargar.');
      }
    } catch (e) {
      final prefix = switch (kind) {
        _ExportKind.pdf => 'No se pudo generar el PDF del informe gráfico.',
        _ExportKind.excel => 'No se pudo generar el Excel del informe gráfico.',
        _ExportKind.csv => 'No se pudo exportar el CSV del informe gráfico.',
        _ExportKind.png => 'No se pudo descargar la imagen de las gráficas.',
      };
      onMessage('$prefix Intente nuevamente.');
    } finally {
      onExportEnd();
    }
  }

  String _fileTimestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

enum _ExportKind { csv, excel, pdf, png }

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.filled = true,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: compact ? 12 : 14);

    final button = filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 12,
              ),
            ),
            child: _ExportButtonContent(
              icon: icon,
              label: label,
              compact: compact,
              labelStyle: labelStyle,
              foreground: Colors.white,
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 12,
              ),
            ),
            child: _ExportButtonContent(
              icon: icon,
              label: label,
              compact: compact,
              labelStyle: labelStyle,
              foreground: AppColors.muted,
            ),
          );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _ExportButtonContent extends StatelessWidget {
  const _ExportButtonContent({
    required this.icon,
    required this.label,
    required this.compact,
    required this.labelStyle,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final TextStyle labelStyle;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 16 : 18, color: foreground),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}
