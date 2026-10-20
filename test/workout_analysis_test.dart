import 'dart:async';
import 'dart:typed_data';

import 'package:ai_gym/services/workout_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends captured bytes and does not overlap analysis requests', () async {
    final response = Completer<String>();
    var captures = 0;
    final analysis = WorkoutAnalysis(
      capture: () async {
        captures++;
        return Uint8List.fromList([1, 2, 3]);
      },
      analyze: (bytes) {
        expect(bytes, [1, 2, 3]);
        return response.future;
      },
    );
    final first = analysis.process();
    await analysis.process();
    expect(captures, 1);
    response.complete('Đưa toàn thân vào khung hình');
    await first;
    expect(analysis.feedback, 'Đưa toàn thân vào khung hình');
    expect(analysis.busy, isFalse);
    analysis.dispose();
  });

  test('pause discards stale feedback even after resuming', () async {
    final response = Completer<String>();
    final analysis = WorkoutAnalysis(
      capture: () async => Uint8List(1),
      analyze: (_) => response.future,
    );
    final pending = analysis.process();
    await Future<void>.delayed(Duration.zero);
    analysis.setPaused(true);
    analysis.setPaused(false);
    response.complete('stale');
    await pending;
    expect(analysis.feedback, isNull);
    analysis.dispose();
  });

  test('pause during capture prevents sending image', () async {
    final capture = Completer<Uint8List>();
    var sent = false;
    final analysis = WorkoutAnalysis(
      capture: () => capture.future,
      analyze: (_) async {
        sent = true;
        return 'result';
      },
    );
    final pending = analysis.process();
    analysis.setPaused(true);
    capture.complete(Uint8List(1));
    await pending;
    expect(sent, isFalse);
    analysis.dispose();
  });

  test('failure is visible and next request can recover', () async {
    var failed = true;
    final analysis = WorkoutAnalysis(
      capture: () async => Uint8List(1),
      analyze: (_) async {
        if (failed) throw Exception('offline');
        return 'feedback';
      },
    );
    await analysis.process();
    expect(analysis.error, contains('offline'));
    expect(analysis.busy, isFalse);
    failed = false;
    await analysis.process();
    expect(analysis.error, isNull);
    expect(analysis.feedback, 'feedback');
    analysis.dispose();
  });

  test('dispose suppresses pending results and future captures', () async {
    final response = Completer<String>();
    var captures = 0;
    final analysis = WorkoutAnalysis(
      capture: () async {
        captures++;
        return Uint8List(1);
      },
      analyze: (_) => response.future,
    );
    final pending = analysis.process();
    await Future<void>.delayed(Duration.zero);
    analysis.dispose();
    response.complete('late');
    await pending;
    await analysis.process();
    expect(analysis.feedback, isNull);
    expect(captures, 1);
  });
}
