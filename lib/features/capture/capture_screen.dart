import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_material_list_tile.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/capture_optional_fields.dart';
import '../../core/widgets/capture_session_actions.dart';
import '../../core/widgets/compact_records_panel.dart';
import '../../core/widgets/edit_record_sheet.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/lote_trama_field.dart';
import '../../core/widgets/report_actions.dart';
import '../../models/nep_record.dart';
import '../../core/permissions/permission.dart';
import '../../core/widgets/permission_gate.dart';
import '../../providers/app_state.dart';
import '../../utils/numeric_input_formatters.dart';

Future<void> _editCaptureRecord(
  BuildContext context,
  AppState appState,
  NepRecord record,
) {
  return showEditRecordDialog(
    context: context,
    appState: appState,
    record: record,
  );
}

Future<void> submitCaptureWithChecks(
  BuildContext context,
  AppState appState,
) async {
  final record = appState.buildCaptureRecord();
  if (record == null) return;

  if (record.neps > 100) {
    if (!context.mounted) return;
    if (!await confirmHighNepsValue(
      context,
      neps: record.neps,
      telar: record.telar,
    )) {
      return;
    }
  }

  if (appState.isRecentDuplicate(record)) {
    if (!context.mounted) return;
    if (!await confirmDuplicateRecord(context)) return;
  }

  await appState.submitCaptureRecord(record);
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final useWideCapture = !isPhoneLayout(context);

    if (!useWideCapture && _tabController == null) {
      _tabController = TabController(length: 2, vsync: this);
    } else if (useWideCapture && _tabController != null) {
      // Diferir dispose: si se hace en didChangeDependencies, TabBar/TabBarView
      // aún pueden depender del controller → assert `_dependents.isEmpty`.
      final old = _tabController;
      _tabController = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.dispose();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _tabController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final useWideCapture = !isPhoneLayout(context);
    final showHeaderActions = isDesktopLayout(context);

    return PermissionGate(
      permission: Permission.captureRecords,
      child: AppPage(
        title: 'Captura de registros',
        subtitle: useWideCapture
            ? 'Su tabla personal. Guarde informes para compartir con el equipo.'
            : 'Su tabla personal',
        fillViewport: true,
        compactPadding: false,
        denseOnPhone: false,
        actions:
            showHeaderActions ? _buildHeaderActions(context, appState) : null,
        child: useWideCapture
            ? _DesktopCaptureLayout(appState: appState)
            : _tabController == null
                ? const Center(child: CircularProgressIndicator())
                : _MobileCaptureLayout(
                    appState: appState,
                    tabController: _tabController!,
                  ),
      ),
    );
  }

  List<Widget> _buildHeaderActions(BuildContext context, AppState appState) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.wide;

    Widget actionButton({
      required VoidCallback? onPressed,
      required IconData icon,
      required String label,
      required Color background,
      Color? foreground,
      bool outlined = false,
    }) {
      if (compact) {
        return IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: outlined ? Colors.transparent : background,
            foregroundColor: foreground ?? Colors.white,
            minimumSize: const Size(48, 48),
            side: outlined
                ? const BorderSide(color: AppColors.danger)
                : BorderSide.none,
          ),
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        );
      }

      if (outlined) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            minimumSize: const Size(48, 48),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
      }

      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: const Size(48, 48),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return [
      actionButton(
        onPressed: captureSaveEnabled(appState)
            ? () => promptSaveCaptureSessionReport(context, appState)
            : null,
        icon: Icons.save,
        label: 'Guardar',
        background: AppColors.primaryBlue,
      ),
      actionButton(
        onPressed: captureActionsEnabled(appState)
            ? () => showShareReportMenu(context, appState)
            : null,
        icon: Icons.ios_share,
        label: 'Compartir',
        background: AppColors.primaryGreen,
      ),
      actionButton(
        onPressed: () => promptNewCaptureSession(context, appState),
        icon: Icons.note_add_outlined,
        label: 'Nueva sesión',
        background: AppColors.accent,
        foreground: AppColors.textDark,
      ),
      actionButton(
        onPressed: () => promptOpenPersonalSessionHistory(context, appState),
        icon: Icons.history,
        label: 'Historial',
        background: AppColors.surfaceAlt,
        foreground: AppColors.textDark,
      ),
      if (compact)
        actionButton(
          onPressed: () => appState.setNavigationIndex(4),
          icon: Icons.texture,
          label: 'Telas',
          background: AppColors.surfaceAlt,
          foreground: AppColors.textDark,
        )
      else
        TextButton.icon(
          onPressed: () => appState.setNavigationIndex(4),
          icon: const Icon(Icons.texture, size: 18),
          label: const Text('Telas'),
        ),
      if (compact)
        actionButton(
          onPressed: () => appState.setNavigationIndex(2),
          icon: Icons.tune,
          label: 'Filtros',
          background: AppColors.surfaceAlt,
          foreground: AppColors.textDark,
        )
      else
        TextButton.icon(
          onPressed: () => appState.setNavigationIndex(2),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Filtros'),
        ),
    ];
  }
}

