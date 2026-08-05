class NotificationModel {
  final String notificationId;
  final String receiverId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String type; // like, follow, comment, upload_approved, upload_rejected, ai_credits, warning, account_notice, update_available, course_update, system
  final String contentId;
  final String title;
  final String body;
  final String? route; // deep link route e.g. /notes/123, /user/xyz, /community
  final String priority; // low, normal, high, critical
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.receiverId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    required this.contentId,
    required this.title,
    required this.body,
    this.route,
    this.priority = 'normal',
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val.runtimeType.toString().contains('Timestamp')) {
        return (val as dynamic).toDate();
      }
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return NotificationModel(
      notificationId: id,
      receiverId: map['receiverId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'],
      type: map['type'] ?? 'system',
      contentId: map['contentId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      route: map['route'],
      priority: map['priority'] ?? 'normal',
      read: map['read'] ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type,
      'contentId': contentId,
      'title': title,
      'body': body,
      'route': route,
      'priority': priority,
      'read': read,
      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({
    String? notificationId,
    String? receiverId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? type,
    String? contentId,
    String? title,
    String? body,
    String? route,
    String? priority,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      receiverId: receiverId ?? this.receiverId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      body: body ?? this.body,
      route: route ?? this.route,
      priority: priority ?? this.priority,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

