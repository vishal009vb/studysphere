import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  return BookmarkService(FirebaseFirestore.instance);
});

enum BookmarkType { note, pdf, post }

class BookmarkItem {
  final String id;
  final String userId;
  final String targetId;
  final BookmarkType type;
  final DateTime createdAt;

  BookmarkItem({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.type,
    required this.createdAt,
  });

  factory BookmarkItem.fromMap(Map<String, dynamic> map, String id) {
    return BookmarkItem(
      id: id,
      userId: map['userId'] ?? '',
      targetId: map['targetId'] ?? '',
      type: BookmarkType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => BookmarkType.post,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetId': targetId,
      'type': type.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class BookmarkService {
  final FirebaseFirestore _firestore;

  BookmarkService(this._firestore);

  /// Adds a bookmark
  Future<void> addBookmark(String userId, String targetId, BookmarkType type) async {
    final query = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .where('targetId', isEqualTo: targetId)
        .where('type', isEqualTo: type.toString().split('.').last)
        .get();

    if (query.docs.isEmpty) {
      await _firestore.collection('bookmarks').add({
        'userId': userId,
        'targetId': targetId,
        'type': type.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Removes a bookmark
  Future<void> removeBookmark(String userId, String targetId, BookmarkType type) async {
    final query = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .where('targetId', isEqualTo: targetId)
        .where('type', isEqualTo: type.toString().split('.').last)
        .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  /// Checks if a target is bookmarked by the user
  Stream<bool> isBookmarked(String userId, String targetId, BookmarkType type) {
    return _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .where('targetId', isEqualTo: targetId)
        .where('type', isEqualTo: type.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Gets all bookmarks for a specific user, optionally filtered by type
  Stream<List<BookmarkItem>> getUserBookmarks(String userId, {BookmarkType? type}) {
    Query query = _firestore.collection('bookmarks').where('userId', isEqualTo: userId);
    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }
    return query.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BookmarkItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }
}
