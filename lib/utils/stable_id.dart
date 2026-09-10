import 'dart:math';

/// Identificador estable para registros y sesiones (no depende de telar/lote/índice).
String generateStableId({String? prefix}) {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final rand = Random.secure().nextInt(0x7fffffff);
  final body = '${now.toRadixString(36)}_${rand.toRadixString(36)}';
  if (prefix == null || prefix.trim().isEmpty) return body;
  return '${prefix.trim()}_$body';
}
