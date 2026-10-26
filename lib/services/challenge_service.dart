import 'dart:convert';
import 'api_client.dart';

class ChallengeService {
  static final ChallengeService instance = ChallengeService();

  Future<List<Map<String, dynamic>>> fetchChallenges() async {
    final response = await ApiClient.instance.get('/api/challenges', includeAuth: true);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List list = jsonDecode(response.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(response.statusCode, 'Không thể tải danh sách thử thách: ${response.body}');
  }

  Future<void> joinChallenge(String challengeId) async {
    final response = await ApiClient.instance.post(
      '/api/challenges/$challengeId/join',
      {},
      includeAuth: true,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    try {
      final data = jsonDecode(response.body);
      throw ApiException(response.statusCode, data['message']?.toString() ?? 'Lỗi tham gia thử thách');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(response.statusCode, 'Lỗi tham gia thử thách');
    }
  }

  Future<void> quitChallenge(String challengeId) async {
    final response = await ApiClient.instance.post(
      '/api/challenges/$challengeId/quit',
      {},
      includeAuth: true,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    try {
      final data = jsonDecode(response.body);
      throw ApiException(response.statusCode, data['message']?.toString() ?? 'Lỗi từ bỏ thử thách');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(response.statusCode, 'Lỗi từ bỏ thử thách');
    }
  }

  Future<Map<String, dynamic>> updateProgress(String challengeId, int amount) async {
    final response = await ApiClient.instance.post(
      '/api/challenges/$challengeId/progress',
      {'amount': amount},
      includeAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    try {
      final data = jsonDecode(response.body);
      final msg = data['message']?.toString() ?? 'Lỗi cập nhật tiến độ';
      throw ApiException(response.statusCode, msg);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(response.statusCode, 'Lỗi cập nhật tiến độ (${response.statusCode})');
    }
  }
}
