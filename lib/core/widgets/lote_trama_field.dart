import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/lote_trama_helper.dart';
import '../theme/app_theme.dart';
import 'app_input_decoration.dart';

class LoteTramaField extends StatefulWidget {
  const LoteTramaField({
    super.key,
    required this.prefixController,
    required this.suffixController,
    required this.fullController,
    required this.fullEntryMode,
    required this.onFullEntryModeChanged,
    this.ultraCompact = false,
    this.compact = false,
    this.onPrefixPersist,
  });

  final TextEditingController prefixController;
  final TextEditingController suffixController;
  final TextEditingController fullController;
  final bool fullEntryMode;
  final ValueChanged<bool> onFullEntryModeChanged;
  final bool ultraCompact;
  final bool compact;
  final VoidCallback? onPrefixPersist;

  @override
  State<LoteTramaField> createState() => _LoteTramaFieldState();
}

class _LoteTramaFieldState extends State<LoteTramaField> {
  String _preview = '';

  @override
  void initState() {
    super.initState();
    widget.prefixController.addListener(_syncFromControllers);
    widget.suffixController.addListener(_syncFromControllers);
    widget.fullController.addListener(_syncFromFull);
    _refreshPreview();
  }

  @override
  void didUpdateWidget(covariant LoteTramaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullEntryMode != widget.fullEntryMode) {
      _refreshPreview();
    }
  }

  @override
  void dispose() {
    widget.prefixController.removeListener(_syncFromControllers);
    widget.suffixController.removeListener(_syncFromControllers);
    widget.fullController.removeListener(_syncFromFull);
    super.dispose();
  }

  void _refreshPreview() {
    final next = widget.fullEntryMode
        ? LoteTramaHelper.normalizeFull(widget.fullController.text)
        : LoteTramaHelper.buildFull(
            prefix: widget.prefixController.text,
            suffix: widget.suffixController.text,
          );
    if (_preview != next) {
      setState(() => _preview = next);
    }
  }

  void _syncFromControllers() {
    if (widget.fullEntryMode) return;
    _refreshPreview();
  }

  void _syncFromFull() {
    if (!widget.fullEntryMode) return;

    final parts = LoteTramaHelper.split(
      widget.fullController.text,
      fallbackPrefix: widget.prefixController.text,
    );

    if (widget.prefixController.text != parts.prefix) {
      widget.prefixController.text = parts.prefix;
      widget.onPrefixPersist?.call();
    }
    if (widget.suffixController.text != parts.suffix) {
      widget.suffixController.text = parts.suffix;
    }
    _refreshPreview();
  }

  void _onPrefixEdited(String value) {
    widget.onPrefixPersist?.call();

    if (widget.fullEntryMode) {
      final parts = LoteTramaHelper.split(
        widget.fullController.text,
        fallbackPrefix: widget.prefixController.text,
      );
      widget.fullController.text = LoteTramaHelper.buildFull(
        prefix: value,
        suffix: parts.suffix,
      );
      return;
    }

    _refreshPreview();
  }

  void _setEntryMode(bool fullMode) {
    if (widget.fullEntryMode == fullMode) return;

    if (fullMode) {
      widget.fullController.text = LoteTramaHelper.buildFull(
        prefix: widget.prefixController.text,
        suffix: widget.suffixController.text,
      );
    } else {
      final parts = LoteTramaHelper.split(
        widget.fullController.text,
        fallbackPrefix: widget.prefixController.text,
      );
      widget.prefixController.text = parts.prefix;
      widget.suffixController.text = parts.suffix;
    }

    widget.onFullEntryModeChanged(fullMode);
    _refreshPreview();
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
    final previewSize = widget.ultraCompact ? 16.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lote de trama',
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            _EntryModeToggle(
              fullEntryMode: widget.fullEntryMode,
              ultraCompact: widget.ultraCompact,
              onChanged: _setEntryMode,
            ),
          ],
        ),
        SizedBox(height: widget.ultraCompact ? 4 : 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.ultraCompact ? 78 : 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base',
                    style: TextStyle(
                      fontSize: widget.ultraCompact ? 10 : 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: widget.prefixController,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.ultraCompact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(
                        LoteTramaHelper.defaultPrefixLength,
                      ),
                    ],
                    decoration: _decoration('63E264').copyWith(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.ultraCompact ? 6 : 8,
                        vertical: widget.ultraCompact ? 8 : 10,
                      ),
                    ),
                    onChanged: _onPrefixEdited,
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.ultraCompact ? 6 : 8),
            Expanded(
              child: widget.fullEntryMode
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          onChanged: (_) => _syncFromFull(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sufijo',
                          style: TextStyle(
                            fontSize: widget.ultraCompact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.suffixController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(
                            fontSize: widget.ultraCompact ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 0.4,
                          ),
                          decoration: _decoration('H10A'),
                          onChanged: (_) => _syncFromControllers(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        SizedBox(height: widget.ultraCompact ? 6 : 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: widget.ultraCompact ? 10 : 14,
            vertical: widget.ultraCompact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.formulaBg,
            borderRadius: BorderRadius.circular(widget.ultraCompact ? 8 : 10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lote completo',
                style: TextStyle(
                  fontSize: widget.ultraCompact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _preview.isEmpty ? '—' : _preview,
                style: TextStyle(
                  fontSize: previewSize,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryModeToggle extends StatelessWidget {
  const _EntryModeToggle({
    required this.fullEntryMode,
    required this.ultraCompact,
    required this.onChanged,
  });

  final bool fullEntryMode;
  final bool ultraCompact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: ultraCompact ? 10 : 11,
      fontWeight: FontWeight.w800,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeChip(
            label: 'Sufijo',
            selected: !fullEntryMode,
            style: style,
            onTap: () => onChanged(false),
          ),
          _ModeChip(
            label: 'Completo',
            selected: fullEntryMode,
            style: style,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: style.copyWith(
              color: selected ? AppColors.header : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
