import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/layout/responsive_layout.dart';
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
      _tabController!.dispose();
      _tabController = null;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
        compactPadding: true,
        denseOnPhone: true,
        actions:
            showHeaderActions ? _buildHeaderActions(context, appState) : null,
        child: useWideCapture
            ? _DesktopCaptureLayout(appState: appState)
            : _tabController == null
                ? const Center(child: CircularProgressIndicator())
                : _MobileCaptureLayout(
                    appState: appState,
                    tabController: _tabController!,
                    onRecordAdded: () => _tabController?.animateTo(1),
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
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
      }

      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: background),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return [
      actionButton(
        onPressed: captureActionsEnabled(appState)
            ? () => promptSaveReport(context, appState)
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
        label: 'Nueva sesion',
        background: AppColors.danger,
        outlined: true,
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
        final formPanel = _CaptureFormPanel(appState: appState);
        final recordsPanel = CompactRecordsPanel(
          appState: appState,
          records: appState.records,
          onDelete: appState.deleteRecord,
          onEdit: (record) => _editCaptureRecord(context, appState, record),
          onClearAll: () => promptNewCaptureSession(context, appState),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionKpis(appState: appState),
            const SizedBox(height: 10),
            _CompactSessionBar(appState: appState),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width:
                        constraints.maxWidth >= AppBreakpoints.wide ? 360 : 300,
                    // El formulario tiene varios botones; en ventanas de poca
                    // altura debe poder desplazarse para no desbordar (el panel
                    // de registros de la derecha ya scrollea internamente).
                    child: SingleChildScrollView(child: formPanel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: recordsPanel),
                ],
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
    required this.onRecordAdded,
  });

  final AppState appState;
  final TabController tabController;
  final VoidCallback onRecordAdded;

  @override
  Widget build(BuildContext context) {
    final recordCount = appState.records.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          child: TabBar(
            controller: tabController,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            indicatorColor: AppColors.accentDark,
            labelColor: AppColors.textDark,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              const Tab(
                height: 40,
                icon: Icon(Icons.edit_note, size: 18),
                text: 'Capturar',
              ),
              Tab(
                height: 40,
                icon: const Icon(Icons.list_alt, size: 18),
                text: 'Lista ($recordCount)',
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _MobileCaptureTab(
                appState: appState,
                onRecordAdded: onRecordAdded,
              ),
              CompactRecordsPanel(
                appState: appState,
                records: appState.records,
                onDelete: appState.deleteRecord,
                onEdit: (record) =>
                    _editCaptureRecord(context, appState, record),
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
  const _MobileCaptureTab({
    required this.appState,
    required this.onRecordAdded,
  });

  final AppState appState;
  final VoidCallback onRecordAdded;

  Future<void> _addRecord(BuildContext context) async {
    final before = appState.records.length;
    await submitCaptureWithChecks(context, appState);
    if (context.mounted && appState.records.length > before) {
      onRecordAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FabricField(appState: appState, ultraCompact: true),
                const SizedBox(height: 6),
                _LoteField(appState: appState, ultraCompact: true),
                const SizedBox(height: 6),
                _CaptureFormPanel(
                  appState: appState,
                  ultraCompact: true,
                  showSessionActions: false,
                ),
              ],
            ),
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
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, 6, 6, 4 + bottomInset + viewInsets),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            final ultraNarrow = constraints.maxWidth < 320;

            final iconActions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(40, 40),
                  ),
                  tooltip: 'Guardar',
                  onPressed: captureActionsEnabled(appState)
                      ? () => promptSaveReport(context, appState)
                      : null,
                  icon: const Icon(Icons.save, size: 20),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(40, 40),
                  ),
                  tooltip: 'Compartir',
                  onPressed: captureActionsEnabled(appState)
                      ? () => showShareReportMenu(context, appState)
                      : null,
                  icon: const Icon(Icons.ios_share, size: 20),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(40, 40),
                  ),
                  tooltip: 'Vaciar registros',
                  onPressed: appState.records.isEmpty
                      ? null
                      : () => promptNewCaptureSession(context, appState),
                  icon: const Icon(Icons.delete_sweep, size: 20),
                ),
              ],
            );

            final addButton = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textDark,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Agregar',
                style: TextStyle(fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            );

            final secondaryActions = Wrap(
              spacing: 4,
              runSpacing: 0,
              alignment:
                  narrow ? WrapAlignment.start : WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: appState.clearCaptureFields,
                  child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => appState.setNavigationIndex(4),
                  icon: const Icon(Icons.texture, size: 16),
                  label: const Text('Telas', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => appState.setNavigationIndex(2),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Filtros', style: TextStyle(fontSize: 12)),
                ),
              ],
            );

            if (ultraNarrow || narrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: iconActions),
                  const SizedBox(height: 6),
                  addButton,
                  secondaryActions,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    iconActions,
                    const SizedBox(width: 8),
                    Expanded(child: addButton),
                  ],
                ),
                secondaryActions,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// KPIs de la sesión de captura extraídos de la tabla hacia la parte superior:
