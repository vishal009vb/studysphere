import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_model.dart';
import 'enrollment_provider.dart';

/// Fetches active courses for users (excluding deleted and hidden ones)
final coursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .where((course) => !course.isDeleted && course.isVisible)
          .toList());
});

/// Fetches featured courses only (excluding deleted and hidden ones)
final featuredCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .where((course) => !course.isDeleted && course.isVisible && course.isFeatured)
          .toList());
});

/// Fetches free courses
final freeCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .where((course) => !course.isDeleted && course.isVisible && !course.isPaid)
          .toList());
});

/// Enrolled courses — filtering based on SharedPreferences enrollment.
final enrolledCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  final enrolledIds = ref.watch(enrollmentProvider);

  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .where((course) => !course.isDeleted && course.isVisible && enrolledIds.contains(course.id))
          .toList());
});

/// Admin Provider: Fetches ALL courses including hidden and deleted ones.
final adminCoursesProvider = StreamProvider<List<CourseModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('courses')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.id, doc.data()))
          .toList());
});
