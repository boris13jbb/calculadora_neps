/// Identificadores de métricas individuales del resumen ejecutivo.
enum ReportMetricId {
  totalRegistros('Total de registros'),
  totalNeps('Total de neps'),
  promedioNeps('Promedio de neps'),
  medianaNeps('Mediana de neps'),
  modaNeps('Moda de neps'),
  minNeps('Valor mínimo de neps'),
  maxNeps('Valor máximo de neps'),
  rangoNeps('Rango de neps'),
  desviacionEstandar('Desviación estándar'),
  varianza('Varianza'),
  percentil25('Percentil 25'),
  percentil50('Percentil 50'),
  percentil75('Percentil 75'),
  percentil90('Percentil 90'),
  percentil95('Percentil 95'),
  coeficienteVariacion('Coeficiente de variación'),
  promedioMts('Promedio de metros calculados'),
  totalMts('Total de metros calculados'),
  minMts('Mínimo de metros calculados'),
  maxMts('Máximo de metros calculados'),
  cantidadNormales('Cantidad de registros normales'),
  cantidadAdvertencias('Cantidad de advertencias'),
  cantidadCriticos('Cantidad de críticos'),
  porcentajeNormales('Porcentaje de normales'),
  porcentajeAdvertencias('Porcentaje de advertencias'),
  porcentajeCriticos('Porcentaje de críticos'),
  cantidadRevisados('Cantidad revisada por supervisor'),
  cantidadPendientes('Cantidad pendiente de revisión'),
  porcentajeCumplimientoRevision('Porcentaje de cumplimiento de revisión'),
  cantidadConAcciones('Cantidad con acciones correctivas'),
  cantidadSinAcciones('Cantidad sin acciones correctivas'),
  tasaCierreAcciones('Tasa de cierre de acciones correctivas'),
  cantidadTelares('Cantidad de telares analizados'),
  cantidadTelas('Cantidad de telas analizadas'),
  cantidadLotes('Cantidad de lotes analizados'),
  cantidadOperarios('Cantidad de operarios analizados'),
  cantidadTurnos('Cantidad de turnos analizados'),
  cantidadLineas('Cantidad de líneas de producción analizadas');

  const ReportMetricId(this.label);

  final String label;

  static Set<ReportMetricId> executiveDefaults() => {
        totalRegistros,
        totalNeps,
        promedioNeps,
        cantidadCriticos,
        porcentajeCriticos,
        cantidadPendientes,
        totalMts,
      };

  static Set<ReportMetricId> technicalDefaults() => Set<ReportMetricId>.from(
        ReportMetricId.values,
      );

  static Set<ReportMetricId> qualityDefaults() => {
        promedioNeps,
        medianaNeps,
        desviacionEstandar,
        coeficienteVariacion,
        cantidadNormales,
        cantidadAdvertencias,
        cantidadCriticos,
        porcentajeNormales,
        porcentajeAdvertencias,
        porcentajeCriticos,
      };

  static Set<ReportMetricId> trackingDefaults() => {
        cantidadRevisados,
        cantidadPendientes,
        porcentajeCumplimientoRevision,
        cantidadConAcciones,
        cantidadSinAcciones,
        tasaCierreAcciones,
      };
}
