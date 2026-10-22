import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../services/post_api.dart';
import '../services/api_client.dart';

class PostController extends ChangeNotifier {
  PostController({required this.api, this.pageSize = 20});

  final PostApi api;
  final int pageSize;
  var _posts = <Post>[];
  var _loading = false;
  var _loadingMore = false;
  var _hasMore = false;
  var _page = 0;
  var _generation = 0;
  var _disposed = false;
  String? _error;
  bool _loadMoreFailed = false;
  final _likeOperations = <String, Future<void>>{};
  String? _postsSession;
  bool isLiking(String postId) => _likeOperations.containsKey(postId);

  List<Post> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get loadMoreFailed => _loadMoreFailed;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> loadPosts() async {
    final session = api.sessionToken;
    if (_postsSession != session) {
      _posts.clear();
      _page = 0;
      _hasMore = false;
      _postsSession = session;
    }
    final generation = ++_generation;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _loadMoreFailed = false;
    _notify();
    try {
      await Future.wait(_likeOperations.values.toList());
      if (_disposed || session != api.sessionToken) return;
      final result = await api.getPostPage(pageSize: pageSize);
      if (generation != _generation || session != api.sessionToken) return;
      _posts = result.items.toList();
      _page = 1;
      _hasMore = result.hasMore;
    } catch (error) {
      if (generation != _generation) return;
      _error = _loadError(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    final session = api.sessionToken;
    if (_postsSession != session) return loadPosts();
    if (_loading || _loadingMore || !_hasMore || _disposed) return;
    final generation = _generation;
    _loadingMore = true;
    _error = null;
    _loadMoreFailed = false;
    _notify();
    try {
      await Future.wait(_likeOperations.values.toList());
      if (_disposed || session != api.sessionToken || generation != _generation) {
        return;
      }
      final result = await api.getPostPage(page: _page + 1, pageSize: pageSize);
      if (generation != _generation || session != api.sessionToken) return;
      final ids = _posts.map((post) => post.id).toSet();
      _posts.addAll(result.items.where((post) => ids.add(post.id)));
      _page++;
      _hasMore = result.hasMore;
    } catch (error) {
      if (generation != _generation) return;
      _error = _loadError(error);
      _loadMoreFailed = true;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  String _loadError(Object error) =>
      error is ApiException && error.statusCode == 401
      ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
      : 'Không thể tải bài viết. Vui lòng kiểm tra kết nối và thử lại.';

  void _replace(Post post) {
    final index = _posts.indexWhere((existing) => existing.id == post.id);
    if (index != -1) _posts[index] = post;
    _notify();
  }

  Future<bool> createPost(String content) async {
    final post = await api.createPost(content);
    if (post == null) return false;
    await loadPosts();
    return true;
  }

  Future<bool> updatePost(String postId, String content) async {
    final post = await api.updatePost(postId, content);
    if (post == null) return false;
    _replace(post);
    return true;
  }

  Future<void> deletePost(String postId) async {
    await api.deletePost(postId);
    _posts.removeWhere((post) => post.id == postId);
    await loadPosts();
  }

  Future<bool> toggleLike(String postId) async {
    if (_disposed ||
        _loading ||
        _loadingMore ||
        isLiking(postId) ||
        _postsSession != api.sessionToken) {
      return false;
    }
    final completion = Completer<void>();
    _likeOperations[postId] = completion.future;
    final session = api.sessionToken;
    _notify();
    try {
      final post = await api.toggleLike(postId);
      if (_disposed || session != api.sessionToken || post == null) {
        return false;
      }
      _replace(post);
      return true;
    } catch (_) {
      return false;
    } finally {
      _likeOperations.remove(postId);
      completion.complete();
      _notify();
    }
  }

  Future<bool> addComment(String postId, String content) async {
    final post = await api.addComment(postId, content);
    if (post == null) return false;
    _replace(post);
    return true;
  }
}