/// registros, neps totales, metros calculados y telares distintos (alcance).
class _SessionKpis extends StatelessWidget {
  const _SessionKpis({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final records = appState.records;
    final totalNeps = records.fold<double>(0, (sum, item) => sum + item.neps);
    final totalMts = records.fold<double>(
      0,
      (sum, item) => sum + appState.calculateMts(item.neps),
    );
    final looms = records.map((r) => r.telar).toSet().length;

    return KpiStrip(
      minCardWidth: 168,
      spacing: 10,
      compact: true,
      cards: [
        KpiCard(
          compact: true,
          label: 'Registros',
          value: '${records.length}',
          icon: Icons.table_rows_outlined,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          compact: true,
          label: 'Neps totales',
          value: appState.formatDecimal(totalNeps),
          icon: Icons.blur_on,
          color: AppColors.accentDark,
        ),
        KpiCard(
          compact: true,
          label: 'Mts calculados',
          value: appState.formatNumber(totalMts),
          icon: Icons.straighten_outlined,
          color: AppColors.statusNormal,
        ),
        KpiCard(
          compact: true,
          label: 'Telares',
          value: '$looms',
          icon: Icons.precision_manufacturing_outlined,
          color: AppColors.primaryGreen,
        ),
      ],
    );
  }
}

class _CompactSessionBar extends StatelessWidget {
  const _CompactSessionBar({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < AppBreakpoints.phone;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FabricField(appState: appState),
                const SizedBox(height: 8),
                _LoteField(appState: appState),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _FabricField(appState: appState)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _LoteField(appState: appState)),
            ],
          );
        },
      ),
    );
  }
}

class _FabricField extends StatelessWidget {
  const _FabricField({
    required this.appState,
    this.ultraCompact = false,
  });

  final AppState appState;
  final bool ultraCompact;

  InputDecoration _decoration() => appInputDecoration(
        ultraCompact ? 'Tela' : 'Seleccione',
        compact: !ultraCompact,
        ultraCompact: ultraCompact,
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
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.55;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: appState.fabrics.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == appState.fabrics.length) {
                        return AppMaterialListTile(
                          dense: true,
                          title: appDropdownItemText('Manual', compact: true),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.textDark,
                            size: 20,
                          ),
                          onTap: () =>
                              Navigator.pop(sheetContext, manualFabricOption),
                        );
                      }

                      final fabric = appState.fabrics[index];
                      final isSelected = fabric == appState.selectedFabric;
                      return AppMaterialListTile(
                        dense: true,
                        selected: isSelected,
                        title: appDropdownItemText(fabric, compact: true),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                                size: 20,
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
    final useSheet = ultraCompact || isPhoneLayout(context);

    if (appState.fabrics.isEmpty || appState.useManualFabric) {
      final canPickFromCatalog = appState.fabrics.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactLabel('Tela / Tejido', ultraCompact: ultraCompact),
          TextField(
            controller: appState.manualTelaController,
            textCapitalization: TextCapitalization.characters,
            style: appDropdownTextStyle(ultraCompact: ultraCompact),
            decoration: decoration.copyWith(
              hintText: 'Nombre de tela',
              suffixIcon: canPickFromCatalog
                  ? IconButton(
                      tooltip: 'Seleccionar del catalogo',
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textDark,
                      ),
                      onPressed: () => _openFabricSheet(context),
                    )
                  : null,
            ),
          ),
          if (canPickFromCatalog)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openFabricSheet(context),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('Elegir del catalogo'),
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
          _CompactLabel('Tela / Tejido', ultraCompact: ultraCompact),
          InkWell(
            borderRadius: BorderRadius.circular(ultraCompact ? 8 : 10),
            onTap: () => _openFabricSheet(context),
            child: InputDecorator(
              decoration: decoration,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedLabel,
                      overflow: TextOverflow.ellipsis,
                      style: appDropdownTextStyle(ultraCompact: ultraCompact),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CompactLabel('Tela / Tejido', ultraCompact: ultraCompact),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'fabric-${appState.selectedFabric}-${appState.fabrics.length}',
          ),
          initialValue: appState.selectedFabric,
          isExpanded: true,
          isDense: true,
          iconEnabledColor: AppColors.textDark,
          dropdownColor: Colors.white,
          menuMaxHeight: MediaQuery.sizeOf(context).height * 0.45,
          style: appDropdownTextStyle(ultraCompact: ultraCompact),
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
      ],
    );
  }
}

