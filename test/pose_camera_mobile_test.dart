import 'dart:async';
import 'dart:convert';

import 'package:ai_gym/models/workout.dart';
import 'package:ai_gym/screens/pose_camera_mobile.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fake_camera.dart';

class _StreamCamera extends FakeCamera {
  final frames = StreamController<CameraImageData>.broadcast();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId,
          {CameraImageStreamOptions? options}) =>
      frames.stream;

  void emit() => frames.add(CameraImageData(
        format:
            const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369),
        width: 480,
        height: 640,
        planes: [
          CameraImagePlane(
              bytes: Uint8List(480 * 640 * 4), bytesPerRow: 480 * 4)
        ],
      ));
}

List<Map<String, Object>> _arms(bool extended) => [
      for (final side in [0, 1]) ...[
        {
          'type': 11 + side,
          'x': (side == 0 ? .4 : .6) * 480,
          'y': .45 * 640,
          'z': 0.0,
          'likelihood': 1.0
        },
        {
          'type': 13 + side,
          'x': (side == 0 ? (extended ? .38 : .25) : (extended ? .62 : .75)) *
              480,
          'y': (extended ? .28 : .45) * 640,
          'z': 0.0,
          'likelihood': 1.0
        },
        {
          'type': 15 + side,
          'x': (side == 0 ? (extended ? .36 : .25) : (extended ? .64 : .75)) *
              480,
          'y': (extended ? .11 : .25) * 640,
          'z': 0.0,
          'likelihood': 1.0
        },
      ],
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const detectorChannel = MethodChannel('google_mlkit_pose_detector');
  const ttsChannel = MethodChannel('flutter_tts');
  const speechChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  late CameraPlatform original;
  late _StreamCamera camera;
  var extended = false;
  var failDetection = false;
  var detectorCalls = 0;

  setUp(() {
    original = CameraPlatform.instance;
    camera = _StreamCamera();
    CameraPlatform.instance = camera;
    extended = false;
    failDetection = false;
    detectorCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(detectorChannel, (call) async {
      if (call.method == 'vision#closePoseDetector') return null;
      detectorCalls++;
      if (failDetection) throw PlatformException(code: 'invalid_image');
      return [_arms(extended)];
    });
    messenger.setMockMethodCallHandler(ttsChannel, (_) async => 1);
    messenger.setMockMethodCallHandler(speechChannel, (_) async => true);
  });

  tearDown(() async {
    CameraPlatform.instance = original;
    await camera.frames.close();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [detectorChannel, ttsChannel, speechChannel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets(
      'catalog shoulder press streams landmarks and displays a correct rep',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MobilePoseCameraScreen(
      exercise: Exercise(
          id: 'catalog_42',
          name: 'Đẩy vai',
          description: '',
          sets: 3,
          reps: 10,
          restSeconds: 60,
          level: 'Cơ bản'),
    )));
    await tester.pumpAndSettle();
    final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(selector.initialValue, 'shoulderPress');
    await tester.ensureVisible(find.text('Bắt đầu'));
    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    for (final up in [false, true, false]) {
      extended = up;
      for (var frame = 0; frame < 8; frame++) {
        await tester.runAsync(() async {
          camera.emit();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
    }
    final correctColumn = find
        .ancestor(of: find.text('Đúng form'), matching: find.byType(Column))
        .first;
    expect(find.descendant(of: correctColumn, matching: find.text('1')),
        findsOneWidget);
    expect(camera.audioEnabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'detector failure is visible instead of silently leaving zero reps',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MobilePoseCameraScreen()));
    await tester.pumpAndSettle();
    failDetection = true;
    expect(camera.frames.hasListener, isTrue);
    for (var frame = 0; frame < 3; frame++) {
      await tester.runAsync(() async {
        camera.emit();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }
    expect(detectorCalls, greaterThan(0));
    expect(find.textContaining('Không xử lý được hình ảnh camera'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('unsupported catalog exercise never starts a different counter',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MobilePoseCameraScreen(
      exercise: Exercise(
          id: 'catalog_99',
          name: 'Leg Press',
          description: '',
          sets: 3,
          reps: 10,
          restSeconds: 60,
          level: 'Cơ bản'),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được hỗ trợ đếm rep'), findsOneWidget);
    expect(camera.opened, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'reaching planned reps auto-saves completion and retries the same result',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ApiClient.instance.token = 'test-account';
    addTearDown(() {
      ApiClient.instance.token = null;
      ProfileService.instance.clear();
    });
    final planWrites = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/results')) {
        planWrites.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', planWrites.length == 1 ? 500 : 201);
      }
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: MobilePoseCameraScreen(
        exercise: Exercise(
            id: 'catalog_42',
            name: 'Đẩy vai',
            description: '',
            sets: 1,
            reps: 1,
            restSeconds: 0,
            level: 'Cơ bản',
            planId: 'plan-a',
            planExerciseId: 'exercise-a'),
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu'));
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();
      for (final up in [false, true, false]) {
        extended = up;
        for (var frame = 0; frame < 8; frame++) {
          await tester.runAsync(() async {
            camera.emit();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
      expect(planWrites, hasLength(1));
      expect(planWrites.single['completed'], isTrue);
      expect(planWrites.single['actualSets'], 1);
      expect(planWrites.single['actualReps'], 1);
      expect(find.text('Thử lưu lại'), findsOneWidget);
      expect(find.text('Đã tập xong'), findsNothing);
      await tester.tap(find.text('Thử lưu lại'));
      await tester.pumpAndSettle();
      expect(planWrites, hasLength(2));
      expect(planWrites[1], planWrites[0]);
      expect(find.text('Đã tập xong'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
