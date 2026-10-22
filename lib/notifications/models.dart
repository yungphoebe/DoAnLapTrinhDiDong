class ReminderSettings {
  const ReminderSettings({
    this.workoutEnabled = false,
    this.workoutTime = '18:00',
    this.workoutDays = const [1, 2, 3, 4, 5, 6, 7],
    this.waterEnabled = false,
    this.waterStart = '09:00',
    this.waterEnd = '21:00',
    this.waterIntervalMinutes = 120,
    this.weeklyEnabled = false,
    this.weeklyDay = 7,
    this.weeklyTime = '20:00',
    this.timeZone = 'Asia/Bangkok',
    this.revision = 0,
  });
  final bool workoutEnabled, waterEnabled, weeklyEnabled;
  final String workoutTime, waterStart, waterEnd, weeklyTime, timeZone;
  final List<int> workoutDays;
  final int waterIntervalMinutes, weeklyDay, revision;
  bool get anyEnabled => workoutEnabled || waterEnabled || weeklyEnabled;
  Map<String, dynamic> toJson() => {
    'workoutEnabled': workoutEnabled,
    'workoutTime': workoutTime,
    'workoutDays': workoutDays,
    'waterEnabled': waterEnabled,
    'waterStart': waterStart,
    'waterEnd': waterEnd,
    'waterIntervalMinutes': waterIntervalMinutes,
    'weeklyEnabled': weeklyEnabled,
    'weeklyDay': weeklyDay,
    'weeklyTime': weeklyTime,
    'timeZone': timeZone,
    'revision': revision,
  };
  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    workoutEnabled: j['workoutEnabled'] == true,
    workoutTime: j['workoutTime'] as String? ?? '18:00',
    workoutDays:
        (j['workoutDays'] as List?)?.cast<int>() ?? const [1, 2, 3, 4, 5, 6, 7],
    waterEnabled: j['waterEnabled'] == true,
    waterStart: j['waterStart'] as String? ?? '09:00',
    waterEnd: j['waterEnd'] as String? ?? '21:00',
    waterIntervalMinutes: j['waterIntervalMinutes'] as int? ?? 120,
    weeklyEnabled: j['weeklyEnabled'] == true,
    weeklyDay: j['weeklyDay'] as int? ?? 7,
    weeklyTime: j['weeklyTime'] as String? ?? '20:00',
    timeZone: j['timeZone'] as String? ?? 'Asia/Bangkok',
    revision: j['revision'] as int? ?? 0,
  );
  ReminderSettings copyWith({
    bool? workoutEnabled,
    String? workoutTime,
    List<int>? workoutDays,
    bool? waterEnabled,
    String? waterStart,
    String? waterEnd,
    int? waterIntervalMinutes,
    bool? weeklyEnabled,
    int? weeklyDay,
    String? weeklyTime,
    String? timeZone,
    int? revision,
  }) => ReminderSettings.fromJson({
    ...toJson(),
    'workoutEnabled': ?workoutEnabled,
    'workoutTime': ?workoutTime,
    'workoutDays': ?workoutDays,
    'waterEnabled': ?waterEnabled,
    'waterStart': ?waterStart,
    'waterEnd': ?waterEnd,
    'waterIntervalMinutes': ?waterIntervalMinutes,
    'weeklyEnabled': ?weeklyEnabled,
    'weeklyDay': ?weeklyDay,
    'weeklyTime': ?weeklyTime,
    'timeZone': ?timeZone,
    'revision': ?revision,
  });
}

class InboxNotification {
  InboxNotification.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      kind = j['kind'] as String,
      title = j['title'] as String,
      body = j['body'] as String,
      at = DateTime.parse(j['scheduledAtUtc'] as String),
      read = j['readAt'] != null;
  final String id, kind, title, body;
  final DateTime at;
  bool read;
}

class NotificationLink {
  const NotificationLink({
    required this.owner,
    required this.kind,
    this.id,
    this.at,
  });
  final String owner, kind;
  final String? id, at;
  String get route {
    final path = switch (kind) {
      'workout' => '/workouts',
      'water' => '/water',
      'weekly' => '/weekly-report',
      _ => '/notifications',
    };
    return at == null || path == '/notifications'
        ? path
        : '$path?at=${Uri.encodeComponent(at!)}';
  }

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'kind': kind,
    if (id != null) 'id': id,
    if (at != null) 'at': at,
  };
  factory NotificationLink.fromJson(Map<String, dynamic> j) => NotificationLink(
    owner: j['owner'] as String? ?? '',
    kind: j['kind'] as String? ?? '',
    id: j['id'] as String?,
    at: j['at'] as String?,
  );
}
