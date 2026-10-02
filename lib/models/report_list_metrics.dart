/// Métricas de carga del listado de Informes (Fase 2A PR2).
class ReportListMetrics {
  const ReportListMetrics({
    required this.listLoadDuration,
    this.cloudSummaryDocs = 0,
    this.localSyntheticSummaries = 0,
    this.cloudFullFetches = 0,
    this.cloudRecordsDeserializedOnList = 0,
    this.localBridgeReportsRead = 0,
    this.usedFetchReportsForList = false,
  });

  final Duration listLoadDuration;
  final int cloudSummaryDocs;
  final int localSyntheticSummaries;

  /// Lecturas full disparadas por Ver/Export (no por listado).
  final int cloudFullFetches;

  /// Debe ser 0 en el path de listado cloud (summaries no traen records[]).
  final int cloudRecordsDeserializedOnList;

  /// Informes full leídos solo desde cache local para puente sintético.
  final int localBridgeReportsRead;

  /// Debe permanecer false en PR2.
  final bool usedFetchReportsForList;

  ReportListMetrics copyWith({
    Duration? listLoadDuration,
    int? cloudSummaryDocs,
    int? localSyntheticSummaries,
    int? cloudFullFetches,
    int? cloudRecordsDeserializedOnList,
    int? localBridgeReportsRead,
    bool? usedFetchReportsForList,
  }) {
    return ReportListMetrics(
      listLoadDuration: listLoadDuration ?? this.listLoadDuration,
      cloudSummaryDocs: cloudSummaryDocs ?? this.cloudSummaryDocs,
      localSyntheticSummaries:
          localSyntheticSummaries ?? this.localSyntheticSummaries,
      cloudFullFetches: cloudFullFetches ?? this.cloudFullFetches,
      cloudRecordsDeserializedOnList:
          cloudRecordsDeserializedOnList ?? this.cloudRecordsDeserializedOnList,
      localBridgeReportsRead:
          localBridgeReportsRead ?? this.localBridgeReportsRead,
      usedFetchReportsForList:
          usedFetchReportsForList ?? this.usedFetchReportsForList,
    );
  }
}
