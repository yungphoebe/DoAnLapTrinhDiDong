import 'dart:math';

/// Dart port of `web/pose_rules.mjs`; keep thresholds and codes in sync.
const poseExercises = [
  'squat',
  'pushup',
  'jumpingJack',
  'shoulderPress',
  'bicepsCurl',
];

/// Resolve a built-in ID or a catalog display name; unknown exercises stay null.
String? poseExerciseFor(String? value) {
  if (value == null) return null;
  if (poseExercises.contains(value)) return value;
  var name = value.toLowerCase().trim();
  const accents = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in accents.entries) {
    name = name.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  name = name.replaceAll(RegExp(r'[-_\s]+'), ' ');
  name = name.replaceFirst(
    RegExp(r'^(?:(?:barbell|dumbbell|bodyweight|seated|standing) )+'),
    '',
  );
  return switch (name) {
    'squat' => 'squat',
    'pushup' || 'push up' || 'chong day' || 'hit dat' => 'pushup',
    'jumpingjack' || 'jumping jack' => 'jumpingJack',
    'shoulderpress' ||
    'shoulder press' ||
    'overhead press' ||
    'day vai' =>
      'shoulderPress',
    'bicepscurl' ||
    'biceps curl' ||
    'bicep curl' ||
    'tap tay truoc' ||
    'cuon tay truoc' =>
      'bicepsCurl',
    _ => null,
  };
}

const poseExerciseNames = {
  'squat': 'Squat',
  'pushup': 'Chống đẩy',
  'jumpingJack': 'Jumping Jack',
  'shoulderPress': 'Đẩy vai',
  'bicepsCurl': 'Tập tay trước',
};

const poseMessages = {
  'tracking': 'Đưa toàn thân vào khung hình, bảo đảm thấy rõ các khớp.',
  'identifying': 'Squat/chống đẩy: quay ngang. Jumping Jack: quay chính diện.',
  'squat_torso_lean': 'Giữ thân trên ổn định, giảm nghiêng người về trước.',
  'squat_shallow': 'Hạ hông sâu hơn, đùi gần song song mặt đất.',
  'pushup_body_line': 'Giữ vai, hông và cổ chân thành một đường thẳng.',
  'pushup_shallow': 'Hạ ngực thấp hơn, gập khuỷu tay sâu hơn.',
  'jack_coordination': 'Phối hợp mở chân và đưa hai tay lên cùng nhau.',
  'shoulder_press_asymmetry': 'Đưa hai tay lên xuống cùng nhịp.',
  'biceps_swing': 'Giữ khuỷu tay sát thân, không đung đưa người.',
  'biceps_partial': 'Co tay hết biên độ, đưa tạ lên gần vai.',
};

/// Normalized image point (0..1) with landmark likelihood.
class PosePoint {
  const PosePoint(this.x, this.y, [this.visibility = 1]);
  final double x, y, visibility;
}

class PoseResult {
  const PoseResult({
    required this.exercise,
    required this.feedbackCodes,
    required this.tracking,
    required this.reps,
    required this.correctReps,
    required this.incorrectReps,
    this.repEvent,
  });
  final String? exercise;
  final List<String> feedbackCodes;
  final bool tracking;
  final int reps, correctReps, incorrectReps;

  /// 'correct' or 'incorrect' on the frame a rep is counted.
  final String? repEvent;
  List<String> get feedback =>
      [for (final c in feedbackCodes) poseMessages[c] ?? c];
}

class ExerciseCount {
  ExerciseCount(this.exercise);
  final String exercise;
  int correctReps = 0, incorrectReps = 0;
  int get reps => correctReps + incorrectReps;
  Map<String, dynamic> toJson() => {
        'exercise': exercise,
        'reps': reps,
        'correctReps': correctReps,
        'incorrectReps': incorrectReps,
      };
}

class PoseSummary {
  const PoseSummary(this.exercises, this.feedbackCounts);
  final List<ExerciseCount> exercises;
  final Map<String, int> feedbackCounts;
}

// Partial-range cue: the angle dipped below `shallow` but never reached `active`.
const _ranges = {
  'squat': (
    baseline: 160.0,
    active: 110.0,
    shallow: 145.0,
    code: 'squat_shallow'
  ),
  'pushup': (
    baseline: 155.0,
    active: 105.0,
    shallow: 140.0,
    code: 'pushup_shallow'
  ),
  'bicepsCurl': (
    baseline: 145.0,
    active: 105.0,
    shallow: 130.0,
    code: 'biceps_partial'
  ),
};

double _distance(PosePoint a, PosePoint b) =>
    sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));

