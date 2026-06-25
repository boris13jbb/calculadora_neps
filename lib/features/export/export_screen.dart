import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';

import '../../core/theme/app_styles.dart';

import '../../core/theme/app_theme.dart';

import '../../core/widgets/app_page.dart';

import '../../core/widgets/export_column_selector.dart';

import '../../core/widgets/formula_box.dart';

import '../../core/widgets/report_actions.dart';

import '../../providers/app_state.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final phone = isPhoneLayout(context);

    final spacing = screenSpacing(context);

    final pad = sectionPadding(context);

    final radius = sectionRadius(context);

    return AppPage(
      title: 'Exportar y compartir',
      subtitle: phone
          ? 'Generar archivos e informes'
          : 'Selecciona los datos y el formato para generar o compartir tu informe.',
      breadcrumb: const ['Inicio', 'Exportar y compartir'],
      fillViewport: phone,
      compactPadding: true,
      denseOnPhone: true,
      child: phone
          ? _MobileExportBody(
              appState: appState,
              spacing: spacing,
              pad: pad,
              radius: radius,
            )
          : _DesktopExportBody(
              appState: appState,
              spacing: spacing,
              pad: pad,
              radius: radius,
            ),
    );
  }
}

class _DesktopExportBody extends StatelessWidget {
  const _DesktopExportBody({
    required this.appState,
    required this.spacing,
    required this.pad,
    required this.radius,
  });

  final AppState appState;

  final double spacing;

  final EdgeInsets pad;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExportStatus(appState: appState),
          _DataInfoCard(appState: appState, pad: pad, radius: radius),
          SizedBox(height: spacing),
          _ColumnSelectorCard(
            appState: appState,
            pad: pad,
            radius: radius,
            compact: false,
          ),
          SizedBox(height: spacing),
          const Text(
            'Exportar tabla actual',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          SizedBox(height: spacing - 2),
          _ExportButtons(appState: appState, phone: false),
          SizedBox(height: spacing + 4),
          _SaveReportSection(appState: appState, phone: false),
          SizedBox(height: spacing),
          const FormulaBox(),
        ],
      ),
    );
  }
}

class _MobileExportBody extends StatelessWidget {
  const _MobileExportBody({
    required this.appState,
    required this.spacing,
    required this.pad,
    required this.radius,
  });

  final AppState appState;

  final double spacing;

