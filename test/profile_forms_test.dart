import 'package:ai_gym/screens/settings.dart';
import 'package:ai_gym/screens/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'opening settings loads without rebuilding its previous route during build',
    (tester) => http.runWithClient(() async {
      ApiClient.instance.token = 'test-token';
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: ProfileService.instance,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                child: const Text('Open profile'),
              ),
            ),
          ),
          routes: {'/settings': (_) => const SettingsScreen()},
        ),
      );
      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Lan'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{"fullName":"Lan"}', 200))),
  );

  testWidgets('valid saved height above 220 can be edited', (tester) async {
    ProfileService.instance.profile = {'fullName': 'Lan', 'heightCm': 225};
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('225'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 225);
  });

  tearDown(() {
    ApiClient.instance.token = null;
    ProfileService.instance.clear();
  });

  testWidgets(
    'saved body metrics are restored and failed save keeps form',
    (tester) => http.runWithClient(() async {
      ApiClient.instance.token = 'test-token';
      ProfileService.instance.profile = {
        'fullName': 'Lan',
        'age': 31,
        'heightCm': 165,
        'weightKg': 58.5,
        'gender': 'Nữ',
        'goal': 'Giảm mỡ thừa',
        'trainingDays': 4,
        'trainingLevel': 'Cơ bản',
        'trainingLocation': 'Tại nhà',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: const OnboardingScreen(),
          routes: {'/home': (_) => const Scaffold(body: Text('Dashboard'))},
        ),
      );
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('31'), findsOneWidget);
      expect(find.text('165'), findsOneWidget);
      expect(find.text('58.5'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo kế hoạch của tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsNothing);
      expect(find.textContaining('Không thể lưu hồ sơ'), findsOneWidget);
      expect(find.text('Tạo kế hoạch của tôi'), findsOneWidget);
      expect(ProfileService.instance.profile?['age'], 31);
    }, () => MockClient((_) async => http.Response('{}', 500))),
  );

  testWidgets('empty profile has no demo identity and shows missing metrics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(find.text('Minh Trí'), findsNothing);
    expect(find.text('tri.nguyen@gym.ai'), findsNothing);
    expect(find.text('Chưa có dữ liệu'), findsWidgets);
  });

  testWidgets('skip setup does not require saving profile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const OnboardingScreen(),
        routes: {'/home': (_) => const Scaffold(body: Text('Dashboard'))},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ qua thiết lập'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
