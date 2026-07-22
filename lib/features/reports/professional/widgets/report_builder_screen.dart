import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/permissions/permission.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../providers/app_state.dart';
import '../../../../providers/auth_provider.dart';
import '../models/report_chart_configuration.dart';
import '../models/report_chart_type.dart';
import '../models/report_configuration.dart';
import '../models/report_metric_id.dart';
import '../models/report_period_preset.dart';
import '../models/report_section_type.dart';
import '../provider/report_builder_provider.dart';
import 'report_advanced_filters.dart';

/// Pantalla principal del Generador de reportes profesionales.
class ReportBuilderScreen extends StatefulWidget {
  const ReportBuilderScreen({super.key});

  @override
  State<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends State<ReportBuilderScreen> {
  late ReportBuilderProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ReportBuilderProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProvider());
  }

  void _initProvider() async {
    final appState = context.read<AppState>();
    final auth = context.read<AuthProvider>();
    final records = await appState.loadAnalyticsRecords();
    if (!mounted) return;
    _provider.initialize(
      records: records,
      user: auth.profile,
      resolveRecords: appState.loadRecordsForReportPeriod,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.exportReports,
      child: ChangeNotifierProvider.value(
        value: _provider,
        child: const _ReportBuilderBody(),
      ),
    );
  }
}

class _ReportBuilderBody extends StatelessWidget {
  const _ReportBuilderBody();

  static const _stepLabels = [
    'Periodo',
    'Filtros',
    'Contenido',
    'Vista previa',
    'Exportar',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportBuilderProvider>();
    final phone = isPhoneLayout(context);
    final stepIndex = provider.currentStep.index;

    return AppPage(
      title: 'Generador de reportes',
      subtitle: phone
          ? null
          : 'Configure y exporte informes ejecutivos y técnicos de calidad Neps',
      fillViewport: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(
            current: stepIndex,
            labels: _stepLabels,
            onTap: (i) => provider.setStep(ReportBuilderStep.values[i]),
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MaterialBanner(
                content: Text(provider.errorMessage!),
                leading: const Icon(Icons.error_outline,
                    color: AppColors.statusCritical),
                actions: [
                  TextButton(
                    onPressed: provider.clearError,
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: phone
                ? _buildMobileStep(context, provider)
                : _buildDesktopLayout(context, provider),
          ),
          _NavigationBar(provider: provider),
        ],
      ),
    );
  }

  Widget _buildMobileStep(
      BuildContext context, ReportBuilderProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _stepContent(context, provider),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    ReportBuilderProvider provider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _stepContent(context, provider),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 4,
          child: _PreviewPanel(provider: provider),
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context, ReportBuilderProvider provider) {
    return switch (provider.currentStep) {
      ReportBuilderStep.periodo => _PeriodStep(provider: provider),
      ReportBuilderStep.filtros => _FiltersStep(provider: provider),
      ReportBuilderStep.contenido => _ContentStep(provider: provider),
      ReportBuilderStep.vistaPrevia => _PreviewStep(provider: provider),
      ReportBuilderStep.exportar => _ExportStep(provider: provider),
    };
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.current,
    required this.labels,
    required this.onTap,
  });

  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color:
                      i <= current ? AppColors.primaryBlue : AppColors.border,
                ),
              ),
            InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: i == current
                      ? AppColors.primaryBlue
                      : i < current
                          ? AppColors.primaryBlue.withValues(alpha: 0.15)
                          : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        i == current ? FontWeight.bold : FontWeight.normal,
                    color: i == current ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    final isFirst = provider.currentStep == ReportBuilderStep.periodo;
    final isLast = provider.currentStep == ReportBuilderStep.exportar;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!isFirst)
            OutlinedButton.icon(
              onPressed: provider.previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Anterior'),
            ),
          const Spacer(),
          if (provider.resultCount > 0)
            Text(
              '${provider.resultCount} registros',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 12),
          if (!isLast)
            FilledButton.icon(
              onPressed: provider.nextStep,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente'),
            ),
        ],
      ),
    );
  }
}

// ─── Paso 1: Periodo ───────────────────────────────────────────────────────────

