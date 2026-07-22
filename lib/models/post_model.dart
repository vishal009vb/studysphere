class PostModel {
  final String postId;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String content;
  final String attachedType; // text, image, pdf, resource, note, pyq
  final String? attachedId;
  final String? attachedUrl; // URL for the uploaded image or PDF
  final int likes;
  final int commentsCount;
  final int reposts;
  final int shares;
  final DateTime createdAt;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.content,
    this.attachedType = 'text',
    this.attachedId,
    this.attachedUrl,
    this.likes = 0,
    this.commentsCount = 0,
    this.reposts = 0,
    this.shares = 0,
    required this.createdAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      postId: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      content: map['content'] ?? '',
      attachedType: map['attachedType'] ?? 'text',
      attachedId: map['attachedId'],
      attachedUrl: map['attachedUrl'],
      likes: map['likes'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      reposts: map['reposts'] ?? 0,
      shares: map['shares'] ?? 0,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'attachedType': attachedType,
      'attachedId': attachedId,
      'attachedUrl': attachedUrl,
      'likes': likes,
      'commentsCount': commentsCount,
      'reposts': reposts,
      'shares': shares,
      'createdAt': createdAt,
    };
  }
}
