import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../models/note_model.dart';
import '../upload/upload_bottom_sheet.dart';
import '../courses/courses_list_screen.dart';
import '../courses/course_detail_screen.dart';
import '../courses/providers/course_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/widgets/animated_transition.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _profile;
  bool _isLoading = true;
  List<NoteModel> _myUploads = [];
  List<Map<String, dynamic>> _bookmarks = [];
  late TabController _tabController;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    try {
      final svc = ref.read(firestoreServiceProvider);
      UserModel profile;
      try {
        profile = await svc.getUserProfile(user.uid);
      } catch (e) {
        if (e.toString().contains('not found')) {
          profile = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'Student',
            username: '',
            email: user.email ?? '',
            photoUrl: user.photoURL ?? '',
            role: 'learner',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            lastUsageReset: DateTime.now(),
          );
          await svc.createUserProfile(profile);
        } else {
          rethrow;
        }
      }

      // My uploads (only for contributors)
      List<NoteModel> myUploads = [];
      if (profile.role == 'contributor') {
        myUploads = await svc.fetchUserUploads(user.uid);
      }

      // Bookmarks from Firestore
      final bookmarksSnap = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('userId', isEqualTo: user.uid)
          .get();
      final bookmarks = bookmarksSnap.docs
          .map((d) => d.data())
          .toList();
          
      bookmarks.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        ref.read(currentUserModelProvider.notifier).state = profile;
        setState(() {
          _profile = profile;
          _myUploads = myUploads;
          _bookmarks = bookmarks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load profile: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingAvatar = true);
        final file = File(result.files.single.path!);
        final user = ref.read(authServiceProvider).currentUser;
        
        if (user != null) {
          final storageSvc = ref.read(storageServiceProvider);
          final firestoreSvc = ref.read(firestoreServiceProvider);
          
          final imageUrl = await storageSvc.uploadImage(file, user.uid);
          
          // Update Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'photoUrl': imageUrl,
          });
          
          // Reload profile
          await _loadProfileData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: AppColors.success,
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload photo: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('Become a Contributor', style: AppTextStyles.headingSmall),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('As a contributor, you can:',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...[
              '📄 Upload study notes and question papers',
              '💬 Post in the community feed',
              '⭐ Earn reputation points',
              '🏆 Appear on the leaderboard',
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(item, style: AppTextStyles.bodyMedium),
                )),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text(
                '⚠️ By upgrading, you agree to only upload original educational content. Spam or duplicates will lead to a permanent ban.',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final svc = ref.read(firestoreServiceProvider);
              await svc.updateUserProfile(
                  _profile!.uid, {'role': 'contributor'});
              if (mounted) {
                Navigator.pop(context);
                _loadProfileData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      '🎉 Congratulations! You are now a Contributor!'),
                  backgroundColor: AppColors.success,
                ));
              }
            },
            icon: const Icon(Icons.stars_rounded),
            label: const Text('Accept & Upgrade'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content: const Text('You will be taken back to the login screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go('/login');
    }
  }

  void _showEditCourseDialog() {
    final courseController = TextEditingController(text: _profile?.coursePreference);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courseController,
              decoration: const InputDecoration(
                labelText: 'Course / Degree',
                hintText: 'e.g. B.Sc Computer Science',
                prefixIcon: Icon(Icons.school_rounded),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Note: To change your location or college, please contact support or re-register for now.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newCourse = courseController.text.trim();
              if (newCourse.isNotEmpty && _profile != null) {
                await ref.read(firestoreServiceProvider).updateUserProfile(_profile!.uid, {'coursePreference': newCourse});
                _loadProfileData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 64),
              SkeletonLoader(width: 120, height: 120, borderRadius: 60),
              const SizedBox(height: 16),
              SkeletonLoader(width: 150, height: 24, borderRadius: 12),
              const SizedBox(height: 8),
              SkeletonLoader(width: 100, height: 16, borderRadius: 8),
              const SizedBox(height: 32),
              SkeletonLoader(width: double.infinity, height: 200, borderRadius: 16),
            ],
          ),
        ),
      );
    }
    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Profile not found', style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loadProfileData,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _signOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 310,
            backgroundColor: AppColors.background,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                onPressed: _signOut,
                tooltip: 'Sign Out',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _buildProfileHero(),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Uploads'),
                Tab(text: 'Bookmarks'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildUploadsTab(),
            _buildBookmarksTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHero() {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.shadowLevel1,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _uploadAvatar,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C72E8), Color(0xFFB8B2FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: _profile!.photoUrl.isEmpty
                                    ? Center(
                                        child: Text(
                                          _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.network(_profile!.photoUrl, fit: BoxFit.cover),
                                      ),
                              ),
                              if (_isUploadingAvatar)
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                              if (!_isUploadingAvatar)
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: _showEditProfileDialog,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _profile!.name,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'B.Tech · Computer Science · 2nd Year',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (_profile!.role == 'contributor')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F2FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('⭐ ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Top Contributor',
                              style: TextStyle(
                                color: Color(0xFF7C72E8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    // ── Figma-style 4-stat grid data ────────────────────────────
    final stats = [
      {'label': 'Notes',  'value': '${_myUploads.length}',           'color': AppColors.primary},
      {'label': 'Solved', 'value': '${_profile!.reputationPoints}',  'color': AppColors.blue},
      {'label': 'Streak', 'value': '5d',                             'color': AppColors.secondary},
      {'label': 'Rank',   'value': '#${_profile!.followersCount + 1}','color': AppColors.tertiary},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Figma 4-stat grid ──────────────────────────────────
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: stats.map((s) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.shadowLevel1,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s['value'] as String,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: s['color'] as Color,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s['label'] as String,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )).toList(),
          ),

          const SizedBox(height: 20),

          // ── My Courses section (Figma style) ──────────────────
          Text('My Courses',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground,
              )),
          const SizedBox(height: 12),
          ref.watch(enrolledCoursesProvider).when(
            data: (courses) {
              if (courses.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No courses started yet',
                        style: AppTextStyles.labelMedium.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Explore available courses and begin your learning journey.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.push('/courses'); // Assuming route exists or fallback to material page route
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesListScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: const Text('Explore Courses', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: courses.map((course) => GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              course.thumbnailUrl,
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 100, height: 80,
                                color: AppColors.surfaceLowest, 
                                child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: AppTextStyles.headingSmall.copyWith(fontSize: 15, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      course.duration,
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${course.modules.length} Lessons',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),

          const SizedBox(height: 20),

          // ── Original Course tag ────────────────────────────────
          _buildInfoCard(
            icon: Icons.school_rounded,
            label: 'My Course',
            value: _profile!.coursePreference.isNotEmpty
                ? _profile!.coursePreference
                : 'Not set',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          if (_profile!.collegeName.isNotEmpty) ...[
            _buildInfoCard(
              icon: Icons.account_balance_rounded,
              label: 'College',
              value: _profile!.collegeName,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
          ],

          if (_profile!.state.isNotEmpty) ...[

                _buildInfoCard(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: '${_profile!.subDistrict}, ${_profile!.district}, ${_profile!.state}',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
              ],

          // Rep points
          _buildInfoCard(
            icon: Icons.military_tech_rounded,
            label: 'Reputation Points',
            value: '${_profile!.reputationPoints} pts',
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),

          // Member since
          _buildInfoCard(
            icon: Icons.calendar_today_rounded,
            label: 'Member Since',
            value: _formatDate(_profile!.createdAt),
            color: AppColors.accent,
          ),

          const SizedBox(height: 24),

          // Upgrade CTA (only for learners)
          if (_profile!.role == 'learner')
            GestureDetector(
              onTap: _showUpgradeDialog,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffd97706), Color(0xffeab308)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Become a Contributor',
                            style: AppTextStyles.headingSmall
                                .copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload notes, earn points, climb the leaderboard.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

          // Quick links
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quick Links', style: AppTextStyles.headingSmall),
              TextButton.icon(
                onPressed: () => _showEditProfileDialog(),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Details'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickLink(Icons.folder_special_rounded, 'My Offline Downloads',
              '/offline-downloads', AppColors.accent),
          const SizedBox(height: 8),
          if (_profile!.role == 'contributor' || _profile!.role == 'admin') ...[
            _buildQuickLink(Icons.cloud_upload_rounded, 'My Uploads',
                '/my-uploads', AppColors.primary),
            const SizedBox(height: 8),
          ],
          _buildQuickLink(Icons.download_done_rounded, 'My Downloads',
              '/downloads', AppColors.warning),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.quiz_rounded, 'Question Papers',
              '/papers', AppColors.success),
          const SizedBox(height: 8),
          _buildQuickLink(
              Icons.forum_rounded, 'Community Feed', '/community', const Color(0xff7c3aed)),
          const SizedBox(height: 24),
          Text('Support & Legal', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          _buildQuickLink(Icons.support_agent_rounded, 'Contact Support',
              '/contact', Colors.teal),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.privacy_tip_rounded, 'Privacy Policy',
              '/privacy', Colors.blueGrey),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.description_rounded, 'Terms & Conditions',
              '/terms', Colors.blueGrey),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.people_rounded, 'Community Guidelines',
              '/community-guidelines', const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.copyright_rounded, 'Copyright Policy',
              '/copyright-policy', Colors.deepOrange),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.smart_toy_rounded, 'AI Disclaimer',
              '/ai-disclaimer', AppColors.blue),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.folder_special_rounded, 'Content Disclaimer',
              '/content-disclaimer', Colors.teal),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.delete_forever_rounded, 'Delete Account',
              '/delete-account', AppColors.error),
          if (_profile?.role == 'admin') ...[
            const SizedBox(height: 24),
            Text('Admin Center', style: AppTextStyles.headingSmall),
            const SizedBox(height: 12),
            _buildQuickLink(Icons.admin_panel_settings_rounded, 'Admin Dashboard',
                '/admin', AppColors.error),
          ],

          const SizedBox(height: 24),
          // Figma-style Sign Out button
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Center(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLink(
      IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Uploads Tab ───────────────────────────────────────────────────────────

  Widget _buildUploadsTab() {
    if (_profile!.role == 'learner') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.upload_rounded,
                    size: 52, color: AppColors.warning),
              ),
              const SizedBox(height: 20),
              Text('Upgrade to Contributor',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 8),
              Text('Upload notes and question papers to earn reputation points.',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showUpgradeDialog,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning),
              ),
            ],
          ),
        ),
      );
    }

    if (_myUploads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('No uploads yet', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text('Start sharing your study notes to earn points!',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myUploads.length,
      itemBuilder: (context, index) {
        final note = _myUploads[index];
        final statusColor = _statusColor(note.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title,
                        style: AppTextStyles.headingSmall
                            .copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${note.course} · ${note.semester}',
                            style: AppTextStyles.bodySmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            note.status.toUpperCase(),
                            style: AppTextStyles.bodySmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.download_rounded,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${note.downloads}',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 12),
                      Icon(Icons.favorite_rounded,
                          size: 13, color: AppColors.error),
                      const SizedBox(width: 3),
                      Text('${note.likes}', style: AppTextStyles.bodySmall),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppColors.textSecondary),
                onPressed: () => context.push('/notes/${note.noteId}'),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      case 'duplicate_detected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  // ── Bookmarks Tab ─────────────────────────────────────────────────────────

  Widget _buildBookmarksTab() {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.bookmark_border_rounded,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No bookmarks yet', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text('Save notes while reading to find them here.',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/notes'),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Browse Notes'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bm = _bookmarks[index];
        final noteTitle = bm['noteTitle'] as String? ?? 'Unknown Note';
        final course = bm['noteCourse'] as String? ?? '';
        final semester = bm['noteSemester'] as String? ?? '';
        final contentId = bm['contentId'] as String? ?? '';

        return GestureDetector(
          onTap: () => context.push('/notes/$contentId'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff2563eb), Color(0xff38bdf8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bookmark_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noteTitle,
                        style: AppTextStyles.headingSmall
                            .copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('$course · $semester',
                            style: AppTextStyles.bodySmall),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String updatedState = _profile!.state;
        String updatedDistrict = _profile!.district;
        String updatedTaluka = _profile!.subDistrict;
        String updatedCollege = _profile!.collegeName;
        String updatedGender = _profile!.gender;
        
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: updatedState,
                  decoration: const InputDecoration(labelText: 'State'),
                  onChanged: (val) => updatedState = val,
                ),
                TextFormField(
                  initialValue: updatedDistrict,
                  decoration: const InputDecoration(labelText: 'District'),
                  onChanged: (val) => updatedDistrict = val,
                ),
                TextFormField(
                  initialValue: updatedTaluka,
                  decoration: const InputDecoration(labelText: 'Taluka'),
                  onChanged: (val) => updatedTaluka = val,
                ),
                TextFormField(
                  initialValue: updatedCollege,
                  decoration: const InputDecoration(labelText: 'College Name'),
                  onChanged: (val) => updatedCollege = val,
                ),
                DropdownButtonFormField<String>(
                  value: updatedGender.isEmpty ? 'female' : updatedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      updatedGender = val;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final svc = ref.read(firestoreServiceProvider);
                await svc.updateUserProfile(_profile!.uid, {
                  'state': updatedState,
                  'district': updatedDistrict,
                  'subDistrict': updatedTaluka,
                  'collegeName': updatedCollege,
                  'gender': updatedGender,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _loadProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
