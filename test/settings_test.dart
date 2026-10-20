import 'package:ai_gym/screens/settings.dart';
import 'package:ai_gym/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'saved coach choices survive reopening and cancel discards edits',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: gymTheme(),
          home: const SettingsScreen(),
          routes: {'/coach-settings': (_) => const CoachSettingsScreen()},
        ),
      );
      await tester.scrollUntilVisible(find.text('Cài đặt AI Coach'), 300);
      await tester.tap(find.text('Cài đặt AI Coach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nữ nhẹ nhàng'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Giọng: Nữ nhẹ nhàng'), findsOneWidget);
      await tester.tap(find.text('Cài đặt AI Coach'));
      await tester.pumpAndSettle();
      final selected = tester.widget<ChoiceTile>(
        find.widgetWithText(ChoiceTile, 'Nữ nhẹ nhàng'),
      );
      expect(selected.selected, isTrue);
      await tester.tap(find.text('Nam trầm'));
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Giọng: Nữ nhẹ nhàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
