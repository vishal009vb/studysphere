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

class CourseProgressNotifier extends StateNotifier<Map<String, Set<String>>> {
  final SharedPreferences _prefs;

  CourseProgressNotifier(this._prefs) : super(_loadInitial(_prefs));

  static Map<String, Set<String>> _loadInitial(SharedPreferences prefs) {
    final map = <String, Set<String>>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('completed_modules_')) {
        final courseId = key.substring('completed_modules_'.length);
        final list = prefs.getStringList(key) ?? [];
        map[courseId] = list.toSet();
      }
    }
    return map;
  }

  Future<void> toggleModuleCompleted(String courseId, String moduleId) async {
    final currentSet = Set<String>.from(state[courseId] ?? {});
    if (currentSet.contains(moduleId)) {
      currentSet.remove(moduleId);
    } else {
      currentSet.add(moduleId);
    }

    final newState = Map<String, Set<String>>.from(state);
    newState[courseId] = currentSet;
    await _prefs.setStringList('completed_modules_$courseId', currentSet.toList());
    state = newState;
  }

  Set<String> getCompletedModules(String courseId) {
    return state[courseId] ?? {};
  }
}

final courseProgressProvider = StateNotifierProvider<CourseProgressNotifier, Map<String, Set<String>>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CourseProgressNotifier(prefs);
});
