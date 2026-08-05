import 'dart:convert';
import 'package:http/http.dart' as http;

class CollegeData {
  final String university;
  final String college;
  final String collegeType;
  final String state;
  final String district;

  CollegeData({
    required this.university,
    required this.college,
    required this.collegeType,
    required this.state,
    required this.district,
  });

  factory CollegeData.fromJson(Map<String, dynamic> json) {
    return CollegeData(
      university: json['university']?.toString() ?? '',
      college: json['college']?.toString() ?? '',
      collegeType: json['college_type']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
    );
  }
}

void main() async {
  final response = await http.get(Uri.parse('https://raw.githubusercontent.com/tridev1004/Indian-Colleges/master/colleges.json'));
  final List<dynamic> jsonList = jsonDecode(response.body);
  final allColleges = jsonList.map((e) => CollegeData.fromJson(e)).toList();

  const lowerState = 'maharashtra';
  const lowerDistrict = 'jalgaon';

  final filtered = allColleges.where((c) {
    final cState = c.state.toLowerCase();
    if (!cState.contains(lowerState) && !lowerState.contains(cState)) return false;

    final cDist = c.district.toLowerCase();
    if (!cDist.contains(lowerDistrict) && !lowerDistrict.contains(cDist)) return false;

    return true;
  }).toList();

  print('Filtered colleges: ${filtered.length}');
  for (var c in filtered.take(10)) {
    print('- ${c.college} (State: ${c.state}, District: ${c.district})');
  }
}
