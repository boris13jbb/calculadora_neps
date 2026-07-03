/// Estilos disponibles para la generación de reportes exportables.
///
/// - [completo]: formato actual con análisis, alertas y hojas adicionales.
/// - [clasico]: formato antiguo simplificado (tabla fija y totales).
enum PdfReportStyle {
  completo,
  clasico;

  String get label => switch (this) {
        PdfReportStyle.completo => 'Completo',
        PdfReportStyle.clasico => 'Clásico',
      };

  String get description => switch (this) {
        PdfReportStyle.completo =>
          'Análisis ejecutivo, alertas y rankings (modo actual).',
        PdfReportStyle.clasico =>
          'Tabla y totales en formato simple (modo antiguo).',
      };

  static PdfReportStyle fromName(String? name) {
    return PdfReportStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => PdfReportStyle.completo,
    );
  }
}