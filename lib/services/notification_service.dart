import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/nep_record.dart';
import 'notification_preferences_service.dart';

/// Notificaciones locales y FCM para alertas críticas de neps.
class NotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> initialize({
    Future<void> Function(String token)? onTokenRegistered,
  }) async {
    if (_initialized || !isSupported) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _initializeAndroid(onTokenRegistered: onTokenRegistered);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        await _initializeWindows();
      }
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Notificaciones no disponibles: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _initializeAndroid({
    Future<void> Function(String token)? onTokenRegistered,
  }) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidSettings),
    );

    const channel = AndroidNotificationChannel(
      'critical_alerts',
      'Alertas críticas',
      description: 'Notificaciones de neps críticos en producción',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null && onTokenRegistered != null) {
      await onTokenRegistered(token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      await onTokenRegistered?.call(newToken);
    });
  }

  Future<void> _initializeWindows() async {
    await _local.initialize(
      const InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: 'VICUNHA Neps',
          appUserModelId: 'com.example.calculadora_neps',
          guid: 'a3f5e8c2-1b4d-4e6f-9a0b-2c3d4e5f6789',
        ),
      ),
    );
  }

  Future<void> showCriticalAlert({
    required NepRecord record,
    required String Function(double) formatDecimal,
  }) async {
    if (!notificationPreferencesService.criticalAlertsEnabled) return;
    if (!isSupported) return;

    final title = 'Alerta crítica — Telar ${record.telar}';
    final body =
        '${formatDecimal(record.neps)} neps · ${record.tela} · ${record.loteTrama}';

    try {
      const androidDetails = AndroidNotificationDetails(
        'critical_alerts',
        'Alertas críticas',
        channelDescription: 'Neps críticos en telar',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFB94D4D),
      );

      const windowsDetails = WindowsNotificationDetails();

      await _local.show(
        record.id.hashCode,
        title,
        body,
        const NotificationDetails(
          android: androidDetails,
          windows: windowsDetails,
        ),
      );
    } catch (error) {
      debugPrint('No se pudo mostrar notificación: $error');
    }
  }
}

final NotificationService notificationService = NotificationService();
