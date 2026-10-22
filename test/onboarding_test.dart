import 'package:ai_gym/screens/onboarding.dart';
import 'package:ai_gym/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'onboarding retains values on back and updates weekly plan at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: gymTheme(),
          home: const OnboardingScreen(),
          routes: {'/home': (_) => const Scaffold(body: Text('Dashboard'))},
        ),
      );
      await tester.tap(find.text('Giảm mỡ thừa'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tăng tuổi'));
      await tester.pump();
      expect(find.text('25'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 buổi'));
      await tester.pump();
      await tester.ensureVisible(find.textContaining('4 buổi/tuần'));
      expect(find.textContaining('4 buổi/tuần'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('25'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 buổi/tuần'), findsOneWidget);
      await tester.tap(find.text('Tạo kế hoạch của tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    },
  );
}
