import 'comment.dart';

class Post {
  const Post({
    required this.id,
    required this.authorName,
    required this.avatarAsset,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.comments,
    this.imageAsset,
    this.liked = false,
    this.tag = 'Chia se',
  });

  final String id;
  final String authorName;
  final String avatarAsset;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final List<Comment> comments;
  final String? imageAsset;
  final bool liked;
  final String tag;

  Post copyWith({
    String? id,
    String? authorName,
    String? avatarAsset,
    String? content,
    DateTime? createdAt,
    int? likeCount,
    List<Comment>? comments,
    String? imageAsset,
    bool? liked,
    String? tag,
  }) => Post(
    id: id ?? this.id,
    authorName: authorName ?? this.authorName,
    avatarAsset: avatarAsset ?? this.avatarAsset,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    likeCount: likeCount ?? this.likeCount,
    comments: comments ?? this.comments,
    imageAsset: imageAsset ?? this.imageAsset,
    liked: liked ?? this.liked,
    tag: tag ?? this.tag,
  );
}
