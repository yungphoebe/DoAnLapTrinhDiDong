import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera_capture.dart';
import '../services/lm_studio_service.dart';
import '../services/workout_analysis.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../models/workout.dart';
import '../ui.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.ai, this.exercise});

  final LMStudioService? ai;
  final Exercise? exercise;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late final LMStudioService _ai;
  final _elapsed = Stopwatch();
  late final WorkoutAnalysis _analysis;
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  Future<void> _cameraTask = Future.value();
  Future<Uint8List>? _captureTask;
  Timer? _timer;
  String? _cameraError;
  String _model = const String.fromEnvironment('LM_STUDIO_VISION_MODEL');
  int _cameraIndex = 0;
  int _cameraGeneration = 0;
  int _ticks = 0;
  bool _opening = true;
  bool _foreground = true;
  bool _started = false;
  bool _paused = false;
  bool _finishing = false;
  DateTime? _startedAt;
  String? _sessionToken;
  late final String _sessionId = _newSessionId();

  String _newSessionId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  bool get _canAnalyze =>
      mounted &&
      _foreground &&
      !_finishing &&
      _started &&
      !_paused &&
      !_opening &&
      _camera?.value.isInitialized == true;

  @override
  void initState() {
    super.initState();
    _ai = widget.ai ?? LMStudioService();
    WidgetsBinding.instance.addObserver(this);
    _analysis = WorkoutAnalysis(
      capture: () async {
        if (_model.trim().isEmpty) {
          final models = await _ai.getModels();
          if (models.isEmpty) {
            throw Exception('Chưa tải model trong LM Studio.');
          }
          _model = models.first;
        }
        if (!_canAnalyze) throw StateError('Phiên phân tích đã dừng.');
        final capture = captureCameraFrame(_camera!);
        _captureTask = capture;
        try {
          return await capture;
        } finally {
          _captureTask = null;
        }
      },
      analyze: (bytes) async {
        return _ai.analyzeImage(
          modelId: _model.trim(),
          imageBytes: bytes,
          prompt:
              'Bạn là trợ lý quan sát tư thế ${widget.exercise?.name ?? 'tập luyện'}. '
              'Nhận xét ảnh hiện tại '
              'bằng tiếng Việt, tối đa 3 câu ngắn. Chỉ mô tả những gì nhìn thấy '
              'và gợi ý chỉnh tư thế nếu có cơ sở. Nếu không thấy rõ toàn thân, '
              'hãy yêu cầu chỉnh vị trí camera. Không bịa góc khớp, số lần tập '
              'hay khẳng định động tác an toàn từ một ảnh.',
        );
      },
    )..addListener(_refresh);
    _restartCamera();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_canAnalyze && ++_ticks % 3 == 0) {
        unawaited(_analysis.process());
      }
      setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _cameraChanged() {
    final value = _camera?.value;
    if (!mounted || value == null || !value.hasError) return;
    _analysis.setPaused(true);
    _elapsed.stop();
    setState(
      () => _cameraError =
          'Camera đã ngừng hoạt động. '
          'Kiểm tra thiết bị rồi thử lại.\n${value.errorDescription}',
    );
  }

  Future<void> _releaseCamera(CameraController? camera) async {
    camera?.removeListener(_cameraChanged);
    try {
      await _captureTask;
    } catch (_) {
      // WorkoutAnalysis reports capture errors; disposal must still run.
    }
    await camera?.dispose();
  }

  // Serialize opening and disposal, including navigation during permission prompts.
  void _restartCamera() {
    final generation = ++_cameraGeneration;
    _analysis.setPaused(true);
    _elapsed.stop();
    if (mounted) setState(() => _opening = true);
    _cameraTask = _cameraTask.then((_) async {
      if (generation != _cameraGeneration) return;
      final previous = _camera;
      _camera = null;
      CameraController? next;
      try {
        await _releaseCamera(previous);
        if (!mounted ||
            !_foreground ||
            _finishing ||
            generation != _cameraGeneration) {
          return;
        }
        _cameras = await availableCameras();
        if (!mounted ||
            !_foreground ||
            _finishing ||
            generation != _cameraGeneration) {
          return;
        }
        if (_cameras.isEmpty) {
          throw CameraException('NoCamera', 'Không tìm thấy camera.');
        }
        _cameraIndex %= _cameras.length;
        next = CameraController(
          _cameras[_cameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await next.initialize();
        if (!mounted ||
            !_foreground ||
            _finishing ||
            generation != _cameraGeneration) {
          await next.dispose();
          return;
        }
        _camera = next;
        next.addListener(_cameraChanged);
        _cameraError = null;
        _analysis.setPaused(!_started || _paused);
        if (_started && !_paused) _elapsed.start();
      } catch (error) {
        await next?.dispose();
        if (mounted) {
          _cameraError =
              error is CameraException &&
                  error.code.toLowerCase().contains('denied')
              ? 'Quyền camera bị từ chối. Hãy cho phép camera trong cài đặt '
                    'ứng dụng hoặc trình duyệt, rồi thử lại.'
              : 'Không mở được camera. Kiểm tra thiết bị, quyền truy cập '
                    'và đóng ứng dụng khác đang dùng camera.\n$error';
        }
      } finally {
        if (mounted && generation == _cameraGeneration) {
          setState(() => _opening = false);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _restartCamera();
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      _restartCamera();
    }
  }

  void _toggleAnalysis() {
    setState(() {
      if (!_started) {
        _started = true;
        _startedAt = DateTime.now().toUtc();
        _sessionToken = ApiClient.instance.token;
      } else {
        _paused = !_paused;
      }
      _analysis.setPaused(_paused);
      if (_paused) {
        _elapsed.stop();
      } else {
        _elapsed.start();
      }
    });
    if (_canAnalyze) unawaited(_analysis.process());
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _paused = true;
    _finishing = true;
    _restartCamera();
    final seconds = _elapsed.elapsed.inSeconds;
    var saved = false;
    var saving = false;
    String? saveError;
    Future<void> save() async {
      try {
        if (_sessionToken == null ||
            _sessionToken != ApiClient.instance.token) {
          throw ApiException(401, 'Vui lòng đăng nhập để lưu phiên tập.');
        }

        await ProfileService.instance.saveWorkout(
          id: _sessionId,
          startedAt: _startedAt!,
          durationSeconds: seconds,
        );
        saved = true;
        saveError = null;
      } catch (_) {
        saveError = 'Chưa lưu được phiên tập. Kiểm tra kết nối và thử lại.';
      }
    }

    if (seconds > 0 && _startedAt != null) await save();
    if (!mounted) return;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hoàn thành buổi tập',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text('$seconds giây phân tích'),
                  const SizedBox(height: 12),
                  Text(
                    saved
                        ? 'Đã lưu vào tài khoản của bạn.'
                        : saveError ?? 'Chưa có thời gian tập để lưu.',
                  ),
                  if (saveError != null)
                    TextButton(
                      onPressed: saving
                          ? null
                          : () async {
                              update(() => saving = true);
                              await save();
                              if (context.mounted) update(() => saving = false);
                            },
                      child: Text(saving ? 'Đang lưu...' : 'Thử lưu lại'),
                    ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: saveError == null
                        ? 'Về trang chủ'
                        : 'Thoát không lưu',
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmExit() async {
    if (!_started || _finishing) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát phiên tập?'),
        content: const Text(
          'Phiên tập sẽ được dừng và lưu thời lượng hiện tại trước khi thoát.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thoát và lưu'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _elapsed.stop();
    _analysis.dispose();
    _foreground = false;
    _camera?.removeListener(_cameraChanged);
    unawaited(_cameraTask.then((_) => _releaseCamera(_camera)));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final seconds = _elapsed.elapsed.inSeconds;
    return PopScope(
      canPop: !_started || _finishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Camera AI'),
          actions: [
            if (_cameras.length > 1)
              IconButton(
                tooltip: 'Đổi camera',
                onPressed: _opening || _analysis.busy
                    ? null
                    : () {
                        _cameraIndex++;
                        _restartCamera();
                      },
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_opening &&
                  _cameraError == null &&
                  camera?.value.isInitialized == true)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .5,
                  child: Center(child: CameraPreview(camera!)),
                )
              else
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _opening
                      ? const Center(child: CircularProgressIndicator())
                      : _cameraError != null
                      ? Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_outlined,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _cameraError!,
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _restartCamera,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Center(child: Text('Camera đã dừng')),
                ),
              const SizedBox(height: 16),
              Text(
                _paused
                    ? 'Đã tạm dừng'
                    : '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
                          '${(seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 12),
              if (!_started) ...[
                TextFormField(
                  initialValue: _model,
                  decoration: const InputDecoration(
                    labelText: 'Model hình ảnh (LM Studio)',
                    hintText: 'Để trống: dùng model đang tải đầu tiên',
                  ),
                  onChanged: (value) => _model = value,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bắt đầu để gửi ảnh camera định kỳ tới máy chủ '
                  'LM Studio đã cấu hình. Cần model hỗ trợ hình ảnh. '
                  'Đặt camera sao cho thấy rõ toàn thân.',
                ),
              ],
              if (_analysis.busy && !_paused) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('AI đang phân tích ảnh…'),
              ],
              if (_analysis.error != null)
                Text(
                  'Chưa phân tích được ảnh. Kiểm tra LM Studio, model '
                  'hình ảnh và kết nối mạng.\n${_analysis.error}',
                  style: const TextStyle(color: Colors.orangeAccent),
                )
              else if (_analysis.feedback != null)
                Text(_analysis.feedback!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Bài đang chọn: ${widget.exercise?.name ?? 'Tập tự do'}. '
                'Phản hồi theo từng ảnh, không đếm số lần hoặc đo góc khớp. '
                'Tốc độ phụ thuộc model AI.',
                style: TextStyle(color: GymColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        _opening || _cameraError != null || camera == null
                        ? null
                        : _toggleAnalysis,
                    icon: Icon(
                      _started && !_paused ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      !_started
                          ? 'Bắt đầu phân tích'
                          : _paused
                          ? 'Tiếp tục'
                          : 'Tạm dừng',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _finish,
                    child: const Text('KẾT THÚC'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
