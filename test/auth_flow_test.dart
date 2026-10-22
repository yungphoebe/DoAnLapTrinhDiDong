import 'package:ai_gym/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
  }

  testWidgets('empty login stays on form with validation feedback', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Vào phòng tập ngay'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vui lòng nhập email hoặc số điện thoại.'),
      findsOneWidget,
    );
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(find.text('TỔNG QUAN HÔM NAY'), findsNothing);
  });

  testWidgets('registration validates confirmation then completes onboarding', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name-field')), 'Minh Trí');
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'tri@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(find.byKey(const Key('confirm-field')), 'different');
    await tester.tap(find.text('Bắt đầu hành trình'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('confirm-field')),
      'password123',
    );
    await tester.tap(find.text('Bắt đầu hành trình'));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu chính của bạn là gì?'), findsOneWidget);
    await tester.tap(find.text('Giảm mỡ thừa'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin cơ thể của bạn'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Phong cách tập & Lịch trình'), findsOneWidget);
    await tester.tap(find.text('4 buổi'));
    await tester.pump();
    expect(find.textContaining('4 buổi/tuần'), findsOneWidget);
    await tester.tap(find.text('Tạo kế hoạch của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('TỔNG QUAN HÔM NAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo account signs in with the updated email and password', (
    tester,
  ) async {
    await openApp(tester);
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'admin123@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      '123123123Az!',
    );
    await tester.tap(find.text('Vào phòng tập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('TỔNG QUAN HÔM NAY'), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsNothing);
  });

  testWidgets('demo account rejects the previous password', (tester) async {
    await openApp(tester);
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'admin123@gmail.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), '123');
    await tester.tap(find.text('Vào phòng tập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu chưa đúng.'), findsOneWidget);
    expect(find.text('Email hoặc số điện thoại chưa hợp lệ.'), findsNothing);
    expect(find.text('TỔNG QUAN HÔM NAY'), findsNothing);
  });

  testWidgets('previous demo credentials no longer sign in', (tester) async {
    await openApp(tester);
    await tester.enterText(find.byKey(const Key('email-field')), 'admin123');
    await tester.enterText(find.byKey(const Key('password-field')), '123');
    await tester.tap(find.text('Vào phòng tập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc số điện thoại chưa hợp lệ.'), findsOneWidget);
    expect(find.text('TỔNG QUAN HÔM NAY'), findsNothing);
  });

  testWidgets('email login still opens the demo', (tester) async {
    await openApp(tester);
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'tri@example.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), 'demo');
    await tester.tap(find.text('Vào phòng tập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('TỔNG QUAN HÔM NAY'), findsOneWidget);
  });

  testWidgets('bare username is not a registration or password reset contact', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email-field')), 'admin123');
    await tester.tap(find.text('Gửi OTP xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc số điện thoại chưa hợp lệ.'), findsOneWidget);
    expect(find.textContaining('Chưa gửi OTP'), findsNothing);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name-field')), 'Admin');
    await tester.enterText(find.byKey(const Key('email-field')), 'admin123');
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-field')),
      'password123',
    );
    await tester.tap(find.text('Bắt đầu hành trình'));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc số điện thoại chưa hợp lệ.'), findsOneWidget);
    expect(find.text('Mục tiêu chính của bạn là gì?'), findsNothing);
  });

  testWidgets('password reset requires contact and shows demo outcome', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi OTP xác nhận'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vui lòng nhập email hoặc số điện thoại.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'tri@example.com',
    );
    await tester.tap(find.text('Gửi OTP xác nhận'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa gửi OTP'), findsOneWidget);
  });
}
