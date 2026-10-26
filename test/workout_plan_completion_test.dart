import 'dart:convert';
import 'package:ai_gym/screens/workout_plans.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
      'returning from camera reloads persisted completion and retains it on reopen',
      (tester) async {
    ApiClient.instance.token = 'test-account';
    addTearDown(() {
      ApiClient.instance.token = null;
      ProfileService.instance.clear();
    });
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = false;
    var loads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/workout-plans') {
        loads++;
        return http.Response(
            jsonEncode([
              {
                'id': 'plan-a',
                'name': 'Kế hoạch thử',
                'daysPerWeek': 1,
                'sessionMinutes': 20,
                'level': 'Cơ bản',
                'exercises': [
                  {
                    'id': 'exercise-a',
                    'exerciseId': 42,
                    'exerciseName': 'Đẩy vai',
                    'dayNumber': 1,
                    'sets': 1,
                    'reps': 1,
                    'restSeconds': 0,
                    'results': completed
                        ? [
                            {'completed': true}
                          ]
                        : [],
                  }
                ],
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 200);
    });
    Widget app() => MaterialApp(home: const WorkoutPlansScreen(), routes: {
          '/camera': (context) => Scaffold(
                  body: TextButton(
                onPressed: () {
                  completed = true;
                  Navigator.pop(context, true);
                },
                child: const Text('Lưu bài đã hoàn thành'),
              )),
        });
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byTooltip('Bắt đầu bài tập này'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Đã tập xong'), findsNothing);
      await tester.tap(find.byTooltip('Bắt đầu bài tập này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu bài đã hoàn thành'));
      await tester.pumpAndSettle();
      expect(loads, 2);
      await tester.scrollUntilVisible(find.byTooltip('Tập lại bài này'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Đã tập xong'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Tập lại bài này'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Đã tập xong'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => client);
  });
}