double? _angle(PosePoint a, PosePoint b, PosePoint c) {
  final ab = _distance(a, b), cb = _distance(c, b);
  if (ab < 0.015 || cb < 0.015) return null;
  final cos =
      ((a.x - b.x) * (c.x - b.x) + (a.y - b.y) * (c.y - b.y)) / (ab * cb);
  return acos(cos.clamp(-1.0, 1.0)) * 180 / pi;
}

/// Image-space heuristics, not a clinical assessment. Same rules as the web
/// engine plus EMA smoothing and partial-range cues.
class PoseWorkout {
  PoseWorkout() {
    resetMotion();
  }

  static const _smoothing = 0.5;

  String mode = 'auto';
  final Map<String, ExerciseCount> _counts = {};
  final Map<String, int> _feedbackCounts = {};
  List<PosePoint?>? _smoothed;

  String? exercise, _candidate, _zone;
  int _candidateSince = 0, _zoneSince = 0;
  int? _cycleStart, _lastTime, _side;
  String _phase = 'waiting';
  bool _bad = false;
  Set<String> _previousCodes = {};
  double _cycleMin = double.infinity;

  void resetMotion() {
    _smoothed = null;
    exercise = null;
    _candidate = null;
    _candidateSince = 0;
    _phase = 'waiting';
    _zone = null;
    _zoneSince = 0;
    _cycleStart = null;
    _bad = false;
    _previousCodes = {};
    _lastTime = null;
    _side = null;
    _cycleMin = double.infinity;
  }

  void setExercise(String value) {
    if (value != 'auto' && !poseExercises.contains(value)) {
      throw ArgumentError('Unknown exercise');
    }
    if (value != mode) {
      mode = value;
      resetMotion();
    }
  }

  PoseSummary summary() => PoseSummary(
        _counts.values.toList(),
        Map.of(_feedbackCounts),
      );

  PoseResult _result(bool tracking, List<String> codes, [String? repEvent]) {
    var correct = 0, incorrect = 0;
    for (final row in _counts.values) {
      correct += row.correctReps;
      incorrect += row.incorrectReps;
    }
    return PoseResult(
      exercise: exercise,
      feedbackCodes: codes,
      tracking: tracking,
      reps: correct + incorrect,
      correctReps: correct,
      incorrectReps: incorrect,
      repEvent: repEvent,
    );
  }

  PoseResult _lost() {
    resetMotion();
    return _result(false, const ['tracking']);
  }

  void _track(List<String> codes) {
    for (final code in codes) {
      if (!_previousCodes.contains(code)) {
        _feedbackCounts[code] = (_feedbackCounts[code] ?? 0) + 1;
      }
    }
    _previousCodes = codes.toSet();
    if (_phase != 'waiting' && codes.isNotEmpty) _bad = true;
  }

  String _count(String name) {
    final row = _counts.putIfAbsent(name, () => ExerciseCount(name));
    if (_bad) {
      row.incorrectReps++;
      return 'incorrect';
    }
    row.correctReps++;
    return 'correct';
  }

  List<PosePoint?> _smooth(List<PosePoint?> raw) {
    final previous = _smoothed;
    final next = [
      for (var i = 0; i < raw.length; i++)
        raw[i] == null ||
                previous == null ||
                i >= previous.length ||
                previous[i] == null
            ? raw[i]
            : PosePoint(
                previous[i]!.x + _smoothing * (raw[i]!.x - previous[i]!.x),
                previous[i]!.y + _smoothing * (raw[i]!.y - previous[i]!.y),
                raw[i]!.visibility,
              ),
    ];
    _smoothed = next;
    return next;
  }

  /// [landmarks] uses the 33-point BlazePose/ML Kit order, normalized to 0..1.
  PoseResult update(
    List<PosePoint?> landmarks,
    int timestampMs, {
    double width = 1,
    double height = 1,
  }) {
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        landmarks.length < 33) {
      _smoothed = null;
      return _lost();
    }
    if (_lastTime != null &&
        (timestampMs <= _lastTime! || timestampMs - _lastTime! > 1000)) {
      _smoothed = null;
      resetMotion();
    }
    final smoothed = _smooth(landmarks);
    final shoulderMode = mode == 'shoulderPress';
    final upperBody = shoulderMode || mode == 'bicepsCurl';
    const threshold = 0.6;
    bool visible(int i) {
      final point = landmarks[i];
      return point != null &&
          point.x.isFinite &&
          point.y.isFinite &&
          point.visibility.isFinite &&
          point.x >= 0 &&
          point.x <= 1 &&
          point.y >= 0 &&
          point.y <= 1 &&
          point.visibility >= threshold;
    }

