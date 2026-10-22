import 'dart:convert';
import 'dart:js_interop';

import 'api.dart';
import 'models.dart';
import 'platform_contract.dart';

@JS('gymNotifications.init')
external void _init(JSFunction callback);
@JS('gymNotifications.timezone')
external JSString _zone();
@JS('gymNotifications.permission')
external JSPromise<JSString> _permission(JSBoolean request);
@JS('gymNotifications.activate')
external JSPromise<JSString> _activate(JSString owner, JSString key);
@JS('gymNotifications.apply')
external JSPromise<JSAny?> _apply(JSString owner, JSString value);
@JS('gymNotifications.deactivate')
external JSPromise<JSAny?> _deactivate();

NotificationPlatform createNotificationPlatform(NotificationApi api) =>
    BrowserNotificationPlatform(api);

class BrowserNotificationPlatform implements NotificationPlatform {
  @override
  Future<String?> requestPermission() async =>
      (await _permission(true.toJS).toDart).toDart == 'granted'
      ? null
      : 'Chrome chưa cấp quyền thông báo.';
  BrowserNotificationPlatform(this.api);
  final NotificationApi api;
  @override
  Future<void> initialize(void Function(NotificationLink) onOpen) async {
    _init(
      ((JSString value) {
        onOpen(
          NotificationLink.fromJson(
            jsonDecode(value.toDart) as Map<String, dynamic>,
          ),
        );
      }).toJS,
    );
  }

  @override
  Future<String> timeZone() async => _zone().toDart;
  @override
  Future<String?> activate(
    String owner, {
    required bool requestPermission,
  }) async {
    final permission = await _permission(requestPermission.toJS).toDart;
    if (permission.toDart != 'granted') {
      return 'Chrome chưa cấp quyền thông báo. Bấm biểu tượng cài đặt cạnh địa chỉ để cấp quyền.';
    }
    final key = await api.publicKey();
    if (owner != api.owner) {
      return 'Tài khoản đã thay đổi. Hãy bật thông báo lại.';
    }
    final value = await _activate(owner.toJS, key.toJS).toDart;
    if (owner != api.owner) {
      return 'Tài khoản đã thay đổi. Hãy bật thông báo lại.';
    }
    await api.subscribe(jsonDecode(value.toDart) as Map<String, dynamic>);
    return null;
  }

  @override
  Future<void> apply(ReminderSettings settings, String owner) async {
    await _apply(owner.toJS, jsonEncode(settings.toJson()).toJS).toDart;
  }

  @override
  Future<void> deactivate() async {
    final endpoint = await _deactivate().toDart;
    if (endpoint != null && endpoint.isA<JSString>()) {
      try {
        await api.unsubscribe((endpoint as JSString).toDart);
      } catch (_) {}
    }
  }
}
