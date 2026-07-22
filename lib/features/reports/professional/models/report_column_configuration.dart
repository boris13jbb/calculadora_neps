import 'report_detail_column.dart';

/// Configuración de la tabla detallada del reporte.
class ReportColumnConfiguration {
  const ReportColumnConfiguration({
    this.columns = ReportDetailColumn.defaultOrder,
    this.recordFilter = ReportTableRecordFilter.todos,
    this.sortColumn = ReportDetailColumn.fecha,
    this.sortAscending = true,
    this.recordLimit,
    this.includeAllRecords = true,
    this.fontSize = 9.0,
    this.landscape = false,
    this.repeatHeaders = true,
    this.pageNumbers = true,
  });

  final List<ReportDetailColumn> columns;
  final ReportTableRecordFilter recordFilter;
  final ReportDetailColumn sortColumn;
  final bool sortAscending;
  final int? recordLimit;
  final bool includeAllRecords;
  final double fontSize;
  final bool landscape;
  final bool repeatHeaders;
  final bool pageNumbers;

  List<ReportDetailColumn> get resolvedColumns =>
      ReportDetailColumn.resolveOrder(columns);

  ReportColumnConfiguration copyWith({
    List<ReportDetailColumn>? columns,
    ReportTableRecordFilter? recordFilter,
    ReportDetailColumn? sortColumn,
    bool? sortAscending,
    int? recordLimit,
    bool? includeAllRecords,
    double? fontSize,
    bool? landscape,
    bool? repeatHeaders,
    bool? pageNumbers,
  }) {
    return ReportColumnConfiguration(
      columns: columns ?? this.columns,
      recordFilter: recordFilter ?? this.recordFilter,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      recordLimit: recordLimit ?? this.recordLimit,
      includeAllRecords: includeAllRecords ?? this.includeAllRecords,
      fontSize: fontSize ?? this.fontSize,
      landscape: landscape ?? this.landscape,
      repeatHeaders: repeatHeaders ?? this.repeatHeaders,
      pageNumbers: pageNumbers ?? this.pageNumbers,
    );
  }

  Map<String, dynamic> toJson() => {
        'columns': columns.map((c) => c.name).toList(),
        'recordFilter': recordFilter.name,
        'sortColumn': sortColumn.name,
        'sortAscending': sortAscending,
        'recordLimit': recordLimit,
        'includeAllRecords': includeAllRecords,
        'fontSize': fontSize,
        'landscape': landscape,
        'repeatHeaders': repeatHeaders,
        'pageNumbers': pageNumbers,
      };

  factory ReportColumnConfiguration.fromJson(Map<String, dynamic> json) {
    final colNames = (json['columns'] as List?)?.map((e) => e.toString()) ?? [];
    final columns = <ReportDetailColumn>[];
    for (final name in colNames) {
      final col =
          ReportDetailColumn.values.cast<ReportDetailColumn?>().firstWhere(
                (e) => e?.name == name,
                orElse: () => null,
              );
      if (col != null) columns.add(col);
    }
    final filterName = json['recordFilter']?.toString() ?? 'todos';
    final sortName = json['sortColumn']?.toString() ?? 'fecha';
    return ReportColumnConfiguration(
      columns: columns.isEmpty ? ReportDetailColumn.defaultOrder : columns,
      recordFilter: ReportTableRecordFilter.values.firstWhere(
        (e) => e.name == filterName,
        orElse: () => ReportTableRecordFilter.todos,
      ),
      sortColumn: ReportDetailColumn.values.firstWhere(
        (e) => e.name == sortName,
        orElse: () => ReportDetailColumn.fecha,
      ),
      sortAscending: json['sortAscending'] as bool? ?? true,
      recordLimit: json['recordLimit'] as int?,
      includeAllRecords: json['includeAllRecords'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 9.0,
      landscape: json['landscape'] as bool? ?? false,
      repeatHeaders: json['repeatHeaders'] as bool? ?? true,
      pageNumbers: json['pageNumbers'] as bool? ?? true,
    );
  }
}
