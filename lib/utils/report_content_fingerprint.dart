import 'dart:convert';

import '../models/saved_report.dart';

/// Huella estable del contenido de un [SavedReport] (sin secretos).
///
/// Sirve para idempotencia y detección de conflictos; no incluye tokens.
/// Compatible con VM y JavaScript (sin literales enteros de 64 bits).
String reportContentFingerprint(SavedReport report) {
  final records = List.of(report.records)
    ..sort((a, b) => a.id.compareTo(b.id));
  final payload = <String, dynamic>{
    'id': report.id.trim(),
    'name': report.name.trim(),
    'createdAt': report.createdAt.toUtc().toIso8601String(),
    'createdByUid': report.createdByUid?.trim() ?? '',
    'recordCount': records.length,
    'records': records
        .map(
          (r) => {
            'id': r.id,
            'telar': r.telar,
            'tela': r.tela,
            'loteTrama': r.loteTrama,
            'neps': r.neps,
            'createdAt': r.createdAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false),
  };
  return _djb2Hex(utf8.encode(jsonEncode(payload)));
}

/// DJB2 32-bit → hex (estable en VM y Web).
String _djb2Hex(List<int> bytes) {
  var hash = 5381;
  for (final b in bytes) {
    hash = ((hash << 5) + hash + b) & 0x7fffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
