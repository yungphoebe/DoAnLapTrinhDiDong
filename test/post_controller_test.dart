import 'package:ai_gym/controllers/post_controller.dart';
import 'package:ai_gym/services/post_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loadPosts exposes seeded posts from the API', () async {
    final controller = PostController(api: PostApi.seeded());

    await controller.loadPosts();

    expect(controller.posts, hasLength(2));
    expect(controller.posts.first.authorName, 'Linh Nguyen');
    expect(controller.posts.first.likeCount, 128);
  });

  test('createPost trims content and inserts the newest post first', () async {
    final controller = PostController(api: PostApi.seeded());
    await controller.loadPosts();

    final created = await controller.createPost('  Tap chan that da  ');

    expect(created, isTrue);
    expect(controller.posts, hasLength(3));
    expect(controller.posts.first.content, 'Tap chan that da');
    expect(controller.posts.first.authorName, 'Ban');
  });

  test('createPost ignores blank content', () async {
    final controller = PostController(api: PostApi.seeded());
    await controller.loadPosts();

    final created = await controller.createPost('   ');

    expect(created, isFalse);
    expect(controller.posts, hasLength(2));
  });

  test('updatePost replaces content and keeps the same post id', () async {
    final controller = PostController(api: PostApi.seeded());
    await controller.loadPosts();
    final postId = controller.posts.first.id;

    final updated = await controller.updatePost(postId, '  PR moi  ');

    expect(updated, isTrue);
    expect(controller.posts.first.id, postId);
    expect(controller.posts.first.content, 'PR moi');
  });

  test('deletePost removes only the matching post', () async {
    final controller = PostController(api: PostApi.seeded());
    await controller.loadPosts();
    final postId = controller.posts.first.id;
    final remainingId = controller.posts.last.id;

    await controller.deletePost(postId);

    expect(controller.posts, hasLength(1));
    expect(controller.posts.single.id, remainingId);
  });

  test('toggleLike updates the liked state and like count', () async {
    final controller = PostController(api: PostApi.seeded());
    await controller.loadPosts();
    final postId = controller.posts.first.id;

    await controller.toggleLike(postId);

    expect(controller.posts.first.liked, isTrue);
    expect(controller.posts.first.likeCount, 129);

    await controller.toggleLike(postId);

    expect(controller.posts.first.liked, isFalse);
    expect(controller.posts.first.likeCount, 128);
  });
}
