import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/note_model.dart';
import '../../models/post_model.dart';
import '../notes/pdf_viewer_screen.dart';
import 'follow_list_screen.dart';

class OtherUserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<OtherUserProfileScreen> createState() =>
      _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState
    extends ConsumerState<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _userProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  List<NoteModel> _userNotes = [];
  List<PostModel> _userPosts = [];
  late TabController _tabController;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  late String resolvedUid;

  @override
  void initState() {
    super.initState();
    resolvedUid = widget.userId;
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    final svc = ref.read(firestoreServiceProvider);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (!doc.exists) {
        final query = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.userId).limit(1).get();
        if (query.docs.isNotEmpty) {
          resolvedUid = query.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('Error resolving user id: $e');
    }

    // Listen to real-time updates for target user's counts/profile data
    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final profile = UserModel.fromMap(doc.data()!);
        setState(() {
          _userProfile = profile;
          _followersCount = profile.followersCount;
          _followingCount = profile.followingCount;
        });
      } else if (!doc.exists && mounted) {
        setState(() => _isLoading = false);
      }
    });

    List<NoteModel> notes = [];
    try {
      notes = await svc.fetchUserUploads(resolvedUid);
    } catch (e) {
      debugPrint('Error loading user notes: $e');
    }

    List<PostModel> posts = [];
    try {
      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: resolvedUid)
          .orderBy('createdAt', descending: true)
          .get();
      posts = postsSnap.docs.map((doc) => PostModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('Error loading user posts with orderBy: $e. Retrying fallback query without orderBy...');
      // Fallback: Fetch without orderBy (avoids index missing error) and sort in memory
      try {
        final postsSnap = await FirebaseFirestore.instance
            .collection('posts')
            .where('authorId', isEqualTo: resolvedUid)
            .get();
        final unsortedPosts = postsSnap.docs.map((doc) => PostModel.fromMap(doc.data(), doc.id)).toList();
        unsortedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        posts = unsortedPosts;
      } catch (err) {
        debugPrint('Fallback posts query failed: $err');
      }
    }

    bool isFollowing = false;
    try {
      if (currentUid != null) {
        final followDoc = await FirebaseFirestore.instance
            .collection('followers')
            .doc('${currentUid}_$resolvedUid')
            .get();
        isFollowing = followDoc.exists;
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }

    if (mounted) {
      setState(() {
        _userNotes = notes;
        _userPosts = posts;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == null || _userProfile == null) return;

    final svc = ref.read(firestoreServiceProvider);
    final isNowFollowing = !_isFollowing;

    setState(() {
      _isFollowing = isNowFollowing;
      _followersCount += isNowFollowing ? 1 : -1;
    });

    try {
      if (isNowFollowing) {
        await svc.followUser(currentUid, resolvedUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Following ${_userProfile!.name} ✨'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await svc.unfollowUser(currentUid, resolvedUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${_userProfile!.name}'),
              backgroundColor: AppColors.textSecondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _isFollowing = !isNowFollowing;
          _followersCount += isNowFollowing ? -1 : 1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    final isSelf = currentUid == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _userProfile?.name ?? 'Student Profile',
          style: AppTextStyles.headingSmall.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildShimmer()
          : _userProfile == null
              ? const Center(child: Text('User profile not found'))
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: Column(
                          children: [
                            // ── Avatar & Info ──
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: _userProfile!.photoUrl.isNotEmpty
                                  ? NetworkImage(_userProfile!.photoUrl)
                                  : null,
                              child: _userProfile!.photoUrl.isEmpty
                                  ? Text(
                                      _userProfile!.name.isNotEmpty
                                          ? _userProfile!.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            Text(
                              _userProfile!.name,
                              style: AppTextStyles.headingMedium.copyWith(fontSize: 22),
                            ),
                            const SizedBox(height: 4),

                            if (_userProfile!.coursePreference.isNotEmpty)
                              Text(
                                '${_userProfile!.coursePreference} · Semester ${_userProfile!.semester}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 16),

                            // ── Follow Button (if not self) ──
                            if (!isSelf)
                              SizedBox(
                                width: 160,
                                height: 40,
                                child: ElevatedButton.icon(
                                  onPressed: _toggleFollow,
                                  icon: Icon(
                                    _isFollowing
                                        ? Icons.check_rounded
                                        : Icons.person_add_rounded,
                                    size: 18,
                                    color: _isFollowing ? AppColors.textPrimary : Colors.white,
                                  ),
                                  label: Text(
                                    _isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isFollowing ? AppColors.textPrimary : Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing
                                        ? const Color(0xFFF3F2FF)
                                        : AppColors.primary,
                                    elevation: _isFollowing ? 0 : 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: _isFollowing
                                          ? const BorderSide(color: AppColors.border)
                                          : BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),

                            // ── Stats Cards ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatCard('${_userNotes.length}', 'Notes'),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowListScreen(
                                          userId: _userProfile!.uid,
                                          initialTab: 0,
                                          userName: _userProfile!.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildStatCard('$_followersCount', 'Followers'),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FollowListScreen(
                                          userId: _userProfile!.uid,
                                          initialTab: 1,
                                          userName: _userProfile!.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildStatCard('$_followingCount', 'Following'),
                                ),
                                _buildStatCard(
                                  '#${_userProfile!.reputationPoints > 0 ? 3 : "-"}',
                                  'Rank',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Tab Bar ──
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(text: 'Uploads'),
                            Tab(text: 'Posts'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUploadsTab(),
                      _buildPostsTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.primary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadsTab() {
    if (_userNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No notes uploaded yet', style: AppTextStyles.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userNotes.length,
      itemBuilder: (context, index) {
        final note = _userNotes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
            ),
            title: Text(note.title, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
            subtitle: Text('${note.subject} · Semester ${note.semester}', style: AppTextStyles.bodySmall),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () {
              if (note.pdfUrl.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PDFViewerScreen(pdfUrl: note.pdfUrl, title: note.title),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No community posts yet', style: AppTextStyles.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.content, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${post.likes}', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${post.commentsCount}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 44),
            const SizedBox(height: 12),
            Container(width: 140, height: 20, color: Colors.white),
            const SizedBox(height: 20),
            Container(width: double.infinity, height: 60, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
