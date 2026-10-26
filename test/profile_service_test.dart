import 'dart:async';
import 'dart:convert';

import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class ProfileApi extends ApiClient {
  Future<http.Response> Function()? read;
  int status = 200;
  Map<String, dynamic> stored = {
    'userId': 'a',
    'fullName': 'An',
    'heightCm': 170,
  };
  @override
  Future<http.Response> get(String path, {bool includeAuth = false}) async =>
      read != null ? read!() : http.Response(jsonEncode(stored), status);
  @override
  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    if (status == 200) stored = {...stored, ...body};
    return http.Response(jsonEncode(stored), status);
  }
}

void main() {
  test(
    'a refresh started before editing cannot overwrite the saved name',
    () async {
      final api = ProfileApi()..token = 'a';
      final service = ProfileService(api: api);
      await service.load();
      final pending = Completer<http.Response>();
      api.read = () => pending.future;
      final refresh = service.load();
      await service.save({'fullName': 'Updated'});
      pending.complete(http.Response('{"fullName":"Old"}', 200));
      await refresh;
      expect(service.profile?['fullName'], 'Updated');
      expect(service.loading, isFalse);
    },
  );
  test('saving a workout accepts empty success response then refreshes real totals', () async {
    final api = ApiClient(baseUrl: 'http://localhost')..token = 'a';
    final service = ProfileService(api: api);
    await http.runWithClient(
      () => service.saveWorkout(
        id: 'a3dc1d64-4b82-4ed9-8acd-2875d01cfb9d',
        startedAt: DateTime.utc(2026, 10, 16),
        durationSeconds: 42,
      ),
      () => MockClient((request) async {
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['durationSeconds'], 42);
          expect(request.headers['Authorization'], 'Bearer a');
          return http.Response('', 204);
        }
        return http.Response(
          '{"totalWorkoutSeconds":42,"workoutSessions":1}',
          200,
        );
      }),
    );
    expect(service.profile?['totalWorkoutSeconds'], 42);
    expect(service.profile?['workoutSessions'], 1);
  });
  test('logout discards an in-flight profile response', () async {
    final api = ProfileApi()..token = 'account-a';
    final pending = Completer<http.Response>();
    api.read = () => pending.future;
    final service = ProfileService(api: api);
    final loading = service.load();
    service.clear();
    api.token = 'account-b';
    pending.complete(http.Response('{"userId":"a","fullName":"An"}', 200));
    await loading;
    expect(service.profile, isNull);
    expect(service.loading, isFalse);
  });

  test(
    'editing name preserves body data and failed saves do not change profile',
    () async {
      final api = ProfileApi()..token = 'account-a';
      final service = ProfileService(api: api);
      await service.load();
      await service.save({'fullName': 'Anh'});
      expect(service.profile?['fullName'], 'Anh');
      expect(service.profile?['heightCm'], 170);
      api.status = 500;
      await expectLater(
        service.save({'fullName': 'Wrong'}),
        throwsA(isA<ApiException>()),
      );
      expect(service.profile?['fullName'], 'Anh');
    },
  );

  test(
    'load failure exposes error instead of showing previous account',
    () async {
      final api = ProfileApi()..token = 'account-a';
      final service = ProfileService(api: api);
      await service.load();
      service.clear();
      api.status = 401;
      await service.load();
      expect(service.profile, isNull);
      expect(service.error, isNotNull);
    },
  );
}
