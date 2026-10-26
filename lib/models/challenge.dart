import 'package:flutter/material.dart';

enum ChallengeDifficulty { easy, medium, hard }

enum ChallengeStatus { available, active, completed }

class ChallengeStep {
  final String title;
  final String description;
  final int targetValue;
  final String unit;

  const ChallengeStep({
    required this.title,
    required this.description,
    required this.targetValue,
    required this.unit,
  });
}

class GymChallenge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final ChallengeDifficulty difficulty;
  final int durationDays;
  final List<ChallengeStep> steps;
  final Color color;
  final IconData icon;
  final String medalTitle;
  final String medalDescription;
  // Matches the backend metric: 'session', 'morningSession' or a camera exercise key.
  final String metric;

  const GymChallenge({
    this.metric = 'session',
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.difficulty,
    required this.durationDays,
    required this.steps,
    required this.color,
    required this.icon,
    required this.medalTitle,
    required this.medalDescription,
  });

  String get difficultyLabel => switch (difficulty) {
    ChallengeDifficulty.easy => 'Dễ',
    ChallengeDifficulty.medium => 'Trung bình',
    ChallengeDifficulty.hard => 'Khó',
  };

  Color get difficultyColor => switch (difficulty) {
    ChallengeDifficulty.easy => const Color(0xFF30D66A),
    ChallengeDifficulty.medium => const Color(0xFFFFB83F),
    ChallengeDifficulty.hard => const Color(0xFFFF4F6D),
  };
}

class DailyProgressLog {
  final String date;
  final int amount;
  final DateTime createdAt;

  DailyProgressLog({
    required this.date,
    required this.amount,
    required this.createdAt,
  });

  factory DailyProgressLog.fromJson(Map<String, dynamic> json) => DailyProgressLog(
    date: (json['date'] ?? '').toString(),
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'amount': amount,
    'created_at': createdAt.toIso8601String(),
  };
}

class ActiveChallenge {
  final GymChallenge challenge;
  final DateTime startDate;
  int currentStepIndex;
  int currentProgress;
  final List<DateTime> completedStepDates;
  String? lastProgressDate;
  List<DailyProgressLog> dailyLogs;
  int todayAmount;
  bool canUpdateToday;
  int secondsUntilNextDay;
  String nextAllowedDate;
  int todayTarget;
  int totalTarget;
  int totalProgress;
  bool isOverTarget;
  bool isTodayTargetReached;

  ActiveChallenge({
    required this.challenge,
    required this.startDate,
    this.currentStepIndex = 0,
    this.currentProgress = 0,
    List<DateTime>? completedStepDates,
    this.lastProgressDate,
    List<DailyProgressLog>? dailyLogs,
    this.todayAmount = 0,
    this.canUpdateToday = true,
    this.secondsUntilNextDay = 0,
    this.nextAllowedDate = '',
    this.todayTarget = 0,
    this.totalTarget = 0,
    this.totalProgress = 0,
    this.isOverTarget = false,
    this.isTodayTargetReached = false,
  })  : completedStepDates = completedStepDates ?? [],
        dailyLogs = dailyLogs ?? [];

  bool get isCompleted => currentStepIndex >= challenge.steps.length;

  double get overallProgress {
    if (challenge.steps.isEmpty) return 0;
    final completedSteps = currentStepIndex;
    final currentStepProgress = currentStepIndex < challenge.steps.length
        ? currentProgress / challenge.steps[currentStepIndex].targetValue
        : 0.0;
    return (completedSteps + currentStepProgress.clamp(0.0, 1.0)) / challenge.steps.length;
  }

  ChallengeStep? get currentStep =>
      currentStepIndex < challenge.steps.length ? challenge.steps[currentStepIndex] : null;

  int get daysElapsed => DateTime.now().difference(startDate).inDays;

  String get progressNotification {
    final pct = (overallProgress * 100).round();
    if (pct < 25) {
      return 'Bạn đã bắt đầu thử thách "${challenge.title}"! Hãy duy trì nhé!';
    } else if (pct < 50) {
      return 'Bạn đã hoàn thành $pct% thử thách "${challenge.title}". Tiếp tục nào!';
    } else if (pct < 75) {
      return 'Hơn nửa chặng đường rồi! $pct% thử thách "${challenge.title}" đã xong!';
    } else if (pct < 100) {
      return 'Sắp về đích! $pct% — Chỉ còn một chút nữa thôi!';
    } else {
      return 'Xuất sắc! Bạn đã hoàn thành thử thách "${challenge.title}"!';
    }
  }
}

class EarnedMedal {
  final GymChallenge challenge;
  final DateTime earnedDate;
  const EarnedMedal({required this.challenge, required this.earnedDate});
}

