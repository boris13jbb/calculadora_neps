import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alert_config.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_material_list_tile.dart';
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
  late final TextEditingController _normalMaxController;
  late final TextEditingController _warningMaxController;
  late final TextEditingController _reincidenciaDiasController;
  late final TextEditingController _reincidenciaCantController;
  bool _alertasActivas = true;
  bool _criticalNotifications = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = alertConfigService.config;
    _normalMaxController =
        TextEditingController(text: '${config.limiteNormalMax}');
    _warningMaxController =
        TextEditingController(text: '${config.limiteAdvertenciaMax}');
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
    _normalMaxController.dispose();
    _warningMaxController.dispose();
    _reincidenciaDiasController.dispose();
    _reincidenciaCantController.dispose();
    super.dispose();
  }

  Future<void> _save(AppState appState) async {
    if (!appState.canEditAlertConfig) {
      appState.showMessage(
        'No tiene permisos para modificar los límites de alerta.',
      );
      return;
    }

    final normalMax = int.tryParse(_normalMaxController.text.trim());
    final warningMax = int.tryParse(_warningMaxController.text.trim());
    final dias = int.tryParse(_reincidenciaDiasController.text.trim());
    final cantidad = int.tryParse(_reincidenciaCantController.text.trim());

    if (normalMax == null ||
        warningMax == null ||
        dias == null ||
        cantidad == null ||
        normalMax < 0 ||
        warningMax <= normalMax ||
        dias < 0 ||
        cantidad < 1) {
      appState.showMessage(
        'Revise los límites: normal < advertencia y valores válidos.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final config = AlertConfig(
        limiteNormalMax: normalMax,
        limiteAdvertenciaMax: warningMax,
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
      _normalMaxController.text = '${config.limiteNormalMax}';
      _warningMaxController.text = '${config.limiteAdvertenciaMax}';
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

    return AppPage(
      title: 'Configuración',
      subtitle: phone ? null : 'Límites de alertas y parámetros de calidad',
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
              final left = _limitsSection(appState);
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
    );
  }

  /// Sección de límites de alertas por neps con las acciones de guardado.
  Widget _limitsSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Límites de alertas por neps',
          subtitle: 'Definen los rangos Normal / Advertencia / Crítico',
          icon: Icons.speed_outlined,
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
                label: 'Máximo neps normal (verde)',
                controller: _normalMaxController,
                helper: 'De 0 a este valor → Normal',
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
              const SizedBox(height: 10),
              _NumberField(
                label: 'Máximo neps advertencia (amarillo)',
                controller: _warningMaxController,
                helper: 'Hasta este valor → Advertencia. Por encima → Crítico',
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
              const SizedBox(height: 10),
              _NumberField(
                label: 'Días para evaluar reincidencia',
                controller: _reincidenciaDiasController,
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
              const SizedBox(height: 10),
              _NumberField(
                label: 'Cantidad de críticos para reincidencia',
                controller: _reincidenciaCantController,
                enabled: appState.canEditAlertConfig && !_isSaving,
              ),
            ],
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

  /// Sección de sistema de alertas, notificaciones y valores de referencia.
  Widget _alertsAndDefaultsSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Sistema de alertas y notificaciones',
          subtitle: 'Controla la evaluación de riesgo y los avisos',
          icon: Icons.notifications_active_outlined,
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
                'Si se desactiva, todos los registros se consideran normales.',
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
                'Notificaciones de alertas críticas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                notificationService.isSupported
                    ? 'Aviso en el dispositivo al registrar neps críticos.'
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
        const AppSectionHeader(
          title: 'Valores por defecto',
          icon: Icons.info_outline,
          dense: true,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.formulaBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Normal 0–30, Advertencia 31–60, Crítico 61+. '
            'Los cambios aplican de inmediato a registros, alertas, dashboard y reportes.',
            style: TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        ),
      ],
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
