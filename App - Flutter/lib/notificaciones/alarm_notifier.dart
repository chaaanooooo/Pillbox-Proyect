// lib/notificaciones/alarm_notifier.dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


@pragma('vm:entry-point')
class AlarmNotifier {
  static final _fln = FlutterLocalNotificationsPlugin();

  static const _channelId = 'meds_channel';
  static const _channelName = 'Recordatorios de medicación';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    category: AndroidNotificationCategory.reminder,
  );

  /// Inicializa tanto las notificaciones como el alarm manager
  static Future<void> init() async {
    if (kIsWeb) return;

    // Inicializar alarm manager
    await AndroidAlarmManager.initialize();

    // Inicializar notificaciones locales
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _fln.initialize(const InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ));

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alertas de toma de medicación',
      importance: Importance.max,
    ));
  }

  static Future<void> requestPermission(BuildContext? context) async {
    if (kIsWeb) return;

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _fln.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ---------------- DIARIA (con AndroidAlarmManager) ----------------
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;

    // Calcular la primera ejecución
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Programar alarma periódica (se repite cada 24 horas)
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      id,
      _showNotificationCallback,
      startAt: scheduledTime,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {
        'title': title,
        'body': body,
      },
    );

    debugPrint('⏰ DAILY ALARM id=$id -> ${scheduledTime.toLocal()}');
  }

  // ---------------- EN X MINUTOS (prueba) ----------------
  static Future<void> scheduleInMinutes({
    required int id,
    required int minutes,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    final scheduledTime = DateTime.now().add(Duration(minutes: minutes));

    // Programar alarma one-shot (no se repite)
    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      id,
      _showNotificationCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: false,
      params: {
        'title': title,
        'body': body,
      },
    );

    debugPrint('⏰ IN-MINUTES ALARM id=$id -> ${scheduledTime.toLocal()}');
  }

  /// Callback que se ejecuta cuando la alarma se dispara
  /// IMPORTANTE: Este método debe ser top-level o static
  @pragma('vm:entry-point')
  static Future<void> _showNotificationCallback(int id, Map<String, dynamic>? params) async {
    debugPrint('🔔 Alarma disparada! id=$id');
    
    // Reinicializar el plugin de notificaciones
    final fln = FlutterLocalNotificationsPlugin();
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await fln.initialize(const InitializationSettings(android: androidInit));

    final title = params?['title'] ?? 'Recordatorio';
    final body = params?['body'] ?? 'Es hora de tomar tu medicación';

    // Mostrar la notificación
    await fln.show(
      id,
      title,
      body,
      const NotificationDetails(android: _androidDetails),
    );
    
    debugPrint('✅ Notificación mostrada: $title');
  }

  /// Test inmediato
  static Future<void> testNow() async {
    if (kIsWeb) return;
    await _fln.show(
      999001,
      '🔔 Test de PillBox',
      'Si ves esto, el canal y permisos están OK.',
      const NotificationDetails(android: _androidDetails),
    );
  }

  /// Cancelar una alarma específica
  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await AndroidAlarmManager.cancel(id);
    debugPrint('❌ Alarma cancelada: id=$id');
  }

  /// Cancelar un rango de alarmas
  static Future<void> cancelRange(int fromId, int toId) async {
    if (kIsWeb) return;
    for (var i = fromId; i <= toId; i++) {
      await AndroidAlarmManager.cancel(i);
    }
    debugPrint('❌ Alarmas canceladas: $fromId-$toId');
  }

  static Future<bool?> areEnabledOnAndroid() async {
    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }
}