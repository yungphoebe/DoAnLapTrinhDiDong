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
