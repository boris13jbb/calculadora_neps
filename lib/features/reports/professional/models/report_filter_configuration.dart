import '../../../../models/alert_level.dart';

/// Configuración de filtros avanzados con selección múltiple.
class ReportFilterConfiguration {
  ReportFilterConfiguration({
    Set<String>? telares,
    Set<String>? telas,
    Set<String>? lotes,
    Set<String>? turnos,
    Set<String>? operarios,
    Set<String>? lineas,
    this.alertLevel,
    this.revisadoSupervisor,
    this.conAccionCorrectiva,
    this.responsableRevision,
    this.usuarioCreador,
    this.rolCreador,
    this.conObservaciones,
    this.nepsMin,
    this.nepsMax,
    this.mtsMin,
    this.mtsMax,
    this.searchText = '',
  })  : telares = telares ?? {},
        telas = telas ?? {},
        lotes = lotes ?? {},
        turnos = turnos ?? {},
        operarios = operarios ?? {},
        lineas = lineas ?? {};

  Set<String> telares;
  Set<String> telas;
  Set<String> lotes;
  Set<String> turnos;
  Set<String> operarios;
  Set<String> lineas;
  AlertLevel? alertLevel;

  /// null = sin filtro, true = solo revisados, false = solo pendientes
  bool? revisadoSupervisor;

  /// null = sin filtro, true = con acción, false = sin acción
  bool? conAccionCorrectiva;
  String? responsableRevision;
  String? usuarioCreador;
  String? rolCreador;

  /// null = sin filtro, true = con observación, false = sin observación
  bool? conObservaciones;
  double? nepsMin;
  double? nepsMax;
  double? mtsMin;
  double? mtsMax;
  String searchText;

  int get activeFilterCount {
    var count = 0;
    if (telares.isNotEmpty) count++;
    if (telas.isNotEmpty) count++;
    if (lotes.isNotEmpty) count++;
    if (turnos.isNotEmpty) count++;
    if (operarios.isNotEmpty) count++;
    if (lineas.isNotEmpty) count++;
    if (alertLevel != null) count++;
    if (revisadoSupervisor != null) count++;
    if (conAccionCorrectiva != null) count++;
    if (responsableRevision != null && responsableRevision!.isNotEmpty) count++;
    if (usuarioCreador != null && usuarioCreador!.isNotEmpty) count++;
    if (rolCreador != null && rolCreador!.isNotEmpty) count++;
    if (conObservaciones != null) count++;
    if (nepsMin != null || nepsMax != null) count++;
    if (mtsMin != null || mtsMax != null) count++;
    if (searchText.trim().isNotEmpty) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  void clear() {
    telares.clear();
    telas.clear();
    lotes.clear();
    turnos.clear();
    operarios.clear();
    lineas.clear();
    alertLevel = null;
    revisadoSupervisor = null;
    conAccionCorrectiva = null;
    responsableRevision = null;
    usuarioCreador = null;
    rolCreador = null;
    conObservaciones = null;
    nepsMin = null;
    nepsMax = null;
    mtsMin = null;
    mtsMax = null;
    searchText = '';
  }

  ReportFilterConfiguration copy() {
    return ReportFilterConfiguration(
      telares: Set<String>.from(telares),
      telas: Set<String>.from(telas),
      lotes: Set<String>.from(lotes),
      turnos: Set<String>.from(turnos),
      operarios: Set<String>.from(operarios),
      lineas: Set<String>.from(lineas),
      alertLevel: alertLevel,
      revisadoSupervisor: revisadoSupervisor,
      conAccionCorrectiva: conAccionCorrectiva,
      responsableRevision: responsableRevision,
      usuarioCreador: usuarioCreador,
      rolCreador: rolCreador,
      conObservaciones: conObservaciones,
      nepsMin: nepsMin,
      nepsMax: nepsMax,
      mtsMin: mtsMin,
      mtsMax: mtsMax,
      searchText: searchText,
    );
  }

  Map<String, dynamic> toJson() => {
        'telares': telares.toList(),
        'telas': telas.toList(),
        'lotes': lotes.toList(),
        'turnos': turnos.toList(),
        'operarios': operarios.toList(),
        'lineas': lineas.toList(),
        if (alertLevel != null) 'alertLevel': alertLevel!.name,
        if (revisadoSupervisor != null)
          'revisadoSupervisor': revisadoSupervisor,
        if (conAccionCorrectiva != null)
          'conAccionCorrectiva': conAccionCorrectiva,
        if (responsableRevision != null)
          'responsableRevision': responsableRevision,
        if (usuarioCreador != null) 'usuarioCreador': usuarioCreador,
        if (rolCreador != null) 'rolCreador': rolCreador,
        if (conObservaciones != null) 'conObservaciones': conObservaciones,
        if (nepsMin != null) 'nepsMin': nepsMin,
        if (nepsMax != null) 'nepsMax': nepsMax,
        if (mtsMin != null) 'mtsMin': mtsMin,
        if (mtsMax != null) 'mtsMax': mtsMax,
        'searchText': searchText,
      };

  factory ReportFilterConfiguration.fromJson(Map<String, dynamic> json) {
    AlertLevel? level;
    final levelName = json['alertLevel']?.toString();
    if (levelName != null) {
      for (final candidate in AlertLevel.values) {
        if (candidate.name == levelName) {
          level = candidate;
          break;
        }
      }
    }
    return ReportFilterConfiguration(
      telares: _stringSet(json['telares']),
      telas: _stringSet(json['telas']),
      lotes: _stringSet(json['lotes']),
      turnos: _stringSet(json['turnos']),
      operarios: _stringSet(json['operarios']),
      lineas: _stringSet(json['lineas']),
      alertLevel: level,
      revisadoSupervisor: json['revisadoSupervisor'] as bool?,
      conAccionCorrectiva: json['conAccionCorrectiva'] as bool?,
      responsableRevision: json['responsableRevision']?.toString(),
      usuarioCreador: json['usuarioCreador']?.toString(),
      rolCreador: json['rolCreador']?.toString(),
      conObservaciones: json['conObservaciones'] as bool?,
      nepsMin: (json['nepsMin'] as num?)?.toDouble(),
      nepsMax: (json['nepsMax'] as num?)?.toDouble(),
      mtsMin: (json['mtsMin'] as num?)?.toDouble(),
      mtsMax: (json['mtsMax'] as num?)?.toDouble(),
      searchText: json['searchText']?.toString() ?? '',
    );
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is! List) return {};
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
  }
}
