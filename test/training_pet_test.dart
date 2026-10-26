import 'package:ai_gym/widgets/training_pet.dart';
import 'package:ai_gym/screens/shell.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pet appears on home only and hides on workout routes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (call) async => call.method == 'initialize' ? true : null,
    );
    ProfileService.instance.profile = {
      'todayWorkoutSeconds': 0,
      'streakDays': 4
    };
    addTearDown(() {
      ProfileService.instance.clear();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugin.csdcorp.com/speech_to_text'), null);
    });
    await tester.pumpWidget(MaterialApp(
      home: const AppShell(),
      routes: {
        '/camera': (_) =>
            Scaffold(appBar: AppBar(title: const Text('Camera test')))
      },
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('chuỗi 4 ngày'), findsOneWidget);
    await tester.tap(find.byTooltip('Thu gọn lời nhắc'));
    await tester.tap(find.text('Cộng đồng/PT'));
    await tester.pumpAndSettle();
    // Let the existing offline community snackbar finish before tapping the pet.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(GymMascot), findsNothing);
    expect(find.textContaining('chuỗi 4 ngày'), findsNothing);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.byType(GymMascot), findsOneWidget);
    await tester.tap(find.text('Tập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Camera test'), findsOneWidget);
    expect(find.byType(GymMascot), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(GymMascot), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  Widget host(
          {String message = 'Tập 5 phút nhé!',
          bool trained = false,
          bool roast = false,
          bool progressKnown = true,
          double textScale = 1,
          VoidCallback? onStart,
          VoidCallback? onSettings}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
            body: Stack(children: [
          const Positioned.fill(child: Center(child: Text('Nội dung app'))),
          TrainingPet(
              message: message,
              trained: trained,
              roast: roast,
              progressKnown: progressKnown,
              onStart: onStart ?? () {},
              onSettings: onSettings ?? () {}),
        ])),
      );

  testWidgets('pet greets, collapses and reopens its speech bubble',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Tập 5 phút nhé!'), findsOneWidget);
    await tester.tap(find.byTooltip('Thu gọn lời nhắc'));
    await tester.pumpAndSettle();
    expect(find.text('Tập 5 phút nhé!'), findsNothing);
    await tester.tap(find.byTooltip('Trò chuyện với GYM BUDDY'));
    await tester.pumpAndSettle();
    expect(find.text('Tập 5 phút nhé!'), findsOneWidget);
  });

  testWidgets(
      'greeting becomes reminder, teasing is opt-in, collapse becomes idle',
      (tester) async {
    await tester.pumpWidget(host());
    expect(tester.widget<GymMascot>(find.byType(GymMascot)).mood,
        PetMood.greeting);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<GymMascot>(find.byType(GymMascot)).mood,
        PetMood.reminding);
    await tester.pumpWidget(host(roast: true));
    expect(
        tester.widget<GymMascot>(find.byType(GymMascot)).mood, PetMood.teasing);
    await tester.tap(find.byTooltip('Thu gọn lời nhắc'));
    await tester.pump();
    expect(tester.widget<GymMascot>(find.byType(GymMascot)).mood, PetMood.idle);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'unknown progress never uses teasing and saved workouts celebrate',
      (tester) async {
    await tester.pumpWidget(host(roast: true, progressKnown: false));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<GymMascot>(find.byType(GymMascot)).mood,
        PetMood.greeting);
    await tester.pumpWidget(host(trained: true, roast: true));
    expect(tester.widget<GymMascot>(find.byType(GymMascot)).mood,
        PetMood.celebrating);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sprite animates and stops when reduced motion is requested',
      (tester) async {
    Widget scene(bool reduce) => MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: const GymMascot(mood: PetMood.reminding),
        ));
    await tester.pumpWidget(scene(false));
    final before = tester
        .widget<Transform>(find.byKey(const Key('fox-sprite-frame')))
        .transform;
    await tester.pump(const Duration(milliseconds: 220));
    final after = tester
        .widget<Transform>(find.byKey(const Key('fox-sprite-frame')))
        .transform;
    expect(after, isNot(before));
    await tester.pumpWidget(scene(true));
    final still = tester
        .widget<Transform>(find.byKey(const Key('fox-sprite-frame')))
        .transform;
    await tester.pump(const Duration(seconds: 1));
    expect(
        tester
            .widget<Transform>(find.byKey(const Key('fox-sprite-frame')))
            .transform,
        still);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bubble actions invoke workout and tone settings',
      (tester) async {
    var starts = 0, settings = 0;
    await tester.pumpWidget(
        host(onStart: () => starts++, onSettings: () => settings++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập ngay'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    await tester.tap(find.byTooltip('Trò chuyện với GYM BUDDY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh giọng bot'));
    expect(settings, 1);
  });

  testWidgets('sprite stops offstage and while app is in background',
      (tester) async {
    Widget scene(bool enabled) => MaterialApp(
        home: TickerMode(
            enabled: enabled, child: const GymMascot(mood: PetMood.idle)));
    Matrix4 frame() => tester
        .widget<Transform>(find.byKey(const Key('fox-sprite-frame')))
        .transform;
    await tester.pumpWidget(scene(false));
    final offstage = frame();
    await tester.pump(const Duration(milliseconds: 440));
    expect(frame(), offstage);
    await tester.pumpWidget(scene(true));
    await tester.pump(const Duration(milliseconds: 220));
    expect(frame(), isNot(offstage));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = frame();
    await tester.pump(const Duration(milliseconds: 440));
    expect(frame(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 220));
    expect(frame(), isNot(paused));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saved workout reopens a collapsed bubble with praise',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thu gọn lời nhắc'));
    await tester
        .pumpWidget(host(message: 'Hôm nay bạn đã tập 5 phút!', trained: true));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay bạn đã tập 5 phút!'), findsOneWidget);
    expect(find.text('Xem buổi tập'), findsOneWidget);
  });

  testWidgets('small screen and large text stay within bounds', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
          textScale: 2,
          message: 'Bạn đang có chuỗi 14 ngày. Đừng để chiếc ghế thắng bạn! '
              'Lướt điện thoại đủ rồi, dậy tập 5 phút coi.'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(find.byTooltip('Trò chuyện với GYM BUDDY')).dx,
        lessThanOrEqualTo(320));
  });
}
