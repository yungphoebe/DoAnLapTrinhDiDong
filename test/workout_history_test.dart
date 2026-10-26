import 'dart:convert';
import 'dart:async';

import 'package:ai_gym/screens/workout_history.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'history shows stored exercise totals',
    (tester) => http.runWithClient(
      () async {
        ApiClient.instance.token = 'account-a';
        await tester.pumpWidget(
          const MaterialApp(home: WorkoutHistoryScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('3 lần · 2 đúng · 1 cần sửa'), findsOneWidget);
        expect(find.text('0 phút 40 giây'), findsOneWidget);
        expect(find.text('knees in: 1'), findsOneWidget);
      },
      () => MockClient(
        (_) async => http.Response(
          '[{"startedAt":"2026-10-16T00:00:00Z","durationSeconds":40,"exercises":[{"exercise":"squat","reps":3,"correctReps":2,"incorrectReps":1}],"feedbackCounts":{"knees_in":1}}]',
          200,
        ),
      ),
    ),
  );
  tearDown(() {
    ApiClient.instance.token = null;
    ProfileService.instance.clear();
  });
  test('workout summary is sent with authenticated request', () async {
    final api = ApiClient(baseUrl: 'http://localhost')..token = 'account-a';
    await http.runWithClient(
      () => ProfileService(api: api).saveWorkout(
        id: 'id',
        startedAt: DateTime.utc(2026),
        durationSeconds: 40,
        exercises: [
          {
            'exercise': 'squat',
            'reps': 3,
            'correctReps': 2,
            'incorrectReps': 1,
          },
        ],
        feedbackCounts: {'knees_in': 1},
      ),
      () => MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.headers['Authorization'], 'Bearer account-a');
          final body = jsonDecode(request.body);
          expect(body['exercises'][0]['correctReps'], 2);
          expect(body['feedbackCounts']['knees_in'], 1);
          return http.Response('', 204);
        }
        return http.Response('{}', 200);
      }),
    );
  });
  testWidgets(
    'history displays empty result',
    (tester) => http.runWithClient(
      () async {
        ApiClient.instance.token = 'account-a';
        await tester.pumpWidget(
          const MaterialApp(home: WorkoutHistoryScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chưa có phiên tập nào được lưu.'), findsOneWidget);
      },
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer account-a');
        expect(request.url.path, '/api/profile/workouts');
        return http.Response('[]', 200);
      }),
    ),
  );
  testWidgets(
    'failed history shows retry',
    (tester) => http.runWithClient(() async {
      ApiClient.instance.token = 'account-a';
      await tester.pumpWidget(const MaterialApp(home: WorkoutHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{}', 500))),
  );
  final pendingHistory = Completer<http.Response>();
  testWidgets(
    'history discards response after account changes',
    (tester) => http.runWithClient(() async {
      ApiClient.instance.token = 'account-a';
      await tester.pumpWidget(const MaterialApp(home: WorkoutHistoryScreen()));
      await tester.pump();
      ApiClient.instance.token = 'account-b';
      ProfileService.instance.clear();
      pendingHistory.complete(
        http.Response(
          '[{"startedAt":"2026-10-16T00:00:00Z","durationSeconds":40,"exercises":[{"exercise":"squat","reps":3,"correctReps":2,"incorrectReps":1}],"feedbackCounts":{}}]',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Squat'), findsNothing);
    }, () => MockClient((_) => pendingHistory.future)),
  );
}
