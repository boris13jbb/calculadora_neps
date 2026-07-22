import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../models/app_user.dart';
import '../../../../models/app_user_role.dart';
import '../../../../models/nep_record.dart';
import '../../../../services/permissions_service.dart';
import '../../../../utils/file_share_helper.dart';
import '../models/report_chart_type.dart';
import '../models/report_configuration.dart';
import '../models/report_section_type.dart';
import '../models/report_template.dart';
import '../services/professional_report_excel_service.dart';
import '../services/professional_report_pdf_service.dart';
import '../services/report_chart_capture_service.dart';
import '../services/report_data_builder.dart';
import '../services/report_template_repository.dart';

enum ReportBuilderStep {
  periodo,
  filtros,
  contenido,
  vistaPrevia,
  exportar,
}

/// Estado del generador de reportes profesionales.
class ReportBuilderProvider extends ChangeNotifier {
  ReportBuilderProvider({
    ReportDataBuilder? dataBuilder,
    ReportTemplateRepository? templateRepo,
    ProfessionalReportPdfService? pdfService,
    ProfessionalReportExcelService? excelService,
    PermissionsService? permissions,
    ReportChartCaptureService? chartCapture,
  })  : _dataBuilder = dataBuilder ?? reportDataBuilder,
        _templateRepo = templateRepo ?? reportTemplateRepository,
        _pdfService = pdfService ?? professionalReportPdfService,
        _excelService = excelService ?? professionalReportExcelService,
        _permissions = permissions ?? permissionsService,
        _chartCapture = chartCapture ?? reportChartCaptureService;

  final ReportDataBuilder _dataBuilder;
  final ReportTemplateRepository _templateRepo;
  final ProfessionalReportPdfService _pdfService;
  final ProfessionalReportExcelService _excelService;
  final PermissionsService _permissions;
  final ReportChartCaptureService _chartCapture;

  ReportConfiguration configuration = ReportConfiguration();
  ReportBuilderStep currentStep = ReportBuilderStep.periodo;
  ProcessedReportData? processedData;
  List<ReportTemplate> templates = [];
  bool isProcessing = false;
  bool isExporting = false;
  double progress = 0;
  String? errorMessage;
  String? statusMessage;
  Uint8List? lastPdfBytes;
  Uint8List? lastExcelBytes;
  Map<ReportChartType, Uint8List> lastChartImages = {};
  List<NepRecord> _sourceRecords = [];
  AppUser? _currentUser;
  Future<List<NepRecord>> Function(ReportConfiguration config)? _resolveRecords;

  List<NepRecord> get sourceRecords => List.unmodifiable(_sourceRecords);

  int get resultCount => processedData?.records.length ?? 0;

  bool get canViewOperatorAnalysis {
    final role = _currentUser?.role;
    return role != AppUserRole.operario;
  }

  bool get canViewCreatorInfo {
    final role = _currentUser?.role;
    return role == AppUserRole.superAdmin ||
        role == AppUserRole.admin ||
        role == AppUserRole.supervisor;
  }

  bool get canExport => _permissions.canExportReports(_currentUser?.role);

  bool get canManageTemplates =>
      _permissions.canManageReports(_currentUser?.role);

  void initialize({
    required List<NepRecord> records,
    AppUser? user,
    Future<List<NepRecord>> Function(ReportConfiguration config)? resolveRecords,
  }) {
    _sourceRecords = records;
    _currentUser = user;
    _resolveRecords = resolveRecords;
    _loadTemplates();
    notifyListeners();
  }

  Future<void> _loadTemplates() async {
    templates = await _templateRepo.loadAll(userUid: _currentUser?.uid);
    notifyListeners();
  }

  void setStep(ReportBuilderStep step) {
    currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    final steps = ReportBuilderStep.values;
    final idx = steps.indexOf(currentStep);
    if (idx < steps.length - 1) {
      currentStep = steps[idx + 1];
      if (currentStep == ReportBuilderStep.vistaPrevia) {
        refreshPreview();
      }
      notifyListeners();
    }
  }

  void previousStep() {
    final steps = ReportBuilderStep.values;
    final idx = steps.indexOf(currentStep);
    if (idx > 0) {
      currentStep = steps[idx - 1];
      notifyListeners();
    }
  }

