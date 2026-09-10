import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Borrador de captura persistido por UID (sobrevive reinicio / cambio de cuenta).
class CaptureDraftSnapshot {
  CaptureDraftSnapshot({
    required this.ownerUid,
    required this.captureSessionId,
    required this.updatedAt,
    this.telar = '',
    this.neps = '',
    this.manualTela = '',
    this.selectedFabric,
    this.useManualFabric = false,
    this.loteFull = '',
    this.lotePrefix = '',
    this.loteSuffix = '',
    this.loteFullEntryMode = false,
    this.turno = '',
    this.operario = '',
    this.lineaProduccion = '',
    this.observacion = '',
    this.accionInmediata = '',
  });

  final String ownerUid;
  final String captureSessionId;
  final DateTime updatedAt;
  final String telar;
  final String neps;
  final String manualTela;
  final String? selectedFabric;
  final bool useManualFabric;
  final String loteFull;
  final String lotePrefix;
  final String loteSuffix;
  final bool loteFullEntryMode;
  final String turno;
  final String operario;
  final String lineaProduccion;
  final String observacion;
  final String accionInmediata;

  bool get isEmpty =>
      telar.isEmpty &&
      neps.isEmpty &&
      manualTela.isEmpty &&
      (selectedFabric == null || selectedFabric!.isEmpty) &&
      !useManualFabric &&
      loteFull.isEmpty &&
      lotePrefix.isEmpty &&
      loteSuffix.isEmpty &&
      turno.isEmpty &&
      operario.isEmpty &&
      lineaProduccion.isEmpty &&
      observacion.isEmpty &&
      accionInmediata.isEmpty;

  Map<String, dynamic> toJson() => {
        'ownerUid': ownerUid,
        'captureSessionId': captureSessionId,
        'updatedAt': updatedAt.toIso8601String(),
        'telar': telar,
        'neps': neps,
        'manualTela': manualTela,
        'selectedFabric': selectedFabric,
        'useManualFabric': useManualFabric,
        'loteFull': loteFull,
        'lotePrefix': lotePrefix,
        'loteSuffix': loteSuffix,
        'loteFullEntryMode': loteFullEntryMode,
        'turno': turno,
        'operario': operario,
        'lineaProduccion': lineaProduccion,
        'observacion': observacion,
        'accionInmediata': accionInmediata,
      };

  factory CaptureDraftSnapshot.fromJson(Map<String, dynamic> json) {
    return CaptureDraftSnapshot(
      ownerUid: json['ownerUid']?.toString() ?? '',
      captureSessionId: json['captureSessionId']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      telar: json['telar']?.toString() ?? '',
      neps: json['neps']?.toString() ?? '',
      manualTela: json['manualTela']?.toString() ?? '',
      selectedFabric: json['selectedFabric']?.toString(),
      useManualFabric: json['useManualFabric'] == true,
      loteFull: json['loteFull']?.toString() ?? '',
      lotePrefix: json['lotePrefix']?.toString() ?? '',
      loteSuffix: json['loteSuffix']?.toString() ?? '',
      loteFullEntryMode: json['loteFullEntryMode'] == true,
      turno: json['turno']?.toString() ?? '',
      operario: json['operario']?.toString() ?? '',
      lineaProduccion: json['lineaProduccion']?.toString() ?? '',
      observacion: json['observacion']?.toString() ?? '',
      accionInmediata: json['accionInmediata']?.toString() ?? '',
    );
  }
}

class CaptureDraftStorageService {
  CaptureDraftStorageService();

  Future<void> save(CaptureDraftSnapshot draft) async {
    final uid = draft.ownerUid.trim();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (draft.isEmpty) {
      await prefs.remove(captureDraftKeyForUid(uid));
      return;
    }
    await prefs.setString(
      captureDraftKeyForUid(uid),
      jsonEncode(draft.toJson()),
    );
  }

  Future<CaptureDraftSnapshot?> loadForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(captureDraftKeyForUid(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      final draft = CaptureDraftSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (draft.ownerUid != uid) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(captureDraftKeyForUid(uid));
  }
}

final CaptureDraftStorageService captureDraftStorageService =
    CaptureDraftStorageService();
