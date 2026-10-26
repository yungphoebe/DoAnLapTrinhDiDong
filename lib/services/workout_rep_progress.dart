import 'pose_rules.dart';

/// Counts only correct reps for one selected exercise, with rest between sets.
class WorkoutRepProgress {
  WorkoutRepProgress(
      {required this.exercise,
      required this.sets,
      required this.repsPerSet,
      required this.restSeconds}) {
    if (sets < 1 || repsPerSet < 1 || restSeconds < 0) {
      throw ArgumentError('Invalid workout targets');
    }
  }

  final String exercise;
  final int sets, repsPerSet, restSeconds;
  int completedSets = 0, repsInSet = 0, correctReps = 0;
  int _lastObserved = 0;
  int? _restUntil, _pausedAt;

  bool get completed => completedSets == sets;
  bool isResting(int now) =>
      _restUntil != null && (_pausedAt ?? now) < _restUntil!;
  int restRemaining(int now) =>
      isResting(now) ? ((_restUntil! - (_pausedAt ?? now)) / 1000).ceil() : 0;

  void pause(int now) {
    _pausedAt ??= now;
  }

  void resume(int now) {
    if (_pausedAt != null && _restUntil != null) {
      _restUntil = _restUntil! + now - _pausedAt!;
    }
    _pausedAt = null;
  }

  /// True only when this frame completes a set. Repeated frames cannot add reps.
  bool update(PoseResult result, int now) {
    if (result.exercise != exercise || result.correctReps <= _lastObserved) {
      return false;
    }
    _lastObserved = result.correctReps;
    if (_pausedAt != null ||
        completed ||
        isResting(now) ||
        !result.tracking ||
        result.repEvent != 'correct') {
      return false;
    }
    correctReps++;
    repsInSet++;
    if (repsInSet < repsPerSet) return false;
    completedSets++;
    if (!completed) {
      repsInSet = 0;
      _restUntil = now + restSeconds * 1000;
    }
    return true;
  }
}