    final p = [
      for (final v in smoothed)
        v == null ? null : PosePoint(v.x * width / height, v.y, v.visibility),
    ];

    if (shoulderMode) return _shoulderPress(p, visible, timestampMs);

    _Side? measure(int side) {
      final required = upperBody
          ? [11 + side, 13 + side, 15 + side]
          : mode == 'pushup'
              ? [11 + side, 13 + side, 15 + side, 23 + side, 27 + side]
              : [11 + side, 23 + side, 25 + side, 27 + side];
      if (!required.every(visible)) return null;
      final shoulder = p[11 + side]!, hip = p[23 + side], ankle = p[27 + side];
      final horizontal = !upperBody &&
          (shoulder.x - ankle!.x).abs() > (shoulder.y - ankle.y).abs() * 1.5;
      final needArms = mode == 'pushup' ||
          mode == 'bicepsCurl' ||
          (mode == 'auto' && horizontal);
      if (needArms) required.addAll([13 + side, 15 + side]);
      if (!required.every(visible)) return null;
      final needsKnee = !upperBody && mode != 'pushup';
      final knee = needsKnee ? _angle(hip!, p[25 + side]!, ankle!) : null;
      final body = upperBody ? null : _angle(shoulder, hip!, ankle!);
      final elbow =
          needArms ? _angle(shoulder, p[13 + side]!, p[15 + side]!) : null;
      if ((needsKnee && knee == null) ||
          (!upperBody && body == null) ||
          (needArms && elbow == null)) {
        return null;
      }
      return _Side(
        side: side,
        shoulder: shoulder,
        hip: hip,
        ankle: ankle,
        horizontal: horizontal,
        knee: knee,
        body: body,
        elbow: elbow,
        score: required.map((i) => landmarks[i]!.visibility).reduce(min),
      );
    }

    final sides = [measure(0), measure(1)].whereType<_Side>().toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    // Keep a usable side through a cycle so confidence flicker cannot splice two limbs.
    final selected =
        sides.where((s) => s.side == _side).firstOrNull ?? sides.firstOrNull;
    if (selected == null) return _lost();
    if (_side != null && selected.side != _side) resetMotion();
    _side = selected.side;
    _lastTime = timestampMs;

    final shoulder = selected.shoulder;
    final torso = !upperBody
        ? _distance(shoulder, selected.hip!)
        : p[11] == null || p[12] == null
            ? 0.1
            : _distance(p[11]!, p[12]!);
    final upright = upperBody ||
        (shoulder.y < selected.hip!.y && selected.hip!.y < selected.ankle!.y);
    final frontal = visible(11) &&
        visible(12) &&
        (p[11]!.x - p[12]!.x).abs() > torso * 0.45;
    final candidate = mode == 'auto'
        ? (selected.horizontal
            ? 'pushup'
            : upright
                ? (frontal ? 'jumpingJack' : 'squat')
                : null)
        : mode;
    if (candidate == 'jumpingJack' &&
        ![11, 12, 15, 16, 23, 24, 25, 26, 27, 28].every(visible)) {
      return _lost();
    }
    if (candidate != _candidate) {
      _candidate = candidate;
      _candidateSince = timestampMs;
    }
    if (candidate != exercise) {
      _phase = 'waiting';
      _zone = null;
      _cycleStart = null;
      _bad = false;
      if (candidate != null &&
          (mode != 'auto' || timestampMs - _candidateSince >= 200)) {
        exercise = candidate;
      } else {
        exercise = null;
        return _result(true, const ['identifying']);
      }
    }
    if (exercise == null) return _result(true, const ['identifying']);

    String? zone;
    double? value;
    final codes = <String>[];
    switch (exercise) {
      case 'squat':
        if (!upright || selected.horizontal) return _lost();
        value = selected.knee!;
        zone = value > 160
            ? 'baseline'
            : value < 110
                ? 'active'
                : null;
        if ((shoulder.x - selected.hip!.x).abs() >
            (shoulder.y - selected.hip!.y).abs() * 0.8) {
          codes.add('squat_torso_lean');
        }
      case 'pushup':
        if (!selected.horizontal) return _lost();
        value = selected.elbow!;
        zone = value > 155
            ? 'baseline'
            : value < 105
                ? 'active'
                : null;
        if (selected.body! < 155) codes.add('pushup_body_line');
      case 'bicepsCurl':
        value = selected.elbow!;
        zone = value > 145
            ? 'baseline'
            : value < 105
                ? 'active'
                : null;
        final elbowPoint = p[13 + selected.side]!;
        if ((shoulder.x - elbowPoint.x).abs() >
            (shoulder.y - elbowPoint.y).abs() * 0.8) {
          codes.add('biceps_swing');
        }
      default:
        if (!upright || !frontal) return _lost();
        final armsUp = p[15]!.y < p[11]!.y && p[16]!.y < p[12]!.y;
        final armsDown = p[15]!.y > p[11]!.y + torso * 0.5 &&
            p[16]!.y > p[12]!.y + torso * 0.5;
        final spread = (p[27]!.x - p[28]!.x).abs() /
            max(0.01, (p[11]!.x - p[12]!.x).abs());
        zone = armsDown && spread < 1.3
            ? 'baseline'
            : armsUp && spread > 1.8
                ? 'active'
                : null;
        if ((armsDown && spread > 1.8) || (armsUp && spread < 1.3)) {
          codes.add('jack_coordination');
        }
    }

