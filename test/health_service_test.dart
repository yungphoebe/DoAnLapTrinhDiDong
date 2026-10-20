import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gym/models/health_workout.dart';
import 'package:ai_gym/services/health_service.dart';

void main() {
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
      (await service.readWorkouts(
        start: workout.start,
        end: workout.end,
      )),
      hasLength(1),
    );
    expect(await service.writeWorkout(workout), isFalse);
    expect(client.writes, isEmpty);
  });
}

class FakeHealthClient implements HealthPlatformClient {
  FakeHealthClient({
    this.available = true,
    this.workouts = const [],
  });

  final bool available;
  final List<HealthWorkout> workouts;
  int authorizationRequests = 0;
  final List<HealthWorkout> writes = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> requestAuthorization() async {
    authorizationRequests++;
    return true;
  }

  @override
  Future<List<HealthWorkout>> readWorkouts(DateTime start, DateTime end) async =>
      workouts;

  @override
  Future<bool> writeWorkout(HealthWorkout workout) async {
    writes.add(workout);
    return true;
  }
}
