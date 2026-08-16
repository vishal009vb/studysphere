import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminLogServiceProvider = Provider<AdminLogService>((ref) {
  return AdminLogService();
});

class AdminLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> logAction({
    required String adminId,
    required String adminName,
    required String action,
    required String targetContent,
    required String targetId,
  }) async {
    final logRef = _db.collection('adminLogs').doc();
    await logRef.set({
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'targetContent': targetContent,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Live admin audit log. Bounded — `adminLogs` is append-only and grows
  /// forever, so an unlimited listener re-read the entire history on every
  /// admin action.
  Stream<QuerySnapshot> getLogsStream({int limit = 100}) {
    return _db
        .collection('adminLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }
}
