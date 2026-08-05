import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/college_service.dart';
import '../../models/user_model.dart';
import '../../models/note_model.dart';
import '../courses/courses_list_screen.dart';
import '../courses/course_detail_screen.dart';
import '../courses/providers/course_provider.dart';
import '../auth/widgets/college_search_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/widgets/animated_transition.dart';
import 'follow_list_screen.dart';
import 'package:share_plus/share_plus.dart';

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
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    // Listen to real-time updates for profile counts/data
    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final profile = UserModel.fromMap(doc.data()!);
        setState(() {
          _profile = profile;
        });
        ref.read(currentUserModelProvider.notifier).state = profile;
      }
    });

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
        setState(() {
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
    // Image upload via File path is not supported on web
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload is only available on the mobile app')),
      );
      return;
    }
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
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
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
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await svc.updateUserProfile(
                  _profile!.uid, {'role': 'contributor'});
              navigator.pop();
              if (mounted) _loadProfileData();
              messenger.showSnackBar(const SnackBar(
                content: Text(
                    '🎉 Congratulations! You are now a Contributor!'),
                backgroundColor: AppColors.success,
              ));
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

  void _showQrCodeDialog() {
    if (_profile == null) return;
    final profileUrl = "https://studysphere-app-3a480.web.app/user/${_profile!.username.isNotEmpty ? _profile!.username : _profile!.uid}";
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile QR Code',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary,
                  backgroundImage: _profile!.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(_profile!.photoUrl)
                      : null,
                  child: _profile!.photoUrl.isEmpty
                      ? Text(
                          _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _profile!.name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '@${_profile!.username.isNotEmpty ? _profile!.username : _profile!.name.toLowerCase().replaceAll(' ', '_')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(profileUrl)}&color=7C72E8',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(
                      width: 180,
                      height: 180,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 180,
                      height: 180,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan to view study profile',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Account Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Colors.teal),
                  title: const Text('Contact Support'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/contact');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded, color: Colors.blueGrey),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/privacy');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_rounded, color: Colors.indigo),
                  title: const Text('Terms & Conditions'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/terms');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: const Text('Delete Account'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/delete-account');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(height: 64),
              SkeletonLoader(width: 120, height: 120, borderRadius: 60),
              SizedBox(height: 16),
              SkeletonLoader(width: 150, height: 24, borderRadius: 12),
              SizedBox(height: 8),
              SkeletonLoader(width: 100, height: 16, borderRadius: 8),
              SizedBox(height: 32),
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
          SliverToBoxAdapter(
            child: _buildProfileHero(),
          ),
          SliverAppBar(
            pinned: true,
            toolbarHeight: 0,
            backgroundColor: AppColors.background,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Overview', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Uploads', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_border_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Bookmarks', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3F2FF), Color(0xFFE8E5FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Header Title & Actions ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        // QR Code Scanner Button
                        GestureDetector(
                          onTap: _showQrCodeDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 20,
                              color: Color(0xFF7C72E8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // More Options Button
                        GestureDetector(
                          onTap: _showMoreOptionsBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: Color(0xFF7C72E8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Main Profile Card ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C72E8).withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Large Profile Photo
                          GestureDetector(
                            onTap: _isUploadingAvatar ? null : _uploadAvatar,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C72E8).withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF7C72E8).withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _profile!.photoUrl.isEmpty
                                        ? Center(
                                            child: Text(
                                              _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF7C72E8),
                                                fontSize: 36,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(100),
                                            child: CachedNetworkImage(
                                              imageUrl: _profile!.photoUrl,
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              errorWidget: (_, __, ___) => Center(
                                                child: Text(
                                                  _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : '?',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF7C72E8),
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (_isUploadingAvatar)
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  ),
                                if (!_isUploadingAvatar)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7C72E8),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Right side: Name, Username, Metadata & Bio
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _profile!.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_profile!.isVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF7C72E8),
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${_profile!.username.isNotEmpty ? _profile!.username : _profile!.name.toLowerCase().replaceAll(' ', '_')}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF7C72E8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                
                                // School / Degree
                                if (_profile!.coursePreference.isNotEmpty)
                                  _buildMetadataRow(Icons.school_outlined, _profile!.coursePreference),
                                // Semester
                                if (_profile!.semester.isNotEmpty)
                                  _buildMetadataRow(Icons.book_outlined, _profile!.semester),
                                // College Name
                                if (_profile!.collegeName.isNotEmpty)
                                  _buildMetadataRow(Icons.account_balance_outlined, _profile!.collegeName),
                                // Location
                                if (_profile!.state.isNotEmpty)
                                  _buildMetadataRow(
                                    Icons.location_on_outlined,
                                    _profile!.district.isNotEmpty
                                        ? '${_profile!.district}, ${_profile!.state}'
                                        : _profile!.state,
                                  ),
                                
                                const SizedBox(height: 8),

                                // Bio bullet lines
                                if (_profile!.bio.isNotEmpty)
                                  ..._profile!.bio.split('\n').map((line) {
                                    if (line.trim().isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        line.trim(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Edit and Share buttons row
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _showEditProfileDialog,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C72E8), Color(0xFF9F97F2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C72E8).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Edit Profile',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _shareProfile,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF7C72E8).withValues(alpha: 0.5), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.share_outlined, color: Color(0xFF7C72E8), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Share Profile',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF7C72E8),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Stats Card ─────────────────────────────────────────
                _buildStatsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = [
      {
        'label': 'Notes',
        'value': '${_myUploads.length}',
        'color': const Color(0xFF7C72E8),
        'bgColor': const Color(0xFFF3F2FF),
        'icon': Icons.description_rounded,
      },
      {
        'label': 'Followers',
        'value': '${_profile!.followersCount}',
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFEFF6FF),
        'icon': Icons.people_alt_rounded,
      },
      {
        'label': 'Following',
        'value': '${_profile!.followingCount}',
        'color': const Color(0xFF22C55E),
        'bgColor': const Color(0xFFF0FDF4),
        'icon': Icons.person_rounded,
      },
      {
        'label': 'Reputation',
        'value': '${_profile!.reputationPoints}',
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
        'icon': Icons.shield_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C72E8).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(stats[0]),
          _buildStatDivider(),
          _buildStatItem(stats[1]),
          _buildStatDivider(),
          _buildStatItem(stats[2]),
          _buildStatDivider(),
          _buildStatItem(stats[3]),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }

  Widget _buildStatItem(Map<String, dynamic> s) {
    final label = s['label'] as String;
    final isClickable = label == 'Followers' || label == 'Following';
    return Expanded(
      child: InkWell(
        onTap: isClickable
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowListScreen(
                      userId: _profile!.uid,
                      initialTab: label == 'Followers' ? 0 : 1,
                      userName: _profile!.name,
                    ),
                  ),
                ).then((_) => _loadProfileData());
              }
            : null,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s['bgColor'] as Color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              s['value'] as String,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    if (_profile == null) return;
    final profileUrl = "https://studysphere-app-3a480.web.app/user/${_profile!.username.isNotEmpty ? _profile!.username : _profile!.uid}";
    final shareText = "Hey! Check out my profile on StudySphere 🎓\n\n"
        "👤 Name: ${_profile!.name}\n"
        "🏷️ Username: @${_profile!.username.isNotEmpty ? _profile!.username : _profile!.name.toLowerCase().replaceAll(' ', '_')}\n"
        "📖 Course: ${_profile!.coursePreference} ${_profile!.semester.isNotEmpty ? '(${_profile!.semester})' : ''}\n"
        "${_profile!.collegeName.isNotEmpty ? '🏫 College: ${_profile!.collegeName}\n' : ''}"
        "\n🔗 Profile Link: $profileUrl\n"
        "\nJoin me on StudySphere to share notes and prepare together! ✨";
    Share.share(shareText);
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        color: Colors.black.withValues(alpha: 0.02),
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
                          color: AppColors.primary.withValues(alpha: 0.1),
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
                          color: AppColors.primary.withValues(alpha: 0.04),
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
                              color: AppColors.primary.withValues(alpha: 0.1),
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
                      color: AppColors.warning.withValues(alpha: 0.3),
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
          Text('Quick Links', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          if (_profile!.role == 'contributor' || _profile!.role == 'admin') ...[
            _buildQuickLink(Icons.cloud_upload_rounded, 'My Uploads',
                '/my-uploads', AppColors.primary),
            const SizedBox(height: 8),
          ],
          _buildQuickLink(Icons.download_done_rounded, 'My Offline Downloads',
              '/downloads', AppColors.warning),
          const SizedBox(height: 8),
          _buildQuickLink(Icons.quiz_rounded, 'Question Papers',
              '/papers', AppColors.success),
          const SizedBox(height: 8),
          _buildQuickLink(
              Icons.forum_rounded, 'Community Feed', '/community', const Color(0xff7c3aed)),
          const SizedBox(height: 24),
          Text('Support & Legal', style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          // Compact 2-column grid for legal items
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCompactLink(Icons.support_agent_rounded, 'Contact Support', '/contact', Colors.teal),
              _buildCompactLink(Icons.privacy_tip_rounded, 'Privacy Policy', '/privacy', Colors.blueGrey),
              _buildCompactLink(Icons.description_rounded, 'Terms & Conditions', '/terms', Colors.indigo),
              _buildCompactLink(Icons.people_rounded, 'Community Rules', '/community-guidelines', const Color(0xFF7C3AED)),
              _buildCompactLink(Icons.copyright_rounded, 'Copyright Policy', '/copyright-policy', Colors.deepOrange),
              _buildCompactLink(Icons.smart_toy_rounded, 'AI Disclaimer', '/ai-disclaimer', AppColors.blue),
              _buildCompactLink(Icons.folder_special_rounded, 'Content Disclaimer', '/content-disclaimer', Colors.teal),
              _buildCompactLink(Icons.delete_forever_rounded, 'Delete Account', '/delete-account', AppColors.error),
            ],
          ),
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
              color: color.withValues(alpha: 0.1),
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
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLink(IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
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
                  color: AppColors.warning.withValues(alpha: 0.1),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                            color: statusColor.withValues(alpha: 0.1),
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
                      const Icon(Icons.download_rounded,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${note.downloads}',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_rounded,
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
                color: AppColors.primary.withValues(alpha: 0.08),
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _profile!.name);
    final usernameController = TextEditingController(text: _profile!.username);
    final bioController = TextEditingController(text: _profile!.bio);
    final courseController = TextEditingController(text: _profile!.coursePreference);
    final collegeDisplayController = TextEditingController(text: _profile!.collegeName);

    // Location state
    String? selectedState = _profile!.state.isNotEmpty ? _profile!.state : null;
    String? selectedDistrict = _profile!.district.isNotEmpty ? _profile!.district : null;
    String? selectedTaluka = _profile!.subDistrict.isNotEmpty ? _profile!.subDistrict : null;
    CollegeData? selectedCollege;
    List<String> states = [];
    List<String> districts = [];
    List<String> talukas = [];
    String updatedGender = _profile!.gender.isEmpty ? 'female' : _profile!.gender;
    String? selectedSemester = _profile!.semester.isNotEmpty ? _profile!.semester : null;
    bool isSaving = false;

    final locationSvc = ref.read(locationServiceProvider);

    Widget buildApiDropdown({
      required String label,
      required String? value,
      required List<String> items,
      required void Function(String?) onChanged,
      IconData? icon,
    }) {
      return DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon ?? Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load states on first build
            if (states.isEmpty) {
              locationSvc.getStates().then((s) {
                if (context.mounted) setDialogState(() => states = s);
              });
            }

            // Pre-load districts/talukas if already selected
            if (selectedState != null && districts.isEmpty) {
              locationSvc.getDistricts(selectedState!).then((d) {
                if (context.mounted) {
                  setDialogState(() => districts = d);
                  if (selectedDistrict != null) {
                    locationSvc.getTalukas(selectedState!, selectedDistrict!).then((t) {
                      if (context.mounted) setDialogState(() => talukas = t);
                    });
                  }
                }
              });
            }

            Future<void> onStateChanged(String? newState) async {
              setDialogState(() {
                selectedState = newState;
                selectedDistrict = null;
                selectedTaluka = null;
                districts = [];
                talukas = [];
              });
              if (newState != null) {
                final d = await locationSvc.getDistricts(newState);
                if (context.mounted) setDialogState(() => districts = d);
              }
            }

            Future<void> onDistrictChanged(String? newDistrict) async {
              setDialogState(() {
                selectedDistrict = newDistrict;
                selectedTaluka = null;
                talukas = [];
              });
              if (newDistrict != null && selectedState != null) {
                final t = await locationSvc.getTalukas(selectedState!, newDistrict);
                if (context.mounted) setDialogState(() => talukas = t);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Edit Profile'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Username is required';
                            if (val.trim().length < 3) return 'Must be at least 3 characters';
                            final regex = RegExp(r'^[a-z0-9_.]+$');
                            if (!regex.hasMatch(val.trim().toLowerCase())) {
                              return 'Lowercase letters, numbers, _ and . only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: bioController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            prefixIcon: Icon(Icons.info_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: courseController,
                                decoration: const InputDecoration(
                                  labelText: 'Course (e.g. BCA)',
                                  prefixIcon: Icon(Icons.school_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedSemester,
                                decoration: const InputDecoration(
                                  labelText: 'Semester',
                                  prefixIcon: Icon(Icons.timeline_rounded),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: List.generate(8, (i) {
                                  final sem = 'Sem ${i + 1}';
                                  return DropdownMenuItem(value: sem, child: Text(sem));
                                }),
                                onChanged: (val) => setDialogState(() => selectedSemester = val),
                                isExpanded: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: updatedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: Icon(Icons.wc_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => updatedGender = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              'Location & College',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        buildApiDropdown(
                          label: 'State',
                          value: selectedState,
                          items: states,
                          icon: Icons.map_rounded,
                          onChanged: (val) => onStateChanged(val),
                        ),
                        const SizedBox(height: 12),
                        buildApiDropdown(
                          label: 'District',
                          value: selectedDistrict,
                          items: districts,
                          icon: Icons.location_city_rounded,
                          onChanged: (val) => onDistrictChanged(val),
                        ),
                        const SizedBox(height: 12),
                        buildApiDropdown(
                          label: 'Taluka / Sub-district',
                          value: selectedTaluka,
                          items: talukas,
                          icon: Icons.near_me_rounded,
                          onChanged: (val) => setDialogState(() => selectedTaluka = val),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showCollegeSearchBottomSheet(
                              context,
                              ref,
                              selectedState,
                              selectedDistrict,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedCollege = picked;
                                collegeDisplayController.text = picked.college;
                              });
                            }
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: collegeDisplayController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'College',
                                hintText: 'Tap to search college',
                                prefixIcon: Icon(Icons.account_balance_rounded),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setDialogState(() => isSaving = true);
                          
                          try {
                            final firestoreSvc = ref.read(firestoreServiceProvider);
                            final targetUid = _profile!.uid;
                            final newUsername = usernameController.text.trim().toLowerCase();
                            final newName = nameController.text.trim();
                            
                            // Check username uniqueness if changed
                            if (newUsername != _profile!.username.toLowerCase()) {
                              final isUnique = await firestoreSvc.isUsernameUnique(newUsername);
                              if (!isUnique) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Username is already taken. Please try another.'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                setDialogState(() => isSaving = false);
                                return;
                              }
                            }
                            
                            final Map<String, dynamic> updates = {
                              'name': newName,
                              'username': newUsername,
                              'bio': bioController.text.trim(),
                              'coursePreference': courseController.text.trim(),
                              'semester': selectedSemester ?? '',
                              'gender': updatedGender,
                              if (selectedState != null) 'state': selectedState!,
                              if (selectedDistrict != null) 'district': selectedDistrict!,
                              if (selectedTaluka != null) 'subDistrict': selectedTaluka!,
                              if (selectedCollege != null) 'collegeName': selectedCollege!.college,
                            };
                            
                            await firestoreSvc.updateUserProfile(targetUid, updates);
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              _loadProfileData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully! ✨'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update profile: $e'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
