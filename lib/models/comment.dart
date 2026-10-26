class Comment {
  const Comment({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
}
