import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';
import 'models.dart';
import 'platform_contract.dart';

NotificationPlatform createNotificationPlatform(NotificationApi api) =>
    NativeNotificationPlatform();

class NativeNotificationPlatform implements NotificationPlatform {
  @override
  Future<String?> requestPermission() async {
    if (!_ready) return 'Thông báo chưa được khởi tạo.';
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted == true ? null : 'Thiết bị chưa cấp quyền thông báo.';
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> initialize(void Function(NotificationLink) onOpen) async {
    if (!_android || _ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        try {
          onOpen(
            NotificationLink.fromJson(
              jsonDecode(response.payload!) as Map<String, dynamic>,
            ),
          );
        } catch (_) {}
      },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      try {
        onOpen(
          NotificationLink.fromJson(
            jsonDecode(launch!.notificationResponse!.payload!)
                as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Future<String> timeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
  @override
  Future<String?> activate(
    String owner, {
    required bool requestPermission,
  }) async {
    if (!_android) return 'Nhắc hệ thống hỗ trợ Android và Chrome.';
    if (!_ready) return 'Lịch nhắc chưa được khởi tạo.';
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = requestPermission
        ? await android?.requestNotificationsPermission()
        : await android?.areNotificationsEnabled();
    return allowed == true
        ? null
        : 'Thiết bị chưa cấp quyền thông báo. Hãy bật quyền trong Cài đặt hệ thống.';
  }

  @override
  Future<void> deactivate() async {
    if (_ready) await _plugin.cancelAll();
  }

  @override
  Future<void> apply(ReminderSettings settings, String owner) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final location = tz.getLocation(settings.timeZone);
    final now = tz.TZDateTime.now(location);
    final slots = <(String, int, int)>[];
    int minutes(String time) {
      final p = time.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    if (settings.workoutEnabled) {
      for (final day in settings.workoutDays) {
        slots.add(('workout', day, minutes(settings.workoutTime)));
      }
    }
    if (settings.weeklyEnabled) {
      slots.add(('weekly', settings.weeklyDay, minutes(settings.weeklyTime)));
    }
    if (settings.waterEnabled) {
      for (
        var m = minutes(settings.waterStart);
        m <= minutes(settings.waterEnd);
        m += settings.waterIntervalMinutes
      ) {
        for (var day = 1; day <= 7; day++) {
          slots.add(('water', day, m));
        }
      }
    }
    for (final (kind, day, minute) in slots) {
      var at = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        minute ~/ 60,
        minute % 60,
      );
      while (at.weekday != day || !at.isAfter(now)) {
        at = tz.TZDateTime(
          location,
          at.year,
          at.month,
          at.day + 1,
          minute ~/ 60,
          minute % 60,
        );
      }
      final base = switch (kind) {
        'workout' => 100000,
        'water' => 200000,
        _ => 300000,
      };
      await _plugin.zonedSchedule(
        id: base + day * 1500 + minute,
        scheduledDate: at,
        title: switch (kind) {
          'workout' => 'Đến giờ tập luyện',
          'water' => 'Nhắc uống nước',
          _ => 'Báo cáo tuần',
        },
        body:
            'Chạm để mở ${switch (kind) {
              'workout' => 'lịch tập',
              'water' => 'lịch uống nước',
              _ => 'báo cáo tuần',
            }}.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Nhắc nhở AI GYM',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode(
          NotificationLink(owner: owner, kind: kind).toJson(),
        ),
      );
    }
  }
}
