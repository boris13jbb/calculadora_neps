/// Límites centralizados para el sistema de alertas de neps.
/// Modificar aquí o cargar desde configuración (Fase 11).
class AlertConfig {
  const AlertConfig({
    this.limiteNormalMax = 30,
    this.limiteAdvertenciaMax = 60,
    this.diasParaReincidencia = 1,
    this.cantidadReincidenciasCriticas = 3,
    this.alertasActivas = true,
  });

  /// Neps de 0 a este valor → estado normal.
  final int limiteNormalMax;

  /// Neps de (limiteNormalMax + 1) a este valor → advertencia.
  final int limiteAdvertenciaMax;

  /// Ventana en días para evaluar reincidencia de telar.
  final int diasParaReincidencia;

  /// Cantidad mínima de registros críticos para marcar telar reincidente.
  final int cantidadReincidenciasCriticas;

  /// Interruptor global de alertas (reservado para configuración futura).
  final bool alertasActivas;

  /// Primer valor que se considera crítico.
  int get limiteCriticoMin => limiteAdvertenciaMax + 1;

  AlertConfig copyWith({
    int? limiteNormalMax,
    int? limiteAdvertenciaMax,
    int? diasParaReincidencia,
    int? cantidadReincidenciasCriticas,
    bool? alertasActivas,
  }) {
    return AlertConfig(
      limiteNormalMax: limiteNormalMax ?? this.limiteNormalMax,
      limiteAdvertenciaMax: limiteAdvertenciaMax ?? this.limiteAdvertenciaMax,
      diasParaReincidencia: diasParaReincidencia ?? this.diasParaReincidencia,
      cantidadReincidenciasCriticas:
          cantidadReincidenciasCriticas ?? this.cantidadReincidenciasCriticas,
      alertasActivas: alertasActivas ?? this.alertasActivas,
    );
  }
}

/// Instancia por defecto usada en toda la app hasta implementar persistencia.
const AlertConfig defaultAlertConfig = AlertConfig();
