import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_gym/services/lm_studio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late LMStudioService ai;
  late Map<String, dynamic> body;
  late String path;
  Object response = {};
  int status = 200;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ai = LMStudioService(baseUrl: 'http://127.0.0.1:${server.port}/v1');
    status = 200;
    server.listen((request) async {
      path = request.uri.path;
      body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  Future<String> analyze() => ai.analyzeImage(
    modelId: 'vision',
    prompt: 'Quan sát tư thế',
    imageBytes: Uint8List.fromList([1, 2, 3]),
  );

  test('image request disables reasoning and storage and returns only final feedback', () async {
    response = {
      'output': [
        {'type': 'reasoning', 'content': 'internal thoughts'},
        {'type': 'message', 'content': ' Giữ toàn thân trong khung hình. '},
      ],
    };
    expect(await analyze(), 'Giữ toàn thân trong khung hình.');
    expect(path, '/api/v1/chat');
    expect(body['model'], 'vision');
    expect(body['reasoning'], 'off');
    expect(body['store'], isFalse);
    expect(body['input'], [
      {'type': 'text', 'content': 'Quan sát tư thế'},
      {'type': 'image', 'data_url': 'data:image/jpeg;base64,AQID'},
    ]);
  });

  test(
    'reasoning-only response cannot be displayed as exercise advice',
    () async {
      response = {
        'output': [
          {'type': 'reasoning', 'content': 'unfinished'},
        ],
      };
      await expectLater(
        analyze(),
        throwsA(predicate((e) => e.toString().contains('phản hồi'))),
      );
    },
  );

  test('vision endpoint reports HTTP failures', () async {
    status = 400;
    response = {'error': 'model does not support images'};
    await expectLater(
      analyze(),
      throwsA(predicate((e) => e.toString().contains('400'))),
    );
  });

  test('malformed output is rejected without casting crash', () async {
    response = {'output': 'invalid'};
    await expectLater(
      analyze(),
      throwsA(predicate((e) => e.toString().contains('phản hồi'))),
    );
  });
}
