import 'package:flutter/material.dart';

import '../../utils/lote_trama_helper.dart';
import '../theme/app_theme.dart';
import 'app_input_decoration.dart';
import 'app_material_list_tile.dart';

/// Selector de lote de trama: lista desplegable, lote completo y gestión de catálogo.
class LoteTramaField extends StatefulWidget {
  const LoteTramaField({
    super.key,
    required this.catalog,
    required this.fullController,
    required this.onAddToCatalog,
    required this.onRemoveFromCatalog,
    this.ultraCompact = false,
    this.compact = false,
  });

  final List<String> catalog;
  final TextEditingController fullController;
  final Future<void> Function(String lote) onAddToCatalog;
  final Future<void> Function(String lote) onRemoveFromCatalog;
  final bool ultraCompact;
  final bool compact;

  @override
  State<LoteTramaField> createState() => _LoteTramaFieldState();
}

class _LoteTramaFieldState extends State<LoteTramaField> {
  final TextEditingController _manualController = TextEditingController();
  bool _managerExpanded = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return appInputDecoration(
      hint,
      compact: widget.compact,
      ultraCompact: widget.ultraCompact,
    );
  }

  String? get _selectedFromCatalog {
    final current = LoteTramaHelper.normalizeFull(widget.fullController.text);
    if (current.isEmpty) return null;
    for (final lote in widget.catalog) {
      if (lote.toUpperCase() == current.toUpperCase()) return lote;
    }
    return null;
  }

  Future<void> _openLoteSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Text(
                  'Seleccionar lote',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: widget.catalog.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No hay lotes guardados. Agregue uno en Gestionar lotes.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: widget.catalog.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final lote = widget.catalog[index];
                            final isSelected = lote == _selectedFromCatalog;
                            return AppMaterialListTile(
                              dense: true,
                              selected: isSelected,
                              title: Text(
                                lote,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primaryGreen,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(sheetContext, lote),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      widget.fullController.text = selected;
      setState(() {});
    }
  }

  Future<void> _addManualLote() async {
    final value = LoteTramaHelper.normalizeFull(_manualController.text);
    if (value.isEmpty) return;

    await widget.onAddToCatalog(value);
    widget.fullController.text = value;
    _manualController.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: widget.ultraCompact ? 10 : 11,
      fontWeight: FontWeight.w800,
      color: AppColors.textGreen,
    );
    final selectedLabel = _selectedFromCatalog ?? 'Seleccionar lote...';
    final hasSelection = _selectedFromCatalog != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: widget.ultraCompact ? 2 : 4),
          child: Text('Lote de trama', style: labelStyle),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
          onTap: _openLoteSheet,
          child: InputDecorator(
            decoration: _decoration(''),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    overflow: TextOverflow.ellipsis,
                    style: appDropdownTextStyle(
                      ultraCompact: widget.ultraCompact,
                    ).copyWith(
                      color: hasSelection
                          ? AppColors.textDark
                          : AppColors.muted,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textDark),
              ],
            ),
          ),
        ),
        SizedBox(height: widget.ultraCompact ? 6 : 8),
        Padding(
          padding: EdgeInsets.only(bottom: widget.ultraCompact ? 2 : 4),
          child: Text('Lote completo', style: labelStyle),
        ),
        TextField(
          controller: widget.fullController,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            fontSize: widget.ultraCompact ? 13 : 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 0.4,
          ),
          decoration: _decoration('63E264H10A'),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: widget.ultraCompact ? 6 : 8),
        Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
              border: Border.all(color: AppColors.border),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(
                horizontal: widget.ultraCompact ? 8 : 12,
              ),
              childrenPadding: EdgeInsets.fromLTRB(
                widget.ultraCompact ? 8 : 12,
                0,
                widget.ultraCompact ? 8 : 12,
                widget.ultraCompact ? 8 : 12,
              ),
              initiallyExpanded: _managerExpanded,
              onExpansionChanged: (value) =>
                  setState(() => _managerExpanded = value),
              title: Text(
                'Gestionar lotes (${widget.catalog.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: widget.ultraCompact ? 12 : 13,
                  color: AppColors.textDark,
                ),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(fontSize: widget.ultraCompact ? 12 : 14),
                        decoration: _decoration('Agregar lote manual, ej. 63E264H10A'),
                        onSubmitted: (_) => _addManualLote(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: Size(widget.ultraCompact ? 40 : 44, widget.ultraCompact ? 40 : 44),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _addManualLote,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.catalog.isEmpty)
                  const Text(
                    'Sin lotes registrados.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final lote in widget.catalog)
                        InputChip(
                          label: Text(
                            lote,
                            style: TextStyle(
                              fontSize: widget.ultraCompact ? 11 : 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () async {
                            await widget.onRemoveFromCatalog(lote);
                            if (mounted) setState(() {});
                          },
                          onPressed: () {
                            widget.fullController.text = lote;
                            setState(() {});
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
