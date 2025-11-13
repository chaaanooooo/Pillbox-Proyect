// lib/notificaciones/local_notifier.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifier {
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

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

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

  // ---------------- DIARIA ----------------
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;

    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await _fln.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('⏰ DAILY (inexact) id=$id -> ${when.toLocal()}');
  }

  // ---------------- EN X MINUTOS (prueba) ----------------
  static Future<void> scheduleInMinutes({
    required int id,
    required int minutes,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    await _fln.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    debugPrint('⏰ IN-MINUTES (inexact) id=$id -> ${when.toLocal()}');
  }

  static Future<void> testNow() async {
    if (kIsWeb) return;
    await _fln.show(
      999001,
      '🔔 Test de PillBox',
      'Si ves esto, el canal y permisos están OK.',
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _fln.cancel(id);
  }

  static Future<void> cancelRange(int fromId, int toId) async {
    if (kIsWeb) return;
    for (var i = fromId; i <= toId; i++) {
      await _fln.cancel(i);
    }
  }

  static Future<bool?> areEnabledOnAndroid() async {
    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }
}