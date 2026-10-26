import 'dart:convert';

import 'package:ai_gym/screens/home.dart';
import 'package:ai_gym/screens/coach.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('coach starts without invented user history or progress', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CoachScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Minh Trí'), findsNothing);
    expect(find.textContaining('80kg'), findsNothing);
    expect(find.textContaining('45%'), findsNothing);
  });
  tearDown(() {
    ApiClient.instance.token = null;
    ProfileService.instance.clear();
  });
  testWidgets(
    'home shows current account and saved session progress without demo metrics',
    (tester) async {
      ApiClient.instance.token = 'a';
      await http.runWithClient(
        () => ProfileService.instance.load(),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'fullName': 'Lan',
              'streakDays': 2,
              'workoutSessions': 3,
              'todayWorkoutSeconds': 120,
              'totalWorkoutSeconds': 600,
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Lan'), findsOneWidget);
      expect(find.text('2 Ngày'), findsOneWidget);
      expect(find.text('2 phút'), findsOneWidget);
      expect(find.text('320'), findsNothing);
      expect(find.text('65%'), findsNothing);
      expect(find.textContaining('Chưa có dữ liệu'), findsWidgets);
      ProfileService.instance.clear();
      await tester.pump();
      expect(find.textContaining('Lan'), findsNothing);
    },
  );
}
