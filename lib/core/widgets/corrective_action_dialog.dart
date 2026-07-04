import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/corrective_action_entry.dart';
import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../widgets/alert_status_badge.dart';
import 'app_input_decoration.dart';

/// Acciones correctivas y seguimiento de supervisor para registros críticos.
Future<bool> showCorrectiveActionDialog({
  required BuildContext context,
  required AppState appState,
  required NepRecord record,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _CorrectiveActionDialog(
      appState: appState,
      record: record,
    ),
  );
  return result ?? false;
}

class _CorrectiveActionDialog extends StatefulWidget {
  const _CorrectiveActionDialog({
    required this.appState,
    required this.record,
  });

  final AppState appState;
  final NepRecord record;

  @override
  State<_CorrectiveActionDialog> createState() =>
      _CorrectiveActionDialogState();
}

class _CorrectiveActionDialogState extends State<_CorrectiveActionDialog> {
  late final TextEditingController responsableController;
  late final TextEditingController accionController;
  bool marcarRevisado = true;
  bool isSaving = false;

  static const _accionesSugeridas = [
    'Se revisó calibración.',
    'Se limpió mecanismo.',
    'Se cambió lote/trama.',
    'Se notificó a mantenimiento.',
    'Se pausó telar.',
  ];

  @override
  void initState() {
    super.initState();
    responsableController = TextEditingController(
      text: widget.record.responsableRevision.isNotEmpty
          ? widget.record.responsableRevision
          : widget.record.operario,
    );
    accionController = TextEditingController(
      text: widget.record.accionCorrectiva,
    );
    marcarRevisado = !widget.record.revisadoPorSupervisor;
  }

  @override
  void dispose() {
    responsableController.dispose();
    accionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final accion = accionController.text.trim();
    final responsable = responsableController.text.trim();

    if (accion.isEmpty) {
      widget.appState.showMessage('Ingrese la acción correctiva.');
      return;
    }
    if (responsable.isEmpty) {
      widget.appState.showMessage('Ingrese el responsable.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await widget.appState.applyCorrectiveAction(
        recordId: widget.record.id,
        accion: accion,
        responsable: responsable,
        marcarRevisado: marcarRevisado,
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final level = alertService.getAlertLevel(record.neps);
    final decoration = appInputDecoration('');

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Seguimiento y acción correctiva',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AlertStatusBadge(level: level, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Telar ${record.telar} · ${widget.appState.formatDecimal(record.neps)} neps',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${record.tela} · ${record.loteTrama}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (record.revisadoPorSupervisor) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.statusNormal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Revisado el ${widget.appState.formatDateTime(record.fechaRevision ?? record.createdAt)}'
                    '${record.responsableRevision.isNotEmpty ? ' por ${record.responsableRevision}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: responsableController,
                decoration: decoration.copyWith(labelText: 'Responsable'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accionController,
                maxLines: 3,
                decoration: decoration.copyWith(
                  labelText: 'Acción correctiva',
                  hintText: 'Describa la acción tomada',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _accionesSugeridas.map((sugerencia) {
                  return ActionChip(
                    label:
                        Text(sugerencia, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      accionController.text = sugerencia;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: marcarRevisado,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) => setState(() => marcarRevisado = v),
                  ),
                  const Expanded(
                    child: Text(
                      'Marcar como revisado por supervisor',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (record.historialAcciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Historial de acciones',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textGreen,
                  ),
                ),
                const SizedBox(height: 6),
                ...record.historialAcciones.reversed.map(_HistoryTile.new),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar seguimiento'),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.entry);

  final CorrectiveActionEntry entry;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final fecha =
        '${two(entry.fecha.day)}/${two(entry.fecha.month)}/${entry.fecha.year} '
        '${two(entry.fecha.hour)}:${two(entry.fecha.minute)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$fecha · ${entry.responsable}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(entry.accion, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
