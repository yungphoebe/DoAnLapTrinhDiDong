import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym/services/pose_rules.dart';

const _hidden = PosePoint(0.5, 0.5, 0);

// Side-on squat: knee angle in degrees, 180 = standing.
List<PosePoint?> squat(double knee) {
  final r = knee * pi / 180;
  final points = List<PosePoint?>.filled(33, _hidden);
  const ankle = PosePoint(0.5, 0.9), kneePoint = PosePoint(0.5, 0.7);
  final hip = PosePoint(0.5 + 0.2 * sin(r), 0.7 + 0.2 * cos(r));
  points[27] = ankle;
  points[25] = kneePoint;
  points[23] = hip;
  points[11] = PosePoint(hip.x, hip.y - 0.25);
  return points;
}

// Side-on push-up: elbow angle in degrees, 180 = arms straight.
List<PosePoint?> pushup(double elbow) {
  final r = elbow * pi / 180;
  final points = List<PosePoint?>.filled(33, _hidden);
  points[11] = const PosePoint(0.2, 0.5);
  points[23] = const PosePoint(0.5, 0.5);
  points[25] = const PosePoint(0.65, 0.5);
  points[27] = const PosePoint(0.8, 0.5);
  points[13] = const PosePoint(0.2, 0.65);
  points[15] = PosePoint(0.2 + 0.15 * sin(r), 0.65 - 0.15 * cos(r));
  return points;
}

List<PosePoint?> shoulderPress(bool extended, {bool rightExtended = false}) {
  final points = List<PosePoint?>.filled(33, _hidden);
  for (final side in [0, 1]) {
    final up = side == 0 ? extended : rightExtended;
    final sign = side == 0 ? -1 : 1;
    final x = side == 0 ? 0.4 : 0.6;
    points[11 + side] = PosePoint(x, 0.45);
    points[13 + side] = up
        ? PosePoint(x + sign * 0.02, 0.28)
        : PosePoint(x + sign * 0.15, 0.45);
    // In the rack position the wrists remain ABOVE the shoulders.
    points[15 + side] = up
        ? PosePoint(x + sign * 0.04, 0.11)
        : PosePoint(x + sign * 0.15, 0.25);
  }
  return points;
}

List<PosePoint?> curl(double elbow) {
  final r = elbow * pi / 180;
  final points = List<PosePoint?>.filled(33, _hidden);
  points[11] = const PosePoint(0.5, 0.25);
  points[13] = const PosePoint(0.5, 0.45);
  points[15] = PosePoint(0.5 + 0.2 * sin(r), 0.45 - 0.2 * cos(r));
  return points;
}

List<PosePoint?> jumpingJack(bool open) {
  final points = List<PosePoint?>.filled(33, _hidden);
  for (final side in [0, 1]) {
    final sign = side == 0 ? -1 : 1;
    final x = 0.5 + sign * 0.1;
    points[11 + side] = PosePoint(x, 0.3);
    points[15 + side] = PosePoint(x, open ? 0.1 : 0.65);
    points[23 + side] = PosePoint(x, 0.55);
    points[25 + side] = PosePoint(x, 0.7);
    points[27 + side] = PosePoint(0.5 + sign * (open ? 0.25 : 0.1), 0.9);
  }
  return points;
}

/// Feeds [poses] each held for [holdMs], one frame every 50 ms.
List<PoseResult> run(
  PoseWorkout engine,
  List<List<PosePoint?>> poses, {
  int holdMs = 500,
}) {
  final results = <PoseResult>[];
  var t = 1000;
  for (final pose in poses) {
    for (var i = 0; i < holdMs ~/ 50; i++) {
      results.add(engine.update(pose, t));
      t += 50;
    }
  }
  return results;
}

