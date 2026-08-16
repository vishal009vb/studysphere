import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../models/comment_model.dart';
import '../../models/report_model.dart';
import '../../services/analytics_service.dart';
import '../../core/widgets/animated_transition.dart';
import '../../core/utils/input_validator.dart';
import '../../core/config/app_config.dart';
import '../notes/pdf_viewer_screen.dart';
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Providers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Tracks locally which posts the current user has liked (optimistic UI).
final _likedPostsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Tracks locally which posts the current user has reposted.
final _repostedPostsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Tracks locally which user IDs the current user is following.
final _followingUsersProvider =
    StateProvider<Set<String>>((ref) => <String>{});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Main CommunityScreen
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostModel> _posts = [];
  List<UserModel> _leaderboard = [];
  bool _isLoading = false;
  
  // Pagination State
  DocumentSnapshot? _lastPostDoc;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  String _leaderboardPeriod = 'allTime';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadMyLikes();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('followers')
          .where('followerId', isEqualTo: user.uid)
          .get();
      final uids = snap.docs
          .map((doc) => doc.data()['followingId'] as String?)
          .whereType<String>()
          .toSet();
      ref.read(_followingUsersProvider.notifier).state = uids;
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePosts) {
      _loadMorePosts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final results = await Future.wait([
        svc.fetchCommunityPosts(),
        svc.fetchLeaderboard(_leaderboardPeriod),
      ]);
      if (mounted) {
        setState(() {
          final postsData = results[0] as Map<String, dynamic>;
          _posts = postsData['posts'] as List<PostModel>;
          _lastPostDoc = postsData['lastDoc'] as DocumentSnapshot?;
          _hasMorePosts = _posts.length == 10;
          _leaderboard = results[1] as List<UserModel>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    setState(() => _isLoadingMore = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final postsData = await svc.fetchCommunityPosts(startAfter: _lastPostDoc);
      final newPosts = postsData['posts'] as List<PostModel>;
      final lastDoc = postsData['lastDoc'] as DocumentSnapshot?;
      
      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _lastPostDoc = lastDoc;
          if (newPosts.length < 10) {
            _hasMorePosts = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load more posts: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Pre-load which posts the user has already liked to set optimistic state.
  Future<void> _loadMyLikes() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('likes')
          .where('userId', isEqualTo: user.uid)
          .where('contentType', isEqualTo: 'post')
          .get();
      final ids = snap.docs.map((d) => d.data()['contentId'] as String).toSet();
      ref.read(_likedPostsProvider.notifier).state = ids;
    } catch (_) {}
  }

  // â”€â”€ Create Post â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        onPosted: () {
          _loadData();
        },
      ),
    );
  }

  // â”€â”€ Like Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _toggleLike(PostModel post) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    HapticFeedback.lightImpact();
    final liked = ref.read(_likedPostsProvider);
    final wasLiked = liked.contains(post.postId);

    // Optimistic update
    final svc = ref.read(firestoreServiceProvider);
    if (wasLiked) {
      ref.read(_likedPostsProvider.notifier).state = Set.from(liked)
        ..remove(post.postId);
      _patchPostLikes(post.postId, -1);
      await svc.unlikeContent(user.uid, post.postId, 'post');
    } else {
      ref.read(_likedPostsProvider.notifier).state = Set.from(liked)
        ..add(post.postId);
      _patchPostLikes(post.postId, 1);
      await svc.likeContent(user.uid, post.postId, 'post');
      ref.read(analyticsServiceProvider).logCommunityLike(post.postId, 'post');
    }
  }

  void _patchPostLikes(String postId, int delta) {
    setState(() {
      _posts = _posts.map((p) {
        if (p.postId == postId) {
          return PostModel(
            postId: p.postId,
            authorId: p.authorId,
            authorName: p.authorName,
            authorPhotoUrl: p.authorPhotoUrl,
            content: p.content,
            attachedType: p.attachedType,
            attachedId: p.attachedId,
            attachedUrl: p.attachedUrl,           // ✅ Fix: photo/file URL preserve करा
            attachedFileName: p.attachedFileName, // ✅ Fix: question paper name preserve करा
            attachedFileSize: p.attachedFileSize, // ✅ Fix: file size preserve करा
            likes: p.likes + delta,
            commentsCount: p.commentsCount,
            reposts: p.reposts,
            shares: p.shares,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
    });
  }

  // â”€â”€ Repost â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _toggleRepost(PostModel post) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final reposted = ref.read(_repostedPostsProvider);
    final wasReposted = reposted.contains(post.postId);

    if (!wasReposted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Repost Content?'),
          content: const Text('Do you want to share this post to your feed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Repost'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    HapticFeedback.mediumImpact();

    if (wasReposted) {
      ref.read(_repostedPostsProvider.notifier).state = Set.from(reposted)
        ..remove(post.postId);
    } else {
      ref.read(_repostedPostsProvider.notifier).state = Set.from(reposted)
        ..add(post.postId);
      // Create a repost record in Firestore
      await FirebaseFirestore.instance
          .collection('reposts')
          .doc('${user.uid}_${post.postId}')
          .set({
        'userId': user.uid,
        'postId': post.postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId)
          .update({'reposts': FieldValue.increment(1)});
      _patchPostReposts(post.postId, 1);
      await ref
          .read(firestoreServiceProvider)
          .addReputationPoints(post.authorId, 2);
    }
  }

  void _patchPostReposts(String postId, int delta) {
    setState(() {
      _posts = _posts.map((p) {
        if (p.postId == postId) {
          return PostModel(
            postId: p.postId,
            authorId: p.authorId,
            authorName: p.authorName,
            authorPhotoUrl: p.authorPhotoUrl,
            content: p.content,
            attachedType: p.attachedType,
            attachedId: p.attachedId,
            likes: p.likes,
            commentsCount: p.commentsCount,
            reposts: p.reposts + delta,
            shares: p.shares,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
    });
  }

  // â”€â”€ Follow / Unfollow â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _toggleFollowUser(String targetUid, String name) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.uid == targetUid) return;

    final following = ref.read(_followingUsersProvider);
    final isFollowing = following.contains(targetUid);

    HapticFeedback.mediumImpact();

    // Optimistic UI state update
    if (isFollowing) {
      ref.read(_followingUsersProvider.notifier).state =
          Set.from(following)..remove(targetUid);
    } else {
      ref.read(_followingUsersProvider.notifier).state =
          Set.from(following)..add(targetUid);
    }

    try {
      if (isFollowing) {
        await ref.read(firestoreServiceProvider).unfollowUser(user.uid, targetUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Unfollowed $name'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        await ref.read(firestoreServiceProvider).followUser(user.uid, targetUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Following $name âœ¨'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      // Rollback on error
      ref.read(_followingUsersProvider.notifier).state = following;
    }
  }

  void _openUserProfile(String authorId) {
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == authorId) {
      context.push('/profile');
    } else {
      context.push('/user-profile/$authorId');
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 140, 
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community',
                            style: AppTextStyles.headingLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Text(
                                'Learn together. Grow together.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                left: 0,
                                child: Container(
                                  height: 2,
                                  width: 16,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Search coming soon!'), behavior: SnackBarBehavior.floating),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notifications coming soon!'), behavior: SnackBarBehavior.floating),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                                ),
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '3',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ), 
                ), 
              ), 
            ), 
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    dividerColor: Colors.transparent,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.article_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Study Feed'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.people_outline_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Following'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emoji_events_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Leaderboard'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFeedTab(),
            _buildFollowingFeedTab(),
            _buildLeaderboardTab(),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A4BFF), Color(0xFF6B2BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B2BFF).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          label: const Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // â”€â”€ Stories Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStoriesRow() {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Create Post
          GestureDetector(
            onTap: _showCreatePostSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 6),
                  const Text('Create Post', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Ask Doubts
          GestureDetector(
            onTap: _showCreatePostSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                          color: const Color(0xFF1E1E2C),
                        ),
                        child: const Center(
                          child: Text('?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Ask Doubts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // User 1
          _buildStoryUser('Rohit P.', 'R'),
          // User 2
          _buildStoryUser('Anjali S.', 'A'),
          // User 3
          _buildStoryUser('Vishal M.', 'V'),
          // More
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz, color: Colors.black54, size: 24),
                ),
                const SizedBox(height: 6),
                const Text('More', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryUser(String name, String initial) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // â”€â”€ Feed Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildFeedTab() {
    if (_isLoading) return _buildFeedSkeleton();
    
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        itemCount: _posts.isEmpty ? 2 : (_posts.length + (_isLoadingMore ? 1 : 0) + 1),
        itemBuilder: (context, index) {
          // Stories Row at the very top
          if (index == 0) return _buildStoriesRow();

          // Empty state placeholder
          if (_posts.isEmpty && index == 1) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(Icons.forum_rounded, size: 52, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('No posts yet!', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 8),
                    Text('Be the first to share a study tip or resource.', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final postIndex = index - 1;

          if (postIndex == _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          
          return AnimatedTransition.slideUp(
            _PostCard(
              post: _posts[postIndex],
              onLike: () => _toggleLike(_posts[postIndex]),
              onRepost: () => _toggleRepost(_posts[postIndex]),
              onFollow: () =>
                  _toggleFollowUser(_posts[postIndex].authorId, _posts[postIndex].authorName),
              onCommentTap: () => _showCommentsSheet(_posts[postIndex]),
              onReport: () => _showReportDialog(_posts[postIndex]),
              onDelete: () => _deletePost(_posts[postIndex].postId),
              onAuthorTap: () => _openUserProfile(_posts[postIndex].authorId),
            ),
            delay: Duration(milliseconds: 50 * postIndex.clamp(0, 5)),
          );
        },
      ),
    );
  }

  // â”€â”€ Following Feed Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildFollowingFeedTab() {
    final followingUids = ref.watch(_followingUsersProvider);
    final followingPosts =
        _posts.where((p) => followingUids.contains(p.authorId)).toList();

    if (_isLoading) return _buildFeedSkeleton();

    if (followingPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_outline_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text('No posts from followed students',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 8),
              Text(
                'Follow active students in the Study Feed or Leaderboard to see their posts & updates here!',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.explore_rounded,
                    size: 18, color: Colors.white),
                label: const Text('Explore Study Feed',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: followingPosts.length,
        itemBuilder: (context, index) {
          final post = followingPosts[index];
          return AnimatedTransition.slideUp(
            _PostCard(
              post: post,
              onLike: () => _toggleLike(post),
              onRepost: () => _toggleRepost(post),
              onFollow: () => _toggleFollowUser(post.authorId, post.authorName),
              onCommentTap: () => _showCommentsSheet(post),
              onReport: () => _showReportDialog(post),
              onDelete: () => _deletePost(post.postId),
              onAuthorTap: () => _openUserProfile(post.authorId),
            ),
            delay: Duration(milliseconds: 50 * index.clamp(0, 5)),
          );
        },
      ),
    );
  }

  // â”€â”€ Comments Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showCommentsSheet(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(post: post),
    );
  }

  // â”€â”€ Report Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showReportDialog(PostModel post) {
    String selectedReason = 'Spam';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDs) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.flag_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Report Post'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[
                'Spam',
                'Hate Speech',
                'Misinformation',
                'Copyright Issue',
                'Other'
              ].map((r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selectedReason,
                    activeColor: AppColors.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDs(() => selectedReason = v!),
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final user = ref.read(authServiceProvider).currentUser;
                if (user == null) return;

                // [H-10] Client-side report rate guard
                if (!InputValidator.checkClientRateLimit(
                  'report_${user.uid}',
                  AppConfig.clientReportPerMinute,
                )) {
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporting too quickly. Please wait a moment.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(firestoreServiceProvider).createReport(
                      ReportModel(
                        reportId:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        contentId: post.postId,
                        contentType: 'post',
                        reason: InputValidator.sanitizeSingleLine(selectedReason),
                        reportedBy: user.uid,
                        createdAt: DateTime.now(),
                      ),
                    );
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Report submitted.')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Delete Post â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.postId == postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // â”€â”€ Leaderboard Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        // Period Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in [
                  ('daily', 'Today'),
                  ('weekly', 'This Week'),
                  ('monthly', 'This Month'),
                  ('allTime', 'All Time'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(period.$2),
                      selected: _leaderboardPeriod == period.$1,
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _leaderboardPeriod == period.$1
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: _leaderboardPeriod == period.$1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _leaderboardPeriod == period.$1
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) async {
                        setState(() => _leaderboardPeriod = period.$1);
                        final lb = await ref
                            .read(firestoreServiceProvider)
                            .fetchLeaderboard(period.$1);
                        setState(() => _leaderboard = lb);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Top 3 podium
        if (_leaderboard.length >= 3) _buildPodium(),

        // Rest of the list
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: SkeletonLoader(width: double.infinity, height: 80),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount:
                      _leaderboard.length > 3 ? _leaderboard.length - 3 : 0,
                  itemBuilder: (context, index) {
                    final rank = index + 4;
                    final user = _leaderboard[index + 3];
                    return AnimatedTransition.slideUp(
                      _buildLeaderboardRow(user, rank),
                      delay: Duration(milliseconds: 50 * index.clamp(0, 5)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPodium() {
    final top = _leaderboard.take(3).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 2nd Place
          _buildPodiumSlot(top[1], 2, 100),
          // 1st Place
          _buildPodiumSlot(top[0], 1, 130),
          // 3rd Place
          _buildPodiumSlot(top[2], 3, 80),
        ],
      ),
    );
  }

  Widget _buildPodiumSlot(UserModel user, int rank, double height) {
    // Use Icons instead of emoji to avoid encoding issues on web
    final medalIcon = rank == 1
        ? Icons.emoji_events_rounded       // 🏆 trophy
        : rank == 2
            ? Icons.workspace_premium_rounded // silver
            : Icons.military_tech_rounded;    // bronze
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)  // Gold
        : rank == 2
            ? const Color(0xFFC0C0C0)  // Silver
            : const Color(0xFFCD7F32); // Bronze
    return GestureDetector(
      onTap: () => _openUserProfile(user.uid),
      child: Column(
        children: [
          Icon(medalIcon, color: medalColor, size: 32),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: rank == 1 ? 30 : 22,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: user.photoUrl.isNotEmpty
                ? NetworkImage(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: rank == 1 ? 22 : 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            user.name.split(' ').first,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            '${user.reputationPoints} pts',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Container(
            width: 60,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(UserModel user, int rank) {
    return GestureDetector(
      onTap: () => _openUserProfile(user.uid),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 250 + rank * 40),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)), child: child),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9), // Translucent glass
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: AppTextStyles.headingSmall
                            .copyWith(fontSize: 14)),
                    Text(
                      user.contributorRank,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.reputationPoints}',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.primary, fontSize: 16),
                  ),
                  Text('pts',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _PostCard â€” individual post widget
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onFollow;
  final VoidCallback onCommentTap;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback onAuthorTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onRepost,
    required this.onFollow,
    required this.onCommentTap,
    required this.onReport,
    required this.onDelete,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedPosts = ref.watch(_likedPostsProvider);
    final repostedPosts = ref.watch(_repostedPostsProvider);
    final isLiked = likedPosts.contains(post.postId);
    final isReposted = repostedPosts.contains(post.postId);
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    final isFollowing = ref.watch(_followingUsersProvider).contains(post.authorId);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Author Row â”€â”€
            Row(
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        const Color(0xff7c3aed).withValues(alpha: 0.12),
                    backgroundImage: post.authorPhotoUrl.isNotEmpty
                        ? NetworkImage(post.authorPhotoUrl)
                        : null,
                    child: post.authorPhotoUrl.isEmpty
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xff7c3aed),
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              post.authorName,
                              style: AppTextStyles.headingSmall
                                  .copyWith(fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.primary, size: 10),
                                  const SizedBox(width: 2),
                                  const Text('Top Contributor', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_timeAgo(post.createdAt)} \u2022 BCA Student',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onFollow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFollowing
                          ? const Color(0xFFF3F2FF)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      border: isFollowing
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                          size: 12,
                          color: isFollowing ? AppColors.primary : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing ? AppColors.primary : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      onDelete();
                    } else if (value == 'report') {
                      onReport();
                    } else if (value == 'save') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post saved to bookmarks')));
                    } else if (value == 'copy') {
                      Clipboard.setData(ClipboardData(text: 'https://studysphere-app-3a480.web.app/post/${post.postId}'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                    } else if (value == 'block') {
                      if (currentUid != null) {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref.read(firestoreServiceProvider).blockUser(currentUid, post.authorId);
                        messenger.showSnackBar(const SnackBar(content: Text('User blocked')));
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.bookmark_border, size: 18), SizedBox(width: 8), Text('Save Post')])),
                    const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.link, size: 18), SizedBox(width: 8), Text('Copy Link')])),
                    if (currentUid == post.authorId)
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Delete Post', style: TextStyle(color: AppColors.error))])),
                    if (currentUid != post.authorId)
                      const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, size: 18), SizedBox(width: 8), Text('Block User')])),
                    if (currentUid != post.authorId)
                      const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Report Post', style: TextStyle(color: AppColors.error))])),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // â”€â”€ Post Content â”€â”€
            Text(post.content, style: AppTextStyles.bodyLarge),

            // â”€â”€ Attachment: Image â”€â”€
            if (post.attachedType == 'image' && post.attachedUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  post.attachedUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),

            // â”€â”€ Attachment: PDF â”€â”€
            ] else if (post.attachedType == 'pdf' && post.attachedUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PDFViewerScreen(
                        pdfUrl: post.attachedUrl!,
                        title: post.attachedFileName ?? 'Community PDF',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFBBAA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.attachedFileName ?? 'PDF Document',
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (post.attachedFileSize != null)
                              Text(
                                () {
                                  final kb = post.attachedFileSize! / 1024;
                                  return kb >= 1024
                                      ? '${(kb / 1024).toStringAsFixed(1)} MB'
                                      : '${kb.toStringAsFixed(0)} KB';
                                }(),
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              )
                            else
                              Text('Tap to open',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

            // â”€â”€ Attachment: Link â”€â”€
            ] else if (post.attachedType == 'link' && post.attachedUrl != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD0B8FF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE0FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.link_rounded, color: Color(0xff7c3aed), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Uri.tryParse(post.attachedUrl!)?.host ?? post.attachedUrl!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff7c3aed),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            post.attachedUrl!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, color: Color(0xff7c3aed), size: 18),
                  ],
                ),
              ),

            // â”€â”€ Attachment: Other (note, pyq, resource) â”€â”€
            ] else if (post.attachedType != 'text' &&
                post.attachedType != 'none' &&
                post.attachedType != 'link') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (post.attachedUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PDFViewerScreen(
                          pdfUrl: post.attachedUrl!,
                          title: 'Community PDF',
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          post.attachedType == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.attach_file_rounded,
                          size: 14,
                          color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        post.attachedType == 'note'
                            ? 'Attached: Study Note'
                            : post.attachedType == 'pdf'
                                ? 'Attached: PDF Document'
                                : 'Attached: Question Paper',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // â”€â”€ Action Row â”€â”€
            Row(
              children: [
                // Like
                _ActionBtn(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes}',
                  color: isLiked ? const Color(0xFFE91E8C) : AppColors.textSecondary,
                  onTap: onLike,
                ),
                const SizedBox(width: 4),
                // Comment
                _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentsCount}',
                  color: AppColors.textSecondary,
                  onTap: onCommentTap,
                ),
                const SizedBox(width: 4),
                // Repost
                _ActionBtn(
                  icon: Icons.repeat_rounded,
                  label: '${post.reposts}',
                  color: isReposted
                      ? AppColors.success
                      : AppColors.textSecondary,
                  onTap: onRepost,
                ),
                const Spacer(),
                // Bookmark
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Post saved to bookmarks!'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: const Icon(Icons.bookmark_border_rounded,
                      size: 22, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                // Share
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Share feature coming soon!'),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: const Icon(Icons.share_outlined,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    // Use UTC comparison to avoid timezone issues with server timestamps
    final now = DateTime.now().toUtc();
    final utcDt = dt.toUtc();
    final diff = now.difference(utcDt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _ActionBtn â€” icon + label button
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, key: ValueKey(icon), color: color, size: 20),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _CreatePostSheet â€” bottom sheet to create a new post
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CreatePostSheet extends ConsumerStatefulWidget {
  final VoidCallback onPosted;
  const _CreatePostSheet({required this.onPosted});

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

/// Attachment types supported in create post
enum _AttachType { image, pdf, link }

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _controller = TextEditingController();
  bool _isPosting = false;
  double? _uploadProgress; // null = not uploading
  int _charCount = 0;
  static const int _maxChars = 500;

  // Attachment state â€” only ONE at a time
  Uint8List? _selectedFileData;     // bytes (web-safe)
  String? _selectedFileName;
  int? _selectedFileBytes;
  _AttachType? _attachType;
  String? _attachedLink; // for Link type

  // Tag selection
  String? _selectedTag;
  static const _tags = ['Study Tip', 'Exam Update', 'Resource', 'Motivation'];

  // 10 MB max
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty ||
      _selectedFileData != null ||
      _attachedLink != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // â”€â”€ Clear attachment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _clearAttachment() {
    setState(() {
      _selectedFileData = null;
      _selectedFileName = null;
      _selectedFileBytes = null;
      _attachType = null;
      _attachedLink = null;
    });
  }

  // ————————————————————————————————————————————————————————————————————————————————

  Future<void> _pickImage() async {
    if (_isPosting) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,   // ← required on Web to get bytes
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) _showError('Could not read the image. Please try another file.');
        return;
      }
      if (bytes.length > _maxFileSizeBytes) {
        if (mounted) _showError('Image is too large. Please select a file under 10 MB.');
        return;
      }
      setState(() {
        _selectedFileData = bytes;
        _selectedFileName = picked.name;
        _selectedFileBytes = bytes.length;
        _attachType = _AttachType.image;
        _attachedLink = null;
      });
    } catch (e) {
      if (mounted) _showError('Could not open image picker. Please try again.');
    }
  }

  // â”€â”€ Pick PDF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickPdf() async {
    if (_isPosting) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,   // ← required on Web to get bytes
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) _showError('Could not read the PDF. Please try another file.');
        return;
      }
      if (bytes.length > _maxFileSizeBytes) {
        if (mounted) _showError('PDF is too large. Please select a file under 10 MB.');
        return;
      }
      setState(() {
        _selectedFileData = bytes;
        _selectedFileName = picked.name;
        _selectedFileBytes = bytes.length;
        _attachType = _AttachType.pdf;
        _attachedLink = null;
      });
    } catch (e) {
      if (mounted) _showError('Could not open file picker. Please try again.');
    }
  }

  // â”€â”€ Add Link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showLinkDialog() async {
    if (_isPosting) return;
    final linkCtrl = TextEditingController(text: _attachedLink ?? '');
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.link_rounded, color: Color(0xff7c3aed)),
            SizedBox(width: 8),
            Text('Add Link'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: linkCtrl,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://example.com',
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff7c3aed),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final url = linkCtrl.text.trim();
                final uri = Uri.tryParse(url);
                if (url.isEmpty || uri == null || !uri.hasScheme) {
                  setDs(() => error = 'Please enter a valid URL (e.g. https://...)');
                  return;
                }
                setState(() {
                  _attachedLink = url;
                  _attachType = _AttachType.link;
                  _selectedFileData = null;
                  _selectedFileName = null;
                  _selectedFileBytes = null;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Link',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    linkCtrl.dispose();
  }

  // â”€â”€ Error helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // â”€â”€ Draft protection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<bool> _onWillPop() async {
    if (!_hasDraft) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Post?'),
        content: const Text(
            'You have unsaved content. Are you sure you want to discard it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // â”€â”€ Submit Post â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _submitPost() async {
    // ✅ Prevent double-tap / double submit
    if (_isPosting) return;

    final text = _controller.text.trim();
    final hasText = text.isNotEmpty;
    final hasAttachment = _selectedFileData != null || _attachedLink != null;

    if (!hasText && !hasAttachment) {
      _showError('Please write something or add an attachment before posting.');
      return;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _showError('You must be signed in to post.');
      return;
    }

    // Client-side rate guard
    if (!InputValidator.checkClientRateLimit(
      'post_${user.uid}',
      AppConfig.clientPostPerMinute,
    )) {
      _showError('You\'re posting too quickly. Please wait a moment before posting again.');
      return;
    }

    // Input validation
    if (hasText) {
      final validation = InputValidator.validatePostContent(text);
      if (!validation.isValid) {
        _showError(validation.error!);
        return;
      }
    }

    setState(() {
      _isPosting = true;
      _uploadProgress = null;
    });

    try {
      final svc = ref.read(firestoreServiceProvider);
      final profile = await svc.getUserProfile(user.uid);


      String? attachedUrl;
      String resolvedType = 'text';

      if (_attachType == _AttachType.link && _attachedLink != null) {
        attachedUrl = _attachedLink;
        resolvedType = 'link';
      } else if (_selectedFileData != null && _attachType != null && _selectedFileName != null) {
        final storageSvc = ref.read(storageServiceProvider);
        setState(() => _uploadProgress = 0.1);

        if (_attachType == _AttachType.pdf) {
          attachedUrl = await storageSvc.uploadPdfBytes(
            _selectedFileData!,
            _selectedFileName!,
            user.uid,
          );
          resolvedType = 'pdf';
        } else {
          attachedUrl = await storageSvc.uploadImageBytes(
            _selectedFileData!,
            _selectedFileName!,
            user.uid,
          );
          resolvedType = 'image';
        }
        setState(() => _uploadProgress = 0.9);
      }

      // Build final content â€” append selected tag if any
      String finalContent = InputValidator.sanitizeForDisplay(text);
      if (_selectedTag != null && finalContent.isNotEmpty) {
        finalContent = '$finalContent\n\n#${_selectedTag!.replaceAll(' ', '')}';
      } else if (_selectedTag != null) {
        finalContent = '#${_selectedTag!.replaceAll(' ', '')}';
      }

      final post = PostModel(
        postId: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: user.uid,
        authorName: profile.name.isNotEmpty
            ? profile.name
            : (user.displayName ?? 'Student'),
        authorPhotoUrl: profile.photoUrl.isNotEmpty
            ? profile.photoUrl
            : (user.photoURL ?? ''),
        content: finalContent,
        attachedType: resolvedType,
        attachedUrl: attachedUrl,
        attachedFileName: _selectedFileName,
        attachedFileSize: _selectedFileBytes,
        createdAt: DateTime.now(),
      );

      await svc.createPost(post);
      // Reputation update is best-effort — silently ignore if rules block it
      try {
        await svc.addReputationPoints(user.uid, 5);
      } catch (_) {}
      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ref.read(analyticsServiceProvider).logCommunityPost(post.postId);
        Navigator.pop(context);
        widget.onPosted();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Post shared with the community!')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final msg = errStr.toLowerCase().contains('socket') ||
                errStr.toLowerCase().contains('network') ||
                errStr.toLowerCase().contains('connection')
            ? 'No internet connection. Please check your network and try again.'
            : errStr.contains('size')
                ? 'File is too large. Please select a smaller file.'
                : errStr.contains('permission') || errStr.contains('Permission') || errStr.contains('PERMISSION_DENIED')
                    ? 'You do not have permission to post. Please try again or contact support.'
                    : errStr.contains('PdfScanException') || errStr.contains('UploadRateLimit')
                        ? errStr
                        : 'Something went wrong. Please try again.';
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() { _isPosting = false; _uploadProgress = null; });
    }
  }

  // â”€â”€ Attachment Preview Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAttachmentPreview() {
    if (_attachType == _AttachType.image && _selectedFileData != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _selectedFileData!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _clearAttachment,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_attachType == _AttachType.pdf && _selectedFileData != null) {
      final sizeKb = (_selectedFileBytes ?? 0) / 1024;
      final sizeStr = sizeKb >= 1024
          ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
          : '${sizeKb.toStringAsFixed(0)} KB';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFBBAA)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFileName ?? 'Document',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(sizeStr,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textSecondary,
              onPressed: _clearAttachment,
            ),
          ],
        ),
      );
    }

    if (_attachType == _AttachType.link && _attachedLink != null) {
      final uri = Uri.tryParse(_attachedLink!);
      final domain = uri?.host ?? _attachedLink!;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD0B8FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded, color: Color(0xff7c3aed), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600, color: const Color(0xff7c3aed)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _attachedLink!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textSecondary,
              onPressed: _clearAttachment,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // â”€â”€ Attachment Icon Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _attachIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: _isPosting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff7c3aed).withOpacity(0.12)
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? const Color(0xff7c3aed).withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: active ? const Color(0xff7c3aed) : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: active ? const Color(0xff7c3aed) : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_hasDraft,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // â”€â”€ Handle + Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A4BFF), Color(0xFF6B2BFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('New Post', style: AppTextStyles.headingMedium),
                              Text(
                                'Share knowledge. Help others. Inspire growth.',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final shouldPop = _hasDraft ? await _onWillPop() : true;
                            if (shouldPop && mounted) Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // â”€â”€ Scrollable body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEDE0FF),
                              const Color(0xFFD6BCFA).withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What would you like to share?',
                              style: AppTextStyles.headingSmall
                                  .copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share a study tip, exam update, resource link, or motivation with the community.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            // Tag chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tags.map((tag) {
                                final isSelected = _selectedTag == tag;
                                return GestureDetector(
                                  onTap: () => setState(() =>
                                      _selectedTag = isSelected ? null : tag),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xff7c3aed)
                                          : Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xff7c3aed)
                                            : Colors.white,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _tagIcon(tag),
                                          size: 13,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xff7c3aed),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xff7c3aed),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Text Field
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBFAFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E0FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded,
                                color: Color(0xff7c3aed), size: 20),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _controller,
                              maxLines: 5,
                              minLines: 4,
                              maxLength: _maxChars,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'Write something valuable...',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary),
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) =>
                                  setState(() => _charCount = val.length),
                              style: AppTextStyles.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$_charCount / $_maxChars',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: _charCount > _maxChars * 0.9
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Attachment preview
                      _buildAttachmentPreview(),

                      // Upload progress
                      if (_uploadProgress != null && _isPosting) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: const Color(0xFFEDE0FF),
                            valueColor: const AlwaysStoppedAnimation(Color(0xff7c3aed)),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Uploading... ${((_uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),

              // â”€â”€ Action Bar (always visible above keyboard) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Container(
                padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    // Image
                    _attachIconBtn(
                      icon: Icons.image_rounded,
                      label: 'Image',
                      active: _attachType == _AttachType.image,
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: 8),
                    // PDF
                    _attachIconBtn(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      active: _attachType == _AttachType.pdf,
                      onTap: _pickPdf,
                    ),
                    const SizedBox(width: 8),
                    // Link
                    _attachIconBtn(
                      icon: Icons.link_rounded,
                      label: 'Link',
                      active: _attachType == _AttachType.link,
                      onTap: _showLinkDialog,
                    ),
                    const Spacer(),
                    // Post button
                    GestureDetector(
                      onTap: _isPosting ? null : _submitPost,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: _isPosting
                              ? const LinearGradient(
                                  colors: [Color(0xFFAA88EE), Color(0xFF9966DD)],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF8A4BFF), Color(0xFF6B2BFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _isPosting
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF6B2BFF).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isPosting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _isPosting ? 'Posting...' : 'Post',
                              style: AppTextStyles.button,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'Study Tip':
        return Icons.lightbulb_outline_rounded;
      case 'Exam Update':
        return Icons.edit_note_rounded;
      case 'Resource':
        return Icons.link_rounded;
      case 'Motivation':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// _CommentsSheet â€” inline comments for a post
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CommentsSheet extends ConsumerStatefulWidget {
  final PostModel post;
  const _CommentsSheet({required this.post});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _commentCtrl = TextEditingController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      // parentId + limit applied server-side; replies were previously fetched
      // (and billed) only to be discarded in Dart.
      final snap = await FirebaseFirestore.instance
          .collection('comments')
          .where('contentId', isEqualTo: widget.post.postId)
          .where('parentId', isNull: true)
          .orderBy('createdAt', descending: false)
          .limit(50)
          .get();
      final all = snap.docs
          .map((d) => CommentModel.fromMap(d.data(), d.id))
          .toList();
      if (mounted) {
        setState(() {
        _comments = all;
        _isLoading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      // [H-09] Client-side comment rate guard
      if (!InputValidator.checkClientRateLimit(
        'comment_${user.uid}',
        AppConfig.clientCommentPerMinute,
      )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commenting too quickly. Please wait a moment.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (mounted) setState(() => _isSending = false);
        return;
      }

      // [H-11] Input validation
      final commentValidation = InputValidator.validateComment(text);
      if (!commentValidation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(commentValidation.error!), backgroundColor: AppColors.error),
          );
        }
        if (mounted) setState(() => _isSending = false);
        return;
      }

      final comment = CommentModel(
        commentId: DateTime.now().millisecondsSinceEpoch.toString(),
        contentId: widget.post.postId,
        authorId: user.uid,
        authorName: user.displayName ?? 'Student',
        authorPhotoUrl: user.photoURL ?? '',
        // Sanitize comment text before writing to Firestore
        text: InputValidator.sanitizeForDisplay(text),
        createdAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).addComment(comment);
      ref.read(analyticsServiceProvider).logCommunityComment(widget.post.postId);
      _commentCtrl.clear();
      setState(() => _comments = [..._comments, comment]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to post comment. Please try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Comments', style: AppTextStyles.headingSmall),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xff7c3aed).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xff7c3aed),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text('No comments yet.',
                              style: AppTextStyles.bodyMedium),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (_, i) =>
                              _buildCommentTile(_comments[i]),
                        ),
            ),

            // Input bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? AppColors.border
                            : const Color(0xff7c3aed),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor:
                const Color(0xff7c3aed).withValues(alpha: 0.1),
            backgroundImage: c.authorPhotoUrl.isNotEmpty
                ? NetworkImage(c.authorPhotoUrl)
                : null,
            child: c.authorPhotoUrl.isEmpty
                ? Text(
                    c.authorName.isNotEmpty
                        ? c.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xff7c3aed),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.authorName,
                        style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff7c3aed)),
                      ),
                      const SizedBox(height: 3),
                      Text(c.text, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(c.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
