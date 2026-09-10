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
    this.comfortable = false,
    this.sideBySide = false,
  });

  final List<String> catalog;
  final TextEditingController fullController;
  final Future<void> Function(String lote) onAddToCatalog;
  final Future<void> Function(String lote) onRemoveFromCatalog;
  final bool ultraCompact;
  final bool compact;

  /// Campos grandes para la pantalla de captura (prioridad UX).
  final bool comfortable;

  /// Lote de trama y Lote completo en dos columnas cuando hay espacio.
  final bool sideBySide;

  @override
  State<LoteTramaField> createState() => _LoteTramaFieldState();
}

class _LoteTramaFieldState extends State<LoteTramaField> {
  final TextEditingController _manualController = TextEditingController();
  bool _managerExpanded = false;

  AppInputSize get _size {
    if (widget.comfortable) return AppInputSize.comfortable;
    if (widget.ultraCompact) return AppInputSize.ultraCompact;
    if (widget.compact) return AppInputSize.compact;
    return AppInputSize.standard;
  }

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
      size: widget.comfortable ? AppInputSize.comfortable : null,
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
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.65;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
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
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: widget.catalog.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No hay lotes guardados. Agregue uno en Gestionar lotes.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              selected: isSelected,
                              title: Text(
                                lote,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primaryGreen,
                                      size: 24,
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

  Widget _buildTramaSelector() {
    final selectedLabel = _selectedFromCatalog ?? 'Seleccionar lote...';
    final hasSelection = _selectedFromCatalog != null;
    final minH = appInputMinHeight(_size);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptureFieldLabel(
          'Lote de trama',
          prominent: widget.comfortable,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openLoteSheet,
            child: InputDecorator(
              decoration: _decoration(''),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedLabel,
                      overflow: TextOverflow.ellipsis,
                      style: appDropdownTextStyle(size: _size).copyWith(
                        fontSize: widget.comfortable ? 18 : null,
                        color:
                            hasSelection ? AppColors.textDark : AppColors.muted,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textDark,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullField() {
    final minH = appInputMinHeight(_size);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptureFieldLabel(
          'Lote completo',
          prominent: widget.comfortable,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: TextField(
            controller: widget.fullController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize:
                  widget.comfortable ? 18 : (widget.ultraCompact ? 13 : 15),
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.4,
              color: AppColors.textDark,
            ),
            decoration: _decoration('Ej: 63E264H10A'),
            // AppState ya notifica al cambiar loteFullController; no setState aquí.
          ),
        ),
      ],
    );
  }

  void _toggleManager() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _managerExpanded = !_managerExpanded);
  }

  Widget _buildManager() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggleManager,
            icon: Icon(
              _managerExpanded ? Icons.expand_less : Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text(
              'Gestionar lotes (${widget.catalog.length})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize:
                    widget.comfortable ? 14 : (widget.ultraCompact ? 12 : 13),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        if (_managerExpanded)
          Padding(
            padding: EdgeInsets.only(top: widget.comfortable ? 4 : 0),
            child: _managerContent(),
          ),
      ],
    );
  }

  Widget _managerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _manualController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  fontSize:
                      widget.comfortable ? 15 : (widget.ultraCompact ? 12 : 14),
                ),
                decoration: _decoration('Agregar lote manual, ej. 63E264H10A'),
                onSubmitted: (_) => _addManualLote(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              onPressed: _addManualLote,
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.catalog.isEmpty)
          const Text(
            'Sin lotes registrados.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lote in widget.catalog)
                InputChip(
                  label: Text(
                    lote,
                    style: TextStyle(
                      fontSize: widget.comfortable ? 13 : 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 18),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.comfortable ? 16.0 : (widget.ultraCompact ? 6.0 : 8.0);

    // El selector de trama refleja el texto de lote completo.
    final trama = ListenableBuilder(
      listenable: widget.fullController,
      builder: (context, _) => _buildTramaSelector(),
    );

    final fields = widget.sideBySide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: trama),
              SizedBox(width: gap),
              Expanded(child: _buildFullField()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              trama,
              SizedBox(height: gap),
              _buildFullField(),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        fields,
        SizedBox(height: widget.comfortable ? 8 : gap),
        _buildManager(),
      ],
    );
  }
}
