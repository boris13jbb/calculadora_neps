import '../core/constants.dart';
import '../models/alert_level.dart';
import '../models/corrective_action_entry.dart';
import '../services/alert_service.dart';

class NepRecord {
  String id;
  String telar;
  double neps;
  String tela;
  String loteTrama;
  DateTime createdAt;
  String turno;
  String operario;
  String lineaProduccion;
  String observacion;
  bool revisadoPorSupervisor;
  String accionCorrectiva;
  String responsableRevision;
  DateTime? fechaRevision;
  List<CorrectiveActionEntry> historialAcciones;
  String? createdByUid;
  String? createdByEmail;
  String? createdByRole;

  NepRecord({
    required this.telar,
    required this.neps,
    String? id,
    this.tela = '',
    this.loteTrama = '',
    DateTime? createdAt,
    this.turno = '',
    this.operario = '',
    this.lineaProduccion = '',
    this.observacion = '',
    this.revisadoPorSupervisor = false,
    this.accionCorrectiva = '',
    this.responsableRevision = '',
    this.fechaRevision,
    List<CorrectiveActionEntry>? historialAcciones,
    this.createdByUid,
    this.createdByEmail,
    this.createdByRole,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        historialAcciones = historialAcciones ?? [];

  double get mtsCalculados => neps / testLengthM;

  AlertLevel get alertLevel => alertService.getAlertLevel(neps);

  String get estadoAlerta => alertLevel.label;

  bool get requiereSeguimiento =>
      alertLevel != AlertLevel.normal && !revisadoPorSupervisor;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'telar': telar,
      'neps': neps,
      'tela': tela,
      'loteTrama': loteTrama,
      'createdAt': createdAt.toIso8601String(),
      if (turno.isNotEmpty) 'turno': turno,
      if (operario.isNotEmpty) 'operario': operario,
      if (lineaProduccion.isNotEmpty) 'lineaProduccion': lineaProduccion,
      if (observacion.isNotEmpty) 'observacion': observacion,
      if (revisadoPorSupervisor) 'revisadoPorSupervisor': revisadoPorSupervisor,
      if (accionCorrectiva.isNotEmpty) 'accionCorrectiva': accionCorrectiva,
      if (responsableRevision.isNotEmpty)
        'responsableRevision': responsableRevision,
      if (fechaRevision != null)
        'fechaRevision': fechaRevision!.toIso8601String(),
      if (historialAcciones.isNotEmpty)
        'historialAcciones': historialAcciones.map((e) => e.toJson()).toList(),
      if (createdByUid != null && createdByUid!.isNotEmpty)
        'createdByUid': createdByUid,
      if (createdByEmail != null && createdByEmail!.isNotEmpty)
        'createdByEmail': createdByEmail,
      if (createdByRole != null && createdByRole!.isNotEmpty)
        'createdByRole': createdByRole,
    };
  }

  factory NepRecord.fromJson(Map<String, dynamic> json) {
    final historialRaw = json['historialAcciones'];
    final historial = <CorrectiveActionEntry>[];
    if (historialRaw is List) {
      for (final item in historialRaw) {
        if (item is Map) {
          historial.add(
            CorrectiveActionEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return NepRecord(
      id: json['id']?.toString(),
      telar: json['telar']?.toString() ?? '',
      neps: double.tryParse(json['neps'].toString()) ?? 0,
      tela: json['tela']?.toString() ?? '',
      loteTrama: json['loteTrama']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      turno: json['turno']?.toString() ?? '',
      operario: json['operario']?.toString() ?? '',
      lineaProduccion: json['lineaProduccion']?.toString() ?? '',
      observacion: json['observacion']?.toString() ?? '',
      revisadoPorSupervisor: json['revisadoPorSupervisor'] == true,
      accionCorrectiva: json['accionCorrectiva']?.toString() ?? '',
      responsableRevision: json['responsableRevision']?.toString() ?? '',
      fechaRevision: json['fechaRevision'] != null
          ? DateTime.tryParse(json['fechaRevision'].toString())
          : null,
      historialAcciones: historial,
      createdByUid: json['createdByUid']?.toString(),
      createdByEmail: json['createdByEmail']?.toString(),
      createdByRole: json['createdByRole']?.toString(),
    );
  }

  NepRecord copyWith({
    String? id,
    String? telar,
    double? neps,
    String? tela,
    String? loteTrama,
    DateTime? createdAt,
    String? turno,
    String? operario,
    String? lineaProduccion,
    String? observacion,
    bool? revisadoPorSupervisor,
    String? accionCorrectiva,
    String? responsableRevision,
    DateTime? fechaRevision,
    List<CorrectiveActionEntry>? historialAcciones,
    String? createdByUid,
    String? createdByEmail,
    String? createdByRole,
  }) {
    return NepRecord(
      id: id ?? this.id,
      telar: telar ?? this.telar,
      neps: neps ?? this.neps,
      tela: tela ?? this.tela,
      loteTrama: loteTrama ?? this.loteTrama,
      createdAt: createdAt ?? this.createdAt,
      turno: turno ?? this.turno,
      operario: operario ?? this.operario,
      lineaProduccion: lineaProduccion ?? this.lineaProduccion,
      observacion: observacion ?? this.observacion,
      revisadoPorSupervisor:
          revisadoPorSupervisor ?? this.revisadoPorSupervisor,
      accionCorrectiva: accionCorrectiva ?? this.accionCorrectiva,
      responsableRevision: responsableRevision ?? this.responsableRevision,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      historialAcciones: historialAcciones ?? this.historialAcciones,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      createdByRole: createdByRole ?? this.createdByRole,
    );
  }
}
