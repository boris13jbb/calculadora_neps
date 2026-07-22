import 'package:pdf/pdf.dart';

/// Opciones de exportación del reporte profesional.
class ReportExportOptions {
  const ReportExportOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.landscape = false,
    this.marginMm = 12.0,
    this.imageQuality = 2.0,
    this.showLogo = true,
    this.showHeader = true,
    this.showFooter = true,
    this.protectSensitiveData = true,
  });

  final PdfPageFormat pageFormat;
  final bool landscape;
  final double marginMm;
  final double imageQuality;
  final bool showLogo;
  final bool showHeader;
  final bool showFooter;
  final bool protectSensitiveData;

  PdfPageFormat get effectiveFormat =>
      landscape ? pageFormat.landscape : pageFormat;

  ReportExportOptions copyWith({
    PdfPageFormat? pageFormat,
    bool? landscape,
    double? marginMm,
    double? imageQuality,
    bool? showLogo,
    bool? showHeader,
    bool? showFooter,
    bool? protectSensitiveData,
  }) {
    return ReportExportOptions(
      pageFormat: pageFormat ?? this.pageFormat,
      landscape: landscape ?? this.landscape,
      marginMm: marginMm ?? this.marginMm,
      imageQuality: imageQuality ?? this.imageQuality,
      showLogo: showLogo ?? this.showLogo,
      showHeader: showHeader ?? this.showHeader,
      showFooter: showFooter ?? this.showFooter,
      protectSensitiveData: protectSensitiveData ?? this.protectSensitiveData,
    );
  }

  Map<String, dynamic> toJson() => {
        'pageFormat': pageFormat == PdfPageFormat.letter ? 'letter' : 'a4',
        'landscape': landscape,
        'marginMm': marginMm,
        'imageQuality': imageQuality,
        'showLogo': showLogo,
        'showHeader': showHeader,
        'showFooter': showFooter,
        'protectSensitiveData': protectSensitiveData,
      };

  factory ReportExportOptions.fromJson(Map<String, dynamic> json) {
    final fmt = json['pageFormat']?.toString() ?? 'a4';
    return ReportExportOptions(
      pageFormat: fmt == 'letter' ? PdfPageFormat.letter : PdfPageFormat.a4,
      landscape: json['landscape'] as bool? ?? false,
      marginMm: (json['marginMm'] as num?)?.toDouble() ?? 12.0,
      imageQuality: (json['imageQuality'] as num?)?.toDouble() ?? 2.0,
      showLogo: json['showLogo'] as bool? ?? true,
      showHeader: json['showHeader'] as bool? ?? true,
      showFooter: json['showFooter'] as bool? ?? true,
      protectSensitiveData: json['protectSensitiveData'] as bool? ?? true,
    );
  }
}
