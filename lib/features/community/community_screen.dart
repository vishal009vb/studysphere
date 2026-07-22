import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
// ────────────────────────────────────────────────────────────────────────────
// Providers
// ────────────────────────────────────────────────────────────────────────────

/// Tracks locally which posts the current user has liked (optimistic UI).
final _likedPostsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Tracks locally which posts the current user has reposted.
final _repostedPostsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

// ────────────────────────────────────────────────────────────────────────────
// Main CommunityScreen
// ────────────────────────────────────────────────────────────────────────────

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
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadMyLikes();
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

  // ── Create Post ──────────────────────────────────────────────────────────

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

  // ── Like Toggle ──────────────────────────────────────────────────────────

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

  // ── Repost ───────────────────────────────────────────────────────────────

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

  // ── Follow ───────────────────────────────────────────────────────────────

  Future<void> _followUser(String targetUid, String name) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.uid == targetUid) return;
    await ref.read(firestoreServiceProvider).followUser(user.uid, targetUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Following $name ✨'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 130, // Increased to avoid overflow
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10), // Removed hardcoded 50 top padding
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Community',
                      style: AppTextStyles.headingLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    ),
                  ],
                ), // Closes Row
              ), // Closes Container
            ), // Closes SafeArea
          ), // Closes FlexibleSpaceBar
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Study Feed'),
                      Tab(text: 'Leaderboard'),
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
            _buildLeaderboardTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostSheet,
        backgroundColor: const Color(0xff7c3aed),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('New Post'),
        elevation: 4,
      ),
    );
  }

  // ── Feed Tab ──────────────────────────────────────────────────────────────

  Widget _buildFeedTab() {
    if (_isLoading) return _buildFeedSkeleton();
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xff7c3aed).withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.forum_rounded,
                  size: 52, color: Color(0xff7c3aed)),
            ),
            const SizedBox(height: 20),
            Text('No posts yet!', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text('Be the first to share a study tip or resource.',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xff7c3aed),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xff7c3aed)),
              ),
            );
          }
          
          return AnimatedTransition.slideUp(
            _PostCard(
              post: _posts[index],
              onLike: () => _toggleLike(_posts[index]),
              onRepost: () => _toggleRepost(_posts[index]),
              onFollow: () =>
                  _followUser(_posts[index].authorId, _posts[index].authorName),
              onCommentTap: () => _showCommentsSheet(_posts[index]),
              onReport: () => _showReportDialog(_posts[index]),
              onDelete: () => _deletePost(_posts[index].postId),
            ),
            delay: Duration(milliseconds: 50 * index.clamp(0, 5)),
          );
        },
      ),
    );
  }

  // ── Comments Sheet ────────────────────────────────────────────────────────

  void _showCommentsSheet(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(post: post),
    );
  }

  // ── Report Dialog ─────────────────────────────────────────────────────────

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
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted.')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete Post ───────────────────────────────────────────────────────────

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

  // ── Leaderboard Tab ───────────────────────────────────────────────────────

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
                          AppColors.primary.withOpacity(0.15),
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
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
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
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Column(
      children: [
        Text(medals[rank]!, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: rank == 1 ? 30 : 22,
          backgroundColor: Colors.white.withOpacity(0.2),
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
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
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
    );
  }

  Widget _buildLeaderboardRow(UserModel user, int rank) {
    return TweenAnimationBuilder<double>(
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
          color: Colors.white.withOpacity(0.9), // Translucent glass
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
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
              backgroundColor: AppColors.primary.withOpacity(0.1),
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

// ────────────────────────────────────────────────────────────────────────────
// _PostCard — individual post widget
// ────────────────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onRepost;
  final VoidCallback onFollow;
  final VoidCallback onCommentTap;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onRepost,
    required this.onFollow,
    required this.onCommentTap,
    required this.onReport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedPosts = ref.watch(_likedPostsProvider);
    final repostedPosts = ref.watch(_repostedPostsProvider);
    final isLiked = likedPosts.contains(post.postId);
    final isReposted = repostedPosts.contains(post.postId);
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;

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
            // ── Author Row ──
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      const Color(0xff7c3aed).withOpacity(0.12),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: AppTextStyles.headingSmall
                            .copyWith(fontSize: 14),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (currentUid != post.authorId)
                  GestureDetector(
                    onTap: onFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
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
                      Clipboard.setData(ClipboardData(text: 'https://studysphere.app/post/${post.postId}'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                    } else if (value == 'block') {
                      if (currentUid != null) {
                        await ref.read(firestoreServiceProvider).blockUser(currentUid, post.authorId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
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

            // ── Post Content ──
            Text(post.content, style: AppTextStyles.bodyLarge),

            // ── Attachment Badge / Image ──
            if (post.attachedType == 'image' && post.attachedUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.attachedUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (post.attachedType != 'text' && post.attachedType != 'none') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (post.attachedType == 'pdf' && post.attachedUrl != null) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        post.attachedType == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.attach_file_rounded,
                        size: 14, color: AppColors.primary),
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

            // ── Action Row ──
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
                  icon: Icons.mode_comment_outlined,
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
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _ActionBtn — icon + label button
// ────────────────────────────────────────────────────────────────────────────

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

// ────────────────────────────────────────────────────────────────────────────
// _CreatePostSheet — bottom sheet to create a new post
// ────────────────────────────────────────────────────────────────────────────

class _CreatePostSheet extends ConsumerStatefulWidget {
  final VoidCallback onPosted;
  const _CreatePostSheet({required this.onPosted});

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _controller = TextEditingController();
  bool _isPosting = false;
  int _charCount = 0;
  static const int _maxChars = 500;
  File? _selectedFile;
  String? _attachedType;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final ext = path.split('.').last.toLowerCase();
        setState(() {
          _selectedFile = File(path);
          _attachedType = (ext == 'pdf') ? 'pdf' : 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _submitPost() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    // [H-09] Client-side post rate guard
    if (!InputValidator.checkClientRateLimit(
      'post_${user.uid}',
      AppConfig.clientPostPerMinute,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Posting too quickly. Please wait before posting again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // [H-11] Input validation
    if (text.isNotEmpty) {
      final validation = InputValidator.validatePostContent(text);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validation.error!), backgroundColor: AppColors.error),
          );
        }
        return;
      }
    }

    setState(() => _isPosting = true);
    try {
      final svc = ref.read(firestoreServiceProvider);

      // Role check
      final profile = await svc.getUserProfile(user.uid);
      if (profile.role == 'learner') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '🔒 Become a Contributor to post in the community feed.'),
            backgroundColor: AppColors.warning,
          ));
        }
        return;
      }

      String? attachedUrl;
      if (_selectedFile != null && _attachedType != null) {
        final storageSvc = ref.read(storageServiceProvider);
        if (_attachedType == 'pdf') {
          // Use secure pipeline: pre-flight + server scan + Cloudinary
          final (url, _) = await storageSvc.uploadPdfSecure(_selectedFile!, user.uid);
          attachedUrl = url;
        } else {
          attachedUrl = await storageSvc.uploadImage(_selectedFile!, user.uid);
        }
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
        // Sanitize content before writing to Firestore
        content: InputValidator.sanitizeForDisplay(text),
        attachedType: _attachedType ?? 'text',
        attachedUrl: attachedUrl,
        createdAt: DateTime.now(),
      );

      await svc.createPost(post);
      // Award 5 rep points for a post
      await svc.addReputationPoints(user.uid, 5);

      if (mounted) {
        ref.read(analyticsServiceProvider).logCommunityPost(post.postId);
        Navigator.pop(context);
        widget.onPosted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text('New Post', style: AppTextStyles.headingMedium),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Text input
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  maxLength: _maxChars,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText:
                        'Share a study tip, exam update, resource link, or motivation...',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (val) =>
                      setState(() => _charCount = val.length),
                  style: AppTextStyles.bodyLarge,
                ),
              ),

              if (_selectedFile != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _attachedType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile!.path.split(Platform.pathSeparator).last,
                          style: AppTextStyles.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _selectedFile = null;
                          _attachedType = null;
                        }),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Char counter + Post button
              Row(
                children: [
                  Text(
                    '$_charCount / $_maxChars',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _charCount > _maxChars * 0.9
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _isPosting ? null : _pickFile,
                    icon: const Icon(Icons.attach_file, color: AppColors.primary),
                    tooltip: 'Attach Image or PDF',
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton.icon(
                      onPressed: _isPosting ? null : _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff7c3aed),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isPosting ? 'Posting...' : 'Post',
                          style: AppTextStyles.button),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _CommentsSheet — inline comments for a post
// ────────────────────────────────────────────────────────────────────────────

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
      final snap = await FirebaseFirestore.instance
          .collection('comments')
          .where('contentId', isEqualTo: widget.post.postId)
          .orderBy('createdAt', descending: false)
          .get();
      final all = snap.docs
          .map((d) => CommentModel.fromMap(d.data(), d.id))
          .where((c) => c.parentId == null)
          .toList();
      if (mounted) setState(() {
        _comments = all;
        _isLoading = false;
      });
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
                      color: const Color(0xff7c3aed).withOpacity(0.1),
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
              decoration: BoxDecoration(
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
                const Color(0xff7c3aed).withOpacity(0.1),
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
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
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
