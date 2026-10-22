import 'package:ai_gym/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell preserves community state across tabs at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MainApp(initialRoute: '/home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cộng đồng/PT'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('community-like')));
    await tester.tap(find.byKey(const Key('community-like')));
    await tester.pumpAndSettle();
    expect(find.text('129'), findsOneWidget);
    await tester.tap(find.text('AI Coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cộng đồng/PT'));
    await tester.pumpAndSettle();
    expect(find.text('129'), findsOneWidget);
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt hệ thống'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
