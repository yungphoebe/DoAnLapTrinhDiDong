import 'package:ai_gym/controllers/post_controller.dart';
import 'package:ai_gym/screens/community.dart';
import 'package:ai_gym/services/post_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingPostApi extends PostApi {
  @override
  Future<PostPage> getPostPage({int page = 1, int pageSize = 20}) async =>
      throw Exception('offline');
}

void main() {
  testWidgets('empty feed explains that there are no posts', (tester) async {
    final controller = PostController(api: PostApi(localOnly: true));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-empty')), findsOneWidget);
    expect(find.byKey(const Key('create-post')), findsOneWidget);
  });

  testWidgets('failed feed offers retry and stops loading', (tester) async {
    final controller = PostController(api: FailingPostApi());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-retry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('remote image failure keeps author and content visible', (
    tester,
  ) async {
    final posts = await PostApi.seeded().getPosts();
    final controller = PostController(
      api: PostApi(
        localOnly: true,
        initialPosts: [
          posts.first.copyWith(imageAsset: 'https://example.com/missing.jpg'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Linh Nguyen'), findsOneWidget);
    expect(find.text(posts.first.content), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load more appends posts and pull refresh replaces the feed', (
    tester,
  ) async {
    final api = PostApi.seeded();
    final controller = PostController(api: api, pageSize: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Linh Nguyen'), findsOneWidget);
    expect(find.text('AI GYM Club'), findsNothing);
    final loadMore = find.byKey(const Key('feed-load-more'));
    await tester.ensureVisible(loadMore);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    expect(find.text('AI GYM Club'), findsOneWidget);
    expect(loadMore, findsNothing);

    await api.createPost('Bài mới từ máy chủ');
    await tester.drag(
      find.byKey(const Key('community-scroll')),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('community-scroll')),
      const Offset(0, 350),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bài mới từ máy chủ'), findsOneWidget);
    expect(find.text('AI GYM Club'), findsNothing);
    expect(controller.posts, hasLength(1));
  });
}
