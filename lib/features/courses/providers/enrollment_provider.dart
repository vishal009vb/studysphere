import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

class EnrollmentNotifier extends StateNotifier<List<String>> {
  final SharedPreferences _prefs;
  static const _key = 'enrolled_courses';

  EnrollmentNotifier(this._prefs) : super(_prefs.getStringList(_key) ?? []);

  Future<void> enroll(String courseId) async {
    if (!state.contains(courseId)) {
      final newState = [...state, courseId];
      await _prefs.setStringList(_key, newState);
      state = newState;
    }
  }

  Future<void> unenroll(String courseId) async {
    final newState = state.where((id) => id != courseId).toList();
    await _prefs.setStringList(_key, newState);
    state = newState;
  }
}

final enrollmentProvider = StateNotifierProvider<EnrollmentNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return EnrollmentNotifier(prefs);
});
