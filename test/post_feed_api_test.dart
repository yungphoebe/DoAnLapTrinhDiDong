import 'dart:async';
import 'dart:convert';

import 'package:ai_gym/controllers/post_controller.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/post_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FeedClient extends ApiClient {
  FeedClient(this.respond) : super(baseUrl: 'https://gym.example');
  final Future<http.Response> Function(String) respond;

  @override
  Future<http.Response> get(String path, {bool includeAuth = false}) {
    expect(includeAuth, isTrue);
    return respond(path);
  }

  @override
  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    expect(includeAuth, isTrue);
    expect(path, matches(RegExp(r'^/api/posts/\d+/like$')));
    final liked = body['liked'] as bool;
    return http.Response(
      jsonEncode({'liked': liked, 'likeCount': liked ? 4 : 3}),
      200,
    );
  }
}

http.Response page(List<int> ids, {bool hasMore = false, String? image}) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'items': [
            for (final id in ids)
              {
                'id': id,
                'authorId': 'author-$id',
                'authorName': 'Nguyễn Ánh',
                'content': 'Buổi tập số $id',
                'imageAsset': image,
                'tag': 'Chia sẻ',
                'likeCount': 3,
                'liked': false,
                'createdAt': '2026-10-18T01:00:00Z',
              },
          ],
          'page': 1,
          'pageSize': 2,
          'hasMore': hasMore,
        }),
      ),
      200,
    );

void main() {
  test('feed decodes Vietnamese and resolves server image paths', () async {
    final api = PostApi(
      client: FeedClient((path) async {
        expect(path, '/api/posts/feed?page=1&pageSize=20');
        return page([9], image: '/uploads/gym.jpg');
      }),
    );
    final result = await api.getPostPage();
    final post = result.items.single;
    expect(post.authorName, 'Nguyễn Ánh');
    expect(post.content, 'Buổi tập số 9');
    expect(post.imageAsset, 'https://gym.example/uploads/gym.jpg');
    expect(post.createdAt, DateTime.utc(2026, 10, 18, 1));
    expect(result.hasMore, isFalse);
  });

  test(
    'failed next page preserves posts and retry requests the same page',
    () async {
      var attempts = 0;
      final controller = PostController(
        pageSize: 2,
        api: PostApi(
          client: FeedClient((path) async {
            if (path == '/api/posts/feed?page=1&pageSize=2') {
              return page([3, 2], hasMore: true);
            }
            expect(path, '/api/posts/feed?page=2&pageSize=2');
            if (attempts++ == 0) return http.Response('', 500);
            return page([2, 1]);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadPosts();
      await controller.loadMore();
      expect(controller.posts.map((post) => post.id), ['3', '2']);
      expect(controller.error, isNotNull);
      expect(controller.loadingMore, isFalse);
      expect(controller.loadMoreFailed, isTrue);
      await controller.loadMore();
      expect(controller.posts.map((post) => post.id), ['3', '2', '1']);
      expect(controller.error, isNull);
      expect(controller.hasMore, isFalse);
    },
  );

  test(
    'refresh supersedes in-flight load more and resets pagination',
    () async {
      final pending = Completer<http.Response>();
      var firstPageCalls = 0;
      final controller = PostController(
        pageSize: 2,
        api: PostApi(
          client: FeedClient((path) async {
            if (path.contains('page=2&')) return pending.future;
            firstPageCalls++;
            return page(firstPageCalls == 1 ? [3, 2] : [5, 4], hasMore: true);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadPosts();
      final loadingMore = controller.loadMore();
      await controller.loadPosts();
      pending.complete(page([1]));
      await loadingMore;
      expect(controller.posts.map((post) => post.id), ['5', '4']);
      expect(controller.hasMore, isTrue);
      expect(controller.loadingMore, isFalse);
    },
  );

  test(
    'unauthorized feed stops loading and explains login is required',
    () async {
      final controller = PostController(
        api: PostApi(client: FeedClient((_) async => http.Response('', 401))),
      );
      addTearDown(controller.dispose);
      await controller.loadPosts();
      expect(controller.loading, isFalse);
      expect(controller.posts, isEmpty);
      expect(controller.error, contains('đăng nhập'));
    },
  );

  test('stale refresh cannot erase cached posts used for likes', () async {
    final older = Completer<http.Response>();
    var calls = 0;
    final controller = PostController(
      api: PostApi(
        client: FeedClient((_) async {
          return calls++ == 0 ? older.future : page([5, 4]);
        }),
      ),
    );
    addTearDown(controller.dispose);
    final first = controller.loadPosts();
    await controller.loadPosts();
    older.complete(page([3, 2]));
    await first;
    await controller.toggleLike('5');
    expect(controller.posts.first.id, '5');
    expect(controller.posts.first.liked, isTrue);
  });

  test(
    'deleting a post resets offsets so the next post is not skipped',
    () async {
      final api = PostApi.seeded();
      for (var i = 0; i < 3; i++) {
        await api.createPost('new $i');
      }
      final controller = PostController(api: api, pageSize: 2);
      addTearDown(controller.dispose);
      await controller.loadPosts();
      await controller.deletePost('post-5');
      await controller.loadMore();
      expect(controller.posts.map((post) => post.id), [
        'post-4',
        'post-3',
        'post-1',
        'post-2',
      ]);
    },
  );

  test(
    'overlapping pages preserve interactions on already displayed posts',
    () async {
      final controller = PostController(
        pageSize: 2,
        api: PostApi(
          client: FeedClient((path) async {
            return path.contains('page=1&')
                ? page([3, 2], hasMore: true)
                : page([2, 1]);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadPosts();
      await controller.addComment('2', 'Giữ bình luận này');
      await controller.loadMore();
      await controller.toggleLike('2');
      final post = controller.posts.firstWhere((post) => post.id == '2');
      expect(post.comments.single.content, 'Giữ bình luận này');
      expect(post.liked, isTrue);
    },
  );
}
