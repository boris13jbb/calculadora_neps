/// Secciones configurables del reporte profesional.
enum ReportSectionType {
  portada('Portada'),
  resumenEjecutivo('Resumen ejecutivo'),
  indicadoresCalidad('Indicadores de calidad'),
  analisisTemporal('Análisis temporal'),
  analisisTelar('Análisis por telar'),
  analisisTela('Análisis por tela'),
  analisisLote('Análisis por lote de trama'),
  analisisTurno('Análisis por turno'),
  analisisOperario('Análisis por operario'),
  analisisLinea('Análisis por línea de producción'),
  alertas('Alertas'),
  accionesCorrectivas('Acciones correctivas y seguimiento'),
  observaciones('Observaciones'),
  tablaDetallada('Tabla detallada de registros'),
  graficas('Gráficas'),
  comparacionPeriodos('Comparación entre periodos'),
  conclusiones('Conclusiones automáticas');

  const ReportSectionType(this.label);

  final String label;

  /// Requiere permiso de análisis por operario.
  bool get requiresOperatorPermission =>
      this == ReportSectionType.analisisOperario;

  /// Requiere permiso para ver datos del creador.
  bool get mayIncludeCreatorInfo => this == ReportSectionType.tablaDetallada;
}
