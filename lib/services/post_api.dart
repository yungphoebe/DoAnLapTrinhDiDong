import 'dart:convert';

import '../models/comment.dart';
import '../models/post.dart';
import 'api_client.dart';

class PostPage {
  const PostPage({required this.items, required this.hasMore});

  final List<Post> items;
  final bool hasMore;
}

class PostApi {
  PostApi({List<Post>? initialPosts, bool localOnly = false, ApiClient? client})
    : _posts = [...?initialPosts],
      // Keep the public localOnly argument while storing the mode privately.
      // ignore: prefer_initializing_formals
      _localOnly = localOnly,
      _client = client ?? ApiClient.instance {
    _cachedSession = _client.token;
  }

  factory PostApi.seeded() {
    final now = DateTime(2026, 10, 9, 20);
    return PostApi(
      localOnly: true,
      initialPosts: [
        Post(
          id: 'post-1',
          authorName: 'Linh Nguyen',
          avatarAsset: 'assets/images/avatar.jpg',
          content: 'Hom nay pha ky luc ca nhan Squat 100kg! Nho AI kiem tra form dung goc do cuc chuan luon.',
          imageAsset: 'assets/images/community.jpg',
          createdAt: now.subtract(const Duration(hours: 2)),
          likeCount: 128,
          comments: [
            Comment(
              id: 'comment-seed-1',
              authorName: 'Minh Anh',
              content: 'Qua dinh! Cung co gang nhe.',
              createdAt: now.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
        Post(
          id: 'post-2',
          authorName: 'AI GYM Club',
          avatarAsset: 'assets/images/trainer.jpg',
          content: 'Thu thach 7 ngay: moi ngay them 10 phut cardio sau buoi tap chinh.',
          createdAt: now.subtract(const Duration(hours: 5)),
          likeCount: 47,
          comments: const [],
          tag: 'Thu thach',
        ),
      ],
    );
  }

  final List<Post> _posts;
  final bool _localOnly;
  final ApiClient _client;
  var _nextCommentId = 2;
  var _feedGeneration = 0;
  String? get sessionToken => _client.token;
  String? _cachedSession;

  void _syncSession() {
    if (_cachedSession == sessionToken) return;
    _cachedSession = sessionToken;
    _posts.clear();
    _feedGeneration++;
  }

  Future<PostPage> getPostPage({int page = 1, int pageSize = 20}) async {
    _syncSession();
    final session = sessionToken;
    final generation = page == 1 ? ++_feedGeneration : _feedGeneration;
    if (_localOnly) {
      final start = (page - 1) * pageSize;
      return PostPage(
        items: List.unmodifiable(_posts.skip(start).take(pageSize)),
        hasMore: start + pageSize < _posts.length,
      );
    }
    final response = await _client
        .get('/api/posts/feed?page=$page&pageSize=$pageSize', includeAuth: true)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Không thể tải bài viết từ máy chủ.',
      );
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = (decoded['items'] as List<dynamic>)
        .map((item) => _fromJson(item as Map<String, dynamic>))
        .toList();
    if (generation == _feedGeneration && session == sessionToken) {
      if (page == 1) _posts.clear();
      final cachedIds = _posts.map((post) => post.id).toSet();
      for (final post in items) {
        if (cachedIds.add(post.id)) _posts.add(post);
      }
    }
    return PostPage(
      items: List.unmodifiable(items),
      hasMore: decoded['hasMore'] == true,
    );
  }

  Future<List<Post>> getPosts() async {
    _syncSession();
    if (_localOnly) return List.unmodifiable(_posts);

    final response = await _client.get('/api/posts', includeAuth: true);
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'Không thể tải bài viết từ máy chủ.',
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    final posts = decoded
        .map((item) => _fromJson(item as Map<String, dynamic>))
        .toList();
    _posts
      ..clear()
      ..addAll(posts);
    return List.unmodifiable(posts);
  }

  Future<Post?> createPost(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    if (_localOnly) {
      final post = Post(
        id: 'post-${_posts.length + 1}',
        authorName: 'Ban',
        avatarAsset: 'assets/images/avatar.jpg',
        content: trimmed,
        createdAt: DateTime.now(),
        likeCount: 0,
        comments: const [],
      );
      _posts.insert(0, post);
      return post;
    }

    final response = await _client.post('/api/posts', {
      'content': trimmed,
      'tag': 'Bai viet',
    }, includeAuth: true);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(response.statusCode, 'Không thể tạo bài viết.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final post = _fromJson(decoded);
    _posts.insert(0, post);
    return post;
  }

  Future<Post?> updatePost(String postId, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    if (_localOnly) {
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index == -1) return null;
      final updated = _posts[index].copyWith(content: trimmed);
      _posts[index] = updated;
      return updated;
    }

    final response = await _client.put('/api/posts/$postId', {
      'content': trimmed,
    }, includeAuth: true);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không thể cập nhật bài viết.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final updated = _fromJson(decoded);

    final index = _posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      _posts[index] = updated;
    }
    return updated;
  }

  Future<void> deletePost(String postId) async {
    if (_localOnly) {
      _posts.removeWhere((post) => post.id == postId);
      return;
    }

    final response = await _client.delete(
      '/api/posts/$postId',
      includeAuth: true,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(response.statusCode, 'Không thể xóa bài viết.');
    }
    _posts.removeWhere((post) => post.id == postId);
  }

  Future<Post?> toggleLike(String postId) async {
    _syncSession();
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return null;
    return setLike(postId, !_posts[index].liked);
  }

  Future<Post?> setLike(String postId, bool liked) async {
    _syncSession();
    var index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return null;
    final session = sessionToken;
    late final bool confirmedLiked;
    late final int confirmedCount;
    if (_localOnly) {
      final post = _posts[index];
      confirmedLiked = liked;
      confirmedCount = post.liked == liked
          ? post.likeCount
          : (post.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
    } else {
      final response = await _client
          .put('/api/posts/$postId/like', {'liked': liked}, includeAuth: true)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode,
          'Không thể cập nhật lượt thích. Vui lòng thử lại.',
        );
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      confirmedLiked = json['liked'] as bool;
      confirmedCount = json['likeCount'] as int;
    }
    if (session != sessionToken) return null;
    index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return null;
    final updated = _posts[index].copyWith(
      liked: confirmedLiked,
      likeCount: confirmedCount,
    );
    _posts[index] = updated;
    return updated;
  }

  Future<Post?> addComment(String postId, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return null;
    final post = _posts[index];
    final comment = Comment(
      id: 'comment-${_nextCommentId++}',
      authorName: 'Ban',
      content: trimmed,
      createdAt: DateTime.now(),
    );
    final updated = post.copyWith(comments: [...post.comments, comment]);
    _posts[index] = updated;
    return updated;
  }

  Post _fromJson(Map<String, dynamic> json) => Post(
    id: (json['id'] ?? '').toString(),
    authorName: (json['authorName'] ?? 'User').toString(),
    avatarAsset: 'assets/images/avatar.jpg',
    content: (json['content'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
    likeCount: int.tryParse((json['likeCount'] ?? '0').toString()) ?? 0,
    comments: const [],
    imageAsset: _imageSource(json['imageAsset']?.toString()),
    liked: json['liked'] == true,
    tag: (json['tag'] ?? 'Bai viet').toString(),
  );

  String? _imageSource(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('assets/')) return value;
    return Uri.parse('${_client.baseUrl}/').resolve(value).toString();
  }
}
