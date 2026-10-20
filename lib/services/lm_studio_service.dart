import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';

class LMStudioService {
  LMStudioService({String? baseUrl, this.apiToken})
    : baseUrl = (baseUrl ?? AIConfig.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  final String baseUrl;
  final String? apiToken;

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiToken != null && apiToken!.isNotEmpty)
      'Authorization': 'Bearer $apiToken',
  };

  /// Uses LM Studio's native reasoning control for short camera feedback.
  Future<String> analyzeImage({
    required String modelId,
    required String prompt,
    required Uint8List imageBytes,
  }) async {
    final serverUrl = baseUrl.replaceFirst(RegExp(r'/v1$'), '');
    final response = await http
        .post(
          Uri.parse('$serverUrl/api/v1/chat'),
          headers: headers,
          body: jsonEncode({
            'model': modelId,
            'input': [
              {'type': 'text', 'content': prompt},
              {
                'type': 'image',
                'data_url':
                    'data:image/jpeg;base64,${base64Encode(imageBytes)}',
              },
            ],
            'reasoning': 'off',
            'store': false,
            'stream': false,
            'temperature': 0.2,
            'max_output_tokens': 256,
          }),
        )
        .timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) {
      throw Exception(
        'AI hình ảnh HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final output = decoded is Map<String, dynamic> ? decoded['output'] : null;
    final messages = output is List
        ? output
              .whereType<Map<String, dynamic>>()
              .where((item) => item['type'] == 'message')
              .map((item) => item['content'])
              .whereType<String>()
              .map((text) => text.trim())
              .where((text) => text.isNotEmpty)
              .join('\n')
        : '';
    if (messages.isEmpty) {
      throw Exception(
        'LM Studio chưa trả về phản hồi hình ảnh. '
        'Kiểm tra model vision và chế độ reasoning.',
      );
    }
    return messages;
  }

  Future<List<String>> getModels() async {
    final response = await http
        .get(Uri.parse('$baseUrl/models'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('LMStudio HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) {
      throw Exception('LMStudio trả về danh sách model không hợp lệ.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((model) => model['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<String> chat({
    required String modelId,
    required String prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];

    if (imageBytes != null) {
      content.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
        },
      });
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: headers,
          body: jsonEncode({
            'model': modelId,
            'messages': [
              {
                'role': 'user',
                'content': imageBytes == null ? prompt : content,
              },
            ],
            'temperature': 0.2,
            'max_tokens': 128,
            'stream': false,
            'chat_template_kwargs': {'enable_thinking': false},
          }),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('AI Error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = decoded is Map<String, dynamic> ? decoded['choices'] : null;
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map<String, dynamic> ? first['message'] : null;
    final answer = message is Map<String, dynamic>
        ? message['content'] ?? message['reasoning_content']
        : null;
    if (answer is! String || answer.trim().isEmpty) {
      throw Exception('LMStudio không trả về nội dung hợp lệ.');
    }
    return answer.trim();
  }
}
