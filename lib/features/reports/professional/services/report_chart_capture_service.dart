import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../utils/widget_capture_helper.dart';
import '../models/report_chart_configuration.dart';
import '../models/report_chart_type.dart';
import 'report_chart_builder.dart';
import 'report_data_builder.dart';

/// Captura gráficas como PNG para incrustar en PDF o compartir.
class ReportChartCaptureService {
  const ReportChartCaptureService({ReportChartBuilder? builder})
      : _builder = builder ?? reportChartBuilder;

  final ReportChartBuilder _builder;

  /// Captura todas las gráficas habilitadas usando un overlay temporal.
  Future<Map<ReportChartType, Uint8List>> captureAll({
    required BuildContext context,
    required ProcessedReportData data,
    required List<ReportChartConfiguration> charts,
    bool includeOperatorData = true,
    double pixelRatio = 2.0,
    void Function(double progress)? onProgress,
  }) async {
    final result = <ReportChartType, Uint8List>{};
    final enabled = charts.where((c) => c.enabled).toList();
    if (enabled.isEmpty) return result;

    final overlay = Overlay.of(context);
    var index = 0;

    for (final config in enabled) {
      onProgress?.call(index / enabled.length);
      final widget = _builder.buildCaptureWidget(
        data,
        config,
        includeOperatorData: includeOperatorData,
      );
      if (widget == null) {
        index++;
        continue;
      }

      final key = GlobalKey();
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: key,
              child: widget,
            ),
          ),
        ),
      );

      overlay.insert(entry);
      try {
        await Future<void>.delayed(Duration.zero);
        await WidgetsBinding.instance.endOfFrame;
        final bytes = await WidgetCaptureHelper.capturePng(
          key,
          pixelRatio: pixelRatio,
        );
        if (bytes != null && bytes.isNotEmpty) {
          result[config.type] = bytes;
        }
      } finally {
        entry.remove();
      }
      index++;
    }

    onProgress?.call(1.0);
    return result;
  }

  /// Captura una sola gráfica por tipo.
  Future<Uint8List?> captureOne({
    required BuildContext context,
    required ProcessedReportData data,
    required ReportChartConfiguration config,
    bool includeOperatorData = true,
    double pixelRatio = 2.0,
  }) async {
    final map = await captureAll(
      context: context,
      data: data,
      charts: [config],
      includeOperatorData: includeOperatorData,
      pixelRatio: pixelRatio,
    );
    return map[config.type];
  }
}

const ReportChartCaptureService reportChartCaptureService =
    ReportChartCaptureService();
