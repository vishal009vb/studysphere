import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'other_user_profile_screen.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  final String userId;
  final int initialTab; // 0 for Followers, 1 for Following
  final String userName;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.initialTab,
    required this.userName,
  });

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<UserModel> _followers = [];
  List<UserModel> _following = [];
  List<UserModel> _suggestions = [];
  Set<String> _myFollowingIds = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _searchController.clear();
          _searchQuery = '';
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;

    setState(() => _isLoading = true);

    try {
      final followers = await firestoreService.getFollowers(widget.userId);
      final following = await firestoreService.getFollowing(widget.userId);
      
      List<UserModel> suggestions = [];
      if (currentUid != null) {
        suggestions = await firestoreService.getSuggestedUsers(currentUid);
      }

      Set<String> myFollowingIds = {};
      if (currentUid != null) {
        if (currentUid == widget.userId) {
          myFollowingIds = following.map((u) => u.uid).toSet();
        } else {
          final myFollowing = await firestoreService.getFollowing(currentUid);
          myFollowingIds = myFollowing.map((u) => u.uid).toSet();
        }
      }

      if (mounted) {
        setState(() {
          _followers = followers;
          _following = following;
          _suggestions = suggestions;
          _myFollowingIds = myFollowingIds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(UserModel targetUser) async {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == null || currentUid == targetUser.uid) return;

    final firestoreService = ref.read(firestoreServiceProvider);
    final isFollowing = _myFollowingIds.contains(targetUser.uid);

    setState(() {
      if (isFollowing) {
        _myFollowingIds.remove(targetUser.uid);
        if (widget.userId == currentUid && _tabController.index == 1) {
          _following.removeWhere((u) => u.uid == targetUser.uid);
        }
      } else {
        _myFollowingIds.add(targetUser.uid);
      }
    });

    try {
      if (isFollowing) {
        await firestoreService.unfollowUser(currentUid, targetUser.uid);
      } else {
        await firestoreService.followUser(currentUid, targetUser.uid);
      }
    } catch (_) {
      setState(() {
        if (isFollowing) {
          _myFollowingIds.add(targetUser.uid);
          if (widget.userId == currentUid && _tabController.index == 1) {
            _following.add(targetUser);
          }
        } else {
          _myFollowingIds.remove(targetUser.uid);
        }
      });
    }
  }

  Future<void> _removeFollower(UserModel targetUser) async {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == null || currentUid != widget.userId) return;

    final firestoreService = ref.read(firestoreServiceProvider);

    setState(() {
      _followers.removeWhere((u) => u.uid == targetUser.uid);
    });

    try {
      await firestoreService.removeFollower(currentUid, targetUser.uid);
    } catch (_) {
      setState(() {
        _followers.add(targetUser);
      });
    }
  }

  List<UserModel> _getFilteredList(List<UserModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((user) {
      final name = user.name.toLowerCase();
      final username = user.username.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  Widget _buildUserList(List<UserModel> users, {bool isFollowersTab = false}) {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    final filtered = _getFilteredList(users);

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline_rounded,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty 
                    ? 'No matches found for "$_searchQuery"'
                    : (isFollowersTab ? 'No followers yet' : 'Not following anyone yet'),
                style: AppTextStyles.headingSmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        final isSelf = user.uid == currentUid;
        final isFollowing = _myFollowingIds.contains(user.uid);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: GestureDetector(
            onTap: () => _navigateToProfile(user.uid),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  : null,
            ),
          ),
          title: GestureDetector(
            onTap: () => _navigateToProfile(user.uid),
            child: Text(
              user.name,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: GestureDetector(
            onTap: () => _navigateToProfile(user.uid),
            child: Text(
              '@${user.username.isNotEmpty ? user.username : user.name.toLowerCase().replaceAll(' ', '_')}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          trailing: isSelf
              ? null
              : isFollowersTab && widget.userId == currentUid
                  ? SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _removeFollower(user),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEAEA),
                          foregroundColor: AppColors.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    )
                  : SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(user),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? const Color(0xFFF3F2FF) : AppColors.primary,
                          foregroundColor: isFollowing ? AppColors.textPrimary : Colors.white,
                          elevation: isFollowing ? 0 : 2,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isFollowing ? const BorderSide(color: AppColors.border) : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildSuggestedList() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Suggested for You',
            style: AppTextStyles.headingSmall.copyWith(fontSize: 15, color: AppColors.textPrimary),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final user = _suggestions[index];
            final isFollowing = _myFollowingIds.contains(user.uid);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: GestureDetector(
                onTap: () => _navigateToProfile(user.uid),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                  child: user.photoUrl.isEmpty
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                        )
                      : null,
                ),
              ),
              title: GestureDetector(
                onTap: () => _navigateToProfile(user.uid),
                child: Text(
                  user.name,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: GestureDetector(
                onTap: () => _navigateToProfile(user.uid),
                child: Text(
                  '@${user.username.isNotEmpty ? user.username : user.name.toLowerCase().replaceAll(' ', '_')}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              trailing: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _toggleFollow(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? const Color(0xFFF3F2FF) : AppColors.primary,
                    foregroundColor: isFollowing ? AppColors.textPrimary : Colors.white,
                    elevation: isFollowing ? 0 : 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isFollowing ? const BorderSide(color: AppColors.border) : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _navigateToProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherUserProfileScreen(userId: uid),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          widget.userName,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.shadowLevel1,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search user...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(_followers, isFollowersTab: true),
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _getFilteredList(_following).length,
                              itemBuilder: (context, index) {
                                final filteredFollowing = _getFilteredList(_following);
                                final user = filteredFollowing[index];
                                final isFollowing = _myFollowingIds.contains(user.uid);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: GestureDetector(
                                    onTap: () => _navigateToProfile(user.uid),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                                      child: user.photoUrl.isEmpty
                                          ? Text(
                                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                            )
                                          : null,
                                    ),
                                  ),
                                  title: GestureDetector(
                                    onTap: () => _navigateToProfile(user.uid),
                                    child: Text(
                                      user.name,
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  subtitle: GestureDetector(
                                    onTap: () => _navigateToProfile(user.uid),
                                    child: Text(
                                      '@${user.username.isNotEmpty ? user.username : user.name.toLowerCase().replaceAll(' ', '_')}',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ),
                                  trailing: SizedBox(
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: () => _toggleFollow(user),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? const Color(0xFFF3F2FF) : AppColors.primary,
                                        foregroundColor: isFollowing ? AppColors.textPrimary : Colors.white,
                                        elevation: isFollowing ? 0 : 2,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: isFollowing ? const BorderSide(color: AppColors.border) : BorderSide.none,
                                        ),
                                      ),
                                      child: Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_getFilteredList(_following).isEmpty && _searchQuery.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 64,
                                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Not following anyone yet',
                                        style: AppTextStyles.headingSmall.copyWith(color: AppColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_getFilteredList(_following).isEmpty && _searchQuery.isNotEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Text(
                                    'No matches found for "$_searchQuery"',
                                    style: AppTextStyles.headingSmall.copyWith(color: AppColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            const Divider(height: 1),
                            _buildSuggestedList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
