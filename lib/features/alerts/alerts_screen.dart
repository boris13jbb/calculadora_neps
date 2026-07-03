import 'package:flutter/material.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/alert_status_badge.dart';
import '../../core/widgets/app_material_list_tile.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/alert_level.dart';
import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/record_filter_helper.dart';
import 'package:provider/provider.dart';

/// Filtros locales de la pantalla de alertas.
class AlertScreenFilters {
  DateTime? dateFrom;
  DateTime? dateTo;
  String? telar;
  String? tela;
  String? loteTrama;
  AlertLevel? estado;

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      telar != null ||
      tela != null ||
      loteTrama != null ||
      estado != null;

  void clear() {
    dateFrom = null;
    dateTo = null;
    telar = null;
    tela = null;
    loteTrama = null;
    estado = null;
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _filters = AlertScreenFilters();

  List<NepRecord> _applyFilters(List<NepRecord> records) {
    var result = List<NepRecord>.from(records);

    if (_filters.telar != null) {
      result = result
          .where(
            (r) =>
                r.telar.toLowerCase() == _filters.telar!.toLowerCase(),
          )
          .toList();
    }
    if (_filters.tela != null) {
      result = result
          .where(
            (r) => r.tela.toLowerCase() == _filters.tela!.toLowerCase(),
          )
          .toList();
    }
    if (_filters.loteTrama != null) {
      result = result
          .where(
            (r) =>
                r.loteTrama.toLowerCase() ==
                _filters.loteTrama!.toLowerCase(),
          )
          .toList();
    }
    if (_filters.dateFrom != null) {
      final from = DateTime(
        _filters.dateFrom!.year,
        _filters.dateFrom!.month,
        _filters.dateFrom!.day,
      );
      result = result.where((r) {
        final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
        return !d.isBefore(from);
      }).toList();
    }
    if (_filters.dateTo != null) {
      final to = DateTime(
        _filters.dateTo!.year,
        _filters.dateTo!.month,
        _filters.dateTo!.day,
        23,
        59,
        59,
      );
      result = result.where((r) => !r.createdAt.isAfter(to)).toList();
    }
    if (_filters.estado != null) {
      result = result
          .where(
            (r) => alertService.getAlertLevel(r.neps) == _filters.estado,
          )
          .toList();
    }

    return result;
  }

  Future<void> _pickDate({
    required bool isFrom,
    required DateTime? current,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _filters.dateFrom = picked;
      } else {
        _filters.dateTo = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);
    final filtered = _applyFilters(appState.records);

    final critical = alertService.detectCriticalRecords(filtered);
    final warnings = alertService.detectWarningRecords(filtered);
    final topTelars = analyticsService.topTelaresPorNeps(filtered, limit: 10);
    final worstTelar = alertService.mostCriticalTelar(filtered);
    final worstTela = alertService.mostProblematicTela(filtered);
    final worstLote = alertService.mostProblematicLote(filtered);

    return AppPage(
      title: 'Alertas',
      subtitle: phone
          ? 'Control de calidad'
          : 'Detección de telares y lotes con neps elevados',
      fillViewport: true,
      maxContentWidth: 1400,
      compactPadding: true,
      denseOnPhone: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersBar(
            compact: phone,
            filters: _filters,
            records: appState.records,
            onTelarChanged: (v) => setState(() => _filters.telar = v),
            onTelaChanged: (v) => setState(() => _filters.tela = v),
            onLoteChanged: (v) => setState(() => _filters.loteTrama = v),
            onEstadoChanged: (v) => setState(() => _filters.estado = v),
            onDateFrom: () => _pickDate(isFrom: true, current: _filters.dateFrom),
            onDateTo: () => _pickDate(isFrom: false, current: _filters.dateTo),
            onClear: () => setState(_filters.clear),
          ),
          SizedBox(height: spacing),
          _SummaryCardsRow(
            compact: phone,
            criticalCount: critical.length,
            warningCount: warnings.length,
            worstTelar: worstTelar?.telar,
            worstTela: worstTela?.key,
            worstLote: worstLote?.key,
          ),
          SizedBox(height: spacing),
          Expanded(
            child: phone
                ? ListView(
                    children: [
                      _AlertSection(
                        title: 'Alertas críticas',
                        emptyMessage: 'No hay alertas críticas.',
                        records: critical,
                        appState: appState,
                        compact: true,
                      ),
                      SizedBox(height: spacing),
                      _AlertSection(
                        title: 'Advertencias',
                        emptyMessage: 'No hay advertencias activas.',
                        records: warnings,
                        appState: appState,
                        compact: true,
                      ),
                      SizedBox(height: spacing),
                      _TopTelarsSection(
                        summaries: topTelars,
                        appState: appState,
                        compact: true,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _AlertSection(
                                title: 'Alertas críticas',
                                emptyMessage: 'No hay alertas críticas.',
                                records: critical,
                                appState: appState,
                              ),
                              SizedBox(height: spacing),
                              _AlertSection(
                                title: 'Advertencias',
                                emptyMessage: 'No hay advertencias activas.',
                                records: warnings,
                                appState: appState,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        flex: 2,
                        child: _TopTelarsSection(
                          summaries: topTelars,
                          appState: appState,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.compact,
    required this.filters,
    required this.records,
    required this.onTelarChanged,
    required this.onTelaChanged,
    required this.onLoteChanged,
    required this.onEstadoChanged,
    required this.onDateFrom,
    required this.onDateTo,
    required this.onClear,
  });

  final bool compact;
  final AlertScreenFilters filters;
  final List<NepRecord> records;
  final ValueChanged<String?> onTelarChanged;
  final ValueChanged<String?> onTelaChanged;
  final ValueChanged<String?> onLoteChanged;
  final ValueChanged<AlertLevel?> onEstadoChanged;
  final VoidCallback onDateFrom;
  final VoidCallback onDateTo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final telares = RecordFilterHelper.uniqueTelares(records);
    final telas = RecordFilterHelper.uniqueTelas(records);
    final lotes = RecordFilterHelper.uniqueLotes(records);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterDropdown<String?>(
            label: 'Telar',
            value: filters.telar,
            items: [null, ...telares],
            itemLabel: (v) => v ?? 'Todos',
            onChanged: onTelarChanged,
            width: compact ? 120 : 140,
          ),
          _FilterDropdown<String?>(
            label: 'Tela',
            value: filters.tela,
            items: [null, ...telas],
            itemLabel: (v) => v ?? 'Todas',
            onChanged: onTelaChanged,
            width: compact ? 120 : 160,
          ),
          _FilterDropdown<String?>(
            label: 'Lote/trama',
            value: filters.loteTrama,
            items: [null, ...lotes],
            itemLabel: (v) => v ?? 'Todos',
            onChanged: onLoteChanged,
            width: compact ? 130 : 180,
          ),
          _FilterDropdown<AlertLevel?>(
            label: 'Estado',
            value: filters.estado,
            items: [null, ...AlertLevel.values],
            itemLabel: (v) => v?.label ?? 'Todos',
            onChanged: onEstadoChanged,
            width: compact ? 120 : 140,
          ),
          OutlinedButton.icon(
            onPressed: onDateFrom,
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              filters.dateFrom != null
                  ? 'Desde ${_fmt(filters.dateFrom!)}'
                  : 'Desde',
              style: TextStyle(fontSize: compact ? 11 : 13),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onDateTo,
            icon: const Icon(Icons.event, size: 16),
            label: Text(
              filters.dateTo != null
                  ? 'Hasta ${_fmt(filters.dateTo!)}'
                  : 'Hasta',
              style: TextStyle(fontSize: compact ? 11 : 13),
            ),
          ),
          if (filters.hasActiveFilters)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Limpiar'),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.width = 140,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({
    required this.compact,
    required this.criticalCount,
    required this.warningCount,
    this.worstTelar,
    this.worstTela,
    this.worstLote,
  });

  final bool compact;
  final int criticalCount;
  final int warningCount;
  final String? worstTelar;
  final String? worstTela;
  final String? worstLote;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: compact ? 2.4 : 2.2,
      children: [
        _SummaryTile(
          title: 'Críticas',
          value: '$criticalCount',
          color: AppColors.statusCritical,
          icon: Icons.error_outline,
        ),
        _SummaryTile(
          title: 'Advertencias',
          value: '$warningCount',
          color: AppColors.statusWarning,
          icon: Icons.warning_amber_outlined,
        ),
        _SummaryTile(
          title: 'Telar crítico',
          value: worstTelar ?? '—',
          color: AppColors.statusCritical,
          icon: Icons.precision_manufacturing_outlined,
          smallValue: worstTelar != null && worstTelar!.length > 8,
        ),
        _SummaryTile(
          title: 'Tela problemática',
          value: worstTela ?? '—',
          color: AppColors.statusWarning,
          icon: Icons.texture_outlined,
          smallValue: true,
        ),
        _SummaryTile(
          title: 'Lote/trama crítico',
          value: worstLote ?? '—',
          color: AppColors.statusWarning,
          icon: Icons.inventory_2_outlined,
          smallValue: true,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.smallValue = false,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: smallValue ? 12 : 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.title,
    required this.emptyMessage,
    required this.records,
    required this.appState,
    this.compact = false,
  });

  final String title;
  final String emptyMessage;
  final List<NepRecord> records;
  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 13 : 15,
                color: AppColors.textGreen,
              ),
            ),
          ),
          if (records.isEmpty)
            EmptyState(
              compact: compact,
              icon: emptyMessage.contains('críticas')
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              title: emptyMessage.contains('críticas')
                  ? 'Sin alertas críticas'
                  : 'Sin advertencias',
              message: emptyMessage,
              iconColor: emptyMessage.contains('críticas')
                  ? AppColors.statusNormal
                  : AppColors.statusWarning,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 12, endIndent: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                final evaluation = alertService.evaluateRecord(
                  record,
                  appState.records,
                );
                return _AlertListTile(
                  record: record,
                  evaluation: evaluation,
                  appState: appState,
                  compact: compact,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({
    required this.record,
    required this.evaluation,
    required this.appState,
    this.compact = false,
  });

  final NepRecord record;
  final AlertEvaluation evaluation;
  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final recText = evaluation.recommendations.isEmpty
        ? 'Sin recomendaciones adicionales.'
        : evaluation.recommendations.join(' ');

    return AppMaterialListTile(
      dense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 2 : 4,
      ),
      leading: AlertLevelDot(level: evaluation.level),
      title: Text(
        'Telar ${record.telar} · ${appState.formatDecimal(record.neps)} neps',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${appState.formatDateTime(record.createdAt)} · ${record.tela} · ${record.loteTrama}',
            style: TextStyle(fontSize: compact ? 10 : 12),
          ),
          const SizedBox(height: 4),
          Text(
            recText,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AlertStatusBadge(level: evaluation.level, compact: true),
          IconButton(
            tooltip: 'Ver en registros',
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => appState.navigateToRecordsFiltered(
              telar: record.telar,
              tela: record.tela,
              loteTrama: record.loteTrama,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTelarsSection extends StatelessWidget {
  const _TopTelarsSection({
    required this.summaries,
    required this.appState,
    this.compact = false,
  });

  final List<GroupNepsSummary> summaries;
  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              'Top 10 telares con más neps',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 13 : 15,
                color: AppColors.textGreen,
              ),
            ),
          ),
          if (summaries.isEmpty)
            EmptyState(
              compact: compact,
              icon: Icons.analytics_outlined,
              title: 'Sin datos de análisis',
              message: 'No hay registros para analizar.',
              actions: [
                EmptyStateAction(
                  label: 'Ir a Captura',
                  icon: Icons.add_circle_outline,
                  onPressed: () => appState.setNavigationIndex(1),
                ),
              ],
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final item = summaries[index];
                return AppMaterialListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.formulaBg,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    'Telar ${item.key}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${appState.formatDecimal(item.totalNeps)} neps · '
                    'Prom: ${appState.formatNumber(item.averageNeps)} · '
                    '${item.recordCount} reg.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: item.criticalCount > 0
                      ? const Icon(
                          Icons.error,
                          color: AppColors.statusCritical,
                          size: 18,
                        )
                      : null,
                  onTap: () => appState.navigateToRecordsFiltered(
                    telar: item.key,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