  final EdgeInsets pad;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExportStatus(appState: appState),
        _DataInfoCard(appState: appState, pad: pad, radius: radius),
        SizedBox(height: spacing),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ColumnSelectorCard(
                  appState: appState,
                  pad: pad,
                  radius: radius,
                  compact: true,
                ),
                SizedBox(height: spacing),
                const Text(
                  'Exportar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                SizedBox(height: spacing - 2),
                _ExportButtons(appState: appState, phone: true),
                SizedBox(height: spacing),
                _SaveReportSection(
                  appState: appState,
                  phone: true,
                ),
                SizedBox(height: spacing),
                const FormulaBox(compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportStatus extends StatelessWidget {
  const _ExportStatus({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    if (!appState.isExporting) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.formulaBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Generando archivo...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DataInfoCard extends StatelessWidget {
  const _DataInfoCard({
    required this.appState,
    required this.pad,
    required this.radius,
  });

  final AppState appState;

  final EdgeInsets pad;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);

    return Container(
      decoration: AppDecorations.card(color: AppColors.formulaBg),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.accent),
            Expanded(
              child: Padding(
                padding: pad,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.accentDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datos a exportar',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: phone ? 13 : 15,
                            ),
                          ),
                          SizedBox(height: phone ? 4 : 8),
                          Text(
                            'Visibles: ${appState.visibleRecords.length} / ${appState.records.length}',
                            style: TextStyle(
                              fontSize: phone ? 12 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (appState.filters.hasActiveFilters)
                            Text(
                              'Filtros activos de Registros aplicados.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: phone ? 11 : 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnSelectorCard extends StatelessWidget {
  const _ColumnSelectorCard({
    required this.appState,
    required this.pad,
    required this.radius,
    required this.compact,
  });

  final AppState appState;

  final EdgeInsets pad;

  final double radius;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: pad,
      decoration: AppDecorations.card(),
      child: ExportColumnSelector(
        compact: compact,
        selected: appState.exportColumns,
        onChanged: appState.setExportColumns,
      ),
    );
  }
}

class _ExportButtons extends StatelessWidget {
  const _ExportButtons({required this.appState, required this.phone});

  final AppState appState;

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final enabled = !appState.isExporting;

    if (phone) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.35,
        children: [
          _ExportTile(
            label: 'CSV',
            icon: Icons.table_chart,
            color: AppColors.primaryGreen,
            enabled: enabled,
            onPressed: appState.exportCsv,
          ),
          _ExportTile(
            label: 'Excel',
            icon: Icons.grid_on,
            color: AppColors.primaryGreen,
            enabled: enabled,
            onPressed: appState.exportExcel,
          ),
          _ExportTile(
            label: 'PDF',
            icon: Icons.picture_as_pdf,
            color: AppColors.accent,
            foreground: AppColors.textDark,
            enabled: enabled,
            onPressed: appState.exportPdf,
          ),
          _ExportTile(
            label: 'Imprimir',
            icon: Icons.print,
            color: const Color(0xFFE2D5B6),
            foreground: const Color(0xFF3B2F1C),
            enabled: enabled,
            onPressed: appState.printPdf,
          ),
          _ExportTile(
            label: 'Copiar',
            icon: Icons.copy,
            color: const Color(0xFFE2D5B6),
            foreground: const Color(0xFF3B2F1C),
            enabled: enabled,
            onPressed: appState.copyTable,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ExportButton(
          label: 'CSV',
          icon: Icons.table_chart,
          color: AppColors.primaryGreen,
          enabled: enabled,
          onPressed: appState.exportCsv,
        ),
        _ExportButton(
          label: 'Excel',
          icon: Icons.grid_on,
          color: AppColors.primaryGreen,
          enabled: enabled,
          onPressed: appState.exportExcel,
        ),
        _ExportButton(
          label: 'PDF',
          icon: Icons.picture_as_pdf,
          color: AppColors.accent,
          foreground: AppColors.textDark,
          enabled: enabled,
          onPressed: appState.exportPdf,
        ),
        _ExportButton(
          label: 'Imprimir',
          icon: Icons.print,
          color: const Color(0xFFE2D5B6),
          foreground: const Color(0xFF3B2F1C),
          enabled: enabled,
          onPressed: appState.printPdf,
        ),
        _ExportButton(
          label: 'Copiar tabla',
          icon: Icons.copy,
          color: const Color(0xFFE2D5B6),
          foreground: const Color(0xFF3B2F1C),
          enabled: enabled,
          onPressed: appState.copyTable,
        ),
      ],
    );
  }
}

class _SaveReportSection extends StatelessWidget {
  const _SaveReportSection({
    required this.appState,
    required this.phone,
  });

  final AppState appState;

  final bool phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Guardar informe',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: phone ? 13 : 15,
          ),
        ),
        SizedBox(height: phone ? 6 : 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            padding: EdgeInsets.symmetric(vertical: phone ? 12 : 16),
          ),
          onPressed: appState.isExporting
              ? null
              : () => promptSaveReport(context, appState),
          icon: const Icon(Icons.save),
          label: Text(phone ? 'Guardar informe' : 'Guardar informe actual'),
        ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.enabled,
    this.foreground = Colors.white,
  });

  final String label;

  final IconData icon;

  final Color color;

  final Color foreground;

  final VoidCallback onPressed;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.enabled,
    this.foreground = Colors.white,
  });

  final String label;

  final IconData icon;

  final Color color;

  final Color foreground;

  final VoidCallback onPressed;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.all(6),
      ),
      onPressed: enabled ? onPressed : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
