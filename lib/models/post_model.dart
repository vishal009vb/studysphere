class PostModel {
  final String postId;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String content;
  final String attachedType; // text, image, pdf, link, resource, note, pyq
  final String? attachedId;
  final String? attachedUrl; // URL for the uploaded image, PDF, or raw link
  final String? attachedFileName; // PDF filename for display
  final int? attachedFileSize; // PDF size in bytes for display
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
    this.attachedFileName,
    this.attachedFileSize,
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
      attachedFileName: map['attachedFileName'],
      attachedFileSize: map['attachedFileSize'] is int ? map['attachedFileSize'] : null,
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
      if (attachedFileName != null) 'attachedFileName': attachedFileName,
      if (attachedFileSize != null) 'attachedFileSize': attachedFileSize,
      'likes': likes,
      'commentsCount': commentsCount,
      'reposts': reposts,
      'shares': shares,
      'createdAt': createdAt,
    };
  }
}
