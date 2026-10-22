import 'package:ai_gym/support/api.dart';
import 'package:ai_gym/support/screens.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FakeSupport extends SupportApi {
  bool fail = true;
  final ids = <String>[];
  @override
  Future<Map<String, dynamic>> content() async => {
    'guide': null,
    'terms': null,
    'privacy': null,
    'groupName': null,
  };
  @override
  Future<String> feedback(String id, String subject, String content) async {
    ids.add(id);
    if (fail) throw ApiException(500, 'Chưa gửi được phản hồi.');
    return id;
  }
}

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'AI GYM',
      packageName: 'com.aigym.ai_gym',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );
  testWidgets(
    'help displays real version and explicitly missing official content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SupportScreen(api: FakeSupport())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phiên bản 0.1.0 (1)'), findsOneWidget);
      expect(find.text('Nhóm chưa cung cấp nội dung'), findsNWidgets(3));
      await tester.tap(find.text('Điều khoản sử dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Nhóm chưa cung cấp nội dung'), findsOneWidget);
    },
  );
  testWidgets(
    'failed feedback keeps content and retry gets a server acknowledgement',
    (tester) async {
      final api = FakeSupport();
      await tester.pumpWidget(MaterialApp(home: FeedbackScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('feedback-content')),
        'Nội dung cần hỗ trợ',
      );
      await tester.ensureVisible(find.byKey(const Key('send-feedback')));
      await tester.tap(find.byKey(const Key('send-feedback')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback-content')))
            .controller!
            .text,
        'Nội dung cần hỗ trợ',
      );
      api.fail = false;
      await tester.tap(find.byKey(const Key('send-feedback')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback-success')), findsOneWidget);
      expect(api.ids[0], api.ids[1]);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('feedback-content')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  testWidgets('blank feedback does not submit', (tester) async {
    final api = FakeSupport();
    await tester.pumpWidget(MaterialApp(home: FeedbackScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('send-feedback')));
    await tester.tap(find.byKey(const Key('send-feedback')));
    await tester.pumpAndSettle();
    expect(api.ids, isEmpty);
    expect(find.text('Vui lòng nhập nội dung phản hồi.'), findsOneWidget);
  });
}
