import 'package:ai_gym/services/pose_rules.dart';
import 'package:ai_gym/services/workout_rep_progress.dart';
import 'package:flutter_test/flutter_test.dart';

PoseResult rep(int count, {String exercise = 'squat', bool correct = true}) =>
    PoseResult(
      exercise: exercise,
      feedbackCodes: const [],
      tracking: true,
      reps: count,
      correctReps: count,
      incorrectReps: 0,
      repEvent: correct ? 'correct' : 'incorrect',
    );

void main() {
  test('requires every set, counts correct matching reps and enforces rest',
      () {
    final p = WorkoutRepProgress(
        exercise: 'squat', sets: 2, repsPerSet: 2, restSeconds: 5);
    expect(p.update(rep(1, exercise: 'pushup'), 0), isFalse);
    expect(p.update(rep(1, correct: false), 0), isFalse);
    expect(p.update(rep(2), 100), isFalse);
    expect(p.update(rep(2), 200), isFalse); // duplicate callback
    expect(p.update(rep(3), 300), isTrue);
    expect(p.completedSets, 1);
    expect(p.correctReps, 2);
    expect(p.completed, isFalse);
    expect(p.restRemaining(301), 5);
    expect(p.update(rep(4), 400), isFalse);
    expect(p.correctReps, 2);
    expect(p.update(rep(5), 5300), isFalse);
    expect(p.update(rep(6), 5600), isTrue);
    expect(p.completed, isTrue);
    expect(p.correctReps, 4);
    expect(p.update(rep(7), 6000), isFalse);
    expect(p.completedSets, 2);
  });

  test('pausing freezes the rest countdown and blocks reps', () {
    final p = WorkoutRepProgress(
        exercise: 'squat', sets: 2, repsPerSet: 1, restSeconds: 5);
    p.update(rep(1), 100);
    p.pause(1100);
    expect(p.restRemaining(9000), 4);
    expect(p.update(rep(2), 9000), isFalse);
    p.resume(10100);
    expect(p.isResting(14099), isTrue);
    expect(p.isResting(14100), isFalse);
    expect(p.update(rep(3), 14100), isTrue);
    expect(p.completed, isTrue);
  });
}