    final range = _ranges[exercise];
    if (range != null && value != null && _phase == 'ready') {
      _cycleMin = min(_cycleMin, value);
      if (zone == 'baseline' && _zone != 'baseline') {
        // A dip past `active` that was too brief to count is not "too shallow".
        if (_cycleMin < range.shallow && _cycleMin >= range.active) {
          codes.add(range.code);
        }
        _cycleMin = double.infinity;
      }
    }
    _track(codes);
    String? repEvent;
    if (zone != _zone) {
      _zone = zone;
      _zoneSince = timestampMs;
      if (_phase == 'ready' && zone != 'baseline' && _cycleStart == null) {
        _cycleStart = timestampMs;
      }
    }
    if (zone != null && timestampMs - _zoneSince >= 150) {
      if (zone == 'baseline') {
        if (_phase == 'active' && timestampMs - _cycleStart! >= 300) {
          repEvent = _count(exercise!);
        }
        _phase = 'ready';
        _cycleStart = null;
        _bad = false;
        _cycleMin = double.infinity;
      } else if (_phase == 'ready') {
        _phase = 'active';
      }
    }
    return _result(true, codes, repEvent);
  }

  PoseResult _shoulderPress(
    List<PosePoint?> p,
    bool Function(int) visible,
    int timestampMs,
  ) {
    if (![11, 12, 13, 14, 15, 16].every(visible)) return _lost();
    exercise = 'shoulderPress';
    final zones = <String?>[];
    for (final side in [0, 1]) {
      final shoulder = p[11 + side]!,
          elbow = p[13 + side]!,
          wrist = p[15 + side]!;
      final angle = _angle(shoulder, elbow, wrist);
      if (angle == null) return _lost();
      final armLength = _distance(shoulder, elbow);
      // The rack position has bent elbows and hands at/above shoulder height.
      // It must not require lowering the weights below the shoulders.
      zones.add(angle > 150 && wrist.y < shoulder.y - armLength * 0.7
          ? 'active'
          : angle >= 45 &&
                  angle < 120 &&
                  wrist.y <= shoulder.y + armLength * 0.2 &&
                  elbow.y >= shoulder.y - armLength * 0.4
              ? 'baseline'
              : null);
    }
    final zone = zones[0] == zones[1] ? zones[0] : null;
    final codes = zones.every((z) => z != null) && zones[0] != zones[1]
        ? ['shoulder_press_asymmetry']
        : <String>[];
    _track(codes);
    String? repEvent;
    if (zone != _zone) {
      _zone = zone;
      _zoneSince = timestampMs;
      if (_phase == 'ready' && zone == 'active' && _cycleStart == null) {
        _cycleStart = timestampMs;
      }
    }
    if (zone != null && timestampMs - _zoneSince >= 150) {
      if (zone == 'baseline') {
        if (_phase == 'active' &&
            _cycleStart != null &&
            timestampMs - _cycleStart! >= 300) {
          repEvent = _count('shoulderPress');
        }
        _phase = 'ready';
        _cycleStart = null;
        _bad = false;
      } else if (zone == 'active' && _phase == 'ready') {
        _phase = 'active';
        _cycleStart ??= timestampMs;
      }
    }
    _lastTime = timestampMs;
    return _result(true, codes, repEvent);
  }
}

class _Side {
  const _Side({
    required this.side,
    required this.shoulder,
    required this.hip,
    required this.ankle,
    required this.horizontal,
    required this.knee,
    required this.body,
    required this.elbow,
    required this.score,
  });
  final int side;
  final PosePoint shoulder;
  final PosePoint? hip, ankle;
  final bool horizontal;
  final double? knee, body, elbow;
  final double score;
}
