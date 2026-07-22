/// Presets de periodo para el generador de reportes profesionales.
enum ReportPeriodPreset {
  hoy('Hoy'),
  ayer('Ayer'),
  estaSemana('Esta semana'),
  semanaAnterior('Semana anterior'),
  esteMes('Este mes'),
  mesAnterior('Mes anterior'),
  esteTrimestre('Este trimestre'),
  trimestreAnterior('Trimestre anterior'),
  esteAno('Este año'),
  anoAnterior('Año anterior'),
  rangoPersonalizado('Rango personalizado'),
  todos('Todos los registros');

  const ReportPeriodPreset(this.label);

  final String label;
}

/// Rango de fechas resuelto a partir de un preset.
class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    required this.preset,
    this.label = '',
  });

  final DateTime? start;
  final DateTime? end;
  final ReportPeriodPreset preset;
  final String label;

  bool get isAll => preset == ReportPeriodPreset.todos;

  bool contains(DateTime date) {
    if (isAll) return true;
    if (start == null || end == null) return true;
    return !date.isBefore(start!) && !date.isAfter(end!);
  }

  String get displayLabel {
    if (label.isNotEmpty) return label;
    if (isAll) return 'Todos los registros';
    if (start == null || end == null) return preset.label;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${fmt(start!)} — ${fmt(end!)}';
  }
}