  void updateConfiguration(ReportConfiguration config) {
    configuration = config;
    notifyListeners();
  }

  Future<void> refreshPreview() async {
    final validationError = _dataBuilder.validate(configuration);
    if (validationError != null) {
      errorMessage = validationError;
      processedData = null;
      notifyListeners();
      return;
    }

    isProcessing = true;
    progress = 0.2;
    errorMessage = null;
    statusMessage = 'Calculando estadísticas...';
    notifyListeners();

    try {
      await Future<void>.delayed(Duration.zero);
      progress = 0.4;
      statusMessage = 'Cargando registros del periodo...';
      notifyListeners();

      if (_resolveRecords != null) {
        _sourceRecords = await _resolveRecords!(configuration);
      }

      progress = 0.6;
      processedData = _dataBuilder.build(
        config: configuration,
        sourceRecords: _sourceRecords,
        includeOperatorData: canViewOperatorAnalysis,
        includeCreatorData: canViewCreatorInfo,
      );
      progress = 1.0;

      if (processedData!.isEmpty) {
        errorMessage =
            'No se encontraron registros para el periodo y filtros seleccionados.';
      } else {
        statusMessage =
            '${processedData!.records.length} registros procesados.';
      }
    } catch (e) {
      errorMessage = 'Error al procesar datos: $e';
      processedData = null;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> exportPdf({
    Map<ReportChartType, Uint8List>? chartImages,
  }) async {
    if (!canExport) {
      errorMessage = _permissions.deniedMessage('exportar reportes');
      notifyListeners();
      return null;
    }
    if (processedData == null || processedData!.isEmpty) {
      await refreshPreview();
      if (processedData == null || processedData!.isEmpty) return null;
    }

    isExporting = true;
    statusMessage = 'Generando PDF...';
    notifyListeners();

    try {
      final images = chartImages ?? lastChartImages;
      final bytes = await _pdfService.buildPdf(
        processedData!,
        generatedBy: _currentUser?.displayName ?? 'Usuario',
        userRole: _currentUser?.role.label ?? '',
        includeOperatorData: canViewOperatorAnalysis,
        includeCreatorData: canViewCreatorInfo,
        chartImages: images,
      );
      lastPdfBytes = bytes;
      statusMessage = 'PDF generado correctamente.';
      return bytes;
    } catch (e) {
      errorMessage = 'Error al generar PDF: $e';
      return null;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  /// Captura gráficas habilitadas como PNG.
  Future<Map<ReportChartType, Uint8List>> captureCharts(
    BuildContext context,
  ) async {
    if (processedData == null) await refreshPreview();
    if (!context.mounted) return {};
    if (processedData == null || processedData!.isEmpty) return {};

    isProcessing = true;
    statusMessage = 'Capturando gráficas...';
    notifyListeners();

    try {
      final images = await _chartCapture.captureAll(
        context: context,
        data: processedData!,
        charts: configuration.charts,
        includeOperatorData: canViewOperatorAnalysis,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      lastChartImages = images;
      statusMessage = '${images.length} gráficas capturadas.';
      return images;
    } catch (e) {
      errorMessage = 'Error al capturar gráficas: $e';
      return {};
    } finally {
      isProcessing = false;
      progress = 0;
      notifyListeners();
    }
  }

  String _fileName(String extension) {
    final raw = configuration.cover.title.trim();
    final safe = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final base = safe.isEmpty ? 'reporte_neps' : safe;
    final stamp = DateTime.now();
    final date =
        '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_'
        '${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}';
    return '${base}_$date.$extension';
  }

  Future<bool> sharePdf(
    BuildContext context, {
    Rect? sharePositionOrigin,
    bool captureChartsFirst = true,
  }) async {
    errorMessage = null;
    if (captureChartsFirst &&
        configuration.sections.contains(ReportSectionType.graficas) &&
        configuration.charts.any((c) => c.enabled)) {
      await captureCharts(context);
      if (!context.mounted) return false;
    }
    final bytes = await exportPdf(chartImages: lastChartImages);
    if (bytes == null) return false;

    try {
      await FileShareHelper.shareBytes(
        bytes: bytes,
        fileName: _fileName('pdf'),
        mimeType: 'application/pdf',
        shareText: configuration.cover.title,
        subject: configuration.cover.title,
        sharePositionOrigin: sharePositionOrigin,
      );
      statusMessage = 'PDF compartido correctamente.';
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'No se pudo compartir el PDF: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> shareExcel(
    BuildContext context, {
    Rect? sharePositionOrigin,
  }) async {
    errorMessage = null;
    final bytes = await exportExcel();
    if (bytes == null) return false;

    try {
      await FileShareHelper.shareBytes(
        bytes: bytes,
        fileName: _fileName('xlsx'),
        mimeType: FileShareHelper.excelMimeType,
        shareText: configuration.cover.title,
        subject: configuration.cover.title,
        sharePositionOrigin: sharePositionOrigin,
      );
      statusMessage = 'Excel compartido correctamente.';
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'No se pudo compartir el Excel: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> shareChartPng(
    BuildContext context,
    ReportChartType type, {
    Rect? sharePositionOrigin,
  }) async {
    if (processedData == null) await refreshPreview();
    if (!context.mounted) return false;
    if (processedData == null) return false;

    final config = configuration.charts
        .where((c) => c.type == type && c.enabled)
        .firstOrNull;
    if (config == null) {
      errorMessage = 'La gráfica seleccionada no está activa.';
      notifyListeners();
      return false;
    }

    final bytes = await _chartCapture.captureOne(
      context: context,
      data: processedData!,
      config: config,
      includeOperatorData: canViewOperatorAnalysis,
    );
    if (bytes == null) return false;

    try {
      await FileShareHelper.shareBytes(
        bytes: bytes,
        fileName: '${_fileName('png').replaceAll('.png', '')}_${type.name}.png',
        mimeType: 'image/png',
        shareText: config.effectiveTitle,
        sharePositionOrigin: sharePositionOrigin,
      );
      return true;
    } catch (e) {
      errorMessage = 'No se pudo compartir la gráfica: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> shareAllChartsPng(
    BuildContext context, {
    Rect? sharePositionOrigin,
  }) async {
    errorMessage = null;
    final images = await captureCharts(context);
    if (images.isEmpty) return false;

    try {
      final files = images.entries.map((e) {
        final name =
            '${_fileName('png').replaceAll('.png', '')}_${e.key.name}.png';
        return XFile.fromData(e.value, mimeType: 'image/png', name: name);
      }).toList();

      await FileShareHelper.shareFiles(
        inputFiles: files,
        text: 'Gráficas del reporte',
        subject: configuration.cover.title,
        sharePositionOrigin: sharePositionOrigin,
      );
      return true;
    } catch (e) {
      errorMessage = 'No se pudieron compartir las gráficas: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> exportExcel() async {
    if (!canExport) {
      errorMessage = _permissions.deniedMessage('exportar reportes');
      notifyListeners();
      return null;
    }
    if (processedData == null) await refreshPreview();
    if (processedData == null || processedData!.isEmpty) return null;

    isExporting = true;
    statusMessage = 'Generando Excel...';
    notifyListeners();

    try {
      final bytes = _excelService.buildExcel(processedData!);
      lastExcelBytes = bytes;
      statusMessage = bytes != null
          ? 'Excel generado correctamente.'
          : 'No se pudo generar Excel.';
      return bytes;
    } catch (e) {
      errorMessage = 'Error al generar Excel: $e';
      return null;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> applyTemplate(ReportTemplate template) async {
    configuration = template.configuration.copy();
    await refreshPreview();
  }

  Future<bool> saveTemplate({
    required String name,
    String description = '',
    bool isGlobal = false,
  }) async {
    if (!canManageTemplates) return false;
    if (await _templateRepo.nameExists(name)) {
      errorMessage = 'Ya existe una plantilla con ese nombre.';
      notifyListeners();
      return false;
    }

    final template = ReportTemplate(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      description: description,
      configuration: configuration.copy(),
      isGlobal: isGlobal && _currentUser?.role == AppUserRole.superAdmin,
      createdByUid: _currentUser?.uid,
    );
    await _templateRepo.save(template);
    await _loadTemplates();
    statusMessage = 'Plantilla guardada.';
    notifyListeners();
    return true;
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