class _LoteField extends StatelessWidget {
  const _LoteField({
    required this.appState,
    this.ultraCompact = false,
  });

  final AppState appState;
  final bool ultraCompact;

  @override
  Widget build(BuildContext context) {
    return LoteTramaField(
      catalog: appState.loteCatalog,
      fullController: appState.loteFullController,
      onAddToCatalog: appState.addLoteTramaToCatalog,
      onRemoveFromCatalog: appState.removeLoteTramaFromCatalog,
      ultraCompact: ultraCompact,
      compact: !ultraCompact,
    );
  }
}

class _CaptureFormPanel extends StatelessWidget {
  const _CaptureFormPanel({
    required this.appState,
    this.showSessionActions = true,
    this.ultraCompact = false,
  });

  final AppState appState;
  final bool showSessionActions;
  final bool ultraCompact;

  InputDecoration _inputDecoration(String hint) {
    return appInputDecoration(
      hint,
      compact: !ultraCompact,
      ultraCompact: ultraCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ultraCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CompactLabel('Telar', ultraCompact: true),
                    TextField(
                      controller: appState.telarController,
                      keyboardType: TextInputType.number,
                      inputFormatters: digitsOnlyInputFormatters,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration('102'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CompactLabel('Neps', ultraCompact: true),
                    TextField(
                      controller: appState.nepsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalNumberInputFormatters,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration('53'),
                      onSubmitted: (_) =>
                          submitCaptureWithChecks(context, appState),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mts = Neps / 0.09',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.textGreen,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent),
                ),
                child: Text(
                  appState.formatNumber(appState.previewValue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF2F4125),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CaptureOptionalFields(appState: appState, ultraCompact: true),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nuevo registro',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const _CompactLabel('Telar'),
          TextField(
            controller: appState.telarController,
            keyboardType: TextInputType.number,
            inputFormatters: digitsOnlyInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Ej: 102'),
          ),
          const SizedBox(height: 8),
          const _CompactLabel('Neps'),
          TextField(
            controller: appState.nepsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalNumberInputFormatters,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration('Ej: 53'),
            onSubmitted: (_) => submitCaptureWithChecks(context, appState),
          ),
          const SizedBox(height: 8),
          CaptureOptionalFields(appState: appState),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: _CompactLabel('Mts = Neps / 0.09'),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent),
                ),
                child: Text(
                  appState.formatNumber(appState.previewValue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF2F4125),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => submitCaptureWithChecks(context, appState),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Agregar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: appState.clearCaptureFields,
            child: const Text('Limpiar campos'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: appState.records.isEmpty
                ? null
                : () => promptNewCaptureSession(context, appState),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: const Text('Vaciar registros'),
          ),
          if (showSessionActions) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Informe de sesion',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 360;
                final saveButton = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: captureActionsEnabled(appState)
                      ? () => promptSaveReport(context, appState)
                      : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Guardar'),
                );
                final shareButton = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
                      const SizedBox(height: 8),
                      shareButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: saveButton),
                    const SizedBox(width: 8),
                    Expanded(child: shareButton),
                  ],
                );
              },
            ),
            if (appState.isExporting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactLabel extends StatelessWidget {
  const _CompactLabel(this.text, {this.ultraCompact = false});

  final String text;
  final bool ultraCompact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultraCompact ? 2 : 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: ultraCompact ? 10 : 11,
          color: AppColors.textGreen,
        ),
      ),
    );
  }
}
