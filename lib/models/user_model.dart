class UserModel {
  final String uid;
  final String username;
  final String name; // Display Name
  final String email;
  final String photoUrl;
  final String role; // learner, contributor, moderator, admin
  final String bio;
  final String coursePreference;
  final String semester;
  final String contributorRank; // Bronze, Silver, Gold, Platinum, Top Contributor, Elite Educator
  final int reputationPoints;
  final int followersCount;
  final int followingCount;
  final int uploadsCount;
  final int downloadsCount;
  final int likesReceived;
  final List<String> badges;

  // New Location & College Fields
  final String state;
  final String district;
  final String subDistrict;
  final String collegeId;
  final String collegeName;
  final String gender;
  // AI Usage Tracking
  final int dailyAiUsage;
  final DateTime? lastUsageReset;

  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isBanned;
  final bool isSuspended;
  final bool isVerified; // Verification Badge
  final int usernameChangeCount;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.username,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.role,
    this.bio = '',
    this.coursePreference = '',
    this.semester = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.uploadsCount = 0,
    this.downloadsCount = 0,
    this.likesReceived = 0,
    this.badges = const [],
    this.contributorRank = 'Bronze Contributor',
    this.reputationPoints = 0,
    this.dailyAiUsage = 0,
    this.lastUsageReset,
    this.state = '',
    this.district = '',
    this.subDistrict = '',
    this.collegeId = '',
    this.collegeName = '',
    this.gender = 'female',
    required this.createdAt,
    required this.lastLogin,
    this.isBanned = false,
    this.isSuspended = false,
    this.isVerified = false,
    this.usernameChangeCount = 0,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      role: map['role'] ?? 'learner',
      bio: map['bio'] ?? '',
      coursePreference: map['coursePreference'] ?? '',
      semester: map['semester'] ?? '',
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      uploadsCount: map['uploadsCount'] ?? 0,
      downloadsCount: map['downloadsCount'] ?? 0,
      likesReceived: map['likesReceived'] ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      contributorRank: map['contributorRank'] ?? 'Bronze Contributor',
      reputationPoints: map['reputationPoints'] ?? 0,
      dailyAiUsage: map['dailyAiUsage'] ?? 0,
      lastUsageReset: (map['lastUsageReset'] as dynamic)?.toDate(),
      state: map['state'] ?? '',
      district: map['district'] ?? '',
      subDistrict: map['subDistrict'] ?? '',
      collegeId: map['collegeId'] ?? '',
      collegeName: map['collegeName'] ?? '',
      gender: map['gender'] ?? 'female',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastLogin: (map['lastLogin'] as dynamic)?.toDate() ?? DateTime.now(),
      isBanned: map['isBanned'] ?? false,
      isSuspended: map['isSuspended'] ?? false,
      isVerified: map['isVerified'] ?? false,
      usernameChangeCount: map['usernameChangeCount'] ?? 0,
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'bio': bio,
      'coursePreference': coursePreference,
      'semester': semester,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'uploadsCount': uploadsCount,
      'downloadsCount': downloadsCount,
      'likesReceived': likesReceived,
      'badges': badges,
      'contributorRank': contributorRank,
      'reputationPoints': reputationPoints,
      'dailyAiUsage': dailyAiUsage,
      'lastUsageReset': lastUsageReset,
      'state': state,
      'district': district,
      'subDistrict': subDistrict,
      'collegeId': collegeId,
      'collegeName': collegeName,
      'gender': gender,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'isBanned': isBanned,
      'isSuspended': isSuspended,
      'isVerified': isVerified,
      'usernameChangeCount': usernameChangeCount,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? username,
    String? name,
    String? photoUrl,
    String? role,
    String? bio,
    String? coursePreference,
    String? semester,
    int? followersCount,
    int? followingCount,
    int? uploadsCount,
    int? downloadsCount,
    int? likesReceived,
    List<String>? badges,
    String? contributorRank,
    int? reputationPoints,
    int? dailyAiUsage,
    DateTime? lastUsageReset,
    String? state,
    String? district,
    String? subDistrict,
    String? collegeId,
    String? collegeName,
    String? gender,
    DateTime? lastLogin,
    bool? isBanned,
    bool? isSuspended,
    bool? isVerified,
    int? usernameChangeCount,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      coursePreference: coursePreference ?? this.coursePreference,
      semester: semester ?? this.semester,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      uploadsCount: uploadsCount ?? this.uploadsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      likesReceived: likesReceived ?? this.likesReceived,
      badges: badges ?? this.badges,
      contributorRank: contributorRank ?? this.contributorRank,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      dailyAiUsage: dailyAiUsage ?? this.dailyAiUsage,
      lastUsageReset: lastUsageReset ?? this.lastUsageReset,
      state: state ?? this.state,
      district: district ?? this.district,
      subDistrict: subDistrict ?? this.subDistrict,
      collegeId: collegeId ?? this.collegeId,
      collegeName: collegeName ?? this.collegeName,
      gender: gender ?? this.gender,
      createdAt: this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isBanned: isBanned ?? this.isBanned,
      isSuspended: isSuspended ?? this.isSuspended,
      isVerified: isVerified ?? this.isVerified,
      usernameChangeCount: usernameChangeCount ?? this.usernameChangeCount,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
