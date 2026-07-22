class NotificationModel {
  final String notificationId;
  final String receiverId;
  final String senderId;
  final String senderName;
  final String type; // like, follow, comment, repost, approved, rejected, system
  final String contentId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.receiverId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.contentId,
    required this.title,
    required this.body,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      notificationId: id,
      receiverId: map['receiverId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      type: map['type'] ?? 'system',
      contentId: map['contentId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      read: map['read'] ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'contentId': contentId,
      'title': title,
      'body': body,
      'read': read,
      'createdAt': createdAt,
    };
  }
}
