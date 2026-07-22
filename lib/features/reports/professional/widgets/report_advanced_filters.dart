import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/section_header.dart';
import '../../../../models/alert_level.dart';
import '../../../../models/nep_record.dart';
import '../../../../utils/record_filter_helper.dart';
import '../models/report_filter_configuration.dart';

/// Panel completo de filtros avanzados para el generador de reportes.
class ReportAdvancedFiltersPanel extends StatelessWidget {
  const ReportAdvancedFiltersPanel({
    super.key,
    required this.records,
    required this.filters,
    required this.onChanged,
    this.canViewOperatorAnalysis = true,
    this.canViewCreatorInfo = false,
  });

  final List<NepRecord> records;
  final ReportFilterConfiguration filters;
  final VoidCallback onChanged;
  final bool canViewOperatorAnalysis;
  final bool canViewCreatorInfo;

  @override
  Widget build(BuildContext context) {
    final telares = RecordFilterHelper.uniqueTelares(records);
    final telas = RecordFilterHelper.uniqueTelas(records);
    final lotes = RecordFilterHelper.uniqueLotes(records);
    final turnos = RecordFilterHelper.uniqueTurnos(records);
    final operarios = RecordFilterHelper.uniqueOperarios(records);
    final lineas = RecordFilterHelper.uniqueLineas(records);
    final responsables =
        _uniqueStrings(records.map((r) => r.responsableRevision));
    final creadores = _uniqueStrings(
      records.map((r) => r.createdByEmail ?? r.createdByUid ?? ''),
    );
    final rolesCreador = _uniqueStrings(
      records.map((r) => r.createdByRole ?? ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Filtros de producción',
          icon: Icons.factory_outlined,
        ),
        const SizedBox(height: 8),
        ReportMultiSelectFilter(
          label: 'Telares',
          options: telares,
          selected: filters.telares,
          onChanged: (s) {
            filters.telares = s;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        ReportMultiSelectFilter(
          label: 'Telas',
          options: telas,
          selected: filters.telas,
          onChanged: (s) {
            filters.telas = s;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        ReportMultiSelectFilter(
          label: 'Lotes de trama',
          options: lotes,
          selected: filters.lotes,
          onChanged: (s) {
            filters.lotes = s;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        ReportMultiSelectFilter(
          label: 'Turnos',
          options: turnos,
          selected: filters.turnos,
          onChanged: (s) {
            filters.turnos = s;
            onChanged();
          },
        ),
        if (canViewOperatorAnalysis) ...[
          const SizedBox(height: 8),
          ReportMultiSelectFilter(
            label: 'Operarios',
            options: operarios,
            selected: filters.operarios,
            onChanged: (s) {
              filters.operarios = s;
              onChanged();
            },
          ),
        ],
        const SizedBox(height: 8),
        ReportMultiSelectFilter(
          label: 'Líneas de producción',
          options: lineas,
          selected: filters.lineas,
          onChanged: (s) {
            filters.lineas = s;
            onChanged();
          },
        ),
        const Divider(height: 28),
        const AppSectionHeader(
          title: 'Filtros de calidad y seguimiento',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 8),
        _AlertLevelSelector(
          value: filters.alertLevel,
          onChanged: (v) {
            filters.alertLevel = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _TriStateChips(
          label: 'Revisado por supervisor',
          value: filters.revisadoSupervisor,
          trueLabel: 'Solo revisados',
          falseLabel: 'Pendientes de revisión',
          onChanged: (v) {
            filters.revisadoSupervisor = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        _TriStateChips(
          label: 'Acción correctiva',
          value: filters.conAccionCorrectiva,
          trueLabel: 'Con acción',
          falseLabel: 'Sin acción',
          onChanged: (v) {
            filters.conAccionCorrectiva = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        _TriStateChips(
          label: 'Observaciones',
          value: filters.conObservaciones,
          trueLabel: 'Con observación',
          falseLabel: 'Sin observación',
          onChanged: (v) {
            filters.conObservaciones = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _OptionalDropdown(
          label: 'Responsable de revisión',
          value: filters.responsableRevision,
          options: responsables,
          onChanged: (v) {
            filters.responsableRevision = v;
            onChanged();
          },
        ),
        if (canViewCreatorInfo) ...[
          const SizedBox(height: 8),
          _OptionalDropdown(
            label: 'Usuario creador',
            value: filters.usuarioCreador,
            options: creadores,
            onChanged: (v) {
              filters.usuarioCreador = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _OptionalDropdown(
            label: 'Rol del creador',
            value: filters.rolCreador,
            options: rolesCreador,
            onChanged: (v) {
              filters.rolCreador = v;
              onChanged();
            },
          ),
        ],
        const Divider(height: 28),
        const AppSectionHeader(
          title: 'Rangos numéricos',
          icon: Icons.tune_outlined,
        ),
        const SizedBox(height: 8),
        _RangeRow(
          labelMin: 'Neps mínimo',
          labelMax: 'Neps máximo',
          minValue: filters.nepsMin,
          maxValue: filters.nepsMax,
          onMinChanged: (v) {
            filters.nepsMin = v;
            onChanged();
          },
          onMaxChanged: (v) {
            filters.nepsMax = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        _RangeRow(
          labelMin: 'Mts mínimo',
          labelMax: 'Mts máximo',
          minValue: filters.mtsMin,
          maxValue: filters.mtsMax,
          onMinChanged: (v) {
            filters.mtsMin = v;
            onChanged();
          },
          onMaxChanged: (v) {
            filters.mtsMax = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Búsqueda de texto',
            hintText: 'Telar, tela, lote, observación...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: filters.searchText)
            ..selection = TextSelection.collapsed(
              offset: filters.searchText.length,
            ),
          onChanged: (v) {
            filters.searchText = v;
            onChanged();
          },
        ),
      ],
    );
  }

  static List<String> _uniqueStrings(Iterable<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}

/// Selector multi-opción con búsqueda interna.
class ReportMultiSelectFilter extends StatefulWidget {
  const ReportMultiSelectFilter({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<ReportMultiSelectFilter> createState() =>
      _ReportMultiSelectFilterState();
}

class _ReportMultiSelectFilterState extends State<ReportMultiSelectFilter> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return ListTile(
        dense: true,
        title: Text(widget.label),
        subtitle: const Text('Sin opciones en los registros'),
      );
    }

    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${widget.label} (${widget.selected.length}/${widget.options.length})',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar...',
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () =>
                  widget.onChanged(Set<String>.from(widget.options)),
              child: const Text('Seleccionar todos'),
            ),
            TextButton(
              onPressed: () => widget.onChanged({}),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final opt = filtered[i];
              return CheckboxListTile(
                dense: true,
                title: Text(opt, style: const TextStyle(fontSize: 13)),
                value: widget.selected.contains(opt),
                onChanged: (v) {
                  final next = Set<String>.from(widget.selected);
                  if (v == true) {
                    next.add(opt);
                  } else {
                    next.remove(opt);
                  }
                  widget.onChanged(next);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlertLevelSelector extends StatelessWidget {
  const _AlertLevelSelector({
    required this.value,
    required this.onChanged,
  });

  final AlertLevel? value;
  final ValueChanged<AlertLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AlertLevel?>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Estado de alerta',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Todos')),
        DropdownMenuItem(
          value: AlertLevel.normal,
          child: Text('Normal'),
        ),
        DropdownMenuItem(
          value: AlertLevel.advertencia,
          child: Text('Advertencia'),
        ),
        DropdownMenuItem(
          value: AlertLevel.critico,
          child: Text('Crítico'),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _TriStateChips extends StatelessWidget {
  const _TriStateChips({
    required this.label,
    required this.value,
    required this.trueLabel,
    required this.falseLabel,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final String trueLabel;
  final String falseLabel;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            ChoiceChip(
              label: Text(trueLabel),
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              label: Text(falseLabel),
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionalDropdown extends StatelessWidget {
  const _OptionalDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      value: value != null && options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ...options.map(
          (o) => DropdownMenuItem(value: o, child: Text(o)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.labelMin,
    required this.labelMax,
    required this.minValue,
    required this.maxValue,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  final String labelMin;
  final String labelMax;
  final double? minValue;
  final double? maxValue;
  final ValueChanged<double?> onMinChanged;
  final ValueChanged<double?> onMaxChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: minValue?.toString() ?? '',
            decoration: InputDecoration(
              labelText: labelMin,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (v) {
              onMinChanged(v.trim().isEmpty ? null : double.tryParse(v));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            initialValue: maxValue?.toString() ?? '',
            decoration: InputDecoration(
              labelText: labelMax,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (v) {
              onMaxChanged(v.trim().isEmpty ? null : double.tryParse(v));
            },
          ),
        ),
      ],
    );
  }
}
