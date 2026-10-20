import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class CoachVoiceService {
  CoachVoiceService() : _speech = SpeechToText(), _tts = FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;

  Future<bool> initializeSpeech({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
  }

  bool get isListening => _speech.isListening;

  Future<void> listen({
    required void Function(String text, bool finalResult) onResult,
    required void Function(String message) onError,
  }) async {
    try {
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          localeId: 'vi_VN',
        ),
      );
    } catch (error) {
      onError('$error');
    }
  }

  Future<void> stopListening() => _speech.stop();

  Future<void> cancelListening() => _speech.cancel();

  Future<List<Map<String, String>>> voices() async {
    final values = await _tts.getVoices;
    return values
        .whereType<Map>()
        .map(
          (voice) => {
            'name': '${voice['name'] ?? ''}',
            'locale': '${voice['locale'] ?? ''}',
          },
        )
        .where((voice) => voice['locale']!.toLowerCase().startsWith('vi'))
        .toList();
  }

  Future<void> speak(String text, {String? voiceName, String? locale}) async {
    await _tts.stop();
    await _tts.setLanguage(locale ?? 'vi-VN');
    if (voiceName != null) {
      await _tts.setVoice({'name': voiceName, 'locale': locale ?? 'vi-VN'});
    }
    await _tts.setSpeechRate(.48);
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() => _tts.stop();

  Future<void> dispose() async {
    await _speech.cancel();
    await _tts.stop();
  }
}
