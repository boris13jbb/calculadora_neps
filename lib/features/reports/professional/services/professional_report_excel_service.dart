import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../../../../core/constants.dart';
import '../models/report_detail_column.dart';
import '../models/report_section_type.dart';
import 'report_data_builder.dart';
import 'report_grouping_service.dart';

/// Generación de Excel multi-hoja para reportes profesionales.
class ProfessionalReportExcelService {
  ProfessionalReportExcelService();

  Uint8List? buildExcel(ProcessedReportData data) {
    if (data.isEmpty) return null;

    final excel = xls.Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final config = data.configuration;

    if (config.sections.contains(ReportSectionType.resumenEjecutivo)) {
      _buildSummarySheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.indicadoresCalidad)) {
      _buildQualitySheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.analisisTemporal)) {
      _buildTemporalSheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.analisisTelar)) {
      _buildDimensionSheet(excel, 'Por telar', data.byTelar);
    }
    if (config.sections.contains(ReportSectionType.analisisTela)) {
      _buildDimensionSheet(excel, 'Por tela', data.byTela);
    }
    if (config.sections.contains(ReportSectionType.analisisLote)) {
      _buildDimensionSheet(excel, 'Por lote', data.byLote);
    }
    if (config.sections.contains(ReportSectionType.analisisTurno)) {
      _buildDimensionSheet(excel, 'Por turno', data.byTurno);
    }
    if (config.sections.contains(ReportSectionType.analisisOperario)) {
      _buildDimensionSheet(excel, 'Por operario', data.byOperario);
    }
    if (config.sections.contains(ReportSectionType.analisisLinea)) {
      _buildDimensionSheet(excel, 'Por linea', data.byLinea);
    }
    if (config.sections.contains(ReportSectionType.alertas)) {
      _buildAlertsSheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.accionesCorrectivas)) {
      _buildCorrectiveSheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.comparacionPeriodos) &&
        data.comparison != null) {
      _buildComparisonSheet(excel, data);
    }
    if (config.sections.contains(ReportSectionType.tablaDetallada)) {
      _buildRecordsSheet(excel, data);
    }
    _buildMetadataSheet(excel, data);

    final sheets = excel.sheets.keys.toList();
    if (sheets.isNotEmpty) {
      excel.setDefaultSheet(sheets.first);
    }

    final bytes = excel.encode();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  void _buildSummarySheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Resumen ejecutivo';
    final sheet = excel[name];
    var row = 0;
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = xls.TextCellValue('Resumen ejecutivo')
      ..cellStyle = xls.CellStyle(bold: true, fontSize: 14);
    row += 2;

    final metrics = data.statistics.toMetricValues(data.configuration.metrics);
    _writeHeader(sheet, row, ['Indicador', 'Valor']);
    row++;
    for (final m in metrics) {
      _writeRow(sheet, row++, [m.label, m.displayValue]);
    }
  }

  void _buildQualitySheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Indicadores';
    final sheet = excel[name];
    final q = data.statistics.qualityIndicators;
    var row = 0;
    _writeHeader(sheet, row, ['Indicador', 'Valor']);
    row++;
    final items = {
      'Telar mayor promedio': q.telarMayorPromedio,
      'Telar menor promedio': q.telarMenorPromedio,
      'Telar más críticos': q.telarMayorCriticos,
      'Tela mayor promedio': q.telaMayorPromedio,
      'Índice calidad': q.indiceCalidadGeneral.toStringAsFixed(1),
      'Tendencia': q.tendenciaGeneral.label,
    };
    for (final e in items.entries) {
      if (e.value != null) _writeRow(sheet, row++, [e.key, e.value!]);
    }
  }

  void _buildTemporalSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Serie temporal';
    final sheet = excel[name];
    var row = 0;
    _writeHeader(sheet, row, [
      'Periodo',
      'Registros',
      'Prom. Neps',
      'Min',
      'Max',
      'Críticos',
      'Mts',
    ]);
    row++;
    for (final p in data.temporalGroups) {
      _writeRow(sheet, row++, [
        p.label,
        p.recordCount,
        p.averageNeps,
        p.minNeps,
        p.maxNeps,
        p.criticalCount,
        p.totalMts,
      ]);
    }
  }

  void _buildDimensionSheet(
    xls.Excel excel,
    String name,
    List<DimensionGroupStats> groups,
  ) {
    final sheet = excel[name];
    var row = 0;
    _writeHeader(sheet, row, [
      'Clave',
      'Registros',
      'Promedio',
      'Mediana',
      'Desv. Est.',
      'Críticos',
      'Mts',
    ]);
    row++;
    for (final g in groups) {
      _writeRow(sheet, row++, [
        g.key,
        g.recordCount,
        g.averageNeps,
        g.medianNeps,
        g.stdDev,
        g.criticalCount,
        g.totalMts,
      ]);
    }
  }

  void _buildAlertsSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Alertas';
    final sheet = excel[name];
    final s = data.statistics;
    var row = 0;
    _writeRow(sheet, row++, ['Normales', s.normalCount]);
    _writeRow(sheet, row++, ['Advertencias', s.warningCount]);
    _writeRow(sheet, row++, ['Críticos', s.criticalCount]);
    _writeRow(sheet, row++, ['Revisados', s.reviewedCount]);
    _writeRow(sheet, row++, ['Pendientes', s.pendingReviewCount]);
  }

  void _buildCorrectiveSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Acciones correctivas';
    final sheet = excel[name];
    var row = 0;
    _writeHeader(sheet, row, [
      'Telar',
      'Fecha',
      'Responsable',
      'Acción',
      'Revisado',
    ]);
    row++;
    for (final r in data.records) {
      if (r.historialAcciones.isEmpty && r.accionCorrectiva.isEmpty) continue;
      if (r.historialAcciones.isEmpty) {
        _writeRow(sheet, row++, [
          r.telar,
          r.createdAt.toIso8601String(),
          r.responsableRevision,
          r.accionCorrectiva,
          r.revisadoPorSupervisor ? 'Sí' : 'No',
        ]);
      } else {
        for (final h in r.historialAcciones) {
          _writeRow(sheet, row++, [
            r.telar,
            h.fecha.toIso8601String(),
            h.responsable,
            h.accion,
            r.revisadoPorSupervisor ? 'Sí' : 'No',
          ]);
        }
      }
    }
  }

  void _buildComparisonSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Comparacion';
    final sheet = excel[name];
    final c = data.comparison!;
    var row = 0;
    _writeHeader(
        sheet, row, ['Métrica', c.periodALabel, c.periodBLabel, 'Cambio %']);
    row++;
    _writeRow(sheet, row++, [
      'Promedio neps',
      c.averageNepsA,
      c.averageNepsB,
      c.averageNepsPctChange,
    ]);
    _writeRow(sheet, row++, [
      'Críticos',
      c.criticalA,
      c.criticalB,
      c.criticalPctChange,
    ]);
    _writeRow(sheet, row++, [
      'Metros calculados',
      c.totalMtsA,
      c.totalMtsB,
      c.mtsPctChange,
    ]);
  }

  void _buildRecordsSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Registros base';
    final sheet = excel[name];
    final cols = data.configuration.tableConfig.resolvedColumns;
    var row = 0;
    _writeHeader(sheet, row, cols.map((c) => c.label).toList());
    row++;
    for (var i = 0; i < data.tableRecords.length; i++) {
      final r = data.tableRecords[i];
      _writeRow(
        sheet,
        row++,
        cols.map((c) => _rawCell(c, r, i)).toList(),
      );
    }
  }

  void _buildMetadataSheet(xls.Excel excel, ProcessedReportData data) {
    const name = 'Metadatos';
    final sheet = excel[name];
    var row = 0;
    _writeRow(sheet, row++, ['Título', data.configuration.cover.title]);
    _writeRow(sheet, row++, ['Periodo', data.dateRangeLabel]);
    _writeRow(sheet, row++, ['Filtros', data.filterDescription]);
    _writeRow(sheet, row++, [
      'Generado',
      data.generatedAt?.toIso8601String() ?? '',
    ]);
    _writeRow(sheet, row++, [
      'Fórmula',
      'Mts calculados = Neps / $testLengthM',
    ]);
  }

  dynamic _rawCell(ReportDetailColumn col, dynamic r, int index) {
    return switch (col) {
      ReportDetailColumn.numero => index + 1,
      ReportDetailColumn.idRegistro => r.id,
      ReportDetailColumn.fecha => r.createdAt.toIso8601String(),
      ReportDetailColumn.neps => r.neps,
      ReportDetailColumn.mtsCalculados => r.mtsCalculados,
      ReportDetailColumn.telar => r.telar,
      ReportDetailColumn.tela => r.tela,
      ReportDetailColumn.loteTrama => r.loteTrama,
      ReportDetailColumn.estadoAlerta => r.estadoAlerta,
      ReportDetailColumn.turno => r.turno,
      ReportDetailColumn.operario => r.operario,
      ReportDetailColumn.observacion => r.observacion,
      ReportDetailColumn.revisadoSupervisor =>
        r.revisadoPorSupervisor ? 'Sí' : 'No',
      ReportDetailColumn.accionCorrectiva => r.accionCorrectiva,
      _ => '',
    };
  }

  void _writeHeader(xls.Sheet sheet, int row, List<dynamic> headers) {
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = xls.TextCellValue(headers[i].toString())
        ..cellStyle = xls.CellStyle(bold: true);
    }
  }

  void _writeRow(xls.Sheet sheet, int row, List<dynamic> values) {
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final cell = sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
      if (v is num) {
        cell.value = xls.DoubleCellValue(v.toDouble());
      } else {
        cell.value = xls.TextCellValue(v.toString());
      }
    }
  }
}

final professionalReportExcelService = ProfessionalReportExcelService();
