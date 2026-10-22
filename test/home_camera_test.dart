import 'package:ai_gym/screens/camera.dart';
import 'package:ai_gym/screens/home.dart';
import 'package:ai_gym/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openHome(WidgetTester tester, {double width = 402}) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: gymTheme(),
        home: const Scaffold(body: HomeScreen()),
        routes: {'/camera': (_) => const CameraScreen()},
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [402.0, 320.0]) {
    testWidgets(
      'form session pauses, resumes, and returns home at ${width.toInt()}px',
      (tester) async {
        await openHome(tester, width: width);
        await tester.tap(find.text('Nhận diện Form'));
        await tester.pumpAndSettle();
        expect(find.text('Barbell Squat'), findsOneWidget);
        await tester.tap(find.text('Tạm dừng'));
        await tester.pump();
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(find.text('Đã tạm dừng'), findsOneWidget);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        expect(find.text('Tạm dừng'), findsOneWidget);
        await tester.tap(find.text('KẾT THÚC'));
        await tester.pumpAndSettle();
        expect(find.text('Hoàn thành buổi tập mẫu'), findsOneWidget);
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
        expect(find.text('Xin chào, Jang'), findsOneWidget);
      },
    );
  }

  testWidgets('nutrition action explains demo scope at 320px', (tester) async {
    await openHome(tester, width: 320);
    await tester.tap(find.text('Quét Dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(find.text('Phân tích bữa ăn mẫu'), findsOneWidget);
    expect(find.textContaining('chưa kết nối camera'), findsOneWidget);
  });
}
