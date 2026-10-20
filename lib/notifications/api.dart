import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import 'models.dart';

class NotificationApi {
  NotificationApi({ApiClient? client}) : client = client ?? ApiClient.instance;
  final ApiClient client;
  String? get owner {
    try {
      final j = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(client.token!.split('.')[1])),
        ),
      ) as Map<String, dynamic>;
      final exp = j['exp'] as num?;
      if (exp == null || exp * 1000 <= DateTime.now().millisecondsSinceEpoch) {
        return null;
      }
      return (j['userId'] ?? j['sub']) as String?;
    } catch (_) {
      return null;
    }
  }

  dynamic decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        response.statusCode == 401
            ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
            : 'Không thể lưu hoặc tải dữ liệu. Vui lòng thử lại.',
      );
    }
    return response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<ReminderSettings> settings() async => ReminderSettings.fromJson(
    decode(
      await client
          .get('/api/notifications/settings', includeAuth: true)
          .timeout(const Duration(seconds: 15)),
    ) as Map<String, dynamic>,
  );
  Future<ReminderSettings> save(ReminderSettings value) async =>
      ReminderSettings.fromJson(
        decode(
          await client
              .put(
                '/api/notifications/settings',
                value.toJson(),
                includeAuth: true,
              )
              .timeout(const Duration(seconds: 15)),
        ) as Map<String, dynamic>,
      );
  Future<Map<String, dynamic>> inbox(int page) async => decode(
    await client
        .get('/api/notifications?page=$page&pageSize=20', includeAuth: true)
        .timeout(const Duration(seconds: 15)),
  ) as Map<String, dynamic>;
  Future<void> read(String id) async {
    decode(
      await client
          .put('/api/notifications/$id/read', {}, includeAuth: true)
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<void> readAll() async {
    decode(
      await client
          .put('/api/notifications/read-all', {}, includeAuth: true)
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<String> publicKey() async =>
      (decode(
            await client
                .get('/api/notifications/push-key', includeAuth: true)
                .timeout(const Duration(seconds: 15)),
          ) as Map<String, dynamic>)['publicKey']
          as String;
  Future<void> subscribe(Map<String, dynamic> value) async {
    decode(
      await client
          .post('/api/notifications/subscriptions', value, includeAuth: true)
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<void> unsubscribe(String endpoint) async {
    decode(
      await client
          .delete(
            '/api/notifications/subscriptions',
            includeAuth: true,
            body: {'endpoint': endpoint},
          )
          .timeout(const Duration(seconds: 5)),
    );
  }
}
