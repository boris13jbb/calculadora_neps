enum ExportColumn {
  nro,
  fecha,
  loteTrama,
  tela,
  telar,
  neps,
  mts;

  String get label => switch (this) {
        ExportColumn.nro => 'Nro',
        ExportColumn.fecha => 'Fecha',
        ExportColumn.loteTrama => 'Lote de trama',
        ExportColumn.tela => 'Tela',
        ExportColumn.telar => 'Telar',
        ExportColumn.neps => 'Neps',
        ExportColumn.mts => 'Mts calculados',
      };

  static const List<ExportColumn> ordered = [
    ExportColumn.nro,
    ExportColumn.fecha,
    ExportColumn.loteTrama,
    ExportColumn.tela,
    ExportColumn.telar,
    ExportColumn.neps,
    ExportColumn.mts,
  ];

  static Set<ExportColumn> defaultSelection() =>
      Set<ExportColumn>.from(ordered);

  static List<ExportColumn> resolveSelection(Set<ExportColumn> selected) =>
      ordered.where(selected.contains).toList();

  static bool isValidSelection(Set<ExportColumn> selected) =>
      ordered.any(selected.contains);
}
