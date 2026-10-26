import 'package:ai_gym/notifications/models.dart';
import 'package:ai_gym/notifications/controller.dart';
import 'package:ai_gym/notifications/settings_screen.dart';
import 'package:ai_gym/notifications/training_bot_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications_test.dart'
    show FakeNotificationsApi, FakeNotificationPlatform;

void main() {
  testWidgets('user can opt into teasing without changing the workout schedule',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = FakeNotificationsApi()
      ..value =
          const ReminderSettings(workoutEnabled: true, workoutTime: '19:30');
    final platform = FakeNotificationPlatform();
    final controller = NotificationController(api: api, platform: platform);
    await tester.pumpWidget(
        MaterialApp(home: ReminderSettingsScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bot cà khịa'));
    await tester.tap(find.text('Bot cà khịa'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu lịch nhắc'), 400);
    await tester.tap(find.text('Lưu lịch nhắc'));
    await tester.pumpAndSettle();
    expect(api.value.botRoastEnabled, isTrue);
    expect(api.value.workoutEnabled, isTrue);
    expect(api.value.workoutTime, '19:30');
    expect(platform.last!.botRoastEnabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('unknown progress does not accuse the user of skipping a workout', () {
    expect(trainingBotMessage(null, roast: true), contains('Chưa có dữ liệu'));
  });
  test('even a short saved workout receives encouragement', () {
    for (final seconds in [1, 59, 60, 1199, 1200]) {
      for (final roast in [false, true]) {
        expect(
            trainingBotMessage({'todayWorkoutSeconds': seconds}, roast: roast),
            contains('đã tập'));
      }
    }
  });
  test('streak and tone are used only when no workout is recorded', () {
    final profile = {'todayWorkoutSeconds': 0, 'streakDays': 4};
    expect(trainingBotMessage(profile), contains('4 ngày'));
    expect(trainingBotMessage(profile, roast: true), contains('chiếc ghế'));
    expect(trainingBotMessage(profile), isNot(contains('chiếc ghế')));
  });
  test('teasing is opt-in and survives settings edits and serialization', () {
    expect(ReminderSettings.fromJson({}).botRoastEnabled, isFalse);
    final settings = const ReminderSettings(botRoastEnabled: true)
        .copyWith(workoutTime: '19:00');
    expect(
        ReminderSettings.fromJson(settings.toJson()).botRoastEnabled, isTrue);
    expect(settings.copyWith(botRoastEnabled: false).botRoastEnabled, isFalse);
  });
  test('workout notification opens the workout camera directly', () {
    expect(
        const NotificationLink(owner: 'a', kind: 'workout').route, '/camera');
    expect(
        const NotificationLink(owner: 'a', kind: 'workout', at: '2026-10-25')
            .route,
        '/camera');
  });
}