class _DesktopCaptureLayout extends StatelessWidget {
  const _DesktopCaptureLayout({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formPanel = _CaptureFormPanel(
          appState: appState,
          includeSessionFields: true,
          showAddButton: true,
          showSessionActions: true,
        );
        final recordsPanel = CompactRecordsPanel(
          appState: appState,
          records: appState.captureSessionRecords,
          onDelete: appState.deleteRecord,
          onEdit: (record) => _editCaptureRecord(context, appState, record),
          onShare: (record) => showShareReportMenu(
            context,
            appState,
            initiallySelectedRecord: record,
          ),
          onClearAll: () => promptNewCaptureSession(context, appState),
        );

        // Formulario amplio (~45–50%), nunca columna fija de 300 px.
        final useSplit = constraints.maxWidth >= 720;
        final formFlex = constraints.maxWidth >= AppBreakpoints.wide ? 48 : 50;
        final recordsFlex = 100 - formFlex;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionKpis(appState: appState),
            const SizedBox(height: 20),
            Expanded(
              child: useSplit
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: formFlex,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(right: 4),
                            child: formPanel,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: recordsFlex,
                          child: recordsPanel,
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          formPanel,
                          const SizedBox(height: 20),
                          SizedBox(
                            height: (constraints.maxHeight * 0.45)
                                .clamp(280.0, 480.0),
                            child: recordsPanel,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MobileCaptureLayout extends StatelessWidget {
  const _MobileCaptureLayout({
    required this.appState,
    required this.tabController,
  });

  final AppState appState;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final recordCount = appState.captureSessionRecords.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.soft,
            ),
            child: TabBar(
              controller: tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              labelColor: AppColors.textDark,
              unselectedLabelColor: AppColors.muted,
              tabs: [
                const Tab(
                  height: 48,
                  icon: Icon(Icons.edit_note, size: 20),
                  text: 'Capturar',
                ),
                Tab(
                  height: 48,
                  icon: const Icon(Icons.list_alt, size: 20),
                  text: 'Lista ($recordCount)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _MobileCaptureTab(appState: appState),
              CompactRecordsPanel(
                appState: appState,
                records: appState.captureSessionRecords,
                onDelete: appState.deleteRecord,
                onEdit: (record) =>
                    _editCaptureRecord(context, appState, record),
                onShare: (record) => showShareReportMenu(
                  context,
                  appState,
                  initiallySelectedRecord: record,
                ),
                onClearAll: () => promptNewCaptureSession(context, appState),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileCaptureTab extends StatelessWidget {
  const _MobileCaptureTab({required this.appState});

  final AppState appState;

  Future<void> _addRecord(BuildContext context) async {
    await submitCaptureWithChecks(context, appState);
  }

  @override
  Widget build(BuildContext context) {
    // El Scaffold del shell ya redimensiona con el teclado; no sumar viewInsets.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: _CaptureFormPanel(
                    appState: appState,
                    includeSessionFields: true,
                    showAddButton: false,
                    showSessionActions: false,
                    forceStacked: true,
                  ),
                ),
              );
            },
          ),
        ),
        _MobileCaptureActionBar(
          appState: appState,
          onAdd: () => _addRecord(context),
        ),
      ],
    );
  }
}

class _MobileCaptureActionBar extends StatelessWidget {
  const _MobileCaptureActionBar({
    required this.appState,
    required this.onAdd,
  });

