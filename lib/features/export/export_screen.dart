import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';

import '../../core/theme/app_theme.dart';

import '../../core/widgets/app_page.dart';

import '../../core/widgets/empty_state.dart';

import '../../core/widgets/export_column_selector.dart';
import '../../core/widgets/report_style_selector.dart';

import '../../core/widgets/formula_box.dart';

import '../../core/widgets/report_actions.dart';

import '../../core/permissions/permission.dart';
import '../../core/widgets/permission_gate.dart';
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

    return PermissionGate(
      permission: Permission.exportReports,
      child: AppPage(
        title: 'Exportar y compartir',
        subtitle: phone
            ? null
            : 'Generar archivos e informes de los registros visibles',
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
          if (appState.visibleRecords.isEmpty) ...[
            SizedBox(height: spacing),
            _NoDataCard(
              appState: appState,
              pad: pad,
              radius: radius,
            ),
          ],
          SizedBox(height: spacing),
          _ColumnSelectorCard(
            appState: appState,
            pad: pad,
            radius: radius,
            compact: false,
          ),
          SizedBox(height: spacing),
          _ReportStyleCard(
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
        if (appState.visibleRecords.isEmpty) ...[
          SizedBox(height: spacing),
          _NoDataCard(
            appState: appState,
            pad: pad,
            radius: radius,
            compact: true,
          ),
        ],
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
                _ReportStyleCard(
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
      padding: pad,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
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
              color: appState.visibleRecords.isEmpty
                  ? AppColors.statusWarning
                  : AppColors.textDark,
              fontWeight: appState.visibleRecords.isEmpty
                  ? FontWeight.w800
                  : FontWeight.normal,
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
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: ExportColumnSelector(
        compact: compact,
        selected: appState.exportColumns,
        onChanged: appState.setExportColumns,
      ),
    );
  }
}

class _ReportStyleCard extends StatelessWidget {
  const _ReportStyleCard({
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
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: ReportStyleSelector(
        compact: compact,
        selected: appState.pdfReportStyle,
        onChanged: appState.setPdfReportStyle,
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
    final hasData = appState.visibleRecords.isNotEmpty;
    final enabled = !appState.isExporting && hasData;

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
          onPressed: appState.isExporting || appState.visibleRecords.isEmpty
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

class _NoDataCard extends StatelessWidget {
  const _NoDataCard({
    required this.appState,
    required this.pad,
    required this.radius,
    this.compact = false,
  });

  final AppState appState;
  final EdgeInsets pad;
  final double radius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: EmptyState(
        compact: compact,
        icon: Icons.file_download_off_outlined,
        title: 'Nada que exportar',
        message: appState.records.isEmpty
            ? 'No hay registros en la tabla. Capture o importe datos primero.'
            : 'Los filtros activos no dejaron registros visibles.',
        actions: [
          if (appState.records.isEmpty)
            EmptyStateAction(
              label: 'Ir a Captura',
              icon: Icons.add_circle_outline,
              onPressed: () => appState.setNavigationIndex(1),
            )
          else
            EmptyStateAction(
              label: 'Ver Registros',
              icon: Icons.table_chart,
              onPressed: () => appState.setNavigationIndex(2),
            ),
        ],
      ),
    );
  }
}
