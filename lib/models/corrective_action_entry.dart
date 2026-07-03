/// Entrada del historial de acciones correctivas sobre un registro.
class CorrectiveActionEntry {
  const CorrectiveActionEntry({
    required this.fecha,
    required this.responsable,
    required this.accion,
  });

  final DateTime fecha;
  final String responsable;
  final String accion;

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'responsable': responsable,
        'accion': accion,
      };

  factory CorrectiveActionEntry.fromJson(Map<String, dynamic> json) {
    return CorrectiveActionEntry(
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
      responsable: json['responsable']?.toString() ?? '',
      accion: json['accion']?.toString() ?? '',
    );
  }
}
