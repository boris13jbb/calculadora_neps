import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_page.dart';
import '../../providers/app_state.dart';
import '../../utils/file_share_helper.dart';

class FabricCatalogScreen extends StatefulWidget {
  const FabricCatalogScreen({super.key});

  @override
  State<FabricCatalogScreen> createState() => _FabricCatalogScreenState();
}

class _FabricCatalogScreenState extends State<FabricCatalogScreen> {
  final TextEditingController manualController = TextEditingController();
  bool isImporting = false;
  bool isExporting = false;

  @override
  void dispose() {
    manualController.dispose();
    super.dispose();
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
    } catch (e) {
      appState.showMessage('Error al importar Excel: $e');
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
    } catch (e) {
      appState.showMessage('Error al exportar telas: $e');
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

    return AppPage(
      title: 'Catalogo de telas',
      subtitle: phone
          ? 'Importar, exportar y administrar tejidos'
          : 'Gestiona tu catalogo de tejidos de forma rapida y segura.',
      breadcrumb: const ['Inicio', 'Telas', 'Catalogo de telas'],
      fillViewport: true,
      compactPadding: true,
      denseOnPhone: true,
      actions: [
        _ActionChip(
          compact: phone,
          color: AppColors.accent,
          foreground: AppColors.textDark,
          onPressed: isBusy ? null : () => _importExcel(appState),
          icon: isImporting ? null : Icons.upload_file,
          loading: isImporting,
          label: phone ? 'Importar' : 'Importar Excel',
        ),
        _ActionChip(
          compact: phone,
          color: AppColors.primaryGreen,
          onPressed: isBusy
              ? null
              : () => _exportFabrics(appState, asExcel: true),
          icon: Icons.download,
          label: phone ? 'Excel' : 'Exportar Excel',
        ),
        _ActionChip(
          compact: phone,
          color: AppColors.primaryGreen,
          onPressed: isBusy
              ? null
              : () => _exportFabrics(appState, asExcel: false),
          icon: Icons.table_chart,
          label: phone ? 'CSV' : 'Exportar CSV',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          phone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: manualController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 13),
                      decoration: appInputDecoration(
                        'Ej: DENIM AZUL',
                        ultraCompact: true,
                      ).copyWith(labelText: 'Agregar tela'),
                      onSubmitted: (_) => _addManual(appState),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: () => _addManual(appState),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar tela'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: manualController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Agregar tela manual',
                          hintText: 'Ej: DENIM AZUL',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addManual(appState),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textDark,
                      ),
                      onPressed: () => _addManual(appState),
                      icon: const Icon(Icons.add),
                      tooltip: 'Agregar',
                    ),
                  ],
                ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${appState.fabrics.length} tela(s)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: phone ? 12 : 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
              if (appState.cloudSyncEnabled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: phone ? 14 : 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone ? 'Firebase' : 'Guardado en Firebase',
                      style: TextStyle(
                        fontSize: phone ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (appState.cloudSyncError != null) ...[
            const SizedBox(height: 6),
            Text(
              'Firebase no disponible: ${appState.cloudSyncError}',
              style: TextStyle(
                fontSize: phone ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: AppDecorations.card(color: AppColors.surface),
              child: appState.fabrics.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay telas. Importe o agregue manualmente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: appState.fabrics.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final fabric = appState.fabrics[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: phone ? 12 : 16,
                            backgroundColor: AppColors.formulaBg,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: phone ? 10 : 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          title: Text(
                            fabric,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: phone ? 13 : 15,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Eliminar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeFabric(appState, fabric),
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                              size: phone ? 18 : 24,
                            ),
                          ),
                        );
                      },
                    ),
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
    this.foreground,
    this.compact = false,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.white;

    if (compact) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
        ),
        onPressed: onPressed,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Icon(icon ?? Icons.circle, size: 18),
        label: Text(
          loading ? 'Procesando...' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
      ),
      onPressed: onPressed,
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Icon(icon ?? Icons.circle),
      label: Text(loading ? 'Procesando...' : label),
    );
  }
}
