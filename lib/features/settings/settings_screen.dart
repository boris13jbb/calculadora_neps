import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alert_config.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_material_list_tile.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/widgets/nav_permission_gate.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/app_state.dart';
import '../../services/alert_config_service.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _reincidenciaDiasController;
  late final TextEditingController _reincidenciaCantController;
  bool _alertasActivas = true;
  bool _criticalNotifications = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = alertConfigService.config;
    _reincidenciaDiasController =
        TextEditingController(text: '${config.diasParaReincidencia}');
    _reincidenciaCantController = TextEditingController(
      text: '${config.cantidadReincidenciasCriticas}',
    );
    _alertasActivas = config.alertasActivas;
    _criticalNotifications =
        notificationPreferencesService.criticalAlertsEnabled;
  }

  @override
  void dispose() {
    _reincidenciaDiasController.dispose();
    _reincidenciaCantController.dispose();
    super.dispose();
  }

  Future<void> _save(AppState appState) async {
    if (!appState.canEditAlertConfig) {
      appState.showMessage(
        'No tiene permisos para modificar la configuración de alertas.',
      );
      return;
    }

    final dias = int.tryParse(_reincidenciaDiasController.text.trim());
    final cantidad = int.tryParse(_reincidenciaCantController.text.trim());

    if (dias == null || cantidad == null || dias < 0 || cantidad < 1) {
      appState.showMessage(
        'Revise los valores de reincidencia (días ≥ 0, cantidad ≥ 1).',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final config = AlertConfig(
        diasParaReincidencia: dias,
        cantidadReincidenciasCriticas: cantidad,
        alertasActivas: _alertasActivas,
      );
      await appState.saveAlertConfig(config);
      if (mounted) {
        appState.showMessage('Configuración guardada correctamente.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reset(AppState appState) async {
    setState(() => _isSaving = true);
    try {
      await appState.saveAlertConfig(defaultAlertConfig);
      const config = defaultAlertConfig;
      _reincidenciaDiasController.text = '${config.diasParaReincidencia}';
      _reincidenciaCantController.text =
          '${config.cantidadReincidenciasCriticas}';
      _alertasActivas = config.alertasActivas;
      if (mounted) {
        appState.showMessage('Configuración restaurada a valores por defecto.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);

    return NavPermissionGate(
      navId: AppNavId.settings,
      child: AppPage(
        title: 'Configuración',
        subtitle: phone
            ? null
            : 'Criterios oficiales NEPS y parámetros de alertas',
        maxContentWidth: 1080,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (appState.cloudSyncEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StatusBanner(
                  type: StatusBannerType.info,
                  message:
                      'Rol: ${appState.authRole.label}${appState.authUsername != null ? ' · ${appState.authUsername}' : ''}',
                ),
              ),
            if (appState.isReadOnlyUser)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: StatusBanner(
                  type: StatusBannerType.warning,
                  message:
                      'Modo solo lectura (Gerencia). No puede capturar ni modificar registros.',
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 820;
                final left = _criteriaSection();
                final right = _alertsAndDefaultsSection(appState);

                if (!twoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: 16),
                      right,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Criterios oficiales de calificación (solo lectura).
  Widget _criteriaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Criterios oficiales de calificación',
          subtitle: 'OK / Mención / Crítico / 2da Calidad (no editables)',
          icon: Icons.verified_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.4),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.4),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
                ),
                children: const [
                  TableRow(
                    children: [
                      _TableHeader('Calificación'),
                      _TableHeader('Puntaje'),
                      _TableHeader('NEPS/m²'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCell('OK'),
                      _TableCell('0 – 18'),
                      _TableCell('≤ 200'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCell('Mención'),
                      _TableCell('19 – 45'),
                      _TableCell('200 < … ≤ 500'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCell('Crítico'),
                      _TableCell('46 – 54'),
                      _TableCell('500 < … ≤ 600'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCell('2da Calidad'),
                      _TableCell('≥ 55'),
                      _TableCell('> 600'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Los umbrales son oficiales y fijos. Solo se pueden ajustar '
                'reincidencia, activación de alertas y notificaciones.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección de sistema de alertas, reincidencia y notificaciones.
  Widget _alertsAndDefaultsSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Sistema de alertas y notificaciones',
          subtitle: 'Reincidencia, activación y avisos del dispositivo',
          icon: Icons.notifications_active_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NumberField(
                label: 'Días para evaluar reincidencia',
                controller: _reincidenciaDiasController,
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
              const SizedBox(height: 10),
              _NumberField(
                label: 'Cantidad de severos para reincidencia',
                controller: _reincidenciaCantController,
                helper: 'Cuenta Crítico y 2da Calidad en la ventana de días',
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppMaterialSwitchListTile(
              title: const Text(
                'Activar sistema de alertas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Si se desactiva, todos los registros se consideran OK.',
                style: TextStyle(fontSize: 12),
              ),
              value: _alertasActivas,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: !appState.canEditAlertConfig || _isSaving
                  ? null
                  : (value) => setState(() => _alertasActivas = value),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppMaterialSwitchListTile(
              title: const Text(
                'Notificaciones de alertas severas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                notificationService.isSupported
                    ? 'Aviso al registrar Crítico o 2da Calidad.'
                    : 'No disponible en esta plataforma (use Android o Windows).',
                style: const TextStyle(fontSize: 12),
              ),
              value: _criticalNotifications && notificationService.isSupported,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: !notificationService.isSupported || _isSaving
                  ? null
                  : (value) async {
                      setState(() => _criticalNotifications = value);
                      await appState.setCriticalNotificationsEnabled(value);
                    },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: !appState.canEditAlertConfig || _isSaving
                    ? null
                    : () => _save(appState),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: !appState.canEditAlertConfig || _isSaving
                  ? null
                  : () => _reset(appState),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: AppColors.textGreen,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textDark),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }
}
