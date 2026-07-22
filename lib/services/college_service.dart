import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

List<CollegeData> _parseColleges(String content) {
  final List<dynamic> jsonList = jsonDecode(content);
  return jsonList.map((e) => CollegeData.fromJson(e)).toList();
}

final collegeServiceProvider = Provider<CollegeService>((ref) {
  return CollegeService();
});

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

class CollegeService {
  static const String _collegesUrl = 'https://raw.githubusercontent.com/tridev1004/Indian-Colleges/master/colleges.json';
  static const String _cacheFileName = 'indian_colleges_cache.json';

  List<CollegeData>? _cachedColleges;

  /// Ensure data is loaded into memory (either from file cache or HTTP)
  Future<void> _ensureDataLoaded() async {
    if (_cachedColleges != null) return;

    try {
      if (kIsWeb) {
        // Skip file caching on web
        final response = await http.get(Uri.parse(_collegesUrl));
        if (response.statusCode == 200) {
          _cachedColleges = await compute(_parseColleges, response.body);
        } else {
          throw Exception('Failed to load colleges data. Status code: ${response.statusCode}');
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_cacheFileName');

        // Check if we have offline cache
        if (await file.exists()) {
          final content = await file.readAsString();
          _cachedColleges = await compute(_parseColleges, content);
        } else {
          // If no cache, fetch from Github
          final response = await http.get(Uri.parse(_collegesUrl));
          if (response.statusCode == 200) {
            final content = response.body;
            // Save to offline cache
            await file.writeAsString(content);

            _cachedColleges = await compute(_parseColleges, content);
          } else {
            throw Exception('Failed to load colleges data. Status code: ${response.statusCode}');
          }
        }
      }
      
      // Inject missing Pachora colleges if they don't exist
      _injectMissingPachoraColleges();
      
    } catch (e) {
      // In case of error (e.g. no internet), initialize with empty list and inject local colleges
      _cachedColleges = [];
      _injectMissingPachoraColleges();
    }
  }

  void _injectMissingPachoraColleges() {
    if (_cachedColleges == null) return;
    
    final customColleges = [
      CollegeData(
        university: 'KBC North Maharashtra University',
        college: 'Annasaheb Dr. Satish Bhaskarrao Patil Polytechnic',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
      CollegeData(
        university: 'KBC North Maharashtra University',
        college: 'Nanaso Narhar Nagraj Patil College of Nursing (GNM)',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
      CollegeData(
        university: 'KBC North Maharashtra University',
        college: 'Sumantai Institute of Pharmacy',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
      CollegeData(
        university: 'Government',
        college: 'Government ITI College Pachora',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
      CollegeData(
        university: 'Maharashtra State Board',
        college: 'Gurukul International School & Jr. College',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
      CollegeData(
        university: 'KBC North Maharashtra University',
        college: 'Shri Sheth Murlidharji Mansingka Arts, Science & Commerce College (SSMM)',
        collegeType: 'Affiliated',
        state: 'Maharashtra',
        district: 'Jalgaon',
      ),
    ];

    for (final custom in customColleges) {
      if (!_cachedColleges!.any((c) => c.college == custom.college)) {
        _cachedColleges!.add(custom);
      }
    }
  }

  /// Search colleges
  Future<List<CollegeData>> searchColleges({
    String query = '',
    String? state,
    String? district,
    int limit = 50,
  }) async {
    await _ensureDataLoaded();

    if (_cachedColleges == null || _cachedColleges!.isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase().trim();
    final lowerState = state?.toLowerCase().trim();
    final lowerDistrict = district?.toLowerCase().trim();

    final filteredByQuery = _cachedColleges!.where((c) {
      // 1. Strict State Filter
      if (lowerState != null && lowerState.isNotEmpty) {
        final cState = c.state.toLowerCase();
        if (!cState.contains(lowerState) && !lowerState.contains(cState)) return false;
      }
      
      // 2. Strict District Filter
      if (lowerDistrict != null && lowerDistrict.isNotEmpty) {
        final cDist = c.district.toLowerCase();
        if (!cDist.contains(lowerDistrict) && !lowerDistrict.contains(cDist)) return false;
      }

      // 3. Query Filter
      if (lowerQuery.isEmpty) return true;
      return c.college.toLowerCase().contains(lowerQuery);
    }).toList();

    return filteredByQuery.take(limit).toList();
  }
}
