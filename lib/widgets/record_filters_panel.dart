import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/layout/responsive_layout.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_input_decoration.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../utils/record_filter_helper.dart';
import 'alert_filter_fields.dart';

class _FilterPalette {
  static const activeBg = Color(0xFFE8F5E9);
  static const activeFg = Color(0xFF1B5E20);
  static const activeIcon = Color(0xFF43A047);
  static const inactiveFg = Color(0xFF37474F);
  static const panelBg = Color(0xFFFFFDF4);
  static const border = Color(0xFFD6C394);
}

class RecordFiltersPanel extends StatefulWidget {
  const RecordFiltersPanel({
    super.key,
    required this.records,
    required this.filters,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
  });

  final List<NepRecord> records;
  final RecordFilters filters;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final bool compact;

  @override
  State<RecordFiltersPanel> createState() => _RecordFiltersPanelState();
}

class _RecordFiltersPanelState extends State<RecordFiltersPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController searchController;
  late final TextEditingController nepsMinController;
  late final TextEditingController nepsMaxController;
  late final TextEditingController mtsMinController;
  late final TextEditingController mtsMaxController;

  bool _expanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.filters.searchText);
    nepsMinController = TextEditingController(
      text: widget.filters.nepsMin?.toString() ?? '',
    );
    nepsMaxController = TextEditingController(
      text: widget.filters.nepsMax?.toString() ?? '',
    );
    mtsMinController = TextEditingController(
      text: widget.filters.mtsMin?.toString() ?? '',
    );
    mtsMaxController = TextEditingController(
      text: widget.filters.mtsMax?.toString() ?? '',
    );
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    nepsMinController.dispose();
    nepsMaxController.dispose();
    mtsMinController.dispose();
    mtsMaxController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  bool _denseFields(BuildContext context) =>
      widget.compact && isPhoneLayout(context);

  InputDecoration _fieldDecoration(
    String hint, {
    String? label,
    required BuildContext context,
  }) {
    final dense = _denseFields(context);
    final base = appInputDecoration(
      hint,
      compact: widget.compact && !dense,
      ultraCompact: dense,
    );
    if (label == null || !dense) return base;
    return base.copyWith(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF2C3E2F),
      ),
    );
  }

  TextStyle? get _fieldTextStyle =>
      widget.compact ? const TextStyle(fontSize: 13) : null;

  @override
  Widget build(BuildContext context) {
    final telas = RecordFilterHelper.uniqueTelas(widget.records);
    final lotes = RecordFilterHelper.uniqueLotes(widget.records);
    final telares = RecordFilterHelper.uniqueTelares(widget.records);
    final filters = widget.filters;
    final activeCount = filters.activeFilterCount;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _FilterPalette.panelBg,
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 18),
        border: Border.all(color: _FilterPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(
              _denseFields(context) ? 8 : (widget.compact ? 10 : 12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: filters.hasActiveFilters
                          ? _FilterPalette.activeBg
                          : AppColors.formulaBg,
                      foregroundColor: filters.hasActiveFilters
                          ? _FilterPalette.activeFg
                          : AppColors.textDark,
                      padding: EdgeInsets.symmetric(
                        vertical: _denseFields(context)
                            ? 8
                            : (widget.compact ? 10 : 12),
                        horizontal: _denseFields(context) ? 10 : 14,
                      ),
                      textStyle: TextStyle(
                        fontSize: _denseFields(context) ? 13 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _toggleExpanded,
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: filters.hasActiveFilters
                          ? _FilterPalette.activeIcon
                          : _FilterPalette.inactiveFg,
                      size: 20,
                    ),
                    label: Text(
                      _expanded
                          ? 'Ocultar filtros'
                          : filters.hasActiveFilters
                              ? 'Filtrar ($activeCount activo${activeCount == 1 ? '' : 's'})'
                              : 'Filtrar',
                    ),
                  ),
                ),
                if (filters.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Limpiar filtros',
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.filter_alt_off, size: 20),
                    color: _FilterPalette.inactiveFg,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                IconButton(
                  tooltip: _expanded ? 'Ocultar' : 'Desplegar',
                  onPressed: _toggleExpanded,
                  icon: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  color: _FilterPalette.inactiveFg,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (!_expanded && filters.hasActiveFilters)
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 12 : 16,
                0,
                widget.compact ? 12 : 16,
                widget.compact ? 10 : 12,
              ),
              child: _ActiveFilterChips(filters: filters),
            ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: Color(0xFFE8DFC8)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.compact ? 12 : 16,
                      _denseFields(context) ? 8 : 12,
                      widget.compact ? 12 : 16,
                      _denseFields(context) ? 8 : (widget.compact ? 12 : 16),
                    ),
                    child: _buildFilterFields(
                      context: context,
                      filters: filters,
                      telas: telas,
                      lotes: lotes,
                      telares: telares,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _fieldGap => widget.compact ? 6.0 : 10.0;

  Widget _filterPairRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: _fieldGap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _buildFilterFields({
    required BuildContext context,
    required RecordFilters filters,
    required List<String> telas,
    required List<String> lotes,
    required List<String> telares,
  }) {
    final dense = _denseFields(context);

    if (dense) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filterDropdown(
            context: context,
            label: 'Tela',
            value: filters.tela,
            options: telas,
            onChanged: (value) {
              filters.tela = value;
              widget.onChanged();
            },
          ),
          SizedBox(height: _fieldGap),
          _filterPairRow([
            _filterDropdown(
              context: context,
              label: 'Lote de trama',
              value: filters.loteTrama,
              options: lotes,
              onChanged: (value) {
                filters.loteTrama = value;
                widget.onChanged();
              },
            ),
            _filterDropdown(
              context: context,
              label: 'Telar',
              value: filters.telar,
              options: telares,
              onChanged: (value) {
                filters.telar = value;
                widget.onChanged();
              },
            ),
          ]),
          SizedBox(height: _fieldGap),
          _filterPairRow([
            _numberField(
              context: context,
              label: 'Neps min',
              controller: nepsMinController,
              onChanged: (value) {
                filters.nepsMin = value;
                widget.onChanged();
              },
            ),
            _numberField(
              context: context,
              label: 'Neps max',
              controller: nepsMaxController,
              onChanged: (value) {
                filters.nepsMax = value;
                widget.onChanged();
              },
            ),
          ]),
          SizedBox(height: _fieldGap),
          _filterPairRow([
            _numberField(
              context: context,
              label: 'Mts min',
              controller: mtsMinController,
              onChanged: (value) {
                filters.mtsMin = value;
                widget.onChanged();
              },
            ),
            _numberField(
              context: context,
              label: 'Mts max',
              controller: mtsMaxController,
              onChanged: (value) {
                filters.mtsMax = value;
                widget.onChanged();
              },
            ),
          ]),
          SizedBox(height: _fieldGap),
          _filterPairRow([
            _dateField(
              context: context,
              label: 'Fecha desde',
              value: filters.dateFrom,
              onChanged: (value) {
                filters.dateFrom = value;
                widget.onChanged();
              },
            ),
            _dateField(
              context: context,
              label: 'Fecha hasta',
              value: filters.dateTo,
              onChanged: (value) {
                filters.dateTo = value;
                widget.onChanged();
              },
            ),
          ]),
          SizedBox(height: _fieldGap),
          _searchField(context: context, filters: filters),
          ExtendedRecordFilterFields(
            records: widget.records,
            filters: filters,
            onChanged: widget.onChanged,
            compact: true,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 180,
          child: _filterDropdown(
            context: context,
            label: 'Tela',
            value: filters.tela,
            options: telas,
            onChanged: (value) {
              filters.tela = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: _filterDropdown(
            context: context,
            label: 'Lote de trama',
            value: filters.loteTrama,
            options: lotes,
            onChanged: (value) {
              filters.loteTrama = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 140,
          child: _filterDropdown(
            context: context,
            label: 'Telar',
            value: filters.telar,
            options: telares,
            onChanged: (value) {
              filters.telar = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 120,
          child: _numberField(
            context: context,
            label: 'Neps min',
            controller: nepsMinController,
            onChanged: (value) {
              filters.nepsMin = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 120,
          child: _numberField(
            context: context,
            label: 'Neps max',
            controller: nepsMaxController,
            onChanged: (value) {
              filters.nepsMax = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 120,
          child: _numberField(
            context: context,
            label: 'Mts min',
            controller: mtsMinController,
            onChanged: (value) {
              filters.mtsMin = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 120,
          child: _numberField(
            context: context,
            label: 'Mts max',
            controller: mtsMaxController,
            onChanged: (value) {
              filters.mtsMax = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: _dateField(
            context: context,
            label: 'Fecha desde',
            value: filters.dateFrom,
            onChanged: (value) {
              filters.dateFrom = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: _dateField(
            context: context,
            label: 'Fecha hasta',
            value: filters.dateTo,
            onChanged: (value) {
              filters.dateTo = value;
              widget.onChanged();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: _searchField(context: context, filters: filters),
        ),
        SizedBox(
          width: double.infinity,
          child: ExtendedRecordFilterFields(
            records: widget.records,
            filters: filters,
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }

  Widget _searchField({
    required BuildContext context,
    required RecordFilters filters,
  }) {
    final dense = _denseFields(context);
    if (dense) {
      return TextField(
        controller: searchController,
        style: _fieldTextStyle,
        decoration: _fieldDecoration(
          'Tela, lote, telar...',
          label: 'Busqueda general',
          context: context,
        ),
        onChanged: (value) {
          filters.searchText = value;
          widget.onChanged();
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Busqueda general',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E2F),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: searchController,
          decoration: _fieldDecoration(
            'Tela, lote, telar...',
            context: context,
          ),
          onChanged: (value) {
            filters.searchText = value;
            widget.onChanged();
          },
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF2C3E2F),
        fontSize: 12,
      ),
    );
  }

  Widget _filterDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final dense = _denseFields(context);
    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${options.length}'),
      initialValue: value,
      isExpanded: true,
      isDense: dense,
      iconEnabledColor: AppColors.textDark,
      dropdownColor: Colors.white,
      menuMaxHeight: MediaQuery.sizeOf(context).height * 0.4,
      style: appDropdownTextStyle(compact: widget.compact, ultraCompact: dense),
      iconSize: dense ? 20 : 24,
      decoration: _fieldDecoration(
        'Todos',
        label: dense ? label : null,
        context: context,
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: appDropdownItemText('Todos', compact: dense),
        ),
        ...options.map(
          (option) => DropdownMenuItem(
            value: option,
            child: appDropdownItemText(option, compact: dense),
          ),
        ),
      ],
      onChanged: onChanged,
    );

    if (dense) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        dropdown,
      ],
    );
  }

  Widget _numberField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required ValueChanged<double?> onChanged,
  }) {
    final dense = _denseFields(context);
    final field = TextField(
      controller: controller,
      style: _fieldTextStyle,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: _fieldDecoration(
        '',
        label: dense ? label : null,
        context: context,
      ),
      onChanged: (text) {
        final normalized = text.replaceAll(',', '.').trim();
        onChanged(normalized.isEmpty ? null : double.tryParse(normalized));
      },
    );

    if (dense) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _dateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    final text = value == null
        ? ''
        : '${two(value.day)}/${two(value.month)}/${value.year}';
    final dense = _denseFields(context);

    final picker = InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _fieldDecoration(
          'Seleccionar',
          label: dense ? label : null,
          context: context,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.isEmpty ? 'Todos' : text,
                style: _fieldTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              IconButton(
                icon: Icon(Icons.close, size: dense ? 16 : 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );

    if (dense) return picker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        picker,
      ],
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.filters});

  final RecordFilters filters;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filters.tela != null) {
      chips.add(_chip('Tela: ${filters.tela}'));
    }
    if (filters.loteTrama != null) {
      chips.add(_chip('Lote: ${filters.loteTrama}'));
    }
    if (filters.telar != null) {
      chips.add(_chip('Telar: ${filters.telar}'));
    }
    if (filters.nepsMin != null || filters.nepsMax != null) {
      chips.add(_chip('Neps: ${_range(filters.nepsMin, filters.nepsMax)}'));
    }
    if (filters.mtsMin != null || filters.mtsMax != null) {
      chips.add(_chip('Mts: ${_range(filters.mtsMin, filters.mtsMax)}'));
    }
    if (filters.dateFrom != null || filters.dateTo != null) {
      chips.add(_chip('Fechas: ${_dateRange()}'));
    }
    if (filters.searchText.trim().isNotEmpty) {
      chips.add(_chip('Busqueda: ${filters.searchText.trim()}'));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  String _range(double? min, double? max) {
    if (min != null && max != null) return '$min - $max';
    if (min != null) return '>= $min';
    return '<= $max';
  }

  String _dateRange() {
    String fmt(DateTime? d) {
      if (d == null) return '...';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    }

    return '${fmt(filters.dateFrom)} - ${fmt(filters.dateTo)}';
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _FilterPalette.activeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _FilterPalette.activeFg,
        ),
      ),
    );
  }
}