  final AppState appState;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: AppColors.textDark.withValues(alpha: 0.12),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textDark,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 22),
              label: const Text(
                'Agregar registro',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: PopupMenuButton<_MobileMoreAction>(
                tooltip: 'Más acciones',
                onSelected: (action) => _handleMoreAction(context, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MobileMoreAction.save,
                    enabled: captureActionsEnabled(appState),
                    child: const _MoreActionRow(
                      icon: Icons.save,
                      iconColor: AppColors.primaryBlue,
                      label: 'Guardar',
                    ),
                  ),
                  PopupMenuItem(
                    value: _MobileMoreAction.share,
                    enabled: captureActionsEnabled(appState),
                    child: const _MoreActionRow(
                      icon: Icons.ios_share,
                      iconColor: AppColors.primaryGreen,
                      label: 'Compartir',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MobileMoreAction.newSession,
                    child: _MoreActionRow(
                      icon: Icons.note_add_outlined,
                      label: 'Nueva sesión',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MobileMoreAction.clear,
                    child: _MoreActionRow(
                      icon: Icons.refresh,
                      label: 'Limpiar campos',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _MobileMoreAction.fabrics,
                    child: _MoreActionRow(
                      icon: Icons.texture,
                      label: 'Telas',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MobileMoreAction.filters,
                    child: _MoreActionRow(
                      icon: Icons.tune,
                      label: 'Filtros',
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz, color: AppColors.muted),
                      SizedBox(width: 6),
                      Text(
                        'Más acciones',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMoreAction(BuildContext context, _MobileMoreAction action) {
    switch (action) {
      case _MobileMoreAction.save:
        promptSaveCaptureSessionReport(context, appState);
      case _MobileMoreAction.share:
        showShareReportMenu(context, appState);
      case _MobileMoreAction.newSession:
        promptNewCaptureSession(context, appState);
      case _MobileMoreAction.clear:
        appState.clearCaptureFields();
      case _MobileMoreAction.fabrics:
        appState.setNavigationIndex(4);
      case _MobileMoreAction.filters:
        appState.setNavigationIndex(2);
    }
  }
}

enum _MobileMoreAction { save, share, newSession, clear, fabrics, filters }

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.textDark, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// KPIs de la sesión de captura.
class _SessionKpis extends StatelessWidget {
  const _SessionKpis({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final records = appState.captureSessionRecords;
    final totalNeps = records.fold<double>(0, (sum, item) => sum + item.neps);
    final totalMts = records.fold<double>(
      0,
      (sum, item) => sum + appState.calculateMts(item.neps),
    );
    final looms = records.map((r) => r.telar).toSet().length;

    return KpiStrip(
      minCardWidth: 168,
      spacing: 12,
      compact: false,
      cards: [
        KpiCard(
          label: 'Registros',
          value: '${records.length}',
          icon: Icons.table_rows_outlined,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          label: 'Neps totales',
          value: appState.formatDecimal(totalNeps),
          icon: Icons.blur_on,
          color: AppColors.accentDark,
        ),
        KpiCard(
          label: 'Mts calculados',
          value: appState.formatNumber(totalMts),
          icon: Icons.straighten_outlined,
          color: AppColors.statusNormal,
        ),
        KpiCard(
          label: 'Telares',
          value: '$looms',
          icon: Icons.precision_manufacturing_outlined,
          color: AppColors.primaryGreen,
        ),
      ],
    );
  }
}

class _FabricField extends StatelessWidget {
  const _FabricField({required this.appState});

  final AppState appState;

  InputDecoration _decoration() => appInputDecoration(
        'Seleccione o escriba la tela',
        size: AppInputSize.comfortable,
      );

  void _selectFabric(String? value) {
    if (value == manualFabricOption) {
      appState.setManualFabricMode(true);
      appState.manualTelaController.clear();
      return;
    }
    appState.setManualFabricMode(false);
    appState.setSelectedFabric(value);
  }

  Future<void> _openFabricSheet(BuildContext context) async {
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
                  'Seleccionar tela',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: appState.fabrics.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == appState.fabrics.length) {
                        return AppMaterialListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          title: const Text(
                            'Manual',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.textDark,
                            size: 22,
                          ),
                          onTap: () =>
                              Navigator.pop(sheetContext, manualFabricOption),
                        );
                      }

                      final fabric = appState.fabrics[index];
                      final isSelected = fabric == appState.selectedFabric;
                      return AppMaterialListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        selected: isSelected,
                        title: Text(
                          fabric,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
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
                        onTap: () => Navigator.pop(sheetContext, fabric),
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

    if (selected != null) _selectFabric(selected);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = _decoration();
    final useSheet = isPhoneLayout(context);
    final minH = appInputMinHeight(AppInputSize.comfortable);

    if (appState.fabrics.isEmpty || appState.useManualFabric) {
      final canPickFromCatalog = appState.fabrics.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CaptureFieldLabel('Tela / Tejido'),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: TextField(
              controller: appState.manualTelaController,
              textCapitalization: TextCapitalization.characters,
              style: appDropdownTextStyle(size: AppInputSize.comfortable),
              decoration: decoration.copyWith(
                hintText: 'Nombre de tela',
                suffixIcon: canPickFromCatalog
                    ? IconButton(
                        tooltip: 'Seleccionar del catálogo',
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textDark,
                          size: 28,
                        ),
                        onPressed: () => _openFabricSheet(context),
                      )
                    : null,
              ),
            ),
          ),
          if (canPickFromCatalog)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openFabricSheet(context),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('Elegir del catálogo'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
        ],
      );
    }

    if (useSheet) {
      final selectedLabel = appState.selectedFabric ?? 'Seleccione tela...';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CaptureFieldLabel('Tela / Tejido'),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openFabricSheet(context),
              child: InputDecorator(
                decoration: decoration,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel,
                        overflow: TextOverflow.ellipsis,
                        style: appDropdownTextStyle(
                          size: AppInputSize.comfortable,
                        ).copyWith(
                          color: appState.selectedFabric != null
                              ? AppColors.textDark
                              : AppColors.muted,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CaptureFieldLabel('Tela / Tejido'),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              'fabric-${appState.selectedFabric}-${appState.fabrics.length}',
            ),
            initialValue: appState.selectedFabric,
            isExpanded: true,
            isDense: false,
            iconEnabledColor: AppColors.textDark,
            dropdownColor: Colors.white,
            menuMaxHeight: MediaQuery.sizeOf(context).height * 0.45,
            style: appDropdownTextStyle(size: AppInputSize.comfortable),
            decoration: decoration,
            items: [
              ...appState.fabrics.map(
                (fabric) => DropdownMenuItem(
                  value: fabric,
                  child: appDropdownItemText(fabric),
                ),
              ),
              DropdownMenuItem(
                value: manualFabricOption,
                child: appDropdownItemText('Manual'),
              ),
            ],
            onChanged: _selectFabric,
          ),
        ),
      ],
    );
  }
}

class _LoteField extends StatelessWidget {
  const _LoteField({
    required this.appState,
    this.sideBySide = false,
  });

  final AppState appState;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    return LoteTramaField(
      catalog: appState.loteCatalog,
      fullController: appState.loteFullController,
      onAddToCatalog: appState.addLoteTramaToCatalog,
      onRemoveFromCatalog: appState.removeLoteTramaFromCatalog,
      comfortable: true,
      sideBySide: sideBySide,
    );
  }
}

class _CaptureFormPanel extends StatelessWidget {
  const _CaptureFormPanel({
    required this.appState,
    this.includeSessionFields = true,
    this.showAddButton = true,
    this.showSessionActions = true,
    this.forceStacked = false,
  });

  final AppState appState;
  final bool includeSessionFields;
  final bool showAddButton;
  final bool showSessionActions;
  final bool forceStacked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canSplitLotes = !forceStacked && constraints.maxWidth >= 420;
        final canSplitPrimary = !forceStacked && constraints.maxWidth >= 400;
        final sectionGap = forceStacked ? 20.0 : 24.0;
        final fieldGap = forceStacked ? 16.0 : 20.0;
        final padding = forceStacked ? 16.0 : 22.0;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (includeSessionFields) ...[
                const Text(
                  'Datos de la sesión',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: fieldGap),
                _FabricField(appState: appState),
                SizedBox(height: fieldGap),
                _LoteField(
                  appState: appState,
                  sideBySide: canSplitLotes,
                ),
                SizedBox(height: sectionGap),
                const Divider(height: 1),
                SizedBox(height: sectionGap),
              ],
              const Text(
                'Nuevo registro',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: fieldGap),
              if (canSplitPrimary)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TelarField(appState: appState)),
                    SizedBox(width: fieldGap),
                    Expanded(child: _NepsField(appState: appState)),
                  ],
                )
              else ...[
                _TelarField(appState: appState),
                SizedBox(height: fieldGap),
                _NepsField(appState: appState),
              ],
              SizedBox(height: fieldGap),
              CaptureOptionalFields(appState: appState),
              SizedBox(height: fieldGap),
              _MetersPreview(appState: appState),
              if (showAddButton) ...[
                SizedBox(height: fieldGap),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textDark,
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => submitCaptureWithChecks(context, appState),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text(
                    'Agregar registro',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
              if (showSessionActions) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: appState.clearCaptureFields,
                  child: const Text('Limpiar campos'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: appState.captureSessionRecords.isEmpty
                      ? null
                      : () => promptNewCaptureSession(context, appState),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Vaciar registros'),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Informe de sesión',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, inner) {
                    final stacked = inner.maxWidth < 360;
                    final saveButton = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: captureSaveEnabled(appState)
                          ? () =>
                              promptSaveCaptureSessionReport(context, appState)
                          : null,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar'),
                    );
                    final shareButton = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: captureActionsEnabled(appState)
                          ? () => showShareReportMenu(context, appState)
                          : null,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Compartir'),
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          saveButton,
                          const SizedBox(height: 10),
                          shareButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: saveButton),
                        const SizedBox(width: 10),
                        Expanded(child: shareButton),
                      ],
                    );
                  },
                ),
                if (appState.isExporting)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TelarField extends StatelessWidget {
  const _TelarField({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CaptureFieldLabel('Telar', prominent: true),
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: appInputMinHeight(AppInputSize.prominent),
          ),
          child: TextField(
            key: ValueKey('capture-telar-${appState.captureFormEpoch}'),
            controller: appState.telarController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitsOnlyInputFormatters,
            textInputAction: TextInputAction.next,
            style: appDropdownTextStyle(size: AppInputSize.prominent),
            decoration: appInputDecoration(
              'Ej: 102',
              size: AppInputSize.prominent,
            ),
          ),
        ),
      ],
    );
  }
}

class _NepsField extends StatelessWidget {
  const _NepsField({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CaptureFieldLabel('Neps', prominent: true),
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: appInputMinHeight(AppInputSize.prominent),
          ),
          child: TextField(
            key: ValueKey('capture-neps-${appState.captureFormEpoch}'),
            controller: appState.nepsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalNumberInputFormatters,
            textInputAction: TextInputAction.done,
            style: appDropdownTextStyle(size: AppInputSize.prominent),
            decoration: appInputDecoration(
              'Ej: 53',
              size: AppInputSize.prominent,
            ),
            onSubmitted: (_) => submitCaptureWithChecks(context, appState),
          ),
        ),
      ],
    );
  }
}

class _MetersPreview extends StatelessWidget {
  const _MetersPreview({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState.nepsController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.formulaBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mts calculados',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appState.formatNumber(appState.previewValue),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Color(0xFF2F4125),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Mts = Neps / 0.09',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textGreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
