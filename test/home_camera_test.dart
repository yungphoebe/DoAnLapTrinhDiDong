import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_gym/screens/camera.dart';
import 'package:ai_gym/screens/home.dart';
import 'package:ai_gym/ui.dart';
import 'package:ai_gym/services/lm_studio_service.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera/camera.dart' show CameraPreview;

import 'helpers/fake_camera.dart';

void main() {
  late FakeCamera camera;
  late CameraPlatform original;
  setUp(() {
    original = CameraPlatform.instance;
    camera = FakeCamera();
    CameraPlatform.instance = camera;
  });
  tearDown(() => CameraPlatform.instance = original);
  testWidgets('completed session retries the same record after save failure', (
    tester,
  ) async {
    ApiClient.instance.token = 'account-a';
    addTearDown(() {
      ApiClient.instance.token = null;
      ProfileService.instance.clear();
    });
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', sent.length == 1 ? 500 : 204);
      }
      return http.Response('{"workoutSessions":1}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CameraScreen()));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu phân tích'));
      await tester.tap(find.text('Bắt đầu phân tích'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.tap(find.text('KẾT THÚC'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lưu lại'), findsOneWidget);
      await tester.tap(find.text('Thử lưu lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu vào tài khoản của bạn.'), findsOneWidget);
      expect(sent, hasLength(2));
      expect(sent[1], sent[0]);
      expect(sent[0]['durationSeconds'], greaterThanOrEqualTo(1));
      expect(ProfileService.instance.profile?['workoutSessions'], 1);
      await tester.pumpWidget(const SizedBox());
    }, () => client);
  });
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
        expect(find.text('Camera AI'), findsOneWidget);
        expect(camera.opened, 1);
        expect(camera.audioEnabled, isFalse);
        await tester.ensureVisible(find.text('Bắt đầu phân tích'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bắt đầu phân tích'));
        await tester.pump();
        await tester.tap(find.text('Tạm dừng'));
        await tester.pump();
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(find.text('Đã tạm dừng'), findsOneWidget);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        expect(find.text('Tạm dừng'), findsOneWidget);
        await tester.tap(find.text('KẾT THÚC'));
        await tester.pumpAndSettle();
        expect(find.text('Hoàn thành buổi tập'), findsOneWidget);
        expect(camera.released, 1);
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
        expect(find.text('Xin chào'), findsOneWidget);
      },
    );
  }

  testWidgets('nutrition action explains demo scope at 320px', (tester) async {
    await openHome(tester, width: 320);
    await tester.tap(find.text('Quét Dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Chưa có dữ liệu. Tính năng phân tích bữa ăn'),
      findsOneWidget,
    );
  });

  testWidgets('denied camera can be retried without starting analysis', (
    tester,
  ) async {
    camera.denied = true;
    await tester.pumpWidget(MaterialApp(home: const CameraScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quyền camera bị từ chối'), findsOneWidget);
    camera.denied = false;
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(camera.opened, 1);
    expect(find.textContaining('Quyền camera bị từ chối'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(camera.released, 1);
  });

  testWidgets('missing camera shows recovery instead of demo footage', (
    tester,
  ) async {
    camera.noCamera = true;
    await tester.pumpWidget(MaterialApp(home: const CameraScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tìm thấy camera'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'portrait camera preview preserves its orientation aspect ratio',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CameraScreen()));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CameraPreview)).aspectRatio,
        closeTo(0.75, 0.001),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('closing while initialization is pending releases the camera', (
    tester,
  ) async {
    camera.opening = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: const CameraScreen()));
    await tester.pump();
    expect(camera.opened, 1);
    await tester.pumpWidget(const SizedBox());
    camera.opening!.complete();
    await tester.pump();
    expect(camera.released, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background releases camera and foreground reopens it', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: const CameraScreen()));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(camera.released, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.opened, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(camera.released, 2);
  });

  testWidgets('camera disconnect shows an error and retry action', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: const CameraScreen()));
    await tester.pumpAndSettle();
    camera.errors.add(CameraErrorEvent(1, 'Camera disconnected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera disconnected'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'closing during capture waits for image and removes temporary file',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'ai-gym-camera-test-',
      );
      final file = File('${directory.path}/capture.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
        directory.deleteSync();
      });
      camera.picture = Completer<XFile>();
      await tester.pumpWidget(
        MaterialApp(home: CameraScreen(ai: FakeVision())),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu phân tích'));
      await tester.tap(find.text('Bắt đầu phân tích'));
      await tester.pump();
      expect(camera.captures, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(camera.released, 0);
      camera.picture!.complete(XFile(file.path));
      for (var i = 0; i < 100 && camera.released == 0; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pump();
      expect(camera.released, 1);
      expect(file.existsSync(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera frames reach AI, render feedback, repeat and pause', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'ai-gym-frames-test-',
    );
    addTearDown(() {
      for (final file in directory.listSync()) {
        file.deleteSync();
      }
      directory.deleteSync();
    });
    camera.capture = () async {
      final file = File('${directory.path}/${camera.captures}.jpg');
      file.writeAsBytesSync([1, 2, 3]);
      return XFile(file.path);
    };
    final ai = FakeVision();
    await tester.pumpWidget(MaterialApp(home: CameraScreen(ai: ai)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bắt đầu phân tích'));
    await tester.tap(find.text('Bắt đầu phân tích'));
    Future<void> waitForFrames(int count) async {
      for (var i = 0; i < 100 && ai.requests < count; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pump();
      expect(ai.requests, count);
    }

    await waitForFrames(1);
    expect(ai.received, [1, 2, 3]);
    expect(find.text('Đưa toàn thân vào khung hình'), findsOneWidget);
    expect(directory.listSync(), isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await waitForFrames(2);
    await tester.ensureVisible(find.text('Tạm dừng'));
    await tester.tap(find.text('Tạm dừng'));
    await tester.pump(const Duration(seconds: 6));
    expect(camera.captures, 2);
    await tester.tap(find.text('Tiếp tục'));
    await waitForFrames(3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(camera.released, 1);
    expect(directory.listSync(), isEmpty);
  });
}

class FakeVision extends LMStudioService {
  Uint8List? received;
  int requests = 0;
  @override
  Future<List<String>> getModels() async => ['vision-test'];

  @override
  Future<String> analyzeImage({
    required String modelId,
    required String prompt,
    required Uint8List imageBytes,
  }) async {
    received = imageBytes;
    requests++;
    return 'Đưa toàn thân vào khung hình';
  }
}
