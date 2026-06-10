import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../utils/lote_trama_helper.dart';
import '../theme/app_theme.dart';
import 'app_input_decoration.dart';
import 'lote_trama_field.dart';

Future<bool> showEditRecordDialog({
  required BuildContext context,
  required AppState appState,
  required NepRecord record,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _EditRecordDialog(
      appState: appState,
      record: record,
    ),
  );
  return result ?? false;
}

class _EditRecordDialog extends StatefulWidget {
  const _EditRecordDialog({
    required this.appState,
    required this.record,
  });

  final AppState appState;
  final NepRecord record;

  @override
  State<_EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<_EditRecordDialog> {
  late final TextEditingController telarController;
  late final TextEditingController nepsController;
  late final TextEditingController lotePrefixController;
  late final TextEditingController loteSuffixController;
  late final TextEditingController loteFullController;
  late final TextEditingController manualTelaController;

  late bool useManualFabric;
  late bool loteFullEntryMode;
  String? selectedFabric;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final loteParts = LoteTramaHelper.split(
      record.loteTrama,
      fallbackPrefix: widget.appState.lotePrefixController.text,
    );

    telarController = TextEditingController(text: record.telar);
    nepsController = TextEditingController(
      text: widget.appState.formatDecimal(record.neps),
    );
    lotePrefixController = TextEditingController(text: loteParts.prefix);
    loteSuffixController = TextEditingController(text: loteParts.suffix);
    loteFullController = TextEditingController(text: loteParts.full);
    loteFullEntryMode = widget.appState.loteFullEntryMode;

    final inCatalog = widget.appState.fabrics.contains(record.tela);
    useManualFabric = record.tela.isEmpty || !inCatalog;
    selectedFabric = inCatalog ? record.tela : null;
    manualTelaController = TextEditingController(
      text: useManualFabric ? record.tela : '',
    );
  }

  @override
  void dispose() {
    telarController.dispose();
    nepsController.dispose();
    lotePrefixController.dispose();
    loteSuffixController.dispose();
    loteFullController.dispose();
    manualTelaController.dispose();
    super.dispose();
  }

  String? _resolveTela() {
    if (useManualFabric) {
      final manual = manualTelaController.text.trim();
      return manual.isEmpty ? null : manual;
    }
    return selectedFabric;
  }

  String? _resolveLoteTrama() {
    if (loteFullEntryMode) {
      final full = LoteTramaHelper.normalizeFull(loteFullController.text);
      if (!LoteTramaHelper.isValidFull(full)) return null;
      return full;
    }

    if (!LoteTramaHelper.isValidParts(
      prefix: lotePrefixController.text,
      suffix: loteSuffixController.text,
    )) {
      return null;
    }

    return LoteTramaHelper.buildFull(
      prefix: lotePrefixController.text,
      suffix: loteSuffixController.text,
    );
  }

  Future<void> _save() async {
    final tela = _resolveTela();
    if (tela == null) {
      widget.appState.showMessage('Seleccione o ingrese la tela.');
      return;
    }

    final loteTrama = _resolveLoteTrama();
    if (loteTrama == null) {
      widget.appState.showMessage(
        'Complete el lote de trama (base y sufijo, o lote completo).',
      );
      return;
    }

    final telar = telarController.text.trim();
    if (telar.isEmpty) {
      widget.appState.showMessage('Ingrese el numero de telar.');
      return;
    }

    final nepsText = nepsController.text.trim();
    if (nepsText.isEmpty || widget.appState.parseNumber(nepsText) <= 0) {
      widget.appState.showMessage('Ingrese una cantidad valida de neps.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await widget.appState.updateRecord(
        id: widget.record.id,
        telar: telar,
        neps: widget.appState.parseNumber(nepsText),
        tela: tela,
        loteTrama: loteTrama,
        createdAt: widget.record.createdAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fabrics = widget.appState.fabrics;
    final decoration = appInputDecoration('');

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Editar registro',
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fecha: ${widget.appState.formatDateTime(widget.record.createdAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telarController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoration.copyWith(labelText: 'Telar'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nepsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoration.copyWith(labelText: 'Neps'),
              ),
              const SizedBox(height: 10),
              if (fabrics.isNotEmpty && !useManualFabric)
                DropdownButtonFormField<String>(
                  key: ValueKey('fabric-$selectedFabric-${fabrics.length}'),
                  initialValue: selectedFabric,
                  isExpanded: true,
                  decoration: decoration.copyWith(labelText: 'Tela / Tejido'),
                  items: [
                    ...fabrics.map(
                      (fabric) => DropdownMenuItem(
                        value: fabric,
                        child: Text(fabric, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: manualFabricOption,
                      child: Text('Manual'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == manualFabricOption) {
                      setState(() {
                        useManualFabric = true;
                        manualTelaController.clear();
                      });
                      return;
                    }
                    setState(() {
                      useManualFabric = false;
                      selectedFabric = value;
                    });
                  },
                )
              else ...[
                TextField(
                  controller: manualTelaController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: decoration.copyWith(
                    labelText: 'Tela / Tejido',
                    suffixIcon: fabrics.isNotEmpty
                        ? IconButton(
                            tooltip: 'Elegir del catalogo',
                            icon: const Icon(Icons.arrow_drop_down),
                            onPressed: () {
                              setState(() {
                                useManualFabric = false;
                                selectedFabric = fabrics.contains(
                                  manualTelaController.text.trim(),
                                )
                                    ? manualTelaController.text.trim()
                                    : fabrics.first;
                              });
                            },
                          )
                        : null,
                  ),
                ),
                if (fabrics.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          useManualFabric = false;
                          selectedFabric = fabrics.first;
                        });
                      },
                      icon: const Icon(Icons.list_alt_outlined, size: 18),
                      label: const Text('Elegir del catalogo'),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              LoteTramaField(
                prefixController: lotePrefixController,
                suffixController: loteSuffixController,
                fullController: loteFullController,
                fullEntryMode: loteFullEntryMode,
                onFullEntryModeChanged: (value) {
                  setState(() => loteFullEntryMode = value);
                },
                compact: true,
              ),
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
