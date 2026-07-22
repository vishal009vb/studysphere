import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../models/note_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// --- User Profile — survives tab switches, never re-fetched unless invalidated -

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserModel?>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    ref.keepAlive();
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return null;
    try {
      return await ref.read(firestoreServiceProvider).getUserProfile(user.uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) { state = const AsyncData(null); return; }
    try {
      final profile =
          await ref.read(firestoreServiceProvider).getUserProfile(user.uid);
      state = AsyncData(profile);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  void updateLocal(UserModel updated) => state = AsyncData(updated);
}

// --- Recent Notes Cache --------------------------------------------------------

final recentNotesProvider =
    AsyncNotifierProvider<RecentNotesNotifier, List<NoteModel>>(
  RecentNotesNotifier.new,
);

class RecentNotesNotifier extends AsyncNotifier<List<NoteModel>> {
  @override
  Future<List<NoteModel>> build() async {
    ref.keepAlive();
    try {
      return await ref
          .read(firestoreServiceProvider)
          .fetchNotes(limit: 10, sortBy: 'createdAt');
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final notes = await ref
          .read(firestoreServiceProvider)
          .fetchNotes(limit: 10, sortBy: 'createdAt');
      state = AsyncData(notes);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

// --- Unread notification count -------------------------------------------------
final unreadNotifCountProvider = StateProvider<int>((ref) => 0);
