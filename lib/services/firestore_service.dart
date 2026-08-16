import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/note_model.dart';
import '../models/question_paper_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/report_model.dart';
import '../models/notification_model.dart';
import '../models/global_notification_model.dart';
import '../models/college_model.dart';
import '../models/banner_model.dart';
import '../features/courses/models/course_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- ADMIN & MODERATION METHODS ---

  Future<Map<String, dynamic>> getUsersPaginated({
    DocumentSnapshot? startAfter,
    int limit = 50,
    String? searchQuery,
    String searchField = 'name',
    String? roleFilter,
    String? statusFilter,
  }) async {
    Query query = _db.collection('users');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Basic prefix search
      query = query
          .where(searchField, isGreaterThanOrEqualTo: searchQuery)
          .where(searchField, isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .orderBy(searchField);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (roleFilter != null && roleFilter != 'All') {
      query = query.where('role', isEqualTo: roleFilter.toLowerCase());
    }

    if (statusFilter == 'Suspended') {
      query = query.where('isSuspended', isEqualTo: true);
    } else if (statusFilter == 'Banned') {
      query = query.where('isBanned', isEqualTo: true);
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final users = snapshot.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>)).toList();

    return {
      'users': users,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<void> logAdminAction(String adminId, String adminName, String action, String targetContent, String targetId) async {
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

  Future<void> updateUserStatus(String uid, {bool? isBanned, bool? isSuspended, String? role, String? contributorRank}) async {
    final Map<String, dynamic> data = {};
    if (isBanned != null) data['isBanned'] = isBanned;
    if (isSuspended != null) data['isSuspended'] = isSuspended;
    if (role != null) data['role'] = role;
    if (contributorRank != null) data['contributorRank'] = contributorRank;

    await _db.collection('users').doc(uid).update(data);
  }

  // --- USER PROFILE & PREFERENCES ---

  Future<void> createUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    throw Exception('User profile not found');
  }

  Future<bool> userProfileExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<bool> isUsernameUnique(String username) async {
    if (username.isEmpty) return false;
    final snapshot = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    return snapshot.docs.isEmpty;
  }

  Future<void> updateLastLogin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _db.collection('users').doc(uid).update({field: value});
  }

  /// Returns true if the username is NOT taken (available)
  Future<bool> isUsernameAvailable(String username) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  Future<void> updateOnboardingData(String uid, String role, String coursePreference, String state, String district, String subDistrict, String collegeId, String collegeName) async {
    // We use set with merge so that if the profile doesn't exist (due to past failure), it gets created.
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'role': role,
      'coursePreference': coursePreference,
      'state': state,
      'district': district,
      'subDistrict': subDistrict,
      'collegeId': collegeId,
      'collegeName': collegeName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // --- COLLEGE DATABASE ---

  Future<List<CollegeModel>> searchColleges(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final snapshot = await _db
        .collection('colleges')
        .where('isActive', isEqualTo: true)
        .where('searchTerms', arrayContains: lowerQuery)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => CollegeModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<CollegeModel>> getCollegesPaginated({DocumentSnapshot? startAfter, int limit = 20}) async {
    Query query = _db.collection('colleges').orderBy('collegeName', descending: false).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => CollegeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<List<String>> getStates() async {
    final snapshot = await _db.collection('locations').doc('india').get();
    if (!snapshot.exists) return ['Maharashtra']; // Fallback
    final data = snapshot.data();
    return List<String>.from(data?['states'] ?? ['Maharashtra']);
  }

  Future<List<String>> getDistricts(String state) async {
    final snapshot = await _db.collection('locations').doc('india_$state').get();
    if (!snapshot.exists) return ['Jalgaon']; // Fallback
    final data = snapshot.data();
    return List<String>.from(data?['districts'] ?? ['Jalgaon']);
  }

  Future<List<String>> getSubDistricts(String state, String district) async {
    final snapshot = await _db.collection('locations').doc('india_${state}_$district').get();
    if (!snapshot.exists) return ['Pachora']; // Fallback
    final data = snapshot.data();
    return List<String>.from(data?['subDistricts'] ?? ['Pachora']);
  }

  Future<List<CollegeModel>> getCollegesByLocation(String state, String district, String subDistrict) async {
    final snapshot = await _db
        .collection('colleges')
        .where('state', isEqualTo: state)
        .where('district', isEqualTo: district)
        .where('subDistrict', isEqualTo: subDistrict)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => CollegeModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> addCollege(CollegeModel college) async {
    await _db.collection('colleges').doc(college.collegeId).set(college.toMap());
  }

  Future<void> updateCollege(CollegeModel college) async {
    await _db.collection('colleges').doc(college.collegeId).update(college.toMap());
  }

  Future<void> setCollegeStatus(String collegeId, bool isActive) async {
    await _db.collection('colleges').doc(collegeId).update({'isActive': isActive});
  }

  // --- NOTES OPERATIONS ---

  Future<bool> checkDuplicateFile(String fileHash) async {
    final noteQuery = await _db
        .collection('notes')
        .where('fileHash', isEqualTo: fileHash)
        .limit(1)
        .get();
    if (noteQuery.docs.isNotEmpty) return true;

    final paperQuery = await _db
        .collection('questionPapers')
        .where('fileHash', isEqualTo: fileHash)
        .limit(1)
        .get();
    return paperQuery.docs.isNotEmpty;
  }

  Future<void> uploadNote(NoteModel note) async {
    await _db.collection('notes').doc(note.noteId).set(note.toMap());
  }

  Future<NoteModel> fetchNoteById(String noteId) async {
    try {
      final doc = await _db.collection('notes').doc(noteId).get();
      if (!doc.exists) {
        throw NoteNotFoundException();
      }
      
      final data = doc.data()!;
      final note = NoteModel.fromMap(data, doc.id);
      
      if (note.status == 'pending') {
        throw NoteNotFoundException("This note is under review and not yet approved.");
      }
      
      return note;
    } catch (e) {
      if (e is NoteNotFoundException) rethrow;
      throw NoteNotFoundException("Error fetching note: $e");
    }
  }

  Future<Map<String, dynamic>> getNotesPaginated({
    DocumentSnapshot? startAfter,
    int limit = 50,
    String? searchQuery,
    String searchField = 'title',
    String? courseFilter,
    String? statusFilter,
    String? uploadedBy,
  }) async {
    Query query = _db.collection('notes');

    if (uploadedBy != null) {
      query = query.where('uploadedBy', isEqualTo: uploadedBy);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      query = query
          .where(searchField, isGreaterThanOrEqualTo: lowercaseQuery)
          .where(searchField, isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .orderBy(searchField);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (courseFilter != null && courseFilter != 'All') {
      query = query.where('course', isEqualTo: courseFilter);
    }

    if (statusFilter != null && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final notes = snapshot.docs.map((doc) => NoteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

    return {
      'notes': notes,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<List<NoteModel>> fetchNotes({
    String? course,
    String? semester,
    String? subject,
    String? sortBy,
    String? collegeId,
    String? district,
    String? state,
    int limit = 50,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _db.collection('notes').where('status', isEqualTo: 'approved');

    if (collegeId != null && collegeId.isNotEmpty) {
      query = query.where('collegeId', whereIn: [collegeId, 'Global']);
    } else if (district != null && district.isNotEmpty) {
      query = query.where('district', whereIn: [district, 'Global']);
    } else if (state != null && state.isNotEmpty) {
      query = query.where('state', whereIn: [state, 'Global']);
    }

    if (course != null && course.isNotEmpty) {
      query = query.where('course', isEqualTo: course);
    }
    if (semester != null && semester.isNotEmpty) {
      query = query.where('semester', isEqualTo: semester);
    }
    if (subject != null && subject.isNotEmpty) {
      query = query.where('subject', isEqualTo: subject);
    }

    // Apply pagination
    query = query.limit(limit);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final notes = snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data() as dynamic, doc.id))
        .toList();

    // Client-side sorting
    notes.sort((a, b) {
      if (sortBy == 'downloads') return b.downloads.compareTo(a.downloads);
      if (sortBy == 'likes') return b.likes.compareTo(a.likes);
      if (sortBy == 'qualityScore') return b.qualityScore.compareTo(a.qualityScore);
      return b.createdAt.compareTo(a.createdAt);
    });

    return notes;
  }

  /// Same query as [fetchNotes] but also returns the last document so callers
  /// can do real cursor pagination instead of re-fetching every previous page
  /// with an ever-growing `limit`.
  Future<({List<NoteModel> notes, DocumentSnapshot? lastDoc})> fetchNotesPage({
    String? course,
    String? semester,
    String? subject,
    String? sortBy,
    String? collegeId,
    String? district,
    String? state,
    int limit = 15,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _db.collection('notes').where('status', isEqualTo: 'approved');

    if (collegeId != null && collegeId.isNotEmpty) {
      query = query.where('collegeId', whereIn: [collegeId, 'Global']);
    } else if (district != null && district.isNotEmpty) {
      query = query.where('district', whereIn: [district, 'Global']);
    } else if (state != null && state.isNotEmpty) {
      query = query.where('state', whereIn: [state, 'Global']);
    }

    if (course != null && course.isNotEmpty) {
      query = query.where('course', isEqualTo: course);
    }
    if (semester != null && semester.isNotEmpty) {
      query = query.where('semester', isEqualTo: semester);
    }
    if (subject != null && subject.isNotEmpty) {
      query = query.where('subject', isEqualTo: subject);
    }

    query = query.limit(limit);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final notes = snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data() as dynamic, doc.id))
        .toList();

    notes.sort((a, b) {
      if (sortBy == 'downloads') return b.downloads.compareTo(a.downloads);
      if (sortBy == 'likes') return b.likes.compareTo(a.likes);
      if (sortBy == 'qualityScore') return b.qualityScore.compareTo(a.qualityScore);
      return b.createdAt.compareTo(a.createdAt);
    });

    return (
      notes: notes,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Future<List<NoteModel>> fetchUserUploads(String uid) async {
    final snapshot = await _db
        .collection('notes')
        .where('uploadedBy', isEqualTo: uid)
        .get();
        
    final notes = snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
        .toList();
        
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  Future<void> updateNote(NoteModel note) async {
    await _db.collection('notes').doc(note.noteId).update({
      'title': note.title,
      'description': note.description,
      'course': note.course,
      'semester': note.semester,
      'subject': note.subject,
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _db.collection('notes').doc(noteId).delete();
  }

  // --- PYQ / QUESTION PAPER OPERATIONS ---

  Future<void> uploadQuestionPaper(QuestionPaperModel paper) async {
    await _db.collection('questionPapers').doc(paper.paperId).set(paper.toMap());
  }

  Future<Map<String, dynamic>> getPapersPaginated({
    DocumentSnapshot? startAfter,
    int limit = 50,
    String? searchQuery,
    String searchField = 'title',
    String? courseFilter,
    String? statusFilter,
  }) async {
    Query query = _db.collection('questionPapers');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      query = query
          .where(searchField, isGreaterThanOrEqualTo: lowercaseQuery)
          .where(searchField, isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .orderBy(searchField);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (courseFilter != null && courseFilter != 'All') {
      query = query.where('course', isEqualTo: courseFilter);
    }

    if (statusFilter != null && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final papers = snapshot.docs.map((doc) => QuestionPaperModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

    return {
      'papers': papers,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<List<QuestionPaperModel>> fetchQuestionPapers({
    String? course,
    String? semester,
    String? subject,
    String? year,
    String? collegeId,
    String? district,
    String? state,
    int limit = 50,
  }) async {
    Query query = _db.collection('questionPapers').where('status', isEqualTo: 'approved');

    if (collegeId != null && collegeId.isNotEmpty) {
      query = query.where('collegeId', whereIn: [collegeId, 'Global']);
    } else if (district != null && district.isNotEmpty) {
      query = query.where('district', whereIn: [district, 'Global']);
    } else if (state != null && state.isNotEmpty) {
      query = query.where('state', whereIn: [state, 'Global']);
    }

    if (course != null && course.isNotEmpty) query = query.where('course', isEqualTo: course);
    if (semester != null && semester.isNotEmpty) query = query.where('semester', isEqualTo: semester);
    if (subject != null && subject.isNotEmpty) query = query.where('subject', isEqualTo: subject);
    if (year != null && year.isNotEmpty) query = query.where('year', isEqualTo: year);

    // Bounded — this had no limit at all, so every call was a full scan of
    // every approved paper matching the filters.
    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => QuestionPaperModel.fromMap(doc.data() as dynamic, doc.id))
        .toList();
  }

  Future<List<QuestionPaperModel>> fetchUserPapers(String uid) async {
    final snapshot = await _db
        .collection('questionPapers')
        .where('uploadedBy', isEqualTo: uid)
        .get();
        
    return snapshot.docs
        .map((doc) => QuestionPaperModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateQuestionPaper(QuestionPaperModel paper) async {
    await _db.collection('questionPapers').doc(paper.paperId).update({
      'title': paper.title,
      'course': paper.course,
      'semester': paper.semester,
      'subject': paper.subject,
      'year': paper.year,
    });
  }

  Future<void> deleteQuestionPaper(String paperId) async {
    await _db.collection('questionPapers').doc(paperId).delete();
  }

  // --- COMMUNITY FEED OPERATIONS ---

  Future<void> createPost(PostModel post) async {
    await _db.collection('posts').doc(post.postId).set(post.toMap());
  }

  Future<Map<String, dynamic>> fetchCommunityPosts({DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection('posts').orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    
    final posts = snapshot.docs
        .map((doc) => PostModel.fromMap(doc.data() as dynamic, doc.id))
        .toList();
        
    return {
      'posts': posts,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  // --- SOCIAL INTERACTION: LIKES, COMMENTS, FOLLOWS ---

  Future<void> likeContent(String userId, String contentId, String contentType) async {
    final likeRef = _db.collection('likes').doc('${userId}_$contentId');
    final doc = await likeRef.get();
    if (doc.exists) return; // Already liked

    await _db.runTransaction((transaction) async {
      transaction.set(likeRef, {
        'userId': userId,
        'contentId': contentId,
        'contentType': contentType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final String collection = contentType == 'post'
          ? 'posts'
          : (contentType == 'note' ? 'notes' : 'questionPapers');
      final contentRef = _db.collection(collection).doc(contentId);
      
      transaction.update(contentRef, {'likes': FieldValue.increment(1)});
    });

    try {
      final String collection = contentType == 'post'
          ? 'posts'
          : (contentType == 'note' ? 'notes' : 'questionPapers');
      final contentDoc = await _db.collection(collection).doc(contentId).get();
      final authorId = contentDoc.data()?['authorId'] ?? contentDoc.data()?['uploadedBy'];
      
      if (authorId != null && authorId != userId) {
        final likerDoc = await _db.collection('users').doc(userId).get();
        final likerName = likerDoc.data()?['name'] ?? 'Someone';
        final title = contentDoc.data()?['title'] ?? 'your content';

        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: authorId,
          senderId: userId,
          senderName: likerName,
          type: 'like',
          contentId: contentId,
          title: 'New Like ❤️',
          body: '$likerName liked "$title"',
          route: contentType == 'note' ? '/notes/$contentId' : '/community',
          priority: 'low',
          createdAt: DateTime.now(),
        ));
      }
    } catch (_) {}
  }

  Future<void> unlikeContent(String userId, String contentId, String contentType) async {
    final likeRef = _db.collection('likes').doc('${userId}_$contentId');
    final doc = await likeRef.get();
    if (!doc.exists) return;

    await _db.runTransaction((transaction) async {
      transaction.delete(likeRef);

      final String collection = contentType == 'post'
          ? 'posts'
          : (contentType == 'note' ? 'notes' : 'questionPapers');
      final contentRef = _db.collection(collection).doc(contentId);
      
      transaction.update(contentRef, {'likes': FieldValue.increment(-1)});
    });
  }

  Future<void> addComment(CommentModel comment) async {
    final commentRef = _db.collection('comments').doc(comment.commentId);
    await commentRef.set(comment.toMap());

    // Increment commentsCount on the parent content.
    // Try posts first, then notes.
    final postDoc = _db.collection('posts').doc(comment.contentId);
    final postSnap = await postDoc.get();
    if (postSnap.exists) {
      await postDoc.update({'commentsCount': FieldValue.increment(1)});
    } else {
      final noteDoc = _db.collection('notes').doc(comment.contentId);
      final noteSnap = await noteDoc.get();
      if (noteSnap.exists) {
        await noteDoc.update({'commentsCount': FieldValue.increment(1)});
      }
    }

    try {
      String? authorId;
      String title = 'your post';

      if (postSnap.exists) {
        authorId = postSnap.data()?['authorId'];
      } else {
        final noteDoc = _db.collection('notes').doc(comment.contentId);
        final noteSnap = await noteDoc.get();
        if (noteSnap.exists) {
          authorId = noteSnap.data()?['uploadedBy'];
          title = noteSnap.data()?['title'] ?? 'your note';
        }
      }

      if (authorId != null && authorId != comment.authorId) {
        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: authorId,
          senderId: comment.authorId,
          senderName: comment.authorName,
          type: 'comment',
          contentId: comment.contentId,
          title: 'New Comment 💬',
          body: '${comment.authorName} commented on $title: "${comment.text}"',
          route: '/community',
          priority: 'normal',
          createdAt: DateTime.now(),
        ));
      }
    } catch (_) {}
  }


  Future<void> followUser(String followerId, String followingId) async {
    final followId = '${followerId}_$followingId';
    final followRef = _db.collection('followers').doc(followId);

    await _db.runTransaction((transaction) async {
      transaction.set(followRef, {
        'followerId': followerId,
        'followingId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(_db.collection('users').doc(followerId), {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
      transaction.set(_db.collection('users').doc(followingId), {'followersCount': FieldValue.increment(1)}, SetOptions(merge: true));
    });
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    final followId = '${followerId}_$followingId';
    final followRef = _db.collection('followers').doc(followId);

    await _db.runTransaction((transaction) async {
      transaction.delete(followRef);

      transaction.set(_db.collection('users').doc(followerId), {'followingCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      transaction.set(_db.collection('users').doc(followingId), {'followersCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    });
  }

  /// Batch-loads user docs by id using `whereIn` (10 ids per query) instead of
  /// one sequential read per id. Batches run concurrently.
  Future<List<UserModel>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ),
    );

    // Preserve the caller's id order.
    final byId = <String, UserModel>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        byId[doc.id] = UserModel.fromMap(doc.data());
      }
    }
    return ids.map((id) => byId[id]).whereType<UserModel>().toList();
  }

  Future<List<UserModel>> getFollowers(String userId, {int limit = 50}) async {
    final snapshot = await _db
        .collection('followers')
        .where('followingId', isEqualTo: userId)
        .limit(limit)
        .get();
    final ids = snapshot.docs
        .map((doc) => doc.data()['followerId'] as String?)
        .whereType<String>()
        .toList();
    return _fetchUsersByIds(ids);
  }

  Future<List<UserModel>> getFollowing(String userId, {int limit = 50}) async {
    final snapshot = await _db
        .collection('followers')
        .where('followerId', isEqualTo: userId)
        .limit(limit)
        .get();
    final ids = snapshot.docs
        .map((doc) => doc.data()['followingId'] as String?)
        .whereType<String>()
        .toList();
    return _fetchUsersByIds(ids);
  }

  Future<bool> isFollowingUser(String followerId, String followingId) async {
    final doc = await _db.collection('followers').doc('${followerId}_$followingId').get();
    return doc.exists;
  }

  Future<List<UserModel>> getSuggestedUsers(String currentUid) async {
    final snapshot = await _db.collection('users').limit(40).get();
    List<UserModel> suggestions = [];
    
    final followingSnapshot = await _db
        .collection('followers')
        .where('followerId', isEqualTo: currentUid)
        .limit(200)
        .get();
    final followingIds = followingSnapshot.docs.map((doc) => doc.data()['followingId'] as String?).toSet();

    final seenUsernames = <String>{};
    for (var doc in snapshot.docs) {
      final user = UserModel.fromMap(doc.data());
      if (user.uid != currentUid && !followingIds.contains(user.uid)) {
        final usernameKey = user.username.trim().toLowerCase();
        if (usernameKey.isEmpty) {
          suggestions.add(user);
        } else if (!seenUsernames.contains(usernameKey)) {
          seenUsernames.add(usernameKey);
          suggestions.add(user);
        }
      }
    }
    return suggestions.take(15).toList();
  }

  Future<void> removeFollower(String currentUid, String followerId) async {
    final followId = '${followerId}_$currentUid';
    final followRef = _db.collection('followers').doc(followId);

    await _db.runTransaction((transaction) async {
      transaction.delete(followRef);
      transaction.set(_db.collection('users').doc(currentUid), {'followersCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      transaction.set(_db.collection('users').doc(followerId), {'followingCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    });
  }

  Future<void> blockUser(String blockerId, String blockedId) async {
    final blockId = '${blockerId}_$blockedId';
    await _db.collection('blocks').doc(blockId).set({
      'blockerId': blockerId,
      'blockedId': blockedId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- REPUTATION AND LEADERBOARDS ---

  Future<void> addReputationPoints(String uid, int points) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) return;

      final currentPoints = userSnapshot.data()?['reputationPoints'] ?? 0;
      final newPoints = currentPoints + points;

      // Calculate Rank based on points
      String rank = 'Bronze Contributor';
      if (newPoints >= 10000) {
        rank = 'Elite Educator';
      } else if (newPoints >= 5000) {
        rank = 'Top Educator';
      } else if (newPoints >= 2000) {
        rank = 'Platinum Contributor';
      } else if (newPoints >= 1000) {
        rank = 'Gold Contributor';
      } else if (newPoints >= 500) {
        rank = 'Silver Contributor';
      }

      transaction.update(userRef, {
        'reputationPoints': newPoints,
        'contributorRank': rank,
      });
    });
  }

  Future<List<UserModel>> fetchLeaderboard(String period) async {
    // Basic implementation uses all-time reputation, in production filters by timeframe logs
    final snapshot = await _db
        .collection('users')
        .orderBy('reputationPoints', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  // --- MODERATION & REPORTS ---

  Future<void> createReport(ReportModel report) async {
    await _db.collection('reports').doc(report.reportId).set(report.toMap());
    // Also increment report tally on note
    if (report.contentType == 'note') {
      await _db.collection('notes').doc(report.contentId).update({
        'reports': FieldValue.increment(1),
      });
    } else if (report.contentType == 'questionPaper') {
      await _db.collection('questionPapers').doc(report.contentId).update({
        'reports': FieldValue.increment(1),
      });
    } else if (report.contentType == 'post') {
      await _db.collection('posts').doc(report.contentId).update({
        'reports': FieldValue.increment(1),
      });
    }
  }

  Future<List<ReportModel>> fetchReports() async {
    final snapshot = await _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .get();

    final docs = snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
        .toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<Map<String, dynamic>> getReportsPaginated({
    DocumentSnapshot? startAfter,
    int limit = 50,
  }) async {
    Query query = _db.collection('reports').orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final reports = snapshot.docs.map((doc) => ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

    return {
      'reports': reports,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<void> resolveReport(String reportId, String status) async {
    await _db.collection('reports').doc(reportId).update({'status': status});
  }

  Future<List<NoteModel>> getPendingNotes() async {
    final snapshot = await _db
        .collection('notes')
        .where('status', isEqualTo: 'pending')
        .get();

    final docs = snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
        .toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<void> moderateNote(String noteId, String status) async {
    await _db.collection('notes').doc(noteId).update({'status': status});
    
    final doc = await _db.collection('notes').doc(noteId).get();
    final uploaderId = doc.data()?['uploadedBy'];
    final title = doc.data()?['title'] ?? 'Note';

    if (uploaderId != null) {
      if (status == 'approved') {
        await addReputationPoints(uploaderId, 10);
        await _db.collection('users').doc(uploaderId).update({
          'uploadsCount': FieldValue.increment(1)
        });
        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: uploaderId,
          senderId: 'system',
          senderName: 'StudySphere Admin',
          type: 'upload_approved',
          contentId: noteId,
          title: 'Note Approved 🎉',
          body: 'Your note "$title" was approved! You earned +10 points.',
          route: '/notes/$noteId',
          priority: 'high',
          createdAt: DateTime.now(),
        ));
      } else if (status == 'rejected') {
        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: uploaderId,
          senderId: 'system',
          senderName: 'StudySphere Admin',
          type: 'upload_rejected',
          contentId: noteId,
          title: 'Note Review Update',
          body: 'Your note "$title" did not meet quality guidelines and was rejected.',
          priority: 'normal',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  Future<void> updateNoteStatus(String noteId, String status) async {
    await _db.collection('notes').doc(noteId).update({'status': status});
  }

  Future<List<NoteModel>> fetchUserNotes(String userId) async {
    final snapshot = await _db
        .collection('notes')
        .where('uploadedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<QuestionPaperModel>> getPendingQuestionPapers() async {
    final snapshot = await _db
        .collection('questionPapers')
        .where('status', isEqualTo: 'pending')
        .get();

    final docs = snapshot.docs
        .map((doc) => QuestionPaperModel.fromMap(doc.data(), doc.id))
        .toList();
    return docs;
  }

  Future<void> moderateQuestionPaper(String paperId, String status) async {
    await _db.collection('questionPapers').doc(paperId).update({'status': status});
    
    final doc = await _db.collection('questionPapers').doc(paperId).get();
    final uploaderId = doc.data()?['uploadedBy'];
    final title = doc.data()?['title'] ?? 'Question Paper';

    if (uploaderId != null) {
      if (status == 'approved') {
        await addReputationPoints(uploaderId, 15);
        await _db.collection('users').doc(uploaderId).update({
          'uploadsCount': FieldValue.increment(1)
        });
        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: uploaderId,
          senderId: 'system',
          senderName: 'StudySphere Admin',
          type: 'upload_approved',
          contentId: paperId,
          title: 'PYQ Approved 🎉',
          body: 'Your question paper "$title" was approved! You earned +15 points.',
          route: '/papers',
          priority: 'high',
          createdAt: DateTime.now(),
        ));
      } else if (status == 'rejected') {
        await sendNotification(NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: uploaderId,
          senderId: 'system',
          senderName: 'StudySphere Admin',
          type: 'upload_rejected',
          contentId: paperId,
          title: 'PYQ Review Update',
          body: 'Your question paper "$title" was rejected by moderators.',
          priority: 'normal',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  Future<void> incrementDownloads(String contentId, String contentType) async {
    final String col = contentType == 'note' ? 'notes' : 'questionPapers';
    final docRef = _db.collection(col).doc(contentId);

    await _db.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) return;

      final currentDownloads = docSnapshot.data()?['downloads'] ?? 0;
      final newDownloads = currentDownloads + 1;

      transaction.update(docRef, {'downloads': newDownloads});

      // Award uploader reputation points based on download milestones
      final uploaderId = docSnapshot.data()?['uploadedBy'];
      if (uploaderId != null) {
        transaction.update(_db.collection('users').doc(uploaderId), {'downloadsCount': FieldValue.increment(1)});
        
        // Award reputation on milestones
        if (newDownloads == 100) {
          await addReputationPoints(uploaderId, 20);
        } else if (newDownloads == 500) {
          await addReputationPoints(uploaderId, 50);
        } else if (newDownloads == 1000) {
          await addReputationPoints(uploaderId, 100);
        }
      }
    });
  }

  Future<void> sendNotification(NotificationModel notification) async {
    await _db.collection('notifications').doc(notification.notificationId).set(notification.toMap());
  }

  /// Streams personal notifications for [userId] (only items within the last 30 days)
  Stream<List<NotificationModel>> streamUserNotifications(String userId, {int limit = 50}) {
    if (userId.isEmpty) return Stream.value([]);
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _db
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        // orderBy is required for limit() to mean "the newest 50". Without it
        // Firestore returns an arbitrary 50 by document ID, so users with more
        // than 50 notifications could miss the most recent ones entirely and
        // the unread badge count was wrong. Uses the existing
        // receiverId + createdAt composite index.
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .where((item) => item.createdAt.isAfter(thirtyDaysAgo))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          // Silently return empty list — permission errors occur briefly during
          // sign-out/sign-in transitions and are not actionable by the user.
          debugPrint("User notifications unavailable: $e");
          return <NotificationModel>[];
        });
  }

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    if (userId.isEmpty) return [];
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .get();

      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .where((item) => item.createdAt.isAfter(thirtyDaysAgo))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      return [];
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'read': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).delete();
  }

  /// Automatically cleans up user notifications older than 30 days to optimize Firestore cost
  Future<void> deleteOldUserNotifications(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final oldDocs = await _db
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('createdAt', isLessThan: thirtyDaysAgo)
        .get();

    final batch = _db.batch();
    for (var doc in oldDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }


  // --- AI ASSISTANT OPERATIONS ---

  Future<void> updateAiUsage(String uid, int usage, DateTime resetDate) async {
    await _db.collection('users').doc(uid).update({
      'dailyAiUsage': usage,
      'lastUsageReset': resetDate,
    });
  }

  Future<void> saveChatMessage(String uid, Map<String, dynamic> messageData) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .doc(messageData['messageId'])
        .set(messageData);
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory(String uid, {int limit = 20}) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> clearChatHistory(String uid) async {
    final batch = _db.batch();
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- ADMIN PLATFORM STATS ---
  Future<Map<String, int>> getPlatformStats() async {
    try {
      final usersQuery = await _db.collection('users').count().get();
      final notesQuery = await _db.collection('notes').count().get();
      final pyqsQuery = await _db.collection('questionPapers').count().get();
      final collegesQuery = await _db.collection('colleges').count().get();
      
      final pendingNotesQuery = await _db.collection('notes').where('status', isEqualTo: 'pending').count().get();
      final pendingPyqsQuery = await _db.collection('questionPapers').where('status', isEqualTo: 'pending').count().get();
      
      final reportedNotesQuery = await _db.collection('notes').where('reports', isGreaterThan: 0).count().get();
      final reportedPyqsQuery = await _db.collection('questionPapers').where('reports', isGreaterThan: 0).count().get();

      return {
        'users': usersQuery.count ?? 0,
        'notes': notesQuery.count ?? 0,
        'pyqs': pyqsQuery.count ?? 0,
        'colleges': collegesQuery.count ?? 0,
        'pending_reviews': (pendingNotesQuery.count ?? 0) + (pendingPyqsQuery.count ?? 0),
        'reported_content': (reportedNotesQuery.count ?? 0) + (reportedPyqsQuery.count ?? 0),
        'downloads': 0, 
      };
    } catch (e) {
      return {'users': 0, 'notes': 0, 'pyqs': 0, 'colleges': 0, 'pending_reviews': 0, 'reported_content': 0, 'downloads': 0};
    }
  }

  Future<Map<String, int>> getAdminStats() async {
    try {
      final usersQ = await _db.collection('users').count().get();
      final notesQ = await _db.collection('notes').count().get();
      final postsQ = await _db.collection('posts').count().get();
      final commentsQ = await _db.collection('comments').count().get();
      final reportsQ = await _db.collection('reports').count().get();
      
      return {
        'users': usersQ.count ?? 0,
        'notes': notesQ.count ?? 0,
        'posts': postsQ.count ?? 0,
        'comments': commentsQ.count ?? 0,
        'reports': reportsQ.count ?? 0,
        'downloads': 0, // Requires sum() aggregate or Analytics API
        'ai_requests': 0, // Logged in Analytics
      };
    } catch (e) {
      return {};
    }
  }

  // ── Admin: Global Announcements ──
  Future<void> sendGlobalAnnouncement({
    required String title,
    required String body,
    String priority = 'normal',
    String type = 'announcement',
    String targetCourse = 'All',
    String targetSemester = 'All',
    String? route,
    String? imageUrl,
    String? actionLabel,
    int expiryDays = 30,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: expiryDays));

    final notification = {
      'title': title,
      'body': body,
      'type': type,
      'priority': priority,
      'targetCourse': targetCourse,
      'targetSemester': targetSemester,
      'route': route,
      'imageUrl': imageUrl,
      'actionLabel': actionLabel,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': true,
    };
    await _db.collection('global_notifications').add(notification);
  }

  Stream<List<GlobalNotificationModel>> streamGlobalAnnouncements({
    String? userCourse,
    String? userSemester,
  }) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _db
        .collection('global_notifications')
        // NOTE: Removed server-side isActive filter to avoid needing a
        // composite index (isActive + createdAt). Filtering is done
        // client-side below, which is equivalent for this small collection.
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => GlobalNotificationModel.fromMap(doc.data(), doc.id))
          .where((item) => item.isActive)
          .where((item) => item.createdAt.isAfter(thirtyDaysAgo))
          .where((item) {
            if (item.targetCourse != 'All' && userCourse != null && userCourse.isNotEmpty) {
              if (item.targetCourse.toLowerCase() != userCourse.toLowerCase()) return false;
            }
            if (item.targetSemester != 'All' && userSemester != null && userSemester.isNotEmpty) {
              if (item.targetSemester.toLowerCase() != userSemester.toLowerCase()) return false;
            }
            return true;
          })
          .take(20)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((e) {
      debugPrint("Global announcements unavailable: $e");
      return <GlobalNotificationModel>[];
    });
  }

  Future<void> deleteGlobalAnnouncement(String announcementId) async {
    await _db.collection('global_notifications').doc(announcementId).delete();
  }

  Future<List<UserModel>> fetchAllUsers({int limit = 100}) async {
    try {
      final snapshot = await _db.collection('users').limit(limit).get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint("Error fetching users: $e");
      return [];
    }
  }


  // ── Admin: Banners ──
  Future<void> addBanner(String imageUrl, int order, String redirectType, Map<String, dynamic> redirectData) async {
    await _db.collection('banners').add({
      'imageUrl': imageUrl,
      'order': order,
      'isActive': true,
      'redirectType': redirectType,
      'redirectData': redirectData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<BannerModel>> fetchActiveBanners() async {
    final snap = await _db
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();
    return snap.docs
        .map((d) => BannerModel.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> deleteBanner(String bannerId) async {
    await _db.collection('banners').doc(bannerId).delete();
  }

  // ── Admin: Legal Docs ──
  Future<String> getLegalDoc(String docId) async {
    final snap = await _db.collection('legal').doc(docId).get();
    if (snap.exists) {
      return snap.data()?['content'] as String? ?? '';
    }
    return '';
  }

  Future<void> saveLegalDoc(String docId, String content) async {
    await _db.collection('legal').doc(docId).set({
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Admin: Colleges ──
  /// Bounded: the colleges collection is large and this rendered into a single
  /// table, so an unlimited fetch was billed on every admin visit and after
  /// every single-row toggle.
  Future<List<CollegeModel>> getAllColleges({int limit = 200}) async {
    final snap = await _db
        .collection('colleges')
        .orderBy('collegeName')
        .limit(limit)
        .get();
    return snap.docs.map((d) => CollegeModel.fromMap(d.data(), d.id)).toList();
  }

  Future<void> toggleCollegeStatus(String collegeId, bool isActive) async {
    await _db.collection('colleges').doc(collegeId).update({'isActive': isActive});
  }

  // ── Courses (Phase 3) ──

  Future<List<CourseModel>> fetchCourses() async {
    final snap = await _db.collection('courses').orderBy('order').get();
    return snap.docs.map((doc) => CourseModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<CourseModel>> fetchFeaturedCourses() async {
    final snap = await _db.collection('courses').where('isFeatured', isEqualTo: true).orderBy('order').get();
    return snap.docs.map((doc) => CourseModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<CourseModel?> fetchCourseById(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    if (doc.exists && doc.data() != null) {
      return CourseModel.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  Future<void> enrollInCourse(String userId, String courseId) async {
    await _db.collection('users').doc(userId).collection('enrolledCourses').doc(courseId).set({
      'enrolledAt': FieldValue.serverTimestamp(),
      'progress': 0.0,
      'lastWatchedModuleId': null,
    }, SetOptions(merge: true));
  }

  Future<List<String>> fetchEnrolledCourseIds(String userId) async {
    final snap = await _db.collection('users').doc(userId).collection('enrolledCourses').get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  Future<void> updateWatchProgress(String userId, String courseId, String moduleId, double progress) async {
    await _db.collection('users').doc(userId).collection('enrolledCourses').doc(courseId).set({
      'progress': progress,
      'lastWatchedModuleId': moduleId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class NoteNotFoundException implements Exception {
  final String message;
  NoteNotFoundException([this.message = "Note not found"]);
  @override
  String toString() => message;
}
