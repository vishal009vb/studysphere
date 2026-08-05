class GlobalNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // announcement, maintenance, exam_alert, update_available
  final String priority; // low, normal, high, critical
  final String? imageUrl;
  final String? actionLabel;
  final String? route; // deep link target route
  final String targetCourse; // All, BCA, Engineering, etc.
  final String targetSemester; // All, Sem 1, Sem 2, etc.
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  GlobalNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'announcement',
    this.priority = 'normal',
    this.imageUrl,
    this.actionLabel,
    this.route,
    this.targetCourse = 'All',
    this.targetSemester = 'All',
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory GlobalNotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val.runtimeType.toString().contains('Timestamp')) {
        return (val as dynamic).toDate();
      }
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return GlobalNotificationModel(
      id: docId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'announcement',
      priority: map['priority'] ?? 'normal',
      imageUrl: map['imageUrl'],
      actionLabel: map['actionLabel'],
      route: map['route'],
      targetCourse: map['targetCourse'] ?? 'All',
      targetSemester: map['targetSemester'] ?? 'All',
      createdAt: parseDate(map['createdAt']),
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'priority': priority,
      'imageUrl': imageUrl,
      'actionLabel': actionLabel,
      'route': route,
      'targetCourse': targetCourse,
      'targetSemester': targetSemester,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'isActive': isActive,
    };
  }
}
