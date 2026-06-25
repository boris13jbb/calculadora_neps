import 'package:flutter/material.dart';

import '../../services/lote_trama_catalog_service.dart';
import '../../utils/lote_trama_helper.dart';
import '../theme/app_theme.dart';
import 'app_input_decoration.dart';

/// Campo de lote de trama: solo entrada del lote completo (ej. 63E264H10A).
class LoteTramaField extends StatefulWidget {
  const LoteTramaField({
    super.key,
    required this.fullController,
    this.presets = const [],
    this.onPresetSelected,
    this.onAddPreset,
    this.onRemovePreset,
    this.ultraCompact = false,
    this.compact = false,
  });

  final TextEditingController fullController;
  final List<String> presets;
  final ValueChanged<String>? onPresetSelected;
  final Future<void> Function(String value)? onAddPreset;
  final Future<void> Function(String value)? onRemovePreset;
  final bool ultraCompact;
  final bool compact;

  @override
  State<LoteTramaField> createState() => _LoteTramaFieldState();
}

class _LoteTramaFieldState extends State<LoteTramaField> {
  String? _selectedPreset;
  final TextEditingController _manualPresetController = TextEditingController();
  bool _catalogExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.fullController.addListener(_syncSelectedPreset);
    _syncSelectedPreset();
  }

  @override
  void didUpdateWidget(covariant LoteTramaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presets != widget.presets) {
      _syncSelectedPreset();
    }
  }

  @override
  void dispose() {
    widget.fullController.removeListener(_syncSelectedPreset);
    _manualPresetController.dispose();
    super.dispose();
  }

  void _syncSelectedPreset() {
    final current =
        LoteTramaHelper.normalizeFull(widget.fullController.text).trim();
    if (current.isEmpty) {
      if (_selectedPreset != null) {
        setState(() => _selectedPreset = null);
      }
      return;
    }

    if (widget.presets.contains(current) && _selectedPreset != current) {
      setState(() => _selectedPreset = current);
    } else if (!widget.presets.contains(current) && _selectedPreset != null) {
      setState(() => _selectedPreset = null);
    }
  }

  void _applyPreset(String? value) {
    if (value == null || value.isEmpty) {
      setState(() => _selectedPreset = null);
      return;
    }

    setState(() => _selectedPreset = value);
    widget.fullController.text = value;
    widget.onPresetSelected?.call(value);
    _syncSelectedPreset();
  }

  Future<void> _addManualPreset() async {
    final value = LoteTramaCatalogService.normalize(
      _manualPresetController.text,
    );
    if (value.isEmpty || widget.onAddPreset == null) return;

    await widget.onAddPreset!(value);
    if (!mounted) return;
    _manualPresetController.clear();
    setState(() => _catalogExpanded = true);
    _applyPreset(value);
  }

  InputDecoration _decoration(String hint) {
    return appInputDecoration(
      hint,
      compact: widget.compact,
      ultraCompact: widget.ultraCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelSize = widget.ultraCompact ? 11.0 : 12.0;
    final canManageCatalog =
        widget.onAddPreset != null && widget.onRemovePreset != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lote de trama',
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        if (widget.presets.isNotEmpty) ...[
          SizedBox(height: widget.ultraCompact ? 6 : 8),
          InputDecorator(
            decoration: _decoration('Seleccionar lote...'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPreset != null &&
                        widget.presets.contains(_selectedPreset)
                    ? _selectedPreset
                    : null,
                hint: const Text('Seleccionar lote...'),
                items: widget.presets
                    .map(
                      (preset) => DropdownMenuItem<String>(
                        value: preset,
                        child: Text(
                          preset,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _applyPreset,
              ),
            ),
          ),
        ],
        SizedBox(height: widget.ultraCompact ? 6 : 8),
        Text(
          'Lote completo',
          style: TextStyle(
            fontSize: widget.ultraCompact ? 10 : 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: widget.fullController,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            fontSize: widget.ultraCompact ? 14 : 17,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 0.6,
          ),
          decoration: _decoration('63E264H10A'),
          onChanged: (_) => _syncSelectedPreset(),
        ),
        if (canManageCatalog) ...[
          SizedBox(height: widget.ultraCompact ? 8 : 10),
          Material(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
            child: InkWell(
              onTap: () => setState(() => _catalogExpanded = !_catalogExpanded),
              borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.ultraCompact ? 10 : 12,
                  vertical: widget.ultraCompact ? 8 : 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      _catalogExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Gestionar lotes (${widget.presets.length})',
                        style: TextStyle(
                          fontSize: widget.ultraCompact ? 11 : 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_catalogExpanded) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualPresetController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                    decoration:
                        _decoration('Agregar lote manual, ej. 63E264H10A'),
                    onSubmitted: (_) => _addManualPreset(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addManualPreset,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.ultraCompact ? 10 : 14,
                      vertical: widget.ultraCompact ? 12 : 14,
                    ),
                  ),
                  child: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.presets.map((preset) {
                return InputChip(
                  label: Text(
                    preset,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: () => _applyPreset(preset),
                  onDeleted: () => widget.onRemovePreset?.call(preset),
                  deleteIconColor: AppColors.danger,
                  backgroundColor: preset == _selectedPreset
                      ? AppColors.accent.withValues(alpha: 0.35)
                      : AppColors.surface,
                  side: BorderSide(
                    color: preset == _selectedPreset
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }
}
