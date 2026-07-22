import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  
  // Basic Info
  final String title;
  final String description;
  final String category;
  final String subCategory;
  final String level; // difficulty
  final String language;

  // Instructor
  final String channelName;
  final String instructorName;

  // Media
  final String thumbnailUrl;
  final String youtubePlaylistUrl;

  // Details
  final String duration;
  final int totalVideos;
  final bool certificateAvailable;
  final bool isPaid;

  // StudySphere Meta
  final bool isFeatured;
  final bool isRecommended;
  final bool isVisible;
  final bool isDeleted;
  final int order;
  final List<String> tags;

  // Analytics
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  final List<CourseModule> modules;

  String get formattedDuration {
    if (modules.isEmpty) return duration;
    
    int totalMinutes = 0;
    for (var m in modules) {
      if (m.duration.isNotEmpty && m.duration.toLowerCase() != 'null') {
        totalMinutes += int.tryParse(m.duration) ?? 0;
      }
    }
    
    if (totalMinutes == 0) return duration;
    
    if (totalMinutes < 60) return '$totalMinutes min';
    
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours hr';
    return '${hours}h ${mins}m';
  }

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.category,
    this.subCategory = '',
    required this.level,
    this.language = 'English',
    required this.duration,
    this.totalVideos = 0,
    this.certificateAvailable = false,
    this.isPaid = false,
    required this.youtubePlaylistUrl,
    required this.channelName,
    this.instructorName = '',
    this.isFeatured = false,
    this.isRecommended = false,
    this.isVisible = true,
    this.isDeleted = false,
    this.order = 0,
    this.tags = const [],
    required this.createdAt,
    DateTime? updatedAt,
    this.createdBy = 'system',
    this.updatedBy = 'system',
    this.modules = const [],
  }) : updatedAt = updatedAt ?? createdAt;

  factory CourseModel.fromMap(String id, Map<String, dynamic> data) {
    return CourseModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      subCategory: data['subCategory'] ?? '',
      level: data['level'] ?? 'Beginner',
      language: data['language'] ?? 'English',
      channelName: data['channelName'] ?? '',
      instructorName: data['instructorName'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      youtubePlaylistUrl: data['youtubePlaylistUrl'] ?? '',
      duration: data['duration'] ?? '',
      totalVideos: data['totalVideos'] ?? 0,
      certificateAvailable: data['certificateAvailable'] ?? false,
      isPaid: data['isPaid'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      isRecommended: data['isRecommended'] ?? false,
      isVisible: data['isVisible'] ?? true,
      isDeleted: data['isDeleted'] ?? false,
      order: data['order'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? 'system',
      updatedBy: data['updatedBy'] ?? 'system',
      modules: (data['modules'] as List<dynamic>?)?.map((m) => CourseModule.fromMap(m)).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'subCategory': subCategory,
      'level': level,
      'language': language,
      'channelName': channelName,
      'instructorName': instructorName,
      'thumbnailUrl': thumbnailUrl,
      'youtubePlaylistUrl': youtubePlaylistUrl,
      'duration': duration,
      'totalVideos': totalVideos,
      'certificateAvailable': certificateAvailable,
      'isPaid': isPaid,
      'isFeatured': isFeatured,
      'isRecommended': isRecommended,
      'isVisible': isVisible,
      'isDeleted': isDeleted,
      'order': order,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'modules': modules.map((m) => m.toMap()).toList(),
    };
  }
}

class CourseModule {
  final String id;
  final String title;
  final String youtubeVideoId;
  final String duration;
  final String notesReference;
  final String importantQuestionsReference;

  CourseModule({
    required this.id,
    required this.title,
    required this.youtubeVideoId,
    required this.duration,
    this.notesReference = '',
    this.importantQuestionsReference = '',
  });

  factory CourseModule.fromMap(Map<String, dynamic> data) {
    return CourseModule(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      youtubeVideoId: data['youtubeVideoId'] ?? '',
      duration: data['duration'] ?? '',
      notesReference: data['notesReference'] ?? '',
      importantQuestionsReference: data['importantQuestionsReference'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'youtubeVideoId': youtubeVideoId,
      'duration': duration,
      'notesReference': notesReference,
      'importantQuestionsReference': importantQuestionsReference,
    };
  }
}