class _PeriodStep extends StatelessWidget {
  const _PeriodStep({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    final config = provider.configuration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Seleccionar periodo',
          icon: Icons.date_range_outlined,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReportPeriodPreset.values.map((preset) {
            final selected = config.periodPreset == preset;
            return ChoiceChip(
              label: Text(preset.label),
              selected: selected,
              onSelected: (_) {
                config.periodPreset = preset;
                provider.updateConfiguration(config);
              },
            );
          }).toList(),
        ),
        if (config.periodPreset == ReportPeriodPreset.rangoPersonalizado) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: config.customDateFrom ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      config.customDateFrom = date;
                      provider.updateConfiguration(config);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    config.customDateFrom != null
                        ? 'Desde: ${_fmt(config.customDateFrom!)}'
                        : 'Fecha inicial',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: config.customDateTo ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      config.customDateTo = date;
                      provider.updateConfiguration(config);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    config.customDateTo != null
                        ? 'Hasta: ${_fmt(config.customDateTo!)}'
                        : 'Fecha final',
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Comparar con periodo anterior'),
          value: config.enableComparison,
          onChanged: (v) {
            config.enableComparison = v;
            provider.updateConfiguration(config);
          },
        ),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─── Paso 2: Filtros ─────────────────────────────────────────────────────────

class _FiltersStep extends StatelessWidget {
  const _FiltersStep({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    final config = provider.configuration;
    final filters = config.filters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Aplicar filtros',
          icon: Icons.filter_list_outlined,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                filters.clear();
                provider.updateConfiguration(config);
                provider.refreshPreview();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpiar filtros'),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => provider.refreshPreview(),
              icon: const Icon(Icons.search),
              label: const Text('Aplicar y contar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReportAdvancedFiltersPanel(
          records: provider.sourceRecords,
          filters: filters,
          canViewOperatorAnalysis: provider.canViewOperatorAnalysis,
          canViewCreatorInfo: provider.canViewCreatorInfo,
          onChanged: () => provider.updateConfiguration(config),
        ),
        if (provider.resultCount == 0 && !provider.isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Sin resultados',
              message:
                  'Ajuste el periodo o los filtros para encontrar registros.',
            ),
          )
        else if (provider.resultCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${provider.resultCount} registros encontrados',
              style: TextStyle(
                color: AppColors.statusNormal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Paso 3: Contenido ───────────────────────────────────────────────────────

class _ContentStep extends StatelessWidget {
  const _ContentStep({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    final config = provider.configuration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Contenido del reporte',
          icon: Icons.checklist_outlined,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _presetButton('Ejecutiva', () {
              config.applyTemplate(ReportTemplateKind.ejecutivo);
              provider.updateConfiguration(config);
            }),
            _presetButton('Técnica', () {
              config.applyTemplate(ReportTemplateKind.tecnico);
              provider.updateConfiguration(config);
            }),
            _presetButton('Calidad', () {
              config.applyTemplate(ReportTemplateKind.calidad);
              provider.updateConfiguration(config);
            }),
            _presetButton('Seguimiento', () {
              config.applyTemplate(ReportTemplateKind.seguimiento);
              provider.updateConfiguration(config);
            }),
            _presetButton('Todo', () {
              config.selectAllSections();
              config.selectAllMetrics();
              provider.updateConfiguration(config);
            }),
            _presetButton('Ninguno', () {
              config.deselectAllSections();
              provider.updateConfiguration(config);
            }),
            _presetButton('Predeterminado', () {
              config.restoreDefaults();
              provider.updateConfiguration(config);
            }),
          ],
        ),
        const SizedBox(height: 16),
        Text('Secciones', style: Theme.of(context).textTheme.titleSmall),
        ...ReportSectionType.values.map((section) {
          if (section.requiresOperatorPermission &&
              !provider.canViewOperatorAnalysis) {
            return const SizedBox.shrink();
          }
          return CheckboxListTile(
            dense: true,
            title: Text(section.label),
            value: config.sections.contains(section),
            onChanged: (v) {
              if (v == true) {
                config.sections.add(section);
              } else {
                config.sections.remove(section);
              }
              provider.updateConfiguration(config);
            },
          );
        }),
        const Divider(),
        Text('Métricas del resumen',
            style: Theme.of(context).textTheme.titleSmall),
        ExpansionTile(
          title: Text('${config.metrics.length} métricas seleccionadas'),
          children: ReportMetricId.values
              .map(
                (m) => CheckboxListTile(
                  dense: true,
                  title: Text(m.label, style: const TextStyle(fontSize: 13)),
                  value: config.metrics.contains(m),
                  onChanged: (v) {
                    if (v == true) {
                      config.metrics.add(m);
                    } else {
                      config.metrics.remove(m);
                    }
                    provider.updateConfiguration(config);
                  },
                ),
              )
              .toList(),
        ),
        const Divider(),
        Text('Gráficas', style: Theme.of(context).textTheme.titleSmall),
        ...ReportChartType.values.map((type) {
          if (type.requiresOperatorPermission &&
              !provider.canViewOperatorAnalysis) {
            return const SizedBox.shrink();
          }
          final existing =
              config.charts.where((c) => c.type == type).firstOrNull;
          final enabled = existing?.enabled ?? false;
          return CheckboxListTile(
            dense: true,
            title: Text(type.label, style: const TextStyle(fontSize: 13)),
            value: enabled,
            onChanged: (v) {
              config.charts.removeWhere((c) => c.type == type);
              if (v == true) {
                config.charts.add(ReportChartConfiguration(type: type));
              }
              provider.updateConfiguration(config);
            },
          );
        }),
        const Divider(),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Título del reporte',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: config.cover.title)
            ..selection = TextSelection.collapsed(
              offset: config.cover.title.length,
            ),
          onChanged: (v) {
            config.cover = config.cover.copyWith(title: v);
            provider.updateConfiguration(config);
          },
        ),
      ],
    );
  }

