import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_handler.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/permissions/permission.dart';
import '../../core/widgets/permission_gate.dart';
import '../../providers/app_state.dart';
import '../../utils/file_share_helper.dart';

class FabricCatalogScreen extends StatefulWidget {
  const FabricCatalogScreen({super.key});

  @override
  State<FabricCatalogScreen> createState() => _FabricCatalogScreenState();
}

class _FabricCatalogScreenState extends State<FabricCatalogScreen> {
  final TextEditingController manualController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String _query = '';
  bool isImporting = false;
  bool isExporting = false;

  @override
  void dispose() {
    manualController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Telas visibles según el texto de búsqueda (sin distinguir mayúsculas).
  List<String> _visibleFabrics(AppState appState) {
    final query = _query.trim().toUpperCase();
    if (query.isEmpty) return appState.fabrics;
    return appState.fabrics
        .where((fabric) => fabric.toUpperCase().contains(query))
        .toList();
  }

  bool get isBusy => isImporting || isExporting;

  String get _timestamp {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _importExcel(AppState appState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      dialogTitle: 'Seleccionar talas.xlsx',
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    setState(() => isImporting = true);

    try {
      final imported = picked.bytes != null
          ? appState.fabricCatalogService.importFromBytes(picked.bytes!)
          : !kIsWeb && picked.path != null
              ? await appState.fabricCatalogService.importFromPath(picked.path!)
              : <String>[];

      if (imported.isEmpty) {
        appState
            .showMessage('No se encontraron nombres de tela en el archivo.');
        return;
      }

      final merged = appState.fabricCatalogService
          .mergeFabrics(appState.fabrics, imported);
      await appState.saveFabrics(merged);
      appState.showMessage('Se importaron ${imported.length} telas.');
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'importFabricExcel');
      appState.showMessage(
        'Error al importar Excel: ${ErrorHandler.userMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<void> _exportFabrics(AppState appState,
      {required bool asExcel}) async {
    if (appState.fabrics.isEmpty) {
      appState.showMessage('No hay telas para exportar.');
      return;
    }

    setState(() => isExporting = true);

    try {
      final service = appState.fabricCatalogService;

      if (asExcel) {
        final bytes = service.buildExportExcelBytes(appState.fabrics);
        if (bytes == null || bytes.isEmpty) {
          appState.showMessage('No se pudo generar el archivo Excel.');
          return;
        }
        await FileShareHelper.shareBytes(
          bytes: bytes,
          fileName: 'telas_$_timestamp.xlsx',
          mimeType: FileShareHelper.excelMimeType,
          shareText: 'Lista de telas VICUNHA',
        );
      } else {
        await FileShareHelper.shareTextContent(
          content: service.buildExportCsv(appState.fabrics),
          fileName: 'telas_$_timestamp.csv',
          mimeType: 'text/csv',
          shareText: 'Lista de telas VICUNHA',
          bom: true,
        );
      }

      appState.showMessage('Lista de telas exportada correctamente.');
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'exportFabrics');
      appState.showMessage(
        'Error al exportar telas: ${ErrorHandler.userMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> _addManual(AppState appState) async {
    final name = manualController.text.trim();
    if (name.isEmpty) {
      appState.showMessage('Escriba el nombre de la tela.');
      return;
    }
    final merged =
        appState.fabricCatalogService.mergeFabrics(appState.fabrics, [name]);
    await appState.saveFabrics(merged);
    manualController.clear();
  }

  Future<void> _removeFabric(AppState appState, String fabric) async {
    final updated = List<String>.from(appState.fabrics)..remove(fabric);
    await appState.saveFabrics(updated);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);
    final visible = _visibleFabrics(appState);

    return PermissionGate(
      permission: Permission.manageFabrics,
      child: AppPage(
        title: 'Catalogo de telas',
        subtitle: phone ? null : 'Importar, exportar y administrar tejidos',
        fillViewport: true,
        compactPadding: true,
        denseOnPhone: true,
        actions: phone ? null : _toolbarActions(appState),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phone) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _toolbarActions(appState),
              ),
              SizedBox(height: spacing),
            ],
            _SearchAndAddBar(
              phone: phone,
              searchController: searchController,
              manualController: manualController,
              onSearch: (value) => setState(() => _query = value),
              onAdd: () => _addManual(appState),
            ),
            SizedBox(height: spacing),
            _CatalogStatusRow(
              phone: phone,
              total: appState.fabrics.length,
              visible: visible.length,
              filtered: _query.trim().isNotEmpty,
              cloudEnabled: appState.cloudSyncEnabled,
            ),
            if (appState.cloudSyncError != null) ...[
              const SizedBox(height: 6),
              StatusBanner(
                type: StatusBannerType.warning,
                message: appState.cloudSyncEnabled
                    ? 'Sincronización parcial con Firebase. El catálogo local sigue disponible.'
                    : 'Catálogo en modo local. Para publicar en la nube se requiere rol Supervisor.',
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(sectionRadius(context)),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildCatalogBody(appState, visible, phone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _toolbarActions(AppState appState) {
    final phone = isPhoneLayout(context);
    return [
      _ActionChip(
        compact: phone,
        onPressed: isBusy ? null : () => _importExcel(appState),
        icon: isImporting ? null : Icons.upload_file,
        loading: isImporting,
        label: phone ? 'Importar' : 'Importar Excel',
      ),
      _ActionChip(
        compact: phone,
        color: AppColors.primaryGreen,
        onPressed:
            isBusy ? null : () => _exportFabrics(appState, asExcel: true),
        icon: isExporting ? null : Icons.download,
        loading: isExporting,
        label: phone ? 'Excel' : 'Exportar Excel',
      ),
      _ActionChip(
        compact: phone,
        color: AppColors.primaryGreen,
        onPressed:
            isBusy ? null : () => _exportFabrics(appState, asExcel: false),
        icon: isExporting ? null : Icons.table_chart,
        loading: isExporting,
        label: phone ? 'CSV' : 'Exportar CSV',
      ),
    ];
  }

  Widget _buildCatalogBody(
    AppState appState,
    List<String> visible,
    bool phone,
  ) {
    if (appState.fabrics.isEmpty) {
      return EmptyState(
        compact: phone,
        icon: Icons.texture_outlined,
        title: 'Catálogo vacío',
        message:
            'No hay telas registradas. Importe un Excel o agregue manualmente.',
        actions: [
          EmptyStateAction(
            label: 'Importar Excel',
            icon: Icons.upload_file,
            onPressed: () {
              if (!isBusy) _importExcel(appState);
            },
          ),
        ],
      );
    }

    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Sin coincidencias',
        message: 'Ninguna tela coincide con la búsqueda.',
      );
    }

    // Grilla responsive: aprovecha el ancho y mejora la densidad visual
    // frente a una única columna perdida en pantallas grandes.
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: phone ? 520 : 340,
        mainAxisExtent: 56,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final fabric = visible[index];
        return _FabricTile(
          position: appState.fabrics.indexOf(fabric) + 1,
          name: fabric,
          onRemove: () => _removeFabric(appState, fabric),
        );
      },
    );
  }
}

/// Barra de búsqueda + alta rápida de telas.
class _SearchAndAddBar extends StatelessWidget {
  const _SearchAndAddBar({
    required this.phone,
    required this.searchController,
    required this.manualController,
    required this.onSearch,
    required this.onAdd,
  });

  final bool phone;
  final TextEditingController searchController;
  final TextEditingController manualController;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: searchController,
      onChanged: onSearch,
      textInputAction: TextInputAction.search,
      decoration: appInputDecoration(
        'Buscar tela...',
        ultraCompact: phone,
      ).copyWith(
        prefixIcon: const Icon(Icons.search, size: 20),
        labelText: 'Buscar',
      ),
    );

    final addField = TextField(
      controller: manualController,
      textCapitalization: TextCapitalization.characters,
      onSubmitted: (_) => onAdd(),
      decoration: appInputDecoration(
        'Ej: DENIM AZUL',
        ultraCompact: phone,
      ).copyWith(labelText: 'Agregar tela'),
    );

    final addButton = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Agregar'),
    );

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 8),
          addField,
          const SizedBox(height: 6),
          addButton,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: addField),
        const SizedBox(width: 8),
        addButton,
      ],
    );
  }
}

