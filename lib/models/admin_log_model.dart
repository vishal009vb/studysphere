class AdminLogModel {
  final String id;
  final String adminId;
  final String adminName;
  final String action;
  final String targetContent;
  final String targetId;
  final DateTime timestamp;

  AdminLogModel({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetContent,
    required this.targetId,
    required this.timestamp,
  });

  factory AdminLogModel.fromMap(Map<String, dynamic> map, String id) {
    return AdminLogModel(
      id: id,
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      action: map['action'] ?? '',
      targetContent: map['targetContent'] ?? '',
      targetId: map['targetId'] ?? '',
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'targetContent': targetContent,
      'targetId': targetId,
      'timestamp': timestamp,
    };
  }
}
