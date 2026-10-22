import 'dart:async';
import 'dart:convert';

import 'package:ai_gym/controllers/post_controller.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/post_api.dart';
import 'package:ai_gym/screens/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class LikeClient extends ApiClient {
  final pending = Completer<http.Response>();
  var writes = 0;
  var fail = false;
  var failRead = false;
  var reads = 0;
  var liked = false;
  var count = 6;

  @override
  Future<http.Response> get(String path, {bool includeAuth = false}) async {
    reads++;
    if (failRead) return http.Response('', 500);
    return http.Response(
      jsonEncode({
        'items': [
          {
            'id': 1,
            'authorName': 'Author',
            'content': 'Post',
            'createdAt': '2026-10-18T00:00:00Z',
            'likeCount': count,
            'liked': liked,
          },
        ],
        'hasMore': false,
      }),
      200,
    );
  }

  @override
  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    expect(path, '/api/posts/1/like');
    expect(body, {'liked': true});
    expect(includeAuth, isTrue);
    writes++;
    if (fail) return http.Response('', 500);
    final response = await pending.future;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    liked = json['liked'] as bool;
    count = json['likeCount'] as int;
    return response;
  }
}

void main() {
  test('account switch with a failed reload does not show the previous account likes', () async {
    final client = LikeClient()..token = 'account-a';
    final controller = PostController(api: PostApi(client: client));
    addTearDown(controller.dispose);
    await controller.loadPosts();
    client.pending.complete(
      http.Response('{"postId":1,"liked":true,"likeCount":8}', 200),
    );
    await controller.toggleLike('1');
    client.token = 'account-b';
    client.failRead = true;
    await controller.loadPosts();
    expect(controller.posts, isEmpty);
    expect(controller.error, isNotNull);
  });
  test('rapid repeated taps send one write and use the server total', () async {
    final client = LikeClient();
    final controller = PostController(api: PostApi(client: client));
    addTearDown(controller.dispose);
    await controller.loadPosts();
    final first = controller.toggleLike('1');
    final repeated = controller.toggleLike('1');
    expect(client.writes, 1);
    client.pending.complete(
      http.Response('{"postId":1,"liked":true,"likeCount":8}', 200),
    );
    await Future.wait([first, repeated]);
    expect(controller.posts.single.liked, isTrue);
    expect(controller.posts.single.likeCount, 8);
  });

  test(
    'failed write preserves the last confirmed state and can be retried',
    () async {
      final client = LikeClient()..fail = true;
      final controller = PostController(api: PostApi(client: client));
      addTearDown(controller.dispose);
      await controller.loadPosts();
      await controller.toggleLike('1');
      expect(controller.posts.single.liked, isFalse);
      expect(controller.posts.single.likeCount, 6);
      client.fail = false;
      client.pending.complete(
        http.Response('{"postId":1,"liked":true,"likeCount":7}', 200),
      );
      await controller.toggleLike('1');
      expect(controller.posts.single.liked, isTrue);
      expect(client.writes, 2);
    },
  );

  test(
    'refresh waits for the like and a new controller reads the saved state',
    () async {
      final client = LikeClient();
      final controller = PostController(api: PostApi(client: client));
      addTearDown(controller.dispose);
      await controller.loadPosts();
      final write = controller.toggleLike('1');
      final refresh = controller.loadPosts();
      await Future<void>.delayed(Duration.zero);
      expect(client.reads, 1);
      client.pending.complete(
        http.Response('{"postId":1,"liked":true,"likeCount":8}', 200),
      );
      await write;
      await refresh;
      expect(controller.posts.single.liked, isTrue);
      expect(controller.posts.single.likeCount, 8);
      final reopened = PostController(api: PostApi(client: client));
      addTearDown(reopened.dispose);
      await reopened.loadPosts();
      expect(reopened.posts.single.liked, isTrue);
      expect(reopened.posts.single.likeCount, 8);
    },
  );

  testWidgets(
    'like button is disabled during the write and displays confirmed count',
    (tester) async {
      final client = LikeClient();
      final controller = PostController(api: PostApi(client: client));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('community-like'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      client.pending.complete(
        http.Response('{"postId":1,"liked":true,"likeCount":8}', 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    },
  );

  testWidgets('failed like displays feedback and leaves the confirmed total', (
    tester,
  ) async {
    final client = LikeClient()..fail = true;
    final controller = PostController(api: PostApi(client: client));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-like')));
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(
      find.textContaining('Không thể cập nhật lượt thích'),
      findsOneWidget,
    );
  });
}
