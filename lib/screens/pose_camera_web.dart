import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../services/api_client.dart';
import '../services/pose_rules.dart';
import '../services/profile_service.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class PoseCameraScreen extends StatefulWidget {
  const PoseCameraScreen({super.key, this.exercise});

  final Exercise? exercise;
  @override
  State<PoseCameraScreen> createState() => _PoseCameraScreenState();
}

class _PoseCameraScreenState extends State<PoseCameraScreen> {
  final _token = ApiClient.instance.token;
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  bool _allowPop = false;
  bool _closeRequested = false;
  bool _frameReady = false;
  final _pending = <String>{};
  final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String? get _poseMode {
    return poseExerciseFor(widget.exercise?.id) ??
        poseExerciseFor(widget.exercise?.name);
  }

  @override
  void initState() {
    super.initState();
    _listener = ((web.MessageEvent event) {
      _message(event);
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  void _send(Map<String, dynamic> message) {
    _frame?.contentWindow?.postMessage(
      jsonEncode(message).toJS,
      web.window.location.origin.toJS,
    );
  }

  void _requestClose() {
    if (_closeRequested) return;
    if (!_frameReady || _frame?.contentWindow == null) {
      _allowPopAndExit();
      return;
    }
    _closeRequested = true;
    _send({'type': 'aigym:requestClose'});
  }

  void _allowPopAndExit() {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _message(web.MessageEvent event) async {
    if (!mounted ||
        event.origin != web.window.location.origin ||
        _frame?.contentWindow == null ||
        event.source != _frame!.contentWindow) {
      return;
    }
    Map<String, dynamic> message;
    try {
      final raw = event.data.dartify();
      if (raw is! String) return;
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (message['type'] == 'aigym:close') {
      _allowPopAndExit();
      return;
    }
    if (message['type'] == 'aigym:closeCancelled') {
      _closeRequested = false;
      return;
    }
    if (message['type'] != 'aigym:save') return;
    final requestId = message['requestId'];
    if (requestId is! String ||
        !_uuid.hasMatch(requestId) ||
        !_pending.add(requestId)) {
      return;
    }
    var ok = false;
    var result = 'Không lưu được phiên tập. Vui lòng thử lại.';
    try {
      if (_token == null || _token != ApiClient.instance.token) {
        throw const FormatException();
      }
      final session = message['session'] as Map<String, dynamic>;
      final id = session['id'];
      final startedAt = DateTime.tryParse(
        session['startedAt']?.toString() ?? '',
      );
      final duration = session['durationSeconds'];
      if (id is! String ||
          !_uuid.hasMatch(id) ||
          startedAt == null ||
          duration is! int ||
          duration < 1 ||
          duration > 86400) {
        throw const FormatException();
      }
      final exercises = (session['exercises'] as List).map((value) {
        final exercise = Map<String, dynamic>.from(value as Map);
        if (![
          'squat',
          'pushup',
          'jumpingJack',
          'shoulderPress',
          'bicepsCurl',
        ].contains(exercise['exercise'])) {
          throw const FormatException();
        }
        for (final key in ['reps', 'correctReps', 'incorrectReps']) {
          if (exercise[key] is! int || exercise[key] < 0) {
            throw const FormatException();
          }
        }
        if (exercise['reps'] !=
            exercise['correctReps'] + exercise['incorrectReps']) {
          throw const FormatException();
        }
        return exercise;
      }).toList();
      final feedback = Map<String, int>.from(session['feedbackCounts'] as Map);
      if (feedback.values.any((count) => count < 0)) {
        throw const FormatException();
      }
      final plannedExercise = widget.exercise;
      if (plannedExercise != null &&
          (plannedExercise.planId != null ||
              plannedExercise.planExerciseId != null)) {
        final mode = _poseMode;
        final matching =
            exercises.where((item) => item['exercise'] == mode).toList();
        if (mode == null ||
            plannedExercise.planId == null ||
            plannedExercise.planExerciseId == null ||
            matching.length != 1) {
          throw const FormatException();
        }
        final measuredReps = matching.single['reps'] as int;
        final measuredSets = (measuredReps ~/ plannedExercise.reps).clamp(
          0,
          plannedExercise.sets,
        );
        final timeTargetMet = plannedExercise.targetSeconds == null ||
            duration >= plannedExercise.targetSeconds! * plannedExercise.sets;
        final completed = measuredSets == plannedExercise.sets && timeTargetMet;
        await WorkoutService().savePlanExerciseResult(
          planId: plannedExercise.planId!,
          planExerciseId: plannedExercise.planExerciseId!,
          id: id,
          startedAt: startedAt,
          durationSeconds: duration,
          actualSets: measuredSets,
          actualReps: measuredReps,
          completed: completed,
          feedbackCounts: feedback,
        );
      }
      await ProfileService.instance
          .saveWorkout(
            id: id,
            startedAt: startedAt,
            durationSeconds: duration,
            exercises: exercises,
            feedbackCounts: feedback,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted || _token != ApiClient.instance.token) return;
      ok = true;
      result = 'Đã lưu phiên tập vào tài khoản.';
    } catch (_) {
      if (_token != ApiClient.instance.token || _token == null) {
        result = 'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.';
      }
    } finally {
      _pending.remove(requestId);
    }
    if (mounted) {
      _send({
        'type': 'aigym:saved',
        'requestId': requestId,
        'ok': ok,
        'message': result,
      });
    }
  }

  @override
  void dispose() {
    _send({'type': 'aigym:dispose'});
    web.window.removeEventListener('message', _listener);
    _frame?.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    if (exercise != null && _poseMode == null) {
      return Scaffold(
        appBar: AppBar(title: Text(exercise.name)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bài "${exercise.name}" chưa được hỗ trợ nhận diện bằng camera.',
              ),
              const SizedBox(height: 12),
              Text(exercise.description),
              const SizedBox(height: 12),
              const Text(
                'Không có kết quả nhận diện hoặc trạng thái hoàn thành nào được tạo.',
              ),
            ],
          ),
        ),
      );
    }
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(exercise?.name ?? 'Camera AI')),
        body: SafeArea(
          child: Column(
            children: [
              if (exercise != null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Ngày ${exercise.dayNumber} · ${exercise.sets} hiệp × ${exercise.reps} lần'
                    '${exercise.targetSeconds == null ? '' : ' / ${exercise.targetSeconds} giây'}'
                    ' · nghỉ ${exercise.restSeconds} giây'
                    '${exercise.muscleGroup == null ? '' : ' · ${exercise.muscleGroup}'}',
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: HtmlElementView.fromTagName(
                  tagName: 'iframe',
                  onElementCreated: (element) {
                    final frame = element as web.HTMLIFrameElement;
                    _frame = frame;
                    frame
                      ..src = Uri.parse(web.document.baseURI)
                          .resolve('pose_camera.html')
                          .toString()
                      ..allow = 'camera'
                      ..title = 'Camera hướng dẫn tập luyện';
                    frame.style
                      ..border = '0'
                      ..width = '100%'
                      ..height = '100%';
                    frame.addEventListener(
                      'load',
                      ((web.Event _) {
                        _frameReady = true;
                        _send({
                          'type': 'aigym:configure',
                          'exercise': _poseMode,
                          'targetSets': exercise?.sets,
                          'targetReps': exercise?.reps,
                          'targetSeconds': exercise?.targetSeconds,
                          'restSeconds': exercise?.restSeconds,
                        });
                      }).toJS,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
