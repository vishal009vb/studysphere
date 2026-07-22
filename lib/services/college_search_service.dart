import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/college_model.dart';

final collegeSearchServiceProvider = Provider((ref) => CollegeSearchService());

class CollegeSearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Searches for colleges using the pre-generated `searchTerms` array in Firestore.
  /// This provides simple but effective autocomplete without needing an external service like Algolia.
  Future<List<CollegeModel>> searchColleges(String query) async {
    if (query.isEmpty) return [];

    // Convert query to lowercase for matching
    final String lowercaseQuery = query.toLowerCase().trim();

    try {
      final snapshot = await _db
          .collection('colleges')
          .where('isActive', isEqualTo: true)
          .where('searchTerms', arrayContains: lowercaseQuery)
          .limit(10)
          .get();

      var results = snapshot.docs
          .map((doc) => CollegeModel.fromMap(doc.data(), doc.id))
          .toList();

      // If arrayContains doesn't return enough results (e.g. partial word typing),
      // fallback to prefix matching if needed, though arrayContains is usually sufficient
      // if searchTerms contains all n-grams.
      if (results.isEmpty && lowercaseQuery.length >= 3) {
        final prefixSnapshot = await _db
            .collection('colleges')
            .where('isActive', isEqualTo: true)
            .where('searchTerms', arrayContainsAny: [lowercaseQuery]) // Simple fallback
            .limit(10)
            .get();
        
        results = prefixSnapshot.docs
            .map((doc) => CollegeModel.fromMap(doc.data(), doc.id))
            .toList();
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search colleges: $e');
    }
  }

  /// Get SSMM College details explicitly.
  Future<CollegeModel?> getSSMMCollege() async {
    try {
      final doc = await _db.collection('colleges').doc('ssmm_pachora').get();
      if (doc.exists) {
        return CollegeModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
