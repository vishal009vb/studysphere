class BannerModel {
  final String id;
  final String title;
  final String imageUrl;
  final String type; // Exam Alerts, Announcements, Featured Notes, Study Tips, Advertisements
  final String targetLink;
  final bool isActive;
  final int priority;
  final DateTime createdAt;
  final String redirectType;
  final Map<String, dynamic> redirectData;

  BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.type,
    this.targetLink = '',
    this.isActive = true,
    this.priority = 0,
    required this.createdAt,
    this.redirectType = 'none',
    this.redirectData = const {},
  });

  factory BannerModel.fromMap(Map<String, dynamic> map, String id) {
    return BannerModel(
      id: id,
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: map['type'] ?? 'Announcements',
      targetLink: map['targetLink'] ?? '',
      isActive: map['isActive'] ?? true,
      priority: map['order'] ?? 0,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      redirectType: map['redirectType'] ?? 'none',
      redirectData: Map<String, dynamic>.from(map['redirectData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'type': type,
      'targetLink': targetLink,
      'isActive': isActive,
      'priority': priority,
      'createdAt': createdAt,
      'redirectType': redirectType,
      'redirectData': redirectData,
    };
  }

  BannerModel copyWith({
    String? title,
    String? imageUrl,
    String? type,
    String? targetLink,
    bool? isActive,
    int? priority,
    String? redirectType,
    Map<String, dynamic>? redirectData,
  }) {
    return BannerModel(
      id: id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      targetLink: targetLink ?? this.targetLink,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      redirectType: redirectType ?? this.redirectType,
      redirectData: redirectData ?? this.redirectData,
    );
  }
}
