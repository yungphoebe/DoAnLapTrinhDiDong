import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_gym/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render the twelve reference screens with real fonts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final fonts = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/roboto-medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final boundaryKey = GlobalKey();
    Future<void> open(String route) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MainApp(key: UniqueKey(), initialRoute: route),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final name in ['avatar', 'workout', 'community', 'trainer']) {
          await precacheImage(
            AssetImage('assets/images/$name.jpg'),
            tester.element(find.byType(MainApp)),
          );
        }
      });
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull, reason: name);
    }

    await open('/login');
    await capture('01-login');
    await open('/register');
    await capture('02-register');
    await open('/forgot');
    await capture('03-forgot-password');
    await open('/onboarding');
    await capture('04-goal');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await capture('05-body-metrics');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await capture('06-schedule');
    await open('/home');
    await capture('07-home');
    await tester.tap(find.text('AI Coach'));
    await tester.pumpAndSettle();
    await capture('08-coach');
    await tester.tap(find.text('Cộng đồng/PT'));
    await tester.pumpAndSettle();
    await capture('09-community');
    await open('/camera');
    await capture('10-camera');
    await open('/settings');
    await capture('11-settings');
    await tester.tap(find.text('Cài đặt AI Coach'));
    await tester.pumpAndSettle();
    await capture('12-coach-settings');
  });
}