  Widget _presetButton(String label, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}

// ─── Paso 4: Vista previa ────────────────────────────────────────────────────

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isProcessing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando reporte...'),
          ],
        ),
      );
    }

    return _PreviewPanel(provider: provider, expanded: true);
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.provider, this.expanded = false});

  final ReportBuilderProvider provider;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final data = provider.processedData;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceAlt.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Vista previa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: provider.refreshPreview,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (provider.isProcessing)
            const LinearProgressIndicator()
          else if (data == null)
            const Expanded(
              child: EmptyState(
                icon: Icons.description_outlined,
                title: 'Sin vista previa',
                message: 'Configure el reporte y pulse actualizar.',
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.configuration.cover.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Periodo: ${data.dateRangeLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (data.filterDescription.isNotEmpty)
                      Text(
                        'Filtros: ${data.filterDescription}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.statistics
                          .toMetricValues(data.configuration.metrics)
                          .take(expanded ? 20 : 6)
                          .map(
                            (m) => Chip(
                              label: Text('${m.label}: ${m.displayValue}'),
                            ),
                          )
                          .toList(),
                    ),
                    if (data.conclusion != null &&
                        data.conclusion!.enabled) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Conclusiones',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(data.conclusion!.displayText),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Secciones: ${data.configuration.orderedSections.map((s) => s.label).join(", ")}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Paso 5: Exportar ────────────────────────────────────────────────────────

class _ExportStep extends StatelessWidget {
  const _ExportStep({required this.provider});

  final ReportBuilderProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Exportar reporte',
          icon: Icons.ios_share_outlined,
        ),
        const SizedBox(height: 16),
        if (provider.isExporting || provider.isProcessing)
          const Center(child: CircularProgressIndicator())
        else ...[
          _ExportCard(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Compartir PDF',
            subtitle:
                'Informe con portada, secciones y gráficas capturadas como imagen',
            onTap: () => _sharePdf(context),
          ),
          const SizedBox(height: 8),
          _ExportCard(
            icon: Icons.table_chart_outlined,
            title: 'Compartir Excel',
            subtitle: 'Hojas organizadas por sección con metadatos',
            onTap: () => _shareExcel(context),
          ),
          if (provider.configuration.charts.any((c) => c.enabled)) ...[
            const SizedBox(height: 8),
            _ExportCard(
              icon: Icons.bar_chart_outlined,
              title: 'Compartir gráficas PNG',
              subtitle: 'Exporta cada gráfica habilitada como imagen',
              onTap: () => _shareCharts(context),
            ),
          ],
        ],
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (provider.statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(provider.statusMessage!),
          ),
        const SizedBox(height: 16),
        if (provider.canManageTemplates) ...[
          const Divider(),
          const Text('Plantillas guardadas'),
          ...provider.templates.take(5).map(
                (t) => ListTile(
                  title: Text(t.name),
                  subtitle: Text(t.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => provider.applyTemplate(t),
                ),
              ),
        ],
      ],
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final ok = await provider.sharePdf(context);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.statusMessage ?? 'PDF compartido.')),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  Future<void> _shareExcel(BuildContext context) async {
    final ok = await provider.shareExcel(context);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.statusMessage ?? 'Excel compartido.')),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  Future<void> _shareCharts(BuildContext context) async {
    final ok = await provider.shareAllChartsPng(context);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gráficas compartidas correctamente.')),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryBlue, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
