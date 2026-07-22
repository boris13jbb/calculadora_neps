/// Tipos de gráficas disponibles en el reporte profesional.
enum ReportChartType {
  tendenciaNeps('Línea de tendencia de neps'),
  promedioMovil('Línea de promedio móvil'),
  barrasRegistrosPeriodo('Barras de registros por periodo'),
  barrasPromedioTelar('Barras de promedio por telar'),
  barrasPromedioTela('Barras de promedio por tela'),
  barrasPromedioTurno('Barras de promedio por turno'),
  barrasPromedioOperario('Barras de promedio por operario'),
  barrasPromedioLinea('Barras de promedio por línea'),
  barrasAlertasTelar('Barras de alertas por telar'),
  barrasApiladasEstadosTelar('Barras apiladas de estados por telar'),
  barrasApiladasEstadosPeriodo('Barras apiladas de estados por periodo'),
  circularAlertas('Gráfico circular de alertas'),
  donaAlertas('Gráfico de dona de alertas'),
  histogramaNeps('Histograma de distribución de neps'),
  cajaBigotesTelar('Diagrama de caja por telar'),
  cajaBigotesTurno('Diagrama de caja por turno'),
  dispersionNepsTiempo('Dispersión de neps frente al tiempo'),
  paretoTelaresCriticos('Pareto de telares con más críticos'),
  mapaCalorDiaTurno('Mapa de calor por día y turno'),
  mapaCalorTelarPeriodo('Mapa de calor por telar y periodo'),
  revisadosVsPendientes('Revisados frente a pendientes'),
  accionesCorrectivas('Gráfico de acciones correctivas'),
  comparacionPeriodos('Comparación periodo actual vs anterior'),
  rankingTelares('Ranking visual de telares'),
  rankingTelas('Ranking visual de telas'),
  rankingLotes('Ranking visual de lotes');

  const ReportChartType(this.label);

  final String label;

  bool get requiresOperatorPermission =>
      this == ReportChartType.barrasPromedioOperario;

  static Set<ReportChartType> executiveDefaults() => {
        tendenciaNeps,
        circularAlertas,
        comparacionPeriodos,
        rankingTelares,
      };

  static Set<ReportChartType> technicalDefaults() => {
        tendenciaNeps,
        promedioMovil,
        barrasPromedioTelar,
        barrasPromedioTela,
        barrasApiladasEstadosTelar,
        histogramaNeps,
        rankingTelares,
      };

  static Set<ReportChartType> qualityDefaults() => {
        circularAlertas,
        barrasAlertasTelar,
        paretoTelaresCriticos,
        histogramaNeps,
      };

  static Set<ReportChartType> trackingDefaults() => {
        revisadosVsPendientes,
        accionesCorrectivas,
        barrasApiladasEstadosPeriodo,
      };
}

/// Agrupación temporal para análisis y gráficas.
enum ReportTemporalGrouping {
  hora('Hora'),
  dia('Día'),
  semana('Semana'),
  mes('Mes'),
  trimestre('Trimestre'),
  semestre('Semestre'),
  ano('Año');

  const ReportTemporalGrouping(this.label);

  final String label;
}
