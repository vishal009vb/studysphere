class ReportModel {
  final String reportId;
  final String contentId;
  final String contentType; // note, paper, post, comment
  final String reason; // Wrong Content, Duplicate Content, Spam, Copyright Issue, Other
  final String reportedBy;
  final String status; // pending, reviewed, content_removed, dismissed
  final DateTime createdAt;

  ReportModel({
    required this.reportId,
    required this.contentId,
    required this.contentType,
    required this.reason,
    required this.reportedBy,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      reportId: id,
      contentId: map['contentId'] ?? '',
      contentType: map['contentType'] ?? '',
      reason: map['reason'] ?? '',
      reportedBy: map['reportedBy'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'reason': reason,
      'reportedBy': reportedBy,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
