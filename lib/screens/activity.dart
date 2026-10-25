import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/activity_service.dart';
import 'activity_route.dart';
import '../ui.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _service = ActivityService();
  final _tts = FlutterTts();
  final _stepsGoal = TextEditingController();
  final _minutesGoal = TextEditingController();
  final _kmGoal = TextEditingController();
  final _clock = Stopwatch();
  StreamSubscription<StepCount>? _stepsSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  Timer? _reminderTimer;
  List<Map<String, dynamic>> _sessions = [];
  final List<ActivityRoutePoint> _route = [];
  Map<String, dynamic>? _goal;
  Position? _lastPosition;
  DateTime? _startedAt;
  String? _sessionId;
  String _activityType = 'walking';
  String? _stepError;
  String? _gpsStatus;
  String? _saveError;
  int? _lastDeviceSteps;
  int? _steps;
  double? _distanceMeters;
  int _elapsedBeforePause = 0;
  bool _running = false;
  bool _started = false;
  bool _saving = false;
  bool _voiceEnabled = false;
  bool _reminderEnabled = false;
  bool _startNextRouteSegment = true;
  int _lastSpokenMinute = 0;
  final Set<String> _notifiedGoals = <String>{};

  int get _activeSeconds =>
      _elapsedBeforePause + (_running ? _clock.elapsed.inSeconds : 0);
  int get _dailySteps =>
      ((_goal?['steps'] as num?)?.toInt() ?? 0) + (_steps ?? 0);
  int get _dailyMinutes =>
      ((_goal?['minutes'] as num?)?.toInt() ?? 0) + _activeSeconds ~/ 60;
  double get _dailyKm =>
      ((_goal?['distanceKm'] as num?)?.toDouble() ?? 0) +
      (_distanceMeters ?? 0) / 1000;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _notifyGoalIfReached();
      _announceProgress();
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reminderTimer?.cancel();
    _stepsSubscription?.cancel();
    _positionSubscription?.cancel();
    _clock.stop();
    _stepsGoal.dispose();
    _minutesGoal.dispose();
    _kmGoal.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final today = DateTime.now();
      final results = await Future.wait([
        _service.goal(today),
        _service.sessions(today.subtract(const Duration(days: 6))),
      ]);
      if (!mounted) return;
      setState(() {
        _goal = results[0] as Map<String, dynamic>;
        _sessions = results[1] as List<Map<String, dynamic>>;
        _stepsGoal.text = (_goal!['stepsGoal'] ?? 0).toString();
        _minutesGoal.text = (_goal!['minutesGoal'] ?? 0).toString();
        _kmGoal.text = (_goal!['distanceGoalKm'] ?? 0).toString();
      });
    } catch (error) {
      if (mounted) setState(() => _saveError = 'Không tải được dữ liệu vận động: $error');
    }
  }

  Future<void> _saveGoals() async {
    final steps = int.tryParse(_stepsGoal.text) ?? -1;
    final minutes = int.tryParse(_minutesGoal.text) ?? -1;
    final kilometers = double.tryParse(_kmGoal.text.replaceAll(',', '.')) ?? -1;
    if (steps < 0 || minutes < 0 || kilometers < 0 ||
        (steps == 0 && minutes == 0 && kilometers == 0)) {
      showMessage(context, 'Đặt ít nhất một mục tiêu hợp lệ.');
      return;
    }
    try {
      final goal = await _service.saveGoal(
        date: DateTime.now(),
        steps: steps,
        minutes: minutes,
        kilometers: kilometers,
      );
      if (!mounted) return;
      setState(() => _goal = goal);
      showMessage(context, 'Đã lưu mục tiêu vận động hôm nay.');
      _notifyGoalIfReached();
    } catch (error) {
      if (mounted) showMessage(context, 'Không lưu được mục tiêu: $error');
    }
  }

  Future<bool> _enableGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _gpsStatus = 'GPS chưa bật; buổi tập vẫn chạy nhưng không có quãng đường.';
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _gpsStatus = 'Chưa được cấp quyền vị trí; quãng đường không được đo.';
        return false;
      }
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastPosition = first;
      if (_running && first.accuracy <= 50) {
        _addRoutePoint(first, segmentStart: true);
      }
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: (Object error) {
        if (mounted) setState(() => _gpsStatus = 'GPS ngừng hoạt động: $error');
      });
      _gpsStatus = 'Đang đo quãng đường bằng GPS.';
      return true;
    } catch (error) {
      _gpsStatus = 'GPS không hoạt động trên thiết bị này: $error';
      return false;
    }
  }

  void _onPosition(Position position) {
    if (!_running) {
      _lastPosition = null;
      return;
    }
    final previous = _lastPosition;
    _lastPosition = position;
    if (position.accuracy > 50) return;
    if (previous == null || previous.accuracy > 50) {
      _addRoutePoint(position, segmentStart: true);
      _startNextRouteSegment = false;
      return;
    }
    final segment = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    if (segment > 0 && segment < 500) {
      _distanceMeters = (_distanceMeters ?? 0) + segment;
      _addRoutePoint(position, segmentStart: _startNextRouteSegment);
      _startNextRouteSegment = false;
    }
  }

  void _addRoutePoint(Position position, {required bool segmentStart}) {
    if (_route.length >= 5000) {
      _gpsStatus = 'Đã đạt giới hạn điểm lưu lộ trình GPS của buổi tập.';
      return;
    }
    _route.add(
      ActivityRoutePoint(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp,
        segmentStart: segmentStart,
      ),
    );
  }

  void _onStepCount(StepCount value) {
    final previous = _lastDeviceSteps;
    _lastDeviceSteps = value.steps;
    if (previous != null && value.steps >= previous && _running) {
      _steps = (_steps ?? 0) + value.steps - previous;
    }
  }

  void _onStepError(Object error) {
    if (!mounted) return;
    setState(() {
      _stepError =
          'Cảm biến bước chân không khả dụng: $error. Không có số bước giả được hiển thị.';
      _steps = null;
    });
  }

  Future<void> _start() async {
    _stepError = null;
    _gpsStatus = null;
    _lastDeviceSteps = null;
    _steps = null;
    _distanceMeters = null;
    _route.clear();
    _startNextRouteSegment = true;
    _elapsedBeforePause = 0;
    _lastSpokenMinute = 0;
    _lastPosition = null;
    var canReadSteps = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final permission = await Permission.activityRecognition.request();
        if (!permission.isGranted) {
          _stepError =
              'Chưa được cấp quyền nhận diện hoạt động. Không có số bước giả được hiển thị.';
          canReadSteps = false;
        }
      } catch (error) {
        _stepError =
            'Không thể yêu cầu quyền cảm biến bước chân: $error';
        canReadSteps = false;
      }
    }
    if (canReadSteps) {
      try {
        _stepsSubscription = Pedometer.stepCountStream.listen(
          _onStepCount,
          onError: _onStepError,
          cancelOnError: false,
        );
      } catch (error) {
        _onStepError(error);
      }
    }
    if (!mounted) return;
    setState(() {
      _started = true;
      _running = true;
      _startedAt = DateTime.now().toUtc();
      _sessionId = _createId();
      _clock
        ..reset()
        ..start();
    });
    _configureReminder();
    await _enableGps();
    if (mounted) setState(() {});
  }

  void _pause() {
    if (_running) {
      _clock.stop();
      _elapsedBeforePause += _clock.elapsed.inSeconds;
      _running = false;
      _lastPosition = null;
      _startNextRouteSegment = true;
    } else {
      _clock
        ..reset()
        ..start();
      _running = true;
    }
    setState(() {});
    _configureReminder();
  }

  Future<void> _finish() async {
    if (!_started || _saving) return;
    if (_running) _pause();
    final seconds = _activeSeconds;
    if (seconds < 1 || _startedAt == null) {
      await _stepsSubscription?.cancel();
      await _positionSubscription?.cancel();
      _stepsSubscription = null;
      _positionSubscription = null;
      setState(() {
        _saveError = 'Buổi tập quá ngắn để lưu.';
        _started = false;
        _sessionId = null;
        _startedAt = null;
        _steps = null;
        _distanceMeters = null;
        _route.clear();
        _elapsedBeforePause = 0;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveSession(
        id: _sessionId!,
        activityType: _activityType,
        startedAt: _startedAt!,
        durationSeconds: seconds,
        steps: _steps,
        distanceMeters: _distanceMeters,
        route: List.unmodifiable(_route),
        completed: true,
      );
      await _stepsSubscription?.cancel();
      await _positionSubscription?.cancel();
      if (!mounted) return;
      setState(() {
        _started = false;
        _elapsedBeforePause = 0;
        _sessionId = null;
        _startedAt = null;
        _steps = null;
        _distanceMeters = null;
        _route.clear();
        _saveError = null;
      });
      await _load();
      if (mounted) showMessage(context, 'Đã lưu kết quả buổi vận động.');
    } catch (error) {
      if (mounted) setState(() => _saveError = 'Lưu buổi tập thất bại: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _createId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _notifyGoalIfReached() {
    if (_goal == null) return;
    final reached = <String>[];
    final stepTarget = (_goal!['stepsGoal'] as num?)?.toInt() ?? 0;
    final minuteTarget = (_goal!['minutesGoal'] as num?)?.toInt() ?? 0;
    final kmTarget = (_goal!['distanceGoalKm'] as num?)?.toDouble() ?? 0;
    if (stepTarget > 0 && _dailySteps >= stepTarget && _notifiedGoals.add('steps')) {
      reached.add('số bước');
    }
    if (minuteTarget > 0 && _dailyMinutes >= minuteTarget && _notifiedGoals.add('minutes')) {
      reached.add('thời gian vận động');
    }
    if (kmTarget > 0 && _dailyKm >= kmTarget && _notifiedGoals.add('distance')) {
      reached.add('quãng đường GPS');
    }
    if (reached.isEmpty) return;
    final message = 'Đã đạt mục tiêu ${reached.join(', ')} hôm nay.';
    if (mounted) showMessage(context, message);
    if (_voiceEnabled) {
      unawaited(_speak('Chúc mừng, $message'));
    }
  }

  void _configureReminder() {
    _reminderTimer?.cancel();
    if (_reminderEnabled && _running) {
      _reminderTimer = Timer.periodic(const Duration(minutes: 30), (_) {
        if (mounted && _running) {
          showMessage(context, 'Đã vận động 30 phút. Hãy kiểm tra sức và uống nước.');
          if (_voiceEnabled) {
            unawaited(
              _speak(
                'Bạn đã vận động 30 phút. Hãy kiểm tra sức và uống nước.',
              ),
            );
          }
        }
      });
    }
  }

  void _openRoute({
    required List<ActivityRoutePoint> route,
    required String title,
    required double? distanceMeters,
    required int durationSeconds,
    required int? steps,
    required DateTime? startedAt,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ActivityRouteScreen(
          title: title,
          route: route,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          steps: steps,
          startedAt: startedAt,
        ),
      ),
    );
  }

  void _announceProgress() {
    if (!_voiceEnabled || !_running || _activeSeconds < 60) return;
    final minute = _activeSeconds ~/ 60;
    if (minute % 5 != 0 || minute == _lastSpokenMinute) return;
    _lastSpokenMinute = minute;
    final progress = <String>['Đã vận động $minute phút'];
    if (_steps != null) progress.add('$_steps bước');
    if (_distanceMeters != null) {
      progress.add('${(_distanceMeters! / 1000).toStringAsFixed(2)} ki-lô-mét');
    }
    unawaited(_speak('${progress.join(', ')}.'));
  }

  Future<void> _speak(String text) async {
    try {
      final vietnameseAvailable = await _tts.isLanguageAvailable('vi-VN');
      if (vietnameseAvailable != true) {
        if (mounted) {
          showMessage(
            context,
            'Thiết bị chưa có giọng đọc tiếng Việt; hãy cài giọng tiếng Việt trong cài đặt hệ thống.',
          );
        }
        return;
      }
      await _tts.setLanguage('vi-VN');
      await _tts.speak(text);
    } catch (error) {
      if (mounted) {
        showMessage(context, 'Không đọc được tiến độ bằng giọng nói: $error');
      }
    }
  }

  String _duration(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đi bộ & chạy bộ')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_saveError != null)
          Text(_saveError!, style: const TextStyle(color: Colors.orange)),
        _sessionCard(),
        const SizedBox(height: 12),
        _goalCard(),
        const SizedBox(height: 12),
        _historyCard(),
      ],
    ),
  );

  Widget _sessionCard() => GymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _activityType,
          decoration: const InputDecoration(labelText: 'Loại vận động'),
          items: const [
            DropdownMenuItem(value: 'walking', child: Text('Đi bộ')),
            DropdownMenuItem(value: 'running', child: Text('Chạy bộ')),
          ],
          onChanged: _started ? null : (value) => setState(() => _activityType = value ?? _activityType),
        ),
        const SizedBox(height: 16),
        Text(_started ? (_running ? 'ĐANG VẬN ĐỘNG' : 'ĐÃ TẠM DỪNG') : 'SẴN SÀNG',
            style: const TextStyle(color: GymColors.muted, fontSize: 12)),
        Text(_duration(_activeSeconds),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text('Số bước buổi này: ${_steps?.toString() ?? 'không khả dụng'}'),
        Text(_distanceMeters == null
            ? 'Quãng đường: GPS chưa đo được'
            : 'Quãng đường GPS: ${(_distanceMeters! / 1000).toStringAsFixed(2)} km'),
        if (_distanceMeters != null && _activeSeconds > 0)
          Text('Tốc độ trung bình: ${(_distanceMeters! * 3.6 / _activeSeconds).toStringAsFixed(1)} km/h'),
        if (_stepError != null)
          Text(_stepError!, style: const TextStyle(color: Colors.orange)),
        if (_gpsStatus != null)
          Text(_gpsStatus!, style: const TextStyle(color: GymColors.muted, fontSize: 12)),
        if (_route.isNotEmpty)
          Row(
            children: [
              Expanded(child: Text('Đã ghi ${_route.length} điểm GPS vào lộ trình.')),
              TextButton.icon(
                onPressed: () => _openRoute(
                  route: List.unmodifiable(_route),
                  title: _activityType == 'running'
                      ? 'Lộ trình chạy bộ'
                      : 'Lộ trình đi bộ',
                  distanceMeters: _distanceMeters,
                  durationSeconds: _activeSeconds,
                  steps: _steps,
                  startedAt: _startedAt,
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Xem'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _started ? null : _start,
              child: const Text('Bắt đầu'),
            ),
            OutlinedButton(
              onPressed: !_started || _saving ? null : _pause,
              child: Text(_running ? 'Tạm dừng' : 'Tiếp tục'),
            ),
            OutlinedButton(
              onPressed: !_started || _saving ? null : _finish,
              child: Text(_saving ? 'Đang lưu...' : 'Kết thúc'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đọc tiến độ'),
                value: _voiceEnabled,
                onChanged: (value) {
                  setState(() => _voiceEnabled = value);
                  if (value) {
                    unawaited(
                      _speak(
                        'Đọc tiến độ tiếng Việt đã bật. Khi đang tập, tiến độ sẽ được đọc sau mỗi năm phút.',
                      ),
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nhắc vận động'),
                value: _reminderEnabled,
                onChanged: (value) => setState(() {
                  _reminderEnabled = value;
                  _configureReminder();
                }),
              ),
            ),
          ],
        ),
        if (_reminderEnabled)
          const Text(
            'Nhắc mỗi 30 phút khi ứng dụng đang mở và buổi tập đang chạy.',
            style: TextStyle(color: GymColors.muted, fontSize: 12),
          ),
        const Text(
          'Khi cho phép vị trí, ứng dụng ghi tuyến GPS để lưu và xem lại trong lịch sử buổi tập.',
          style: TextStyle(color: GymColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _goalCard() => GymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MỤC TIÊU HÔM NAY', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Bước đã ghi trong app: $_dailySteps / ${_goal?['stepsGoal'] ?? 0}'),
        Text('Phút: $_dailyMinutes / ${_goal?['minutesGoal'] ?? 0}'),
        Text('Km GPS: ${_dailyKm.toStringAsFixed(2)} / ${_goal?['distanceGoalKm'] ?? 0}'),
        TextField(
          controller: _stepsGoal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Mục tiêu bước/ngày'),
        ),
        TextField(
          controller: _minutesGoal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Mục tiêu phút/ngày'),
        ),
        TextField(
          controller: _kmGoal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Mục tiêu km GPS/ngày'),
        ),
        TextButton(onPressed: _saveGoals, child: const Text('Lưu mục tiêu')),
      ],
    ),
  );

  Widget _historyCard() => GymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LỊCH SỬ GẦN ĐÂY', style: TextStyle(fontWeight: FontWeight.w700)),
        if (_sessions.isEmpty) const Text('Chưa có buổi đi bộ/chạy nào được lưu.'),
        for (final session in _sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session['activityType'] == 'running' ? 'Chạy bộ' : 'Đi bộ'),
            subtitle: Text(
              '${DateTime.tryParse(session['startedAt']?.toString() ?? '')?.toLocal() ?? ''} · '
              '${_duration((session['durationSeconds'] as num?)?.toInt() ?? 0)} · '
              '${session['steps'] == null ? 'bước chưa khả dụng' : '${session['steps']} bước'} · '
              '${session['distanceMeters'] == null ? 'chưa có GPS' : '${((session['distanceMeters'] as num) / 1000).toStringAsFixed(2)} km'}'
              '${session['distanceEstimated'] == true ? ' (ước tính)' : ''}',
            ),
            trailing: session['route'] is List &&
                    (session['route'] as List).isNotEmpty
                ? const Icon(Icons.map_outlined)
                : null,
            onTap: session['route'] is List &&
                    (session['route'] as List).isNotEmpty
                ? () => _openRoute(
                    title: session['activityType'] == 'running'
                        ? 'Lộ trình chạy bộ'
                        : 'Lộ trình đi bộ',
                    route: (session['route'] as List)
                        .map(
                          (point) => ActivityRoutePoint.fromJson(
                            Map<String, dynamic>.from(point as Map),
                          ),
                        )
                        .toList(),
                    distanceMeters:
                        (session['distanceMeters'] as num?)?.toDouble(),
                    durationSeconds:
                        (session['durationSeconds'] as num?)?.toInt() ?? 0,
                    steps: (session['steps'] as num?)?.toInt(),
                    startedAt: DateTime.tryParse(
                      session['startedAt']?.toString() ?? '',
                    ),
                  )
                : null,
          ),
      ],
    ),
  );
}
