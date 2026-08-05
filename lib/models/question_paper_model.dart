class QuestionPaperModel {
  final String paperId;
  final String title;
  final String course;
  final String semester;
  final String subject;
  final String year;
  final String pdfUrl;
  final String fileHash;
  final String uploadedBy;
  final int downloads;
  final int likes;
  final int reports;
  final String status; // pending, approved, rejected
  final String collegeId;
  final String state;
  final String district;

  QuestionPaperModel({
    required this.paperId,
    required this.title,
    required this.course,
    required this.semester,
    required this.subject,
    required this.year,
    required this.pdfUrl,
    required this.fileHash,
    required this.uploadedBy,
    this.downloads = 0,
    this.likes = 0,
    this.reports = 0,
    this.status = 'pending',
    this.collegeId = '',
    this.state = '',
    this.district = '',
  });

  factory QuestionPaperModel.fromMap(Map<String, dynamic> map, String id) {
    return QuestionPaperModel(
      paperId: id,
      title: map['title'] ?? '',
      course: map['course'] ?? '',
      semester: map['semester'] ?? '',
      subject: map['subject'] ?? '',
      year: map['year'] ?? '',
      pdfUrl: map['pdfUrl'] ?? '',
      fileHash: map['fileHash'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      downloads: (map['downloads'] as num?)?.toInt() ?? 0,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      reports: (map['reports'] as num?)?.toInt() ?? 0,
      status: map['status'] ?? 'pending',
      collegeId: map['collegeId'] ?? '',
      state: map['state'] ?? '',
      district: map['district'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'course': course,
      'semester': semester,
      'subject': subject,
      'year': year,
      'pdfUrl': pdfUrl,
      'fileHash': fileHash,
      'uploadedBy': uploadedBy,
      'downloads': downloads,
      'likes': likes,
      'reports': reports,
      'status': status,
      'collegeId': collegeId,
      'state': state,
      'district': district,
    };
  }

  QuestionPaperModel copyWith({
    String? title,
    String? course,
    String? semester,
    String? subject,
    String? year,
    String? pdfUrl,
    String? status,
  }) {
    return QuestionPaperModel(
      paperId: paperId,
      title: title ?? this.title,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      subject: subject ?? this.subject,
      year: year ?? this.year,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      fileHash: fileHash,
      uploadedBy: uploadedBy,
      downloads: downloads,
      likes: likes,
      reports: reports,
      status: status ?? this.status,
      collegeId: collegeId,
      state: state,
      district: district,
    );
  }
}
