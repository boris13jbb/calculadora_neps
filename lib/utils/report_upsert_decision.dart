/// Decisión pura de upsert cloud de un informe (sin I/O).
enum ReportUpsertDecision {
  /// Crear o actualizar de forma segura.
  write,

  /// Remoto ya tiene el mismo contenido (ACK perdido / reintento idempotente).
  alreadySynced,

  /// Remoto difiere y no hay base conocida compatible.
  conflict,
}

/// Política definitiva de conflictos:
/// - Sin remoto → crear.
/// - Misma huella local/remota → ya sincronizado.
/// - Remoto == expectedBase → actualización legítima.
/// - Cualquier otro caso (incluido mismo dueño sin base) → conflicto.
///
/// La huella DJB2 es comprobación de consistencia, no garantía criptográfica.
ReportUpsertDecision decideReportUpsert({
  required String localFingerprint,
  String? remoteFingerprint,
  String? expectedBaseFingerprint,
}) {
  final local = localFingerprint.trim();
  if (local.isEmpty) return ReportUpsertDecision.conflict;

  final remote = remoteFingerprint?.trim();
  if (remote == null || remote.isEmpty) {
    return ReportUpsertDecision.write;
  }
  if (remote == local) {
    return ReportUpsertDecision.alreadySynced;
  }

  final base = expectedBaseFingerprint?.trim();
  if (base != null && base.isNotEmpty && remote == base) {
    return ReportUpsertDecision.write;
  }
  return ReportUpsertDecision.conflict;
}

/// Excepción de conflicto de sync de informes (cliente / fakes / tests).
class ReportSyncConflictException implements Exception {
  ReportSyncConflictException(this.reportId, {this.detail});

  final String reportId;
  final String? detail;

  @override
  String toString() =>
      'Report sync conflict for $reportId${detail == null ? '' : ': $detail'}';
}