final List<GymChallenge> allChallenges = [
  const GymChallenge(
    id: 'c1',
    title: '7 Ngày Không Nghỉ',
    description: 'Tập gym liên tục 7 ngày không bỏ lỡ một buổi nào. Xây dựng thói quen kiên trì!',
    emoji: '🔥',
    difficulty: ChallengeDifficulty.easy,
    durationDays: 7,
    color: Color(0xFFFF6B35),
    icon: Icons.local_fire_department_rounded,
    medalTitle: 'Huy Chương Kiên Trì',
    medalDescription: 'Hoàn thành 7 ngày tập không nghỉ',
    steps: [
      ChallengeStep(title: 'Ngày 1-2', description: 'Tập ít nhất 2 buổi gym', targetValue: 2, unit: 'buổi'),
      ChallengeStep(title: 'Ngày 3-5', description: 'Tập thêm 3 buổi liên tiếp', targetValue: 3, unit: 'buổi'),
      ChallengeStep(title: 'Ngày 6-7', description: 'Hoàn thành 2 buổi cuối', targetValue: 2, unit: 'buổi'),
    ],
  ),
  const GymChallenge(
    id: 'c2',
    title: 'Vua Cardio 30 Ngày',
    description: 'Thực hiện tổng cộng 1000 cái jumping jack trong 30 ngày. Thử thách sức bền thực sự!',
    emoji: '🏃',
    difficulty: ChallengeDifficulty.medium,
    durationDays: 30,
    metric: 'jumpingJack',
    color: Color(0xFF4ECDC4),
    icon: Icons.directions_run_rounded,
    medalTitle: 'Huy Chương Cardio Vương',
    medalDescription: 'Hoàn thành 1000 jumping jack trong 30 ngày',
    steps: [
      ChallengeStep(title: 'Tuần 1', description: '200 jumping jack đầu tiên', targetValue: 200, unit: 'cái'),
      ChallengeStep(title: 'Tuần 2', description: 'Tiếp tục 300 cái', targetValue: 300, unit: 'cái'),
      ChallengeStep(title: 'Tuần 3', description: 'Đẩy lên 300 cái nữa', targetValue: 300, unit: 'cái'),
      ChallengeStep(title: 'Tuần 4', description: 'Về đích với 200 cái còn lại', targetValue: 200, unit: 'cái'),
    ],
  ),
  const GymChallenge(
    id: 'c3',
    title: 'Thách Thức Squat 1000',
    description: 'Thực hiện 1000 cái squat trong 10 ngày. Đùi thép cho bạn!',
    emoji: '🦵',
    difficulty: ChallengeDifficulty.medium,
    durationDays: 10,
    metric: 'squat',
    color: Color(0xFF983BFA),
    icon: Icons.fitness_center_rounded,
    medalTitle: 'Huy Chương Đùi Thép',
    medalDescription: 'Hoàn thành 1000 squat trong 10 ngày',
    steps: [
      ChallengeStep(title: 'Ngày 1-3', description: 'Warm-up: 300 squat', targetValue: 300, unit: 'cái'),
      ChallengeStep(title: 'Ngày 4-7', description: 'Tăng tốc: 400 squat', targetValue: 400, unit: 'cái'),
      ChallengeStep(title: 'Ngày 8-10', description: 'Về đích: 300 squat cuối', targetValue: 300, unit: 'cái'),
    ],
  ),
  const GymChallenge(
    id: 'c4',
    title: 'Chiến Binh Push-up',
    description: 'Từ 10 cái lên 100 cái push-up mỗi ngày trong 21 ngày. Vượt giới hạn bản thân!',
    emoji: '💪',
    difficulty: ChallengeDifficulty.hard,
    durationDays: 21,
    metric: 'pushup',
    color: Color(0xFFFF4F6D),
    icon: Icons.sports_gymnastics_rounded,
    medalTitle: 'Huy Chương Chiến Binh',
    medalDescription: 'Hoàn thành thử thách push-up 21 ngày',
    steps: [
      ChallengeStep(title: 'Tuần 1', description: 'Bắt đầu: 10-30 cái/ngày', targetValue: 140, unit: 'cái'),
      ChallengeStep(title: 'Tuần 2', description: 'Tăng: 30-60 cái/ngày', targetValue: 315, unit: 'cái'),
      ChallengeStep(title: 'Tuần 3', description: 'Đỉnh cao: 60-100 cái/ngày', targetValue: 560, unit: 'cái'),
    ],
  ),
  const GymChallenge(
    id: 'c5',
    title: 'Thiền Gym Buổi Sáng',
    description: 'Tập gym vào buổi sáng trước 8h, 15 ngày liên tiếp. Sức mạnh bắt đầu từ bình minh!',
    emoji: '🌅',
    difficulty: ChallengeDifficulty.easy,
    durationDays: 15,
    metric: 'morningSession',
    color: Color(0xFFFFB83F),
    icon: Icons.wb_sunny_rounded,
    medalTitle: 'Huy Chương Bình Minh',
    medalDescription: 'Hoàn thành 15 buổi tập sáng sớm',
    steps: [
      ChallengeStep(title: 'Tuần 1', description: '5 buổi tập buổi sáng', targetValue: 5, unit: 'buổi'),
      ChallengeStep(title: 'Tuần 2', description: '5 buổi tiếp theo', targetValue: 5, unit: 'buổi'),
      ChallengeStep(title: 'Giai đoạn cuối', description: '5 buổi về đích', targetValue: 5, unit: 'buổi'),
    ],
  ),
  const GymChallenge(
    id: 'c6',
    title: 'Thử Thách Vai Thép',
    description: 'Thực hiện 500 cái shoulder press trong 30 ngày. Vai thép - Tinh thần thép!',
    emoji: '🏋️',
    difficulty: ChallengeDifficulty.hard,
    durationDays: 30,
    metric: 'shoulderPress',
    color: Color(0xFF00B4D8),
    icon: Icons.accessibility_new_rounded,
    medalTitle: 'Huy Chương Vai Thép',
    medalDescription: 'Hoàn thành 500 shoulder press trong 30 ngày',
    steps: [
      ChallengeStep(title: 'Tuần 1', description: 'Khởi động: 100 cái', targetValue: 100, unit: 'cái'),
      ChallengeStep(title: 'Tuần 2', description: 'Tăng lên 150 cái', targetValue: 150, unit: 'cái'),
      ChallengeStep(title: 'Tuần 3-4', description: 'Chinh phục 250 cái cuối', targetValue: 250, unit: 'cái'),
    ],
  ),
];
