/// Agrupación temporal para gráficas de informes.
enum AnalyticsPeriod {
  day('Día'),
  week('Semana'),
  month('Mes'),
  year('Año'),
  custom('Rango personalizado');

  const AnalyticsPeriod(this.label);

  final String label;
}
