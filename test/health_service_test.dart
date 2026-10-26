import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'package:ai_gym/models/health_workout.dart';
import 'package:ai_gym/services/health_service.dart';

void main() {
  test('normal iOS builds retain health integration by default', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = FakeHealthClient();
    final service = HealthService(client: client);

    expect(
      (await service.requestPermission()).state,
      HealthIntegrationState.ready,
    );
    expect(client.authorizationRequests, 1);
  });

  test('optional iOS fallback never requests HealthKit access', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = FakeHealthClient();
    final service = HealthService(client: client, disableIosHealth: true);

    expect(
      (await service.initialize()).state,
      HealthIntegrationState.unsupported,
    );
    expect(
      (await service.requestPermission()).state,
      HealthIntegrationState.unsupported,
    );
    expect(client.availabilityChecks, 0);
    expect(client.authorizationRequests, 0);
  });

  test('sideload flag preserves Android health integration', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = FakeHealthClient();
    final service = HealthService(client: client, disableIosHealth: true);

    expect(
      (await service.requestPermission()).state,
      HealthIntegrationState.ready,
    );
    expect(client.authorizationRequests, 1);
  });

  test('reports unsupported devices without requesting permissions', () async {
    final client = FakeHealthClient(available: false);
    final service = HealthService(client: client);

    final status = await service.initialize();

    expect(status.state, HealthIntegrationState.unsupported);
    expect(client.authorizationRequests, 0);
  });

  test('deduplicates reads and avoids writing an existing workout', () async {
    final workout = HealthWorkout(
      id: 'health-id',
      activity: 'STRENGTH_TRAINING',
      start: DateTime(2026, 1, 1, 10),
      end: DateTime(2026, 1, 1, 11),
      source: 'Apple Health',
    );
    final client = FakeHealthClient(workouts: [workout, workout]);
    final service = HealthService(client: client);
    await service.initialize();
    await service.requestPermission();

    expect(
      (await service.readWorkouts(start: workout.start, end: workout.end)),
      hasLength(1),
    );
    expect(await service.writeWorkout(workout), isFalse);
    expect(client.writes, isEmpty);
  });
}

class FakeHealthClient implements HealthPlatformClient {
  FakeHealthClient({this.available = true, this.workouts = const []});

  final bool available;
  final List<HealthWorkout> workouts;
  int authorizationRequests = 0;
  int availabilityChecks = 0;
  final List<HealthWorkout> writes = [];

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<bool> requestAuthorization() async {
    authorizationRequests++;
    return true;
  }

  @override
  Future<List<HealthWorkout>> readWorkouts(
    DateTime start,
    DateTime end,
  ) async => workouts;

  @override
  Future<bool> writeWorkout(HealthWorkout workout) async {
    writes.add(workout);
    return true;
  }
}
