import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_model.dart';
import 'enrollment_provider.dart';

/// Single live listener on `courses`, shared by every course provider below.
///
/// Previously coursesProvider / featuredCoursesProvider / freeCoursesProvider /
/// enrolledCoursesProvider each opened their own identical `.snapshots()` on
/// this collection and differed only in a client-side filter. Firestore bills
/// per document per listener, so the same documents were charged four times
/// over. They now all derive from this one stream.
final _allCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  ref.keepAlive();
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('order')
      // Safety bound so the listener can never fan out over an unbounded
      // collection. The catalogue is curated and far below this ceiling.
      .limit(200)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .toList());
});

/// Courses visible to users (excluding deleted and hidden ones).
final coursesProvider = Provider<AsyncValue<List<CourseModel>>>((ref) {
  return ref.watch(_allCoursesProvider).whenData(
        (courses) => courses
            .where((course) => !course.isDeleted && course.isVisible)
            .toList(),
      );
});

/// Featured courses only (excluding deleted and hidden ones).
final featuredCoursesProvider = Provider<AsyncValue<List<CourseModel>>>((ref) {
  return ref.watch(_allCoursesProvider).whenData(
        (courses) => courses
            .where((course) =>
                !course.isDeleted && course.isVisible && course.isFeatured)
            .toList(),
      );
});

/// Free courses.
final freeCoursesProvider = Provider<AsyncValue<List<CourseModel>>>((ref) {
  return ref.watch(_allCoursesProvider).whenData(
        (courses) => courses
            .where((course) =>
                !course.isDeleted && course.isVisible && !course.isPaid)
            .toList(),
      );
});

/// Enrolled courses — filtered by the SharedPreferences enrollment list.
///
/// Deriving from the shared stream also means enrolling/unenrolling no longer
/// tears down a Firestore listener and re-reads the whole collection; only this
/// client-side filter recomputes.
final enrolledCoursesProvider = Provider<AsyncValue<List<CourseModel>>>((ref) {
  final enrolledIds = ref.watch(enrollmentProvider);
  return ref.watch(_allCoursesProvider).whenData(
        (courses) => courses
            .where((course) =>
                !course.isDeleted &&
                course.isVisible &&
                enrolledIds.contains(course.id))
            .toList(),
      );
});

/// Admin Provider: ALL courses including hidden and deleted ones.
///
/// autoDispose so the admin listener is released when the admin screen closes
/// instead of staying subscribed for the whole app session.
final adminCoursesProvider =
    StreamProvider.autoDispose<List<CourseModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .toList());
});
