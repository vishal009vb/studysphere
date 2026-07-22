import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeModel {
  final String collegeId;
  final String collegeName;
  final String shortName;
  final String state;
  final String district;
  final String subDistrict;
  final String website;
  final bool isActive;
  final List<String> searchTerms;
  final DateTime createdAt;

  CollegeModel({
    required this.collegeId,
    required this.collegeName,
    required this.shortName,
    required this.state,
    required this.district,
    required this.subDistrict,
    required this.website,
    required this.isActive,
    required this.searchTerms,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'collegeName': collegeName,
      'shortName': shortName,
      'state': state,
      'district': district,
      'subDistrict': subDistrict,
      'website': website,
      'isActive': isActive,
      'searchTerms': searchTerms,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory CollegeModel.fromMap(Map<String, dynamic> map, String id) {
    return CollegeModel(
      collegeId: id,
      collegeName: map['collegeName'] ?? '',
      shortName: map['shortName'] ?? '',
      state: map['state'] ?? '',
      district: map['district'] ?? '',
      subDistrict: map['subDistrict'] ?? '',
      website: map['website'] ?? '',
      isActive: map['isActive'] ?? true,
      searchTerms: List<String>.from(map['searchTerms'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
