import 'models.dart';

abstract class NotificationPlatform {
  Future<String?> requestPermission();
  Future<void> initialize(void Function(NotificationLink) onOpen);
  Future<String> timeZone();
  Future<String?> activate(String owner, {required bool requestPermission});
  Future<void> apply(ReminderSettings settings, String owner);
  Future<void> deactivate();
}
