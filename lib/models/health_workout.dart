enum HealthIntegrationState {
  unsupported,
  permissionRequired,
  ready,
  permissionDenied,
  error,
}

class HealthIntegrationStatus {
  const HealthIntegrationStatus(this.state, {this.message});

  final HealthIntegrationState state;
  final String? message;
  bool get canUse => state == HealthIntegrationState.ready;
}

class HealthWorkout {
  const HealthWorkout({
    required this.id,
    required this.activity,
    required this.start,
    required this.end,
    required this.source,
    this.energyKilocalories,
    this.distanceMeters,
  });

  final String id;
  final String activity;
  final DateTime start;
  final DateTime end;
  final String source;
  final double? energyKilocalories;
  final double? distanceMeters;

  String get deduplicationKey => id.isNotEmpty
      ? id
      : '$source|$activity|${start.toUtc().toIso8601String()}|${end.toUtc().toIso8601String()}';
}
