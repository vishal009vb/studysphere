class NoteModel {
  final String noteId;
  final String title;
  final String description;
  final String course;
  final String semester;
  final String subject;
  final String pdfUrl;
  final String fileHash; // SHA256 for duplicate check
  final String uploadedBy;
  final String status; // pending, approved, rejected, duplicate_detected
  final int views;
  final int downloads;
  final int likes;
  final int shares;
  final int reposts;
  final int reports;
  final int qualityScore; // downloads + likes - reports
  final DateTime createdAt;
  final bool isFeatured;
  final bool isTrending;
  final String collegeId;
  final String state;
  final String district;

  NoteModel({
    required this.noteId,
    required this.title,
    required this.description,
    required this.course,
    required this.semester,
    required this.subject,
    required this.pdfUrl,
    required this.fileHash,
    required this.uploadedBy,
    this.status = 'pending',
    this.views = 0,
    this.downloads = 0,
    this.likes = 0,
    this.shares = 0,
    this.reposts = 0,
    this.reports = 0,
    this.qualityScore = 0,
    required this.createdAt,
    this.isFeatured = false,
    this.isTrending = false,
    this.collegeId = '',
    this.state = '',
    this.district = '',
  });

  factory NoteModel.fromMap(Map<String, dynamic> map, String id) {
    return NoteModel(
      noteId: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      course: map['course'] ?? '',
      semester: map['semester'] ?? '',
      subject: map['subject'] ?? '',
      pdfUrl: map['pdfUrl'] ?? '',
      fileHash: map['fileHash'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      status: map['status'] ?? 'pending',
      views: (map['views'] as num?)?.toInt() ?? 0,
      downloads: (map['downloads'] as num?)?.toInt() ?? 0,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      shares: (map['shares'] as num?)?.toInt() ?? 0,
      reposts: (map['reposts'] as num?)?.toInt() ?? 0,
      reports: (map['reports'] as num?)?.toInt() ?? 0,
      qualityScore: (map['qualityScore'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isFeatured: map['isFeatured'] ?? false,
      isTrending: map['isTrending'] ?? false,
      collegeId: map['collegeId'] ?? '',
      state: map['state'] ?? '',
      district: map['district'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'course': course,
      'semester': semester,
      'subject': subject,
      'pdfUrl': pdfUrl,
      'fileHash': fileHash,
      'uploadedBy': uploadedBy,
      'status': status,
      'views': views,
      'downloads': downloads,
      'likes': likes,
      'shares': shares,
      'reposts': reposts,
      'reports': reports,
      'qualityScore': downloads + likes - reports,
      'createdAt': createdAt,
      'isFeatured': isFeatured,
      'isTrending': isTrending,
      'collegeId': collegeId,
      'state': state,
      'district': district,
    };
  }

  NoteModel copyWith({
    String? title,
    String? description,
    String? course,
    String? semester,
    String? subject,
    String? pdfUrl,
    String? status,
  }) {
    return NoteModel(
      noteId: noteId,
      title: title ?? this.title,
      description: description ?? this.description,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      subject: subject ?? this.subject,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      fileHash: fileHash,
      uploadedBy: uploadedBy,
      status: status ?? this.status,
      views: views,
      downloads: downloads,
      likes: likes,
      shares: shares,
      reposts: reposts,
      reports: reports,
      qualityScore: qualityScore,
      createdAt: createdAt,
      isFeatured: isFeatured,
      isTrending: isTrending,
      collegeId: collegeId,
      state: state,
      district: district,
    );
  }
}