/// Fila de contador de telas y estado de guardado en la nube.
class _CatalogStatusRow extends StatelessWidget {
  const _CatalogStatusRow({
    required this.phone,
    required this.total,
    required this.visible,
    required this.filtered,
    required this.cloudEnabled,
  });

  final bool phone;
  final int total;
  final int visible;
  final bool filtered;
  final bool cloudEnabled;

  @override
  Widget build(BuildContext context) {
    final counter = filtered ? '$visible de $total tela(s)' : '$total tela(s)';
    return Row(
      children: [
        Expanded(
          child: Text(
            counter,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: phone ? 12 : 14,
              color: AppColors.muted,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              cloudEnabled
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: phone ? 14 : 16,
              color: cloudEnabled ? AppColors.primaryGreen : AppColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              cloudEnabled
                  ? (phone ? 'Firebase' : 'Guardado en Firebase')
                  : (phone ? 'Local' : 'Guardado local'),
              style: TextStyle(
                fontSize: phone ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: cloudEnabled ? AppColors.primaryGreen : AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta compacta de una tela dentro de la grilla del catálogo.
class _FabricTile extends StatelessWidget {
  const _FabricTile({
    required this.position,
    required this.name,
    required this.onRemove,
  });

  final int position;
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.formulaBg,
            child: Text(
              '$position',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.danger,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.onPressed,
    required this.label,
    this.icon,
    this.color,
    this.compact = false,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: const TextStyle(fontSize: 12)),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.circle),
      label: Text(loading ? 'Procesando...' : label),
    );
  }
}
