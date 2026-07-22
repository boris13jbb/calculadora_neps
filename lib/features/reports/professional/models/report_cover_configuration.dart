/// Configuración de la portada del reporte.
class ReportCoverConfiguration {
  const ReportCoverConfiguration({
    this.showLogo = true,
    this.companyName = 'VICUNHA',
    this.title = 'Informe de calidad Neps',
    this.subtitle = 'Análisis de producción textil',
    this.reportType = 'Reporte profesional',
    this.department = 'Control de calidad',
    this.internalCode = '',
    this.version = '1.0',
    this.confidentialityText = 'Documento confidencial. Uso exclusivo interno.',
    this.generalNote = '',
    this.showElaboratedSignature = true,
    this.showReviewedSignature = true,
    this.showApprovedSignature = false,
    this.elaboratedBy = '',
    this.reviewedBy = '',
    this.approvedBy = '',
  });

  final bool showLogo;
  final String companyName;
  final String title;
  final String subtitle;
  final String reportType;
  final String department;
  final String internalCode;
  final String version;
  final String confidentialityText;
  final String generalNote;
  final bool showElaboratedSignature;
  final bool showReviewedSignature;
  final bool showApprovedSignature;
  final String elaboratedBy;
  final String reviewedBy;
  final String approvedBy;

  ReportCoverConfiguration copyWith({
    bool? showLogo,
    String? companyName,
    String? title,
    String? subtitle,
    String? reportType,
    String? department,
    String? internalCode,
    String? version,
    String? confidentialityText,
    String? generalNote,
    bool? showElaboratedSignature,
    bool? showReviewedSignature,
    bool? showApprovedSignature,
    String? elaboratedBy,
    String? reviewedBy,
    String? approvedBy,
  }) {
    return ReportCoverConfiguration(
      showLogo: showLogo ?? this.showLogo,
      companyName: companyName ?? this.companyName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      reportType: reportType ?? this.reportType,
      department: department ?? this.department,
      internalCode: internalCode ?? this.internalCode,
      version: version ?? this.version,
      confidentialityText: confidentialityText ?? this.confidentialityText,
      generalNote: generalNote ?? this.generalNote,
      showElaboratedSignature:
          showElaboratedSignature ?? this.showElaboratedSignature,
      showReviewedSignature:
          showReviewedSignature ?? this.showReviewedSignature,
      showApprovedSignature:
          showApprovedSignature ?? this.showApprovedSignature,
      elaboratedBy: elaboratedBy ?? this.elaboratedBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'showLogo': showLogo,
        'companyName': companyName,
        'title': title,
        'subtitle': subtitle,
        'reportType': reportType,
        'department': department,
        'internalCode': internalCode,
        'version': version,
        'confidentialityText': confidentialityText,
        'generalNote': generalNote,
        'showElaboratedSignature': showElaboratedSignature,
        'showReviewedSignature': showReviewedSignature,
        'showApprovedSignature': showApprovedSignature,
        'elaboratedBy': elaboratedBy,
        'reviewedBy': reviewedBy,
        'approvedBy': approvedBy,
      };

  factory ReportCoverConfiguration.fromJson(Map<String, dynamic> json) {
    return ReportCoverConfiguration(
      showLogo: json['showLogo'] as bool? ?? true,
      companyName: json['companyName']?.toString() ?? 'VICUNHA',
      title: json['title']?.toString() ?? 'Informe de calidad Neps',
      subtitle: json['subtitle']?.toString() ?? 'Análisis de producción textil',
      reportType: json['reportType']?.toString() ?? 'Reporte profesional',
      department: json['department']?.toString() ?? 'Control de calidad',
      internalCode: json['internalCode']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0',
      confidentialityText: json['confidentialityText']?.toString() ??
          'Documento confidencial. Uso exclusivo interno.',
      generalNote: json['generalNote']?.toString() ?? '',
      showElaboratedSignature: json['showElaboratedSignature'] as bool? ?? true,
      showReviewedSignature: json['showReviewedSignature'] as bool? ?? true,
      showApprovedSignature: json['showApprovedSignature'] as bool? ?? false,
      elaboratedBy: json['elaboratedBy']?.toString() ?? '',
      reviewedBy: json['reviewedBy']?.toString() ?? '',
      approvedBy: json['approvedBy']?.toString() ?? '',
    );
  }
}
