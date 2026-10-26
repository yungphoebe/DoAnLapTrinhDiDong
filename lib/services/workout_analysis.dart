import 'package:flutter/foundation.dart';

/// Processes at most one frame at a time; paused sessions ignore late results.
class WorkoutAnalysis extends ChangeNotifier {
  WorkoutAnalysis({required this.capture, required this.analyze});

  final Future<Uint8List> Function() capture;
  final Future<String> Function(Uint8List) analyze;
  String? feedback;
  String? error;
  bool busy = false;
  bool _paused = false;
  bool _disposed = false;
  int _generation = 0;

  void setPaused(bool value) {
    _paused = value;
    _generation++;
    feedback = null;
    error = null;
  }

  Future<void> process() async {
    if (_disposed || _paused || busy) return;
    final generation = _generation;
    bool isCurrent() => !_disposed && !_paused && generation == _generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final bytes = await capture();
      if (!isCurrent()) return;
      final result = await analyze(bytes);
      if (isCurrent()) feedback = result;
    } catch (exception) {
      if (isCurrent()) {
        feedback = null;
        error = exception.toString();
      }
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
