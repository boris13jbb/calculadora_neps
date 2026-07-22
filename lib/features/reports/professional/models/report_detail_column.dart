/// Columnas disponibles en la tabla detallada del reporte profesional.
enum ReportDetailColumn {
  numero('Número'),
  idRegistro('ID del registro'),
  fecha('Fecha'),
  hora('Hora'),
  telar('Telar'),
  tela('Tela'),
  loteTrama('Lote de trama'),
  neps('Neps'),
  mtsCalculados('Metros calculados'),
  estadoAlerta('Estado de alerta'),
  turno('Turno'),
  operario('Operario'),
  lineaProduccion('Línea de producción'),
  observacion('Observación'),
  recomendacion('Recomendación'),
  revisadoSupervisor('Revisado por supervisor'),
  accionCorrectiva('Acción correctiva'),
  responsableRevision('Responsable de revisión'),
  fechaRevision('Fecha de revisión'),
  tiempoRespuesta('Tiempo de respuesta'),
  cantidadAcciones('Cantidad de acciones registradas'),
  usuarioCreador('Usuario creador'),
  correoCreador('Correo del usuario creador'),
  rolCreador('Rol del usuario creador');

  const ReportDetailColumn(this.label);

  final String label;

  bool get requiresCreatorPermission =>
      this == usuarioCreador || this == correoCreador || this == rolCreador;

  bool get requiresOperatorPermission => this == operario;

  static const List<ReportDetailColumn> defaultOrder = [
    ReportDetailColumn.numero,
    ReportDetailColumn.fecha,
    ReportDetailColumn.hora,
    ReportDetailColumn.telar,
    ReportDetailColumn.tela,
    ReportDetailColumn.loteTrama,
    ReportDetailColumn.neps,
    ReportDetailColumn.mtsCalculados,
    ReportDetailColumn.estadoAlerta,
    ReportDetailColumn.turno,
    ReportDetailColumn.operario,
    ReportDetailColumn.observacion,
  ];

  static List<ReportDetailColumn> resolveOrder(
      List<ReportDetailColumn> selected) {
    final set = selected.toSet();
    final ordered = defaultOrder.where(set.contains).toList();
    for (final col in selected) {
      if (!ordered.contains(col)) ordered.add(col);
    }
    return ordered;
  }
}

/// Modo de filtrado de registros en la tabla detallada.
enum ReportTableRecordFilter {
  todos('Todos los registros'),
  soloCriticos('Solo registros críticos'),
  soloPendientes('Solo registros pendientes de revisión'),
  resumida('Tabla resumida'),
  completa('Tabla completa');

  const ReportTableRecordFilter(this.label);

  final String label;
}
