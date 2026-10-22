import 'package:ai_gym/notifications/models.dart';
import 'package:ai_gym/notifications/controller.dart';
import 'package:ai_gym/notifications/api.dart';
import 'package:ai_gym/notifications/platform_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'dart:async';

import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/notifications/runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline cold start preserves scheduled reminders', (
    tester,
  ) async {
    final api = FakeNotificationsApi()..failLoad = true;
    final device = FakeNotificationPlatform();
    final c = NotificationController(api: api, platform: device);
    await tester.pumpWidget(
      NotificationRuntime(
        controller: c,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(device.cancelCount, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  test(
    'a delayed load cannot replace settings saved after it started',
    () async {
      final api = FakeNotificationsApi();
      final device = FakeNotificationPlatform();
      final c = NotificationController(api: api, platform: device);
      await c.load();
      final pending = Completer<Map<String, dynamic>>();
      api.inboxPending = pending;
      final refresh = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(await c.save(c.settings.copyWith(waterEnabled: true)), isTrue);
      pending.complete(api.inboxData);
      await refresh;
      expect(c.settings.waterEnabled, isTrue);
      expect(device.last!.waterEnabled, isTrue);
      c.dispose();
    },
  );
  test('resume synchronizes a changed device timezone', () async {
    final api = FakeNotificationsApi();
    final device = FakeNotificationPlatform()..zone = 'Asia/Tokyo';
    final c = NotificationController(api: api, platform: device);
    await c.load();
    expect(api.value.timeZone, 'Asia/Tokyo');
    expect(device.last!.timeZone, 'Asia/Tokyo');
    c.dispose();
  });
  test('late permission approval cannot activate a previous account', () async {
    final api = FakeNotificationsApi();
    final device = FakeNotificationPlatform();
    final c = NotificationController(api: api, platform: device);
    await c.load();
    device.activations.clear();
    final permission = Completer<String?>();
    device.permissionPending = permission;
    final enable = c.enableDevice();
    await Future<void>.delayed(Duration.zero);
    final logout = c.logout();
    api.user = 'account-b';
    final switched = c.load();
    permission.complete(null);
    await Future.wait([enable, logout, switched]);
    expect(device.activations, isNot(contains('account-a')));
    c.dispose();
  });
  test('expired notification sessions require login', () {
    final token =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'userId': 'a', 'exp': 1}))).replaceAll('=', '')}.signature';
    expect(NotificationApi(client: ApiClient()..token = token).owner, isNull);
  });
  test('an old save cannot write settings into the next account', () async {
    final api = FakeNotificationsApi();
    final device = FakeNotificationPlatform();
    final c = NotificationController(api: api, platform: device);
    await c.load();
    final pendingZone = Completer<String>();
    device.zonePending = pendingZone;
    final save = c.save(c.settings.copyWith(waterEnabled: true));
    await Future<void>.delayed(Duration.zero);
    api.user = 'account-b';
    await c.load();
    pendingZone.complete('Asia/Bangkok');
    expect(await save, isFalse);
    expect(api.savedCalls, 0);
    c.dispose();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('off switch blocks local schedules even when saving fails, including after reopen', () async {
    final api = FakeNotificationsApi()
      ..value = const ReminderSettings(waterEnabled: true);
    final device = FakeNotificationPlatform();
    final c = NotificationController(api: api, platform: device);
    await c.load();
    api.failSave = true;
    expect(await c.save(c.settings.copyWith(waterEnabled: false)), isFalse);
    expect(device.last!.waterEnabled, isFalse);
    expect(c.blocked, isTrue);
    final reopenedDevice = FakeNotificationPlatform();
    final reopened = NotificationController(api: api, platform: reopenedDevice);
    await reopened.load();
    expect(reopened.localSettings.waterEnabled, isFalse);
    expect(reopenedDevice.last!.waterEnabled, isFalse);
    c.dispose();
    reopened.dispose();
  });
  test(
    'confirmed server save remains successful when the device scheduler fails',
    () async {
      final api = FakeNotificationsApi();
      final device = FakeNotificationPlatform();
      final c = NotificationController(api: api, platform: device);
      await c.load();
      device.fail = true;
      expect(await c.save(c.settings.copyWith(waterEnabled: true)), isTrue);
      expect(api.value.waterEnabled, isTrue);
      expect(c.deviceMessage, isNotNull);
      c.dispose();
    },
  );
  test('logout clears inbox even if device cleanup fails', () async {
    final device = FakeNotificationPlatform();
    final c = NotificationController(
      api: FakeNotificationsApi(),
      platform: device,
    );
    await c.load();
    expect(c.items, isNotEmpty);
    device.fail = true;
    await c.logout();
    expect(c.items, isEmpty);
    expect(c.unread, 0);
    c.dispose();
  });
  test(
    'reminder defaults are off and editing preserves the remaining schedule',
    () {
      const settings = ReminderSettings();
      expect(settings.workoutEnabled, isFalse);
      expect(settings.waterEnabled, isFalse);
      expect(settings.weeklyEnabled, isFalse);
      final edited = settings.copyWith(
        waterEnabled: true,
        waterIntervalMinutes: 180,
      );
      final restored = ReminderSettings.fromJson(edited.toJson());
      expect(restored.waterEnabled, isTrue);
      expect(restored.waterIntervalMinutes, 180);
      expect(restored.workoutTime, '18:00');
    },
  );
  test('notification links use only recognized destinations', () {
    expect(
      NotificationLink(owner: 'a', kind: 'workout').route,
      startsWith('/workouts'),
    );
    expect(
      NotificationLink(owner: 'a', kind: 'water').route,
      startsWith('/water'),
    );
    expect(
      NotificationLink(owner: 'a', kind: 'weekly').route,
      startsWith('/weekly-report'),
    );
    expect(
      NotificationLink(owner: 'a', kind: 'https://bad.example').route,
      '/notifications',
    );
  });
}

class FakeNotificationsApi extends NotificationApi {
  bool failLoad = false;
  Completer<Map<String, dynamic>>? inboxPending;
  Map<String, dynamic> get inboxData => {
    'items': [
      {
        'id': '1',
        'kind': 'water',
        'title': 'Water',
        'body': 'Reminder',
        'scheduledAtUtc': '2026-10-19T01:00:00Z',
        'readAt': null,
      },
    ],
    'hasMore': false,
    'unreadCount': 1,
  };
  String user = 'account-a';
  int savedCalls = 0;
  ReminderSettings value = const ReminderSettings();
  bool failSave = false;
  @override
  String? get owner => user;
  @override
  Future<ReminderSettings> settings() async {
    if (failLoad) throw Exception('offline');
    return value;
  }

  @override
  Future<ReminderSettings> save(ReminderSettings settings) async {
    savedCalls++;
    if (failSave) throw Exception('offline');
    value = settings.copyWith(revision: value.revision + 1);
    return value;
  }

  @override
  Future<Map<String, dynamic>> inbox(int page) async =>
      inboxPending?.future ?? Future.value(inboxData);
  Map<String, dynamic> get oldFixture => {
    'items': [
      {
        'id': '1',
        'kind': 'water',
        'title': 'Water',
        'body': 'Reminder',
        'scheduledAtUtc': '2026-10-19T01:00:00Z',
        'readAt': null,
      },
    ],
    'hasMore': false,
    'unreadCount': 1,
  };
}

class FakeNotificationPlatform implements NotificationPlatform {
  String zone = 'Asia/Bangkok';
  int cancelCount = 0;
  final activations = <String>[];
  Completer<String?>? permissionPending;
  @override
  Future<String?> requestPermission() async =>
      permissionPending?.future ?? Future.value(null);
  Completer<String>? zonePending;
  ReminderSettings? last;
  bool fail = false;
  @override
  Future<void> initialize(void Function(NotificationLink) open) async {}
  @override
  Future<String> timeZone() async {
    final pending = zonePending;
    zonePending = null;
    return pending?.future ?? Future.value(zone);
  }

  @override
  Future<String?> activate(
    String owner, {
    required bool requestPermission,
  }) async {
    if (requestPermission && permissionPending != null) {
      await permissionPending!.future;
    }
    activations.add(owner);
    return null;
  }

  @override
  Future<void> apply(ReminderSettings settings, String owner) async {
    if (fail) throw Exception('scheduler');
    last = settings;
  }

  @override
  Future<void> deactivate() async {
    cancelCount++;
    if (fail) throw Exception('cleanup');
    last = const ReminderSettings();
  }
}
