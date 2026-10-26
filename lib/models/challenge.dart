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

  const GymChallenge({
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
    ChallengeDifficulty.easy => 'De',
    ChallengeDifficulty.medium => 'Trung binh',
    ChallengeDifficulty.hard => 'Kho',
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
      return 'Ban da bat dau thu thach "${challenge.title}"! Hay duy tri nhe!';
    } else if (pct < 50) {
      return 'Ban da hoan thanh $pct% thu thach "${challenge.title}". Tiep tuc nao!';
    } else if (pct < 75) {
      return 'Hon nua chang duong roi! $pct% thu thach "${challenge.title}" da xong!';
    } else if (pct < 100) {
      return 'Sap ve dich! $pct% — Chi con mot chut nua thoi!';
    } else {
      return 'Xuat sac! Ban da hoan thanh thu thach "${challenge.title}"!';
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
    title: '7 Ngay Khong Nghi',
    description: 'Tap gym lien tuc 7 ngay khong bo lo mot buoi nao. Xay dung thoi quen kien tri!',
    emoji: '🔥',
    difficulty: ChallengeDifficulty.easy,
    durationDays: 7,
    color: Color(0xFFFF6B35),
    icon: Icons.local_fire_department_rounded,
    medalTitle: 'Huy Chuong Kien Tri',
    medalDescription: 'Hoan thanh 7 ngay tap khong nghi',
    steps: [
      ChallengeStep(title: 'Ngay 1-2', description: 'Tap it nhat 2 buoi gym', targetValue: 2, unit: 'buoi'),
      ChallengeStep(title: 'Ngay 3-5', description: 'Tap them 3 buoi lien tiep', targetValue: 3, unit: 'buoi'),
      ChallengeStep(title: 'Ngay 6-7', description: 'Hoan thanh 2 buoi cuoi', targetValue: 2, unit: 'buoi'),
    ],
  ),
  const GymChallenge(
    id: 'c2',
    title: 'Vua Cardio 30 Ngay',
    description: 'Chay tong cong 100km trong 30 ngay. Thu thach suc ben thuc su!',
    emoji: '🏃',
    difficulty: ChallengeDifficulty.medium,
    durationDays: 30,
    color: Color(0xFF4ECDC4),
    icon: Icons.directions_run_rounded,
    medalTitle: 'Huy Chuong Cardio Vuong',
    medalDescription: 'Hoan thanh 100km chay bo trong 30 ngay',
    steps: [
      ChallengeStep(title: 'Tuan 1', description: 'Chay 20km dau tien', targetValue: 20, unit: 'km'),
      ChallengeStep(title: 'Tuan 2', description: 'Tiep tuc 30km tiep theo', targetValue: 30, unit: 'km'),
      ChallengeStep(title: 'Tuan 3', description: 'Day len 30km nua', targetValue: 30, unit: 'km'),
      ChallengeStep(title: 'Tuan 4', description: 'Ve dich voi 20km con lai', targetValue: 20, unit: 'km'),
    ],
  ),
  const GymChallenge(
    id: 'c3',
    title: 'Thach Thuc Squat 1000',
    description: 'Thuc hien 1000 cai squat trong 10 ngay. Dui thep cho ban!',
    emoji: '🦵',
    difficulty: ChallengeDifficulty.medium,
    durationDays: 10,
    color: Color(0xFF983BFA),
    icon: Icons.fitness_center_rounded,
    medalTitle: 'Huy Chuong Dui Thep',
    medalDescription: 'Hoan thanh 1000 squat trong 10 ngay',
    steps: [
      ChallengeStep(title: 'Ngay 1-3', description: 'Warm-up: 300 squat', targetValue: 300, unit: 'cai'),
      ChallengeStep(title: 'Ngay 4-7', description: 'Tang toc: 400 squat', targetValue: 400, unit: 'cai'),
      ChallengeStep(title: 'Ngay 8-10', description: 'Ve dich: 300 squat cuoi', targetValue: 300, unit: 'cai'),
    ],
  ),
  const GymChallenge(
    id: 'c4',
    title: 'Chien Binh Push-up',
    description: 'Tu 10 cai len 100 cai push-up moi ngay trong 21 ngay. Vuot gioi han ban than!',
    emoji: '💪',
    difficulty: ChallengeDifficulty.hard,
    durationDays: 21,
    color: Color(0xFFFF4F6D),
    icon: Icons.sports_gymnastics_rounded,
    medalTitle: 'Huy Chuong Chien Binh',
    medalDescription: 'Hoan thanh thu thach push-up 21 ngay',
    steps: [
      ChallengeStep(title: 'Tuan 1', description: 'Bat dau: 10-30 cai/ngay', targetValue: 140, unit: 'cai'),
      ChallengeStep(title: 'Tuan 2', description: 'Tang: 30-60 cai/ngay', targetValue: 315, unit: 'cai'),
      ChallengeStep(title: 'Tuan 3', description: 'Dinh cao: 60-100 cai/ngay', targetValue: 560, unit: 'cai'),
    ],
  ),
  const GymChallenge(
    id: 'c5',
    title: 'Thien Gym Buoi Sang',
    description: 'Tap gym vao buoi sang truoc 8h, 15 ngay lien tiep. Suc manh bat dau tu binh minh!',
    emoji: '🌅',
    difficulty: ChallengeDifficulty.easy,
    durationDays: 15,
    color: Color(0xFFFFB83F),
    icon: Icons.wb_sunny_rounded,
    medalTitle: 'Huy Chuong Binh Minh',
    medalDescription: 'Hoan thanh 15 buoi tap sang som',
    steps: [
      ChallengeStep(title: 'Tuan 1', description: '5 buoi tap buoi sang', targetValue: 5, unit: 'buoi'),
      ChallengeStep(title: 'Tuan 2', description: '5 buoi tiep theo', targetValue: 5, unit: 'buoi'),
      ChallengeStep(title: 'Giai doan cuoi', description: '5 buoi ve dich', targetValue: 5, unit: 'buoi'),
    ],
  ),
  const GymChallenge(
    id: 'c6',
    title: 'Thu Thach Plank Thep',
    description: 'Plank tu 30 giay len 5 phut trong 30 ngay. Loi thep - Tinh than thep!',
    emoji: '🧱',
    difficulty: ChallengeDifficulty.hard,
    durationDays: 30,
    color: Color(0xFF00B4D8),
    icon: Icons.accessibility_new_rounded,
    medalTitle: 'Huy Chuong Loi Thep',
    medalDescription: 'Hoan thanh thu thach plank 30 ngay',
    steps: [
      ChallengeStep(title: 'Tuan 1', description: 'Plank 30-60 giay/ngay', targetValue: 7, unit: 'ngay'),
      ChallengeStep(title: 'Tuan 2', description: 'Tang len 1-2 phut/ngay', targetValue: 7, unit: 'ngay'),
      ChallengeStep(title: 'Tuan 3-4', description: 'Chinh phuc 3-5 phut/ngay', targetValue: 14, unit: 'ngay'),
    ],
  ),
];
