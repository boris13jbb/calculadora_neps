import '../core/neps_quality_criteria.dart';

/// Parámetros operativos del sistema de alertas.
///
/// Los umbrales de calificación de calidad (OK / Mención / Crítico /
/// 2da Calidad) son oficiales y fijos en [NepsQualityCriteria]. Este modelo
/// solo conserva interruptores y reglas de reincidencia.
class AlertConfig {
  const AlertConfig({
    this.diasParaReincidencia = 1,
    this.cantidadReincidenciasCriticas = 3,
    this.alertasActivas = true,
  });

  /// Ventana en días para evaluar reincidencia de telar.
  final int diasParaReincidencia;

  /// Cantidad mínima de registros severos (Crítico / 2da Calidad) para
  /// marcar telar reincidente.
  final int cantidadReincidenciasCriticas;

  /// Interruptor global de alertas.
  final bool alertasActivas;

  /// Límites oficiales expuestos para UI de configuración (solo lectura).
  int get limiteOkMaxScore => NepsQualityCriteria.okMaxScore;
  int get limiteMencionMaxScore => NepsQualityCriteria.mencionMaxScore;
  int get limiteCriticoMaxScore => NepsQualityCriteria.criticoMaxScore;

  AlertConfig copyWith({
    int? diasParaReincidencia,
    int? cantidadReincidenciasCriticas,
    bool? alertasActivas,
  }) {
    return AlertConfig(
      diasParaReincidencia: diasParaReincidencia ?? this.diasParaReincidencia,
      cantidadReincidenciasCriticas:
          cantidadReincidenciasCriticas ?? this.cantidadReincidenciasCriticas,
      alertasActivas: alertasActivas ?? this.alertasActivas,
    );
  }
}

/// Instancia por defecto usada en toda la app.
const AlertConfig defaultAlertConfig = AlertConfig();