void main() {
  test('catalog names resolve to the same rules as built-in exercises', () {
    final names = {
      'Squat': 'squat',
      'Push-up': 'pushup',
      'Chống đẩy': 'pushup',
      'Jumping Jack': 'jumpingJack',
      'Dumbbell Shoulder Press': 'shoulderPress',
      'Đẩy vai': 'shoulderPress',
      'Biceps Curl': 'bicepsCurl',
      'Tập tay trước': 'bicepsCurl',
    };
    for (final entry in names.entries) {
      expect(poseExerciseFor('catalog_42') ?? poseExerciseFor(entry.key),
          entry.value);
    }
    expect(
        poseExerciseFor('catalog_99') ?? poseExerciseFor('Leg Press'), isNull);
  });

  test('shoulder press counts rack-overhead-rack with wrists above shoulders',
      () {
    final engine = PoseWorkout()..setExercise('shoulderPress');
    final rack = shoulderPress(false);
    final top = shoulderPress(true, rightExtended: true);
    final results = run(engine, [rack, top, rack, top, rack]);
    expect(results.last.reps, 2);
    expect(results.last.correctReps, 2);
    expect(results.where((r) => r.repEvent != null), hasLength(2));
  });

  test('shoulder press does not count static, partial or one-arm movements',
      () {
    for (final poses in [
      [shoulderPress(true, rightExtended: true)],
      [shoulderPress(false), shoulderPress(false), shoulderPress(false)],
      [shoulderPress(false), shoulderPress(true), shoulderPress(false)],
    ]) {
      final engine = PoseWorkout()..setExercise('shoulderPress');
      expect(run(engine, poses).last.reps, 0);
    }
  });

  test('shoulder press ignores low-confidence arms instead of counting them',
      () {
    final engine = PoseWorkout()..setExercise('shoulderPress');
    final points = shoulderPress(true, rightExtended: true)
        .map((p) => p == null ? null : PosePoint(p.x, p.y, 0.1))
        .toList();
    final results =
        run(engine, [shoulderPress(false), points, shoulderPress(false)]);
    expect(results.last.reps, 0);
    expect(results.any((r) => !r.tracking), isTrue);
  });

  test('push-up counts without knees visible', () {
    final engine = PoseWorkout()..setExercise('pushup');
    final poses = [pushup(180), pushup(90), pushup(180)];
    for (final p in poses) {
      p[25] = null;
    }
    expect(run(engine, poses).last.correctReps, 1);
  });

  test('all five supported exercises count in portrait image coordinates', () {
    final sequences = {
      'squat': [squat(180), squat(90), squat(180)],
      'pushup': [pushup(180), pushup(90), pushup(180)],
      'jumpingJack': [
        jumpingJack(false),
        jumpingJack(true),
        jumpingJack(false)
      ],
      'bicepsCurl': [curl(180), curl(70), curl(180)],
      'shoulderPress': [
        shoulderPress(false),
        shoulderPress(true, rightExtended: true),
        shoulderPress(false)
      ],
    };
    // Center and shrink fixtures in pixel space, then normalize for a 480x640 frame.
    for (final entry in sequences.entries) {
      final engine = PoseWorkout()..setExercise(entry.key);
      PoseResult? last;
      var timestamp = 1000;
      for (final pose in entry.value) {
        final portrait = pose
            .map((p) => p == null
                ? null
                : PosePoint(
                    (p.x * 0.6 + 0.075) / 0.75, p.y * 0.6 + 0.2, p.visibility))
            .toList();
        for (var frame = 0; frame < 10; frame++) {
          last = engine.update(portrait, timestamp, width: 480, height: 640);
          timestamp += 50;
        }
      }
      expect(last!.correctReps, 1, reason: entry.key);
    }
  });

  test('squat counts a full rep as correct and announces it', () {
    final engine = PoseWorkout()..setExercise('squat');
    final results = run(engine, [squat(180), squat(90), squat(180)]);
    expect(results.last.reps, 1);
    expect(results.last.correctReps, 1);
    expect(results.where((r) => r.repEvent == 'correct'), hasLength(1));
    expect(engine.summary().exercises.single.exercise, 'squat');
  });

  test('shallow squat is not counted and gives a depth cue', () {
    final engine = PoseWorkout()..setExercise('squat');
    final results = run(engine, [squat(180), squat(135), squat(180)]);
    expect(results.last.reps, 0);
    expect(engine.summary().feedbackCounts['squat_shallow'], 1);
    expect(
      results.expand((r) => r.feedbackCodes),
      contains('squat_shallow'),
    );
  });

  test('too-brief full-depth dip is neither counted nor called shallow', () {
    final engine = PoseWorkout()..setExercise('squat');
    run(engine, [squat(180)]);
    run(engine, [squat(140), squat(90)], holdMs: 100);
    run(engine, [squat(180)]);
    expect(engine.summary().feedbackCounts['squat_shallow'], isNull);
  });

  test('app exercise ids map to rule keys', () {
    expect(poseExerciseFor('shoulder_press'), 'shoulderPress');
    expect(poseExerciseFor('biceps_curl'), 'bicepsCurl');
    expect(poseExerciseFor('squat'), 'squat');
    expect(poseExerciseFor('leg_press'), isNull);
  });

  test('push-up counts a rep and flags a shallow one', () {
    final engine = PoseWorkout()..setExercise('pushup');
    final results = run(engine, [
      pushup(180),
      pushup(90),
      pushup(180),
      pushup(125),
      pushup(180),
    ]);
    expect(results.last.reps, 1);
    expect(engine.summary().feedbackCounts['pushup_shallow'], 1);
  });

  test('missing joints report tracking and drop partial reps', () {
    final engine = PoseWorkout()..setExercise('squat');
    run(engine, [squat(180), squat(90)]);
    final lost = engine.update(List.filled(33, _hidden), 99999);
    expect(lost.tracking, isFalse);
    expect(lost.feedbackCodes, ['tracking']);
    expect(lost.reps, 0);
  });
}
