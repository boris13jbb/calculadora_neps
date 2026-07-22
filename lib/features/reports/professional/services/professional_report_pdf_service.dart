import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/nep_record.dart';
import '../../../../services/alert_service.dart';
import '../../../../services/report_export_service.dart';
import '../models/report_chart_type.dart';
import '../models/report_detail_column.dart';
import '../models/report_export_options.dart';
import '../models/report_section_type.dart';
import 'report_data_builder.dart';
import 'report_grouping_service.dart';

/// Generación de PDF profesional para el generador de reportes.
class ProfessionalReportPdfService {
  ProfessionalReportPdfService({
    ReportExportService? exportService,
    AlertService? alerts,
  })  : _export = exportService ?? ReportExportService(),
        _alerts = alerts ?? alertService;

  final ReportExportService _export;
  final AlertService _alerts;
  static pw.ThemeData? _themeCache;

  static final PdfColor _tableHeaderBg = PdfColor.fromHex('#1F4E79');
  static final PdfColor _tableHeaderFg = PdfColor.fromHex('#F7EAC5');
  static final PdfColor _tableBorder = PdfColor.fromHex('#C5CCD3');
  static final PdfColor _tableStripe = PdfColor.fromHex('#F4F7FA');
  static const pw.EdgeInsets _cellPadding =
      pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7);

  /// Añade una sección con encabezado/pie fijos y contenido paginable.
  void _addSectionPage(
    pw.Document doc, {
    required ReportExportOptions options,
    required String title,
    required pw.Widget Function(String sectionTitle) buildHeader,
    required pw.Widget Function(pw.Context context) buildFooter,
    required List<pw.Widget> content,
  }) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: options.effectiveFormat,
        margin: pw.EdgeInsets.all(options.marginMm * PdfPageFormat.mm),
        header: (context) => buildHeader(title),
        footer: buildFooter,
        build: (context) => content,
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 8,
    int maxLines = 4,
  }) {
    return pw.Padding(
      padding: _cellPadding,
      child: pw.Align(
        alignment: switch (align) {
          pw.TextAlign.right => pw.Alignment.centerRight,
          pw.TextAlign.center => pw.Alignment.center,
          _ => pw.Alignment.centerLeft,
        },
        child: pw.Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? _tableHeaderFg : PdfColors.blueGrey900,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildPdfTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> columnFlex,
    List<pw.TextAlign>? columnAlignments,
    double fontSize = 8,
    bool zebraRows = true,
  }) {
    final alignments = columnAlignments ??
        List<pw.TextAlign>.filled(headers.length, pw.TextAlign.left);

    final columnWidths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < columnFlex.length; i++)
        i: pw.FlexColumnWidth(columnFlex[i]),
    };

    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
      columnWidths: columnWidths,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _tableHeaderBg),
          children: [
            for (var i = 0; i < headers.length; i++)
              _tableCell(
                headers[i],
                isHeader: true,
                align: pw.TextAlign.center,
                fontSize: fontSize,
                maxLines: 2,
              ),
          ],
        ),
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
          pw.TableRow(
            decoration: zebraRows && rowIndex.isOdd
                ? pw.BoxDecoration(color: _tableStripe)
                : null,
            children: [
              for (var colIndex = 0;
                  colIndex < rows[rowIndex].length;
                  colIndex++)
                _tableCell(
                  rows[rowIndex][colIndex],
                  align: alignments[colIndex],
                  fontSize: fontSize,
                ),
            ],
          ),
      ],
    );
  }

  List<double> _numericTailFlex(int count, {double labelFlex = 2.0}) {
    if (count <= 1) return [labelFlex];
    return [
      labelFlex,
      ...List<double>.filled(count - 1, 1.0),
    ];
  }

  List<pw.TextAlign> _numericTailAlignments(int count) {
    return [
      pw.TextAlign.left,
      ...List<pw.TextAlign>.filled(
        count - 1,
        pw.TextAlign.right,
      ),
    ];
  }

  String _detailHeader(ReportDetailColumn col) => switch (col) {
        ReportDetailColumn.numero => 'Nº',
        ReportDetailColumn.idRegistro => 'ID',
        ReportDetailColumn.mtsCalculados => 'Mts calc.',
        ReportDetailColumn.estadoAlerta => 'Alerta',
        ReportDetailColumn.loteTrama => 'Lote trama',
        ReportDetailColumn.lineaProduccion => 'Línea',
        ReportDetailColumn.revisadoSupervisor => 'Revisado',
        ReportDetailColumn.accionCorrectiva => 'Acción corr.',
        ReportDetailColumn.responsableRevision => 'Responsable',
        ReportDetailColumn.fechaRevision => 'F. revisión',
        ReportDetailColumn.tiempoRespuesta => 'T. respuesta',
        ReportDetailColumn.cantidadAcciones => 'Nº acciones',
        ReportDetailColumn.usuarioCreador => 'Creador',
        ReportDetailColumn.correoCreador => 'Correo',
        ReportDetailColumn.rolCreador => 'Rol',
        _ => col.label,
      };

  double _detailColumnFlex(ReportDetailColumn col) => switch (col) {
        ReportDetailColumn.numero => 0.45,
        ReportDetailColumn.idRegistro => 1.0,
        ReportDetailColumn.fecha => 0.85,
        ReportDetailColumn.hora => 0.55,
        ReportDetailColumn.telar => 0.55,
        ReportDetailColumn.tela => 1.25,
        ReportDetailColumn.loteTrama => 1.1,
        ReportDetailColumn.neps => 0.55,
        ReportDetailColumn.mtsCalculados => 0.65,
        ReportDetailColumn.estadoAlerta => 0.8,
        ReportDetailColumn.turno => 0.5,
        ReportDetailColumn.operario => 0.85,
        ReportDetailColumn.lineaProduccion => 0.85,
        ReportDetailColumn.observacion => 1.5,
        ReportDetailColumn.recomendacion => 1.5,
        ReportDetailColumn.revisadoSupervisor => 0.65,
        ReportDetailColumn.accionCorrectiva => 1.1,
        ReportDetailColumn.responsableRevision => 0.9,
        ReportDetailColumn.fechaRevision => 0.85,
        ReportDetailColumn.tiempoRespuesta => 0.7,
        ReportDetailColumn.cantidadAcciones => 0.65,
        ReportDetailColumn.usuarioCreador => 1.0,
        ReportDetailColumn.correoCreador => 1.1,
        ReportDetailColumn.rolCreador => 0.7,
      };

  pw.TextAlign _detailColumnAlign(ReportDetailColumn col) => switch (col) {
        ReportDetailColumn.numero ||
        ReportDetailColumn.neps ||
        ReportDetailColumn.mtsCalculados ||
        ReportDetailColumn.cantidadAcciones ||
        ReportDetailColumn.tiempoRespuesta =>
          pw.TextAlign.right,
        ReportDetailColumn.fecha ||
        ReportDetailColumn.hora ||
        ReportDetailColumn.telar ||
        ReportDetailColumn.estadoAlerta ||
        ReportDetailColumn.turno ||
        ReportDetailColumn.revisadoSupervisor =>
          pw.TextAlign.center,
        _ => pw.TextAlign.left,
      };

  Future<pw.ThemeData> _theme() async {
    if (_themeCache != null) return _themeCache!;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/OpenSans-Bold.ttf'),
    );
    _themeCache = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
    return _themeCache!;
  }

  Future<Uint8List> buildPdf(
    ProcessedReportData data, {
    required String generatedBy,
    required String userRole,
    bool includeOperatorData = true,
    bool includeCreatorData = false,
    Map<ReportChartType, Uint8List>? chartImages,
  }) async {
    final theme = await _theme();
    final config = data.configuration;
    final options = config.exportOptions;
    final doc = pw.Document(theme: theme);

    pw.Widget buildHeader(String title) {
      if (!options.showHeader) return pw.SizedBox(height: 4);
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              config.cover.companyName,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildFooter(pw.Context context) {
      if (!options.showFooter) return pw.SizedBox();
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado: ${_formatDateTime(data.generatedAt ?? DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Página ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      );
    }

    for (final section in config.orderedSections) {
      switch (section) {
        case ReportSectionType.portada:
          doc.addPage(
            pw.Page(
              pageFormat: options.effectiveFormat,
              margin: pw.EdgeInsets.all(options.marginMm * PdfPageFormat.mm),
              build: (context) => _buildCover(
                data,
                generatedBy: generatedBy,
                userRole: userRole,
              ),
            ),
          );
        case ReportSectionType.resumenEjecutivo:
          _addSectionPage(
            doc,
            options: options,
            title: 'Resumen ejecutivo',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildMetricsTable(data)],
          );
        case ReportSectionType.indicadoresCalidad:
          _addSectionPage(
            doc,
            options: options,
            title: 'Indicadores de calidad',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildQualityIndicators(data)],
          );
        case ReportSectionType.analisisTemporal:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis temporal',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildTemporalTable(data)],
          );
        case ReportSectionType.analisisTelar:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis por telar',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildDimensionTable(data.byTelar, 'Telar')],
          );
        case ReportSectionType.analisisTela:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis por tela',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildDimensionTable(data.byTela, 'Tela')],
          );
        case ReportSectionType.analisisLote:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis por lote',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildDimensionTable(data.byLote, 'Lote')],
          );
        case ReportSectionType.analisisTurno:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis por turno',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildDimensionTable(data.byTurno, 'Turno')],
          );
        case ReportSectionType.analisisOperario:
          if (includeOperatorData) {
            _addSectionPage(
              doc,
              options: options,
              title: 'Análisis por operario',
              buildHeader: buildHeader,
              buildFooter: buildFooter,
              content: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    'Información para análisis del proceso. '
                    'No constituye valoración personal.',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                _buildDimensionTable(data.byOperario, 'Operario'),
              ],
            );
          }
        case ReportSectionType.analisisLinea:
          _addSectionPage(
            doc,
            options: options,
            title: 'Análisis por línea',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildDimensionTable(data.byLinea, 'Línea')],
          );
        case ReportSectionType.alertas:
          _addSectionPage(
            doc,
            options: options,
            title: 'Alertas',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildAlertsSection(data)],
          );
        case ReportSectionType.accionesCorrectivas:
          _addSectionPage(
            doc,
            options: options,
            title: 'Acciones correctivas',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildCorrectiveSection(data)],
          );
        case ReportSectionType.observaciones:
          _addSectionPage(
            doc,
            options: options,
            title: 'Observaciones',
            buildHeader: buildHeader,
            buildFooter: buildFooter,
            content: [_buildObservations(data)],
          );
        case ReportSectionType.comparacionPeriodos:
          if (data.comparison != null) {
            _addSectionPage(
              doc,
              options: options,
              title: 'Comparación de periodos',
              buildHeader: buildHeader,
              buildFooter: buildFooter,
              content: [_buildComparison(data.comparison!)],
            );
          }
        case ReportSectionType.conclusiones:
          if (data.conclusion != null && data.conclusion!.enabled) {
            _addSectionPage(
              doc,
              options: options,
              title: 'Conclusiones',
              buildHeader: buildHeader,
              buildFooter: buildFooter,
              content: [
                pw.Text(
                  data.conclusion!.fullText,
                  style: const pw.TextStyle(fontSize: 10, height: 1.4),
                ),
              ],
            );
          }
        case ReportSectionType.tablaDetallada:
          if (data.tableRecords.isNotEmpty) {
            final cols = _resolveColumns(
              config,
              includeOperatorData: includeOperatorData,
              includeCreatorData: includeCreatorData,
            );
            _addSectionPage(
              doc,
              options: options,
              title: 'Registros detallados',
              buildHeader: buildHeader,
              buildFooter: buildFooter,
              content: [_buildDetailTable(data.tableRecords, cols)],
            );
          }
        case ReportSectionType.graficas:
          _addChartSectionPages(
            doc,
            data: data,
            chartImages: chartImages,
            options: options,
            buildHeader: buildHeader,
            buildFooter: buildFooter,
          );
      }
    }

    return doc.save();
  }

  pw.Widget _buildCover(
    ProcessedReportData data, {
    required String generatedBy,
    required String userRole,
  }) {
    final cover = data.configuration.cover;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        if (cover.showLogo)
          pw.Text(
            cover.companyName,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          cover.title,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (cover.subtitle.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(cover.subtitle, style: const pw.TextStyle(fontSize: 14)),
        ],
        pw.SizedBox(height: 24),
        pw.Text('Periodo: ${data.dateRangeLabel}'),
        pw.Text('Tipo: ${cover.reportType}'),
        pw.Text('Departamento: ${cover.department}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Generado: ${_formatDateTime(data.generatedAt ?? DateTime.now())}',
        ),
        pw.Text('Por: $generatedBy ($userRole)'),
        if (cover.internalCode.isNotEmpty)
          pw.Text('Código: ${cover.internalCode}'),
        pw.Text('Versión: ${cover.version}'),
        pw.SizedBox(height: 32),
        if (cover.confidentialityText.isNotEmpty)
          pw.Text(
            cover.confidentialityText,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        pw.Spacer(),
        if (cover.showElaboratedSignature)
          _signatureLine('Elaborado por', cover.elaboratedBy),
        if (cover.showReviewedSignature)
          _signatureLine('Revisado por', cover.reviewedBy),
        if (cover.showApprovedSignature)
          _signatureLine('Aprobado por', cover.approvedBy),
      ],
    );
  }

  pw.Widget _signatureLine(String label, String name) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 24),
      child: pw.Column(
        children: [
          pw.Container(
            width: 200,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide()),
            ),
            height: 40,
          ),
          pw.SizedBox(height: 4),
          pw.Text('$label${name.isNotEmpty ? ': $name' : ''}',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildMetricsTable(ProcessedReportData data) {
    final metrics = data.statistics.toMetricValues(data.configuration.metrics);
    if (metrics.isEmpty) {
      return pw.Text('Sin métricas seleccionadas.');
    }
    return _buildPdfTable(
      headers: const ['Indicador', 'Valor'],
      rows: metrics.map((m) => [m.label, m.displayValue]).toList(),
      columnFlex: const [2.4, 1.0],
      columnAlignments: const [pw.TextAlign.left, pw.TextAlign.right],
      fontSize: 9,
    );
  }

  pw.Widget _buildQualityIndicators(ProcessedReportData data) {
    final q = data.statistics.qualityIndicators;
    final items = <String, String?>{
      'Telar mayor promedio': q.telarMayorPromedio,
      'Telar menor promedio': q.telarMenorPromedio,
      'Telar más críticos': q.telarMayorCriticos,
      'Tela mayor promedio': q.telaMayorPromedio,
      'Turno mayor incidencia': q.turnoMayorPromedio,
      'Índice de calidad': '${q.indiceCalidadGeneral.toStringAsFixed(1)}%',
      'Tendencia': q.tendenciaGeneral.label,
      '% dentro de límite normal':
          '${q.porcentajeDentroLimite.toStringAsFixed(1)}%',
    };
    return _buildPdfTable(
      headers: const ['Indicador', 'Valor'],
      rows: items.entries
          .where((e) => e.value != null)
          .map((e) => [e.key, e.value!])
          .toList(),
      columnFlex: const [2.2, 1.2],
      columnAlignments: const [pw.TextAlign.left, pw.TextAlign.left],
      fontSize: 9,
    );
  }

  pw.Widget _buildTemporalTable(ProcessedReportData data) {
    if (data.temporalGroups.isEmpty) {
      return pw.Text('Sin datos temporales.');
    }
    const headers = [
      'Periodo',
      'Registros',
      'Prom. Neps',
      'Críticos',
      '% Críticos',
      'Mts',
    ];
    return _buildPdfTable(
      headers: headers,
      rows: data.temporalGroups
          .map(
            (p) => [
              p.label,
              '${p.recordCount}',
              _export.formatDecimal(p.averageNeps),
              '${p.criticalCount}',
              '${p.criticalPercentage.toStringAsFixed(1)}%',
              _export.formatNumber(p.totalMts),
            ],
          )
          .toList(),
      columnFlex: _numericTailFlex(headers.length, labelFlex: 1.8),
      columnAlignments: _numericTailAlignments(headers.length),
      fontSize: 8,
    );
  }

  pw.Widget _buildDimensionTable(
    List<DimensionGroupStats> groups,
    String labelCol,
  ) {
    if (groups.isEmpty) return pw.Text('Sin datos para $labelCol.');
    const headers = [
      '',
      'Reg.',
      'Prom.',
      'Med.',
      'Crít.',
      '% Crít.',
      'Mts',
    ];
    final resolvedHeaders = [labelCol, ...headers.sublist(1)];
    return _buildPdfTable(
      headers: resolvedHeaders,
      rows: groups
          .take(30)
          .map(
            (g) => [
              g.key,
              '${g.recordCount}',
              _export.formatDecimal(g.averageNeps),
              _export.formatDecimal(g.medianNeps),
              '${g.criticalCount}',
              '${g.criticalPercentage.toStringAsFixed(1)}%',
              _export.formatNumber(g.totalMts),
            ],
          )
          .toList(),
      columnFlex: const [2.4, 0.65, 0.8, 0.8, 0.65, 0.85, 0.85],
      columnAlignments: _numericTailAlignments(resolvedHeaders.length),
      fontSize: 8,
    );
  }

  pw.Widget _buildAlertsSection(ProcessedReportData data) {
    final s = data.statistics;
    return _buildPdfTable(
      headers: const ['Categoría', 'Cantidad', 'Porcentaje'],
      rows: [
        ['Total alertas', '${s.totalRecords}', '100%'],
        [
          'Normales',
          '${s.normalCount}',
          '${s.normalPercentage.toStringAsFixed(1)}%',
        ],
        [
          'Advertencias',
          '${s.warningCount}',
          '${s.warningPercentage.toStringAsFixed(1)}%',
        ],
        [
          'Críticos',
          '${s.criticalCount}',
          '${s.criticalPercentage.toStringAsFixed(1)}%',
        ],
        ['Revisadas', '${s.reviewedCount}', '—'],
        ['Pendientes', '${s.pendingReviewCount}', '—'],
      ],
      columnFlex: const [2.0, 0.8, 0.8],
      columnAlignments: const [
        pw.TextAlign.left,
        pw.TextAlign.right,
        pw.TextAlign.right,
      ],
      fontSize: 9,
    );
  }

  pw.Widget _buildCorrectiveSection(ProcessedReportData data) {
    final s = data.statistics;
    final withHistory = data.records
        .where((r) => r.historialAcciones.isNotEmpty)
        .take(20)
        .toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfTable(
          headers: const ['Indicador', 'Valor'],
          rows: [
            ['Con acción correctiva', '${s.withCorrectiveActionCount}'],
            ['Sin acción', '${s.withoutCorrectiveActionCount}'],
            [
              'Tasa de cierre',
              '${s.correctiveActionClosureRate.toStringAsFixed(1)}%',
            ],
          ],
          columnFlex: const [2.2, 1.0],
          columnAlignments: const [pw.TextAlign.left, pw.TextAlign.right],
          fontSize: 9,
        ),
        if (withHistory.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Detalle de acciones registradas',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildPdfTable(
            headers: const ['Telar', 'Fecha', 'Acción'],
            rows: [
              for (final r in withHistory)
                for (final h in r.historialAcciones)
                  [
                    r.telar,
                    _formatDateTime(h.fecha),
                    '${h.responsable}: ${h.accion}',
                  ],
            ],
            columnFlex: const [0.7, 1.1, 2.8],
            columnAlignments: const [
              pw.TextAlign.center,
              pw.TextAlign.left,
              pw.TextAlign.left,
            ],
            fontSize: 7.5,
          ),
        ],
      ],
    );
  }

  pw.Widget _buildObservations(ProcessedReportData data) {
    final withObs = data.records
        .where((r) => r.observacion.trim().isNotEmpty)
        .take(30)
        .toList();
    if (withObs.isEmpty) return pw.Text('No hay observaciones registradas.');
    return _buildPdfTable(
      headers: const ['Telar', 'Alerta', 'Observación'],
      rows: withObs
          .map(
            (r) => [r.telar, r.estadoAlerta, r.observacion],
          )
          .toList(),
      columnFlex: const [0.7, 0.9, 2.8],
      columnAlignments: const [
        pw.TextAlign.center,
        pw.TextAlign.center,
        pw.TextAlign.left,
      ],
      fontSize: 7.5,
    );
  }

  pw.Widget _buildComparison(dynamic comparison) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${comparison.periodALabel} vs ${comparison.periodBLabel}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        _buildPdfTable(
          headers: const ['Indicador', 'Periodo A', 'Periodo B', 'Variación'],
          rows: [
            [
              'Promedio neps',
              _export.formatDecimal(comparison.averageNepsA),
              _export.formatDecimal(comparison.averageNepsB),
              '${comparison.averageNepsPctChange >= 0 ? "+" : ""}${comparison.averageNepsPctChange.toStringAsFixed(1)}%',
            ],
            [
              'Críticos',
              '${comparison.criticalA}',
              '${comparison.criticalB}',
              '${comparison.criticalPctChange >= 0 ? "+" : ""}${comparison.criticalPctChange.toStringAsFixed(1)}%',
            ],
            [
              'Metros calc.',
              _export.formatNumber(comparison.totalMtsA),
              _export.formatNumber(comparison.totalMtsB),
              '${comparison.mtsPctChange >= 0 ? "+" : ""}${comparison.mtsPctChange.toStringAsFixed(1)}%',
            ],
          ],
          columnFlex: const [1.4, 0.9, 0.9, 0.8],
          columnAlignments: const [
            pw.TextAlign.left,
            pw.TextAlign.right,
            pw.TextAlign.right,
            pw.TextAlign.right,
          ],
          fontSize: 8,
        ),
        if (comparison.improvedTelars.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Telares mejorados: ${comparison.improvedTelars.join(", ")}'),
        ],
        if (comparison.worsenedTelars.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
              'Telares empeorados: ${comparison.worsenedTelars.join(", ")}'),
        ],
        pw.SizedBox(height: 8),
        pw.Text('Variación general: ${comparison.qualityVariation.label}'),
      ],
    );
  }

  void _addChartSectionPages(
    pw.Document doc, {
    required ProcessedReportData data,
    required Map<ReportChartType, Uint8List>? chartImages,
    required ReportExportOptions options,
    required pw.Widget Function(String title) buildHeader,
    required pw.Widget Function(pw.Context context) buildFooter,
  }) {
    final enabled = data.configuration.charts.where((c) => c.enabled).toList();
    final images = chartImages ?? {};
    final embedded = enabled.where((c) {
      final bytes = images[c.type];
      return bytes != null && bytes.isNotEmpty;
    }).toList();

    if (embedded.isEmpty) {
      _addSectionPage(
        doc,
        options: options,
        title: 'Gráficas',
        buildHeader: buildHeader,
        buildFooter: buildFooter,
        content: [
          pw.Text(
            enabled.isEmpty
                ? 'No hay gráficas habilitadas en la configuración.'
                : 'No se capturaron imágenes de gráficas. '
                    'Genere el PDF desde exportar con captura activada '
                    'o comparta las gráficas en PNG por separado.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (enabled.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildChartSummary(data),
          ],
        ],
      );
      return;
    }

    for (final config in embedded) {
      final bytes = images[config.type]!;
      _addSectionPage(
        doc,
        options: options,
        title: 'Gráficas',
        buildHeader: buildHeader,
        buildFooter: buildFooter,
        content: [
          pw.Text(
            config.effectiveTitle,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            height: 420,
            alignment: pw.Alignment.center,
            child: pw.Image(
              pw.MemoryImage(bytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ],
      );
    }

    final missing = enabled
        .where((c) => !images.containsKey(c.type) || images[c.type]!.isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      _addSectionPage(
        doc,
        options: options,
        title: 'Gráficas — resumen',
        buildHeader: buildHeader,
        buildFooter: buildFooter,
        content: [
          pw.Text(
            'Gráficas sin imagen capturada:',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: missing
                .map(
                  (c) => pw.Text(
                    '• ${c.effectiveTitle}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }
  }

  pw.Widget _buildChartSummary(ProcessedReportData data) {
    final enabled = data.configuration.charts.where((c) => c.enabled).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: enabled
          .map((c) => pw.Text('• ${c.effectiveTitle}',
              style: const pw.TextStyle(fontSize: 9)))
          .toList(),
    );
  }

  pw.Widget _buildDetailTable(
    List<NepRecord> records,
    List<ReportDetailColumn> columns,
  ) {
    final headers = columns.map(_detailHeader).toList();
    final flex = columns.map(_detailColumnFlex).toList();
    final alignments = columns.map(_detailColumnAlign).toList();

    return _buildPdfTable(
      headers: headers,
      rows: [
        for (var i = 0; i < records.length; i++)
          columns.map((col) => _cellValue(col, records[i], i)).toList(),
      ],
      columnFlex: flex,
      columnAlignments: alignments,
      fontSize: 7.5,
    );
  }

  List<ReportDetailColumn> _resolveColumns(
    dynamic config, {
    required bool includeOperatorData,
    required bool includeCreatorData,
  }) {
    return config.tableConfig.resolvedColumns.where((c) {
      if (c.requiresOperatorPermission && !includeOperatorData) return false;
      if (c.requiresCreatorPermission && !includeCreatorData) return false;
      return true;
    }).toList();
  }

  String _cellValue(ReportDetailColumn col, NepRecord r, int index) {
    return switch (col) {
      ReportDetailColumn.numero => '${index + 1}',
      ReportDetailColumn.idRegistro => r.id,
      ReportDetailColumn.fecha =>
        '${r.createdAt.day.toString().padLeft(2, "0")}/${r.createdAt.month.toString().padLeft(2, "0")}/${r.createdAt.year}',
      ReportDetailColumn.hora =>
        '${r.createdAt.hour.toString().padLeft(2, "0")}:${r.createdAt.minute.toString().padLeft(2, "0")}',
      ReportDetailColumn.telar => r.telar,
      ReportDetailColumn.tela => r.tela,
      ReportDetailColumn.loteTrama => r.loteTrama,
      ReportDetailColumn.neps => _export.formatDecimal(r.neps),
      ReportDetailColumn.mtsCalculados => _export.formatNumber(r.mtsCalculados),
      ReportDetailColumn.estadoAlerta => r.estadoAlerta,
      ReportDetailColumn.turno => r.turno,
      ReportDetailColumn.operario => r.operario,
      ReportDetailColumn.lineaProduccion => r.lineaProduccion,
      ReportDetailColumn.observacion => r.observacion,
      ReportDetailColumn.recomendacion =>
        _alerts.generateRecommendations(r, []).join(' '),
      ReportDetailColumn.revisadoSupervisor =>
        r.revisadoPorSupervisor ? 'Sí' : 'No',
      ReportDetailColumn.accionCorrectiva => r.accionCorrectiva,
      ReportDetailColumn.responsableRevision => r.responsableRevision,
      ReportDetailColumn.fechaRevision =>
        r.fechaRevision != null ? _formatDateTime(r.fechaRevision!) : '',
      ReportDetailColumn.tiempoRespuesta => r.fechaRevision != null
          ? '${r.fechaRevision!.difference(r.createdAt).inHours}h'
          : '',
      ReportDetailColumn.cantidadAcciones => '${r.historialAcciones.length}',
      ReportDetailColumn.usuarioCreador =>
        r.createdByEmail ?? r.createdByUid ?? '',
      ReportDetailColumn.correoCreador => r.createdByEmail ?? '',
      ReportDetailColumn.rolCreador => r.createdByRole ?? '',
    };
  }

  String _formatDateTime(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
    return '$d $t';
  }
}

final professionalReportPdfService = ProfessionalReportPdfService();
