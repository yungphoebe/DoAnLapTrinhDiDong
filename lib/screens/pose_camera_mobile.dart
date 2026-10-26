import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/workout.dart';
import '../services/coach_voice_service.dart';
import '../services/pose_rules.dart';
import '../services/profile_service.dart';
import '../ui.dart';

/// On-device pose tracking (ML Kit) with rep counting and Vietnamese voice cues.
class MobilePoseCameraScreen extends StatefulWidget {
  const MobilePoseCameraScreen({super.key, this.exercise});

  final Exercise? exercise;

  @override
  State<MobilePoseCameraScreen> createState() => _MobilePoseCameraScreenState();
}

class _MobilePoseCameraScreenState extends State<MobilePoseCameraScreen>
    with WidgetsBindingObserver {
  final _detector = PoseDetector(options: PoseDetectorOptions());
  final _engine = PoseWorkout();
  final _voice = CoachVoiceService();
  final _elapsed = Stopwatch();
  late final String _sessionId = _uuid();
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int? _cameraIndex;
  Future<void> _cameraTask = Future.value();
  Timer? _clock;
  List<PosePoint?> _points = const [];
  PoseResult? _result;
  String? _error;
  String? _trackingError;
  String _mode = 'auto';
  DateTime? _startedAt;
  DateTime _spokenAt = DateTime(2000);
  String _spoken = '';
  int _lastFrame = 0;
  bool _busy = false, _running = false, _finishing = false, _voiceOn = true;

  String? get _requestedMode =>
      poseExerciseFor(widget.exercise?.id) ??
      poseExerciseFor(widget.exercise?.name);
  bool get _unsupported => widget.exercise != null && _requestedMode == null;

  static String _uuid() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    _mode = _requestedMode ?? 'auto';
    _engine.setExercise(_mode);
    // Rotation is derived from the sensor only, so keep the device upright.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _running) setState(() {});
    });
    _openCamera();
  }

  // Serialized so lifecycle changes during permission prompts cannot race.
  void _openCamera() {
    if (_unsupported) return;
    _cameraTask = _cameraTask.then((_) async {
      await _closeCamera();
      if (!mounted || _finishing) return;
      try {
        _cameras = await availableCameras();
        if (_cameras.isEmpty) {
          throw CameraException('NoCamera', 'Không tìm thấy camera.');
        }
        // Default to the front camera once; later reopens keep the user's choice.
        final index = (_cameraIndex ??= max(
                0,
                _cameras.indexWhere(
                    (c) => c.lensDirection == CameraLensDirection.front))) %
            _cameras.length;
        _cameraIndex = index;
        final camera = CameraController(
          _cameras[index],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        await camera.initialize();
        if (!mounted || _finishing) {
          await camera.dispose();
          return;
        }
        await camera.startImageStream(_onFrame);
        if (!mounted || _finishing) {
          await camera.stopImageStream();
          await camera.dispose();
          return;
        }
        setState(() {
          _camera = camera;
          _error = null;
        });
      } catch (error) {
        if (mounted) {
          setState(() => _error = error is CameraException &&
                  error.code.toLowerCase().contains('denied')
              ? 'Quyền camera bị từ chối. Hãy cho phép camera trong cài đặt rồi thử lại.'
              : 'Không mở được camera.\n$error');
        }
      }
    });
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    _engine.resetMotion();
    if (camera == null) return;
    if (camera.value.isStreamingImages) await camera.stopImageStream();
    await camera.dispose();
  }

  InputImage? _inputImage(CameraImage image, CameraDescription description) {
    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    final camera = _camera;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || camera == null || now - _lastFrame < 80) return;
    _lastFrame = now;
    final input = _inputImage(image, camera.description);
    if (input == null) {
      _showTrackingError(
          'Định dạng ảnh camera chưa được hỗ trợ. Hãy đổi camera hoặc mở lại màn hình.',
          now);
      return;
    }
    _busy = true;
    try {
      final poses = await _detector.processImage(input);
      if (!mounted || camera != _camera) return;
      // Android frames arrive in sensor orientation; iOS frames are already upright.
      final rotated =
          Platform.isAndroid && camera.description.sensorOrientation % 180 != 0;
      final w = (rotated ? image.height : image.width).toDouble();
      final h = (rotated ? image.width : image.height).toDouble();
      final landmarks = poses.isEmpty ? null : poses.first.landmarks;
      final points = [
        for (final type in PoseLandmarkType.values)
          if (landmarks?[type] case final l?)
            PosePoint(l.x / w, l.y / h, l.likelihood)
          else
            null,
      ];
      if (!_running) {
        setState(() {
          _points = points;
          _trackingError = null;
        });
        return;
      }
      final result = _engine.update(points, now, width: w, height: h);
      setState(() {
        _points = points;
        _result = result;
        _trackingError = null;
      });
      _announce(result);
    } catch (_) {
      if (mounted && camera == _camera) {
        _showTrackingError(
            'Không xử lý được hình ảnh camera. Hãy đổi camera hoặc mở lại màn hình.',
            now);
      }
    } finally {
      _busy = false;
    }
  }

  void _showTrackingError(String message, int timestamp) {
    if (!mounted) return;
    setState(() {
      _points = const [];
      _result = _engine.update(const [], timestamp);
      _trackingError = message;
    });
  }

  void _announce(PoseResult result) {
    if (!_voiceOn) return;
    if (result.repEvent != null) {
      _say(
          result.repEvent == 'correct'
              ? '${result.reps}'
              : '${result.reps}, chưa đạt',
          force: true);
    } else if (result.feedbackCodes.isNotEmpty) {
      _say(result.feedback.join(' '));
    }
  }

  // Counts always speak and do not hold back cues; cues wait 5 s (15 s if repeated).
  void _say(String text, {bool force = false}) {
    final since = DateTime.now().difference(_spokenAt).inMilliseconds;
    if (!force && (since < 5000 || (text == _spoken && since < 15000))) return;
    if (!force) {
      _spokenAt = DateTime.now();
      _spoken = text;
    }
    unawaited(_voice.speak(text).catchError((_) {}));
  }

  void _toggle() {
    setState(() {
      _running = !_running;
      _engine.resetMotion();
      if (_running) {
        _startedAt ??= DateTime.now().toUtc();
        _elapsed.start();
      } else {
        _elapsed.stop();
      }
    });
    if (_voiceOn) {
      _say(
          _running
              ? 'Bắt đầu ${poseExerciseNames[_mode] ?? 'tập'}. Cố lên!'
              : 'Tạm dừng.',
          force: true);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _running = false;
    });
    _elapsed.stop();
    _cameraTask = _cameraTask.then((_) => _closeCamera());
    final summary = _engine.summary();
    final seconds = _elapsed.elapsed.inSeconds;
    final reps = summary.exercises.fold(0, (sum, e) => sum + e.reps);
    final correct = summary.exercises.fold(0, (sum, e) => sum + e.correctReps);
    if (_voiceOn) {
      _say('Hoàn thành. $reps lần, $correct lần đúng form.', force: true);
    }
    String? saveError;
    var saved = false;
    Future<void> save() async {
      try {
        await ProfileService.instance.saveWorkout(
          id: _sessionId,
          startedAt: _startedAt!,
          durationSeconds: seconds,
          exercises: [for (final e in summary.exercises) e.toJson()],
          feedbackCounts: summary.feedbackCounts,
        );
        saved = true;
        saveError = null;
      } catch (_) {
        saveError = 'Chưa lưu được phiên tập. Kiểm tra kết nối và thử lại.';
      }
    }

    if (seconds > 0 && _startedAt != null) await save();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Hoàn thành buổi tập',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('$seconds giây hoạt động'),
                for (final e in summary.exercises)
                  Text(
                      '${poseExerciseNames[e.exercise]}: ${e.reps} lần · ${e.correctReps} đạt · ${e.incorrectReps} có lỗi'),
                const SizedBox(height: 12),
                Text(saved
                    ? 'Đã lưu vào tài khoản và cập nhật thử thách.'
                    : saveError ?? 'Chưa có thời gian tập để lưu.'),
                if (saveError != null)
                  TextButton(
                    onPressed: () async {
                      await save();
                      if (context.mounted) update(() {});
                    },
                    child: const Text('Thử lưu lại'),
                  ),
                const SizedBox(height: 20),
                PrimaryButton(
                    label: 'Xong', onPressed: () => Navigator.pop(sheet)),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_running) _toggle();
      _cameraTask = _cameraTask.then((_) => _closeCamera());
    } else if (state == AppLifecycleState.resumed && !_finishing) {
      _openCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _finishing = true;
    SystemChrome.setPreferredOrientations([]);
    unawaited(
        _cameraTask.then((_) => _closeCamera()).then((_) => _detector.close()));
    unawaited(_voice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exercise!.name)),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Bài tập này chưa được hỗ trợ đếm rep. Các bài hiện có: Squat, chống đẩy, Jumping Jack, đẩy vai và tay trước.'),
        ),
      );
    }
    final camera = _camera;
    final result = _result;
    final seconds = _elapsed.elapsed.inSeconds;
    final state = result == null || !result.tracking
        ? Colors.purpleAccent
        : result.feedbackCodes.isEmpty
            ? Colors.greenAccent
            : Colors.redAccent;
    final message = _trackingError != null
        ? _trackingError!
        : !_running
            ? 'Đặt máy để thấy toàn thân, rồi bấm Bắt đầu.'
            : result == null
                ? 'Đang nhận diện…'
                : result.feedbackCodes.isNotEmpty
                    ? result.feedback.join(' ')
                    : 'Tốt lắm, tiếp tục động tác đủ biên độ.';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Camera AI đếm rep'),
        actions: [
          IconButton(
            tooltip: _voiceOn ? 'Tắt giọng nói' : 'Bật giọng nói',
            onPressed: () => setState(() => _voiceOn = !_voiceOn),
            icon: Icon(_voiceOn ? Icons.volume_up : Icons.volume_off),
          ),
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Đổi camera',
              onPressed: _finishing
                  ? null
                  : () {
                      _cameraIndex = (_cameraIndex ?? 0) + 1;
                      _openCamera();
                    },
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: camera?.value.isInitialized == true
                  ? 1 / camera!.value.aspectRatio
                  : 3 / 4,
              child: _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : camera?.value.isInitialized != true
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(camera!),
                            CustomPaint(
                              painter: _SkeletonPainter(
                                _points,
                                state,
                                mirror: camera.description.lensDirection ==
                                    CameraLensDirection.front,
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Thời gian',
                    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}'),
                _stat('Tổng', '${result?.reps ?? 0}'),
                _stat('Đúng form', '${result?.correctReps ?? 0}'),
                _stat('Có lỗi', '${result?.incorrectReps ?? 0}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(fontSize: 16, color: state)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Bài tập'),
              items: [
                const DropdownMenuItem(
                    value: 'auto', child: Text('Tự nhận diện')),
                for (final e in poseExercises)
                  DropdownMenuItem(
                      value: e, child: Text(poseExerciseNames[e]!)),
              ],
              onChanged: _finishing ||
                      _startedAt !=
                          null // backend accepts at most 3 exercises per session
                  ? null
                  : (value) => setState(() {
                        _mode = value!;
                        _engine.setExercise(_mode);
                      }),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: camera == null || _finishing ? null : _toggle,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running
                      ? 'Tạm dừng'
                      : _startedAt == null
                          ? 'Bắt đầu'
                          : 'Tiếp tục'),
                ),
                OutlinedButton(
                  onPressed: _startedAt == null || _finishing ? null : _finish,
                  child: const Text('KẾT THÚC'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nhận diện chạy ngay trên máy, không gửi ảnh đi. Squat/chống đẩy: quay ngang. '
              'Jumping Jack/đẩy vai: quay chính diện. '
              'Đẩy vai và tay trước cần chọn đúng bài trước khi Bắt đầu. '
              'Đẩy vai: hạ tạ về ngang vai, đẩy lên duỗi tay rồi hạ về ngang vai để tính 1 rep.',
              style: TextStyle(color: GymColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(fontSize: 11, color: GymColors.muted)),
          ],
        ),
      );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.points, this.color, {required this.mirror});

  static const _edges = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
    [27, 29],
    [29, 31],
    [28, 30],
    [30, 32],
  ];
  final List<PosePoint?> points;
  final Color color;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    Offset? at(int i) {
      final p = i < points.length ? points[i] : null;
      if (p == null || p.visibility < .25) return null;
      return Offset((mirror ? 1 - p.x : p.x) * size.width, p.y * size.height);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    for (final edge in _edges) {
      final a = at(edge[0]), b = at(edge[1]);
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
    for (var i = 0; i < points.length; i++) {
      final p = at(i);
      if (p != null) canvas.drawCircle(p, 4, paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.points != points || old.color != color;
}
