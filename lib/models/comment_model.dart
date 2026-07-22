class CommentModel {
  final String commentId;
  final String contentId; // noteId, paperId, or postId
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String text;
  final String? parentId; // null for top-level comments, commentId for replies
  final DateTime createdAt;

  CommentModel({
    required this.commentId,
    required this.contentId,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.text,
    this.parentId,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    return CommentModel(
      commentId: id,
      contentId: map['contentId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      text: map['text'] ?? '',
      parentId: map['parentId'],
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'parentId': parentId,
      'createdAt': createdAt,
    };
  }
}
