import 'package:health/health.dart';

import '../models/health_workout.dart';

abstract interface class HealthPlatformClient {
  Future<bool> isAvailable();
  Future<bool> requestAuthorization();
  Future<List<HealthWorkout>> readWorkouts(DateTime start, DateTime end);
  Future<bool> writeWorkout(HealthWorkout workout);
}

class HealthService {
  HealthService({HealthPlatformClient? client})
      : _client = client ?? HealthPlatformClientAdapter();

  final HealthPlatformClient _client;
  HealthIntegrationStatus status = const HealthIntegrationStatus(
    HealthIntegrationState.permissionRequired,
  );
  final Set<String> _knownWorkoutIds = <String>{};

  Future<HealthIntegrationStatus> initialize() async {
    try {
      if (!await _client.isAvailable()) {
        return status = const HealthIntegrationStatus(
          HealthIntegrationState.unsupported,
          message: 'Health data is not available on this device.',
        );
      }
      return status = const HealthIntegrationStatus(
        HealthIntegrationState.permissionRequired,
      );
    } catch (error) {
      return status = HealthIntegrationStatus(
        HealthIntegrationState.error,
        message: error.toString(),
      );
    }
  }

  Future<HealthIntegrationStatus> requestPermission() async {
    try {
      if (!await _client.isAvailable()) {
        return status = const HealthIntegrationStatus(
          HealthIntegrationState.unsupported,
        );
      }
      final granted = await _client.requestAuthorization();
      return status = granted
          ? const HealthIntegrationStatus(HealthIntegrationState.ready)
          : const HealthIntegrationStatus(
              HealthIntegrationState.permissionDenied,
            );
    } catch (error) {
      return status = HealthIntegrationStatus(
        HealthIntegrationState.error,
        message: error.toString(),
      );
    }
  }

  Future<List<HealthWorkout>> readWorkouts({
    required DateTime start,
    required DateTime end,
  }) async {
    _ensureReady();
    try {
      final unique = <String, HealthWorkout>{};
      for (final workout in await _client.readWorkouts(start, end)) {
        unique[workout.deduplicationKey] = workout;
        _knownWorkoutIds.add(workout.deduplicationKey);
      }
      return unique.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    } catch (error) {
      status = HealthIntegrationStatus(
        HealthIntegrationState.error,
        message: error.toString(),
      );
      rethrow;
    }
  }

  Future<bool> writeWorkout(HealthWorkout workout) async {
    _ensureReady();
    if (_knownWorkoutIds.contains(workout.deduplicationKey)) return false;
    final existing = await readWorkouts(
      start: workout.start.subtract(const Duration(seconds: 1)),
      end: workout.end.add(const Duration(seconds: 1)),
    );
    if (existing.any((other) => _sameWorkout(other, workout))) return false;
    try {
      final written = await _client.writeWorkout(workout);
      if (written) _knownWorkoutIds.add(workout.deduplicationKey);
      return written;
    } catch (error) {
      status = HealthIntegrationStatus(
        HealthIntegrationState.error,
        message: error.toString(),
      );
      rethrow;
    }
  }

  bool _sameWorkout(HealthWorkout a, HealthWorkout b) =>
      a.activity == b.activity &&
      a.start.toUtc() == b.start.toUtc() &&
      a.end.toUtc() == b.end.toUtc();

  void _ensureReady() {
    if (!status.canUse) {
      throw StateError('Health service is not ready: ${status.state.name}');
    }
  }
}

class HealthPlatformClientAdapter implements HealthPlatformClient {
  HealthPlatformClientAdapter({Health? health}) : _health = health ?? Health();

  final Health _health;
  static const _types = <HealthDataType>[HealthDataType.WORKOUT];

  @override
  Future<bool> isAvailable() async {
    await _health.configure();
    return _health.isHealthConnectAvailable();
  }

  @override
  Future<bool> requestAuthorization() => _health.requestAuthorization(
        _types,
        permissions: const [HealthDataAccess.READ_WRITE],
      );

  @override
  Future<List<HealthWorkout>> readWorkouts(DateTime start, DateTime end) async {
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    return points.map(_fromPoint).toList();
  }

  @override
  Future<bool> writeWorkout(HealthWorkout workout) => _health.writeWorkoutData(
        activityType: _activityType(workout.activity),
        start: workout.start,
        end: workout.end,
        totalEnergyBurned: workout.energyKilocalories?.round(),
        totalDistance: workout.distanceMeters?.round(),
        title: workout.activity,
      );

  HealthWorkout _fromPoint(HealthDataPoint point) {
    final summary = point.workoutSummary;
    return HealthWorkout(
      id: point.uuid,
      activity: summary?.workoutType ?? point.type.name,
      start: point.dateFrom,
      end: point.dateTo,
      source: point.sourceName.isEmpty ? point.sourceId : point.sourceName,
      energyKilocalories: summary?.totalEnergyBurned.toDouble(),
      distanceMeters: summary?.totalDistance.toDouble(),
    );
  }

  HealthWorkoutActivityType _activityType(String activity) =>
      HealthWorkoutActivityType.values.firstWhere(
        (value) => value.name == activity,
        orElse: () => HealthWorkoutActivityType.values.first,
      );
}
