import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_cache_provider.dart';
import '../../core/widgets/shimmer_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/banner_model.dart';
import '../notes/notes_screen.dart';
import '../upload/upload_bottom_sheet.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../community/community_screen.dart';
import '../profile/profile_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/widgets/animated_transition.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../courses/models/course_model.dart';
import '../courses/course_detail_screen.dart';
import '../courses/courses_list_screen.dart';
import '../courses/providers/course_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _currentTab = 0;
  UserModel? _userProfile;
  int _currentBannerIndex = 0;
  String? _initialCourse;
  String? _initialSemester;
  String? _initialSearch;
  List<String> _recentSearches = [];

  late AnimationController _heroAnimController;
  late AnimationController _cardsAnimController;

  @override
  void initState() {
    super.initState();
    // Profile loaded from cache — no direct Firestore call needed here
    _loadRecentSearches();

    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _cardsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsAnimController.forward();
    });
  }

  @override
  void dispose() {
    _heroAnimController.dispose();
    _cardsAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches = prefs.getStringList('recent_searches') ?? [];
      });
    }
  }

  Future<void> _addRecentSearch(String search) async {
    if (search.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(search);
    _recentSearches.insert(0, search);
    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.sublist(0, 5);
    }
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  void _handleBannerTap(BannerModel banner) async {
    if (banner.redirectType == 'notes') {
      setState(() {
        _initialCourse = banner.redirectData['course'] as String?;
        _initialSemester = banner.redirectData['semester'] as String?;
        _initialSearch = banner.redirectData['subject'] as String?;
        _currentTab = 1;
      });
    } else if (banner.redirectType == 'url') {
      final url = banner.redirectData['url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        return _buildHomeDashboard();
      case 1:
        return NotesScreen(
          initialCourse: _initialCourse,
          initialSemester: _initialSemester,
          initialSearch: _initialSearch,
        );
      case 2:
        return const CommunityScreen();
      case 3:
        return const AIAssistantScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read from cache provider — no Firestore call on each rebuild
    final profileAsync = ref.watch(userProfileProvider);
    profileAsync.whenData((profile) {
      if (profile != null && _userProfile?.uid != profile.uid) {
        _userProfile = profile;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION — Figma style
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_outlined,       'activeIcon': Icons.home_rounded,        'label': 'Home'},
      {'icon': Icons.description_outlined,'activeIcon': Icons.description_rounded,  'label': 'Notes'},
      {'icon': Icons.forum_outlined,      'activeIcon': Icons.forum_rounded,       'label': 'Community'},
      {'icon': Icons.smart_toy_outlined,  'activeIcon': Icons.smart_toy_rounded,   'label': 'AI'},
      {'icon': Icons.person_outline,      'activeIcon': Icons.person_rounded,      'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isActive = _currentTab == index;
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (index == 1 && _currentTab != 1) {
                      _initialCourse = null;
                      _initialSemester = null;
                      _initialSearch = null;
                    }
                    _currentTab = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 18 : 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryFixed
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOME DASHBOARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHomeDashboard() {
    if (_userProfile == null) {
      return _buildSkeletonLoader();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── TOP APP BAR ──────────────────────────────────────
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.surfaceLowest,
          surfaceTintColor: Colors.transparent,
          shadowColor: AppColors.primary.withOpacity(0.08),
          forceElevated: true,
          toolbarHeight: 60,
          title: Row(
            children: [
              // Logo icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'StudySphere',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_outlined,
                      color: AppColors.primary, size: 22),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── CONTENT ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section
              _buildHeroSection(),

              const SizedBox(height: 16),

              // Search bar (separate from hero — Figma style)
              _buildSearchBar(),

              const SizedBox(height: 24),

              // Quick Actions — Figma style full-color cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Quick Access'),
                    const SizedBox(height: 14),
                    _buildQuickActionsGrid(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Continue Learning
              _buildContinueLearningSection(),

              // Banners
              _buildBannerSection(),

              const SizedBox(height: 24),

              // Recent Activity / Recommended Notes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Recommended Notes'),
                        TextButton(
                          onPressed: () => setState(() => _currentTab = 1),
                          child: Text(
                            'See All',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 195,
                      child: _buildTrendingNotesList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO SECTION — Figma gradient style
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _heroAnimController,
        curve: Curves.easeOut,
      )),
      child: FadeTransition(
        opacity: _heroAnimController,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          height: 160,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.shadowLevel2,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Decorative circles — Figma style
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: 10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),


              // Content
              Positioned(
                left: 20,
                top: 20,
                right: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_userProfile!.name.split(' ').first}! 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Let's continue your\nlearning journey today!",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Hero illustration — student character (Figma style)
              Positioned(
                bottom: 0,
                right: 8,
                child: _buildHeroIllustration(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simple hero illustration matching Figma's student character
  Widget _buildHeroIllustration() {
    final bool isMale = _userProfile?.gender == 'male';
    return SizedBox(
      height: 140,
      width: 100,
      child: CustomPaint(
        painter: isMale ? _MaleStudentPainter() : _StudentPainter(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH BAR — Separate below hero (Figma style)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
          decoration: InputDecoration(
            hintText: 'Search papers, subjects...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onSubmitted: (val) {
            _addRecentSearch(val);
            setState(() {
              _initialSearch = val;
              _currentTab = 1;
            });
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION TITLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.onBackground,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS — Figma full-color 2x2 grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickActionData(
        title: 'Notes',
        subtitle: 'Study smarter',
        icon: Icons.description_rounded,
        cardColor: AppColors.qaNotesColor,
        onTap: () => setState(() => _currentTab = 1),
      ),
      _QuickActionData(
        title: 'Free Courses',
        subtitle: 'Start learning',
        icon: Icons.play_circle_outline_rounded,
        cardColor: AppColors.qaQPColor,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesListScreen())),
      ),
      _QuickActionData(
        title: 'Community',
        subtitle: 'Ask & answer',
        icon: Icons.forum_rounded,
        cardColor: AppColors.qaCommunityColor,
        onTap: () => setState(() => _currentTab = 2),
      ),
      _QuickActionData(
        title: 'AI Assistant',
        subtitle: 'Learn faster',
        icon: Icons.smart_toy_rounded,
        cardColor: AppColors.qaAIColor,
        onTap: () => setState(() => _currentTab = 3),
      ),
    ];

    return AnimatedBuilder(
      animation: _cardsAnimController,
      builder: (context, child) {
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(actions.length, (index) {
            final delay = index * 0.15;
            final animValue = Curves.easeOut.transform(
              (_cardsAnimController.value - delay).clamp(0.0, 1.0) /
                  (1.0 - delay).clamp(0.01, 1.0),
            );
            return Opacity(
              opacity: animValue,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - animValue)),
                child: _buildQuickActionCard(actions[index]),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildQuickActionCard(_QuickActionData data) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          data.onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: data.cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: data.cardColor.withOpacity(0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container — white translucent bg
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(
                data.title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTINUE LEARNING — Figma horizontal scroll cards with progress
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContinueLearningSection() {
    final enrolledCoursesAsync = ref.watch(enrolledCoursesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Continue Learning'),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesListScreen()));
                },
                child: Text(
                  'Explore All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        enrolledCoursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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

            return SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
                    },
                    child: Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.shadowLevel1,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: AspectRatio(
                              aspectRatio: 16 / 7,
                              child: Image.network(
                                course.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surfaceLowest, child: const Icon(Icons.image_not_supported)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: AppTextStyles.headingSmall.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.ondemand_video, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        course.channelName,
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: 0.3, // Dummy progress for now
                                  backgroundColor: AppColors.border,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FREE COURSES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFreeCoursesSection() {
    final freeCoursesAsync = ref.watch(freeCoursesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Free Courses'),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesListScreen()));
                },
                child: Text(
                  'Explore All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        freeCoursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return const SizedBox(); // Hide section if no free courses
            }

            return SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
                    },
                    child: Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.shadowLevel1,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                course.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surfaceLowest, child: const Icon(Icons.image_not_supported)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${course.modules.length} Lessons',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
          error: (err, stack) => SizedBox(height: 240, child: Center(child: Text('Error: $err'))),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BANNER SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionTitle('Announcements'),
        ),
        const SizedBox(height: 12),
        CarouselSlider(
          options: CarouselOptions(
            aspectRatio: 16 / 6,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            viewportFraction: 0.92,
            enlargeCenterPage: true,
            onPageChanged: (index, reason) =>
                setState(() => _currentBannerIndex = index),
          ),
          items: [
            'assets/images/banners/banner1.jpg',
            'assets/images/banners/banner2.jpg',
            'assets/images/banners/banner3.jpg',
            'assets/images/banners/banner4.jpg',
            'assets/images/banners/banner5.jpg',
          ].map((imagePath) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(imagePath,
                  fit: BoxFit.cover, width: double.infinity),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentBannerIndex == index ? 20.0 : 6.0,
              height: 6.0,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _currentBannerIndex == index
                    ? AppColors.primary
                    : AppColors.outlineVariant,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRENDING NOTES — Horizontal scroll
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTrendingNotesList() {
    final firestoreService = ref.read(firestoreServiceProvider);
    return FutureBuilder(
      future: firestoreService.fetchNotes(
          course: _userProfile?.coursePreference),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) => Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Shimmer.fromColors(
                baseColor: AppColors.surfaceContainer,
                highlightColor: AppColors.surfaceLowest,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          );
        }

        final notes = snapshot.data!;
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined,
                    color: AppColors.onSurfaceVariant, size: 40),
                const SizedBox(height: 8),
                Text('No notes yet. Be the first to upload!',
                    style: AppTextStyles.bodyMedium),
              ],
            ),
          );
        }

        final noteColors = [
          AppColors.primary,
          AppColors.tertiary,
          AppColors.secondary,
          AppColors.success,
          AppColors.blue,
        ];

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final color = noteColors[index % noteColors.length];

            return GestureDetector(
              onTap: () => context.push('/notes/${note.noteId}'),
              child: Container(
                width: 155,
                margin: const EdgeInsets.only(right: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.shadowLevel1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Color top bar
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.description_rounded,
                                      size: 18, color: color),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PDF',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 9,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              note.title,
                              style: AppTextStyles.headingSmall.copyWith(
                                fontSize: 13,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${note.course} • ${note.semester}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 13,
                                    color: AppColors.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text('${note.downloads}',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(fontSize: 11)),
                                const SizedBox(width: 10),
                                Icon(Icons.favorite_rounded,
                                    size: 13, color: AppColors.tertiary),
                                const SizedBox(width: 3),
                                Text('${note.likes}',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SKELETON LOADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 80),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UploadBottomSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    required this.onTap,
  });
}

class _CourseData {
  final String title;
  final String subtitle;
  final Color color;
  final String initial;
  final double progress;
  final String course;
  final String semester;

  const _CourseData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.initial,
    required this.progress,
    this.course = 'BCA',
    this.semester = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Illustration Painter — matches Figma hero avatar
// ─────────────────────────────────────────────────────────────────────────────
class _StudentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hair back
    final hairBackPaint = Paint()..color = const Color(0xFF2D1B0E);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.40), width: w * 0.65, height: h * 0.54),
        hairBackPaint);

    // Hair puffs
    final puffPaint = Paint()..color = const Color(0xFF3D2010);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.18), width: w * 0.44, height: h * 0.30),
        puffPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.29, h * 0.23), width: w * 0.31, height: h * 0.26),
        puffPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.71, h * 0.23), width: w * 0.31, height: h * 0.26),
        puffPaint);

    // Face
    final facePaint = Paint()..color = const Color(0xFFFDBCB4);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.46), width: w * 0.49, height: h * 0.38),
        facePaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1A0A00);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.38, h * 0.44), width: w * 0.09, height: h * 0.07),
        eyePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.62, h * 0.44), width: w * 0.09, height: h * 0.07),
        eyePaint);
    // Eye shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.40, h * 0.42), w * 0.03, shinePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.42), w * 0.03, shinePaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFD4896A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.38, h * 0.52)
      ..quadraticBezierTo(w * 0.5, h * 0.60, w * 0.62, h * 0.52);
    canvas.drawPath(smilePath, smilePaint);

    // Hoodie body
    final hoodiePaint = Paint()..color = const Color(0xFFFF9800);
    final hoodPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.08, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.92, h * 0.85)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hoodPath, hoodiePaint);

    // Neck
    final neckPaint = Paint()..color = const Color(0xFFFDBCB4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: w * 0.16, height: h * 0.09),
        const Radius.circular(5),
      ),
      neckPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Male Student Illustration Painter
// ─────────────────────────────────────────────────────────────────────────────
class _MaleStudentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hair back (short hair for male)
    final hairBackPaint = Paint()..color = const Color(0xFF2D1B0E);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.35), width: w * 0.55, height: h * 0.40),
        hairBackPaint);

    // Face
    final facePaint = Paint()..color = const Color(0xFFFDBCB4);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.46), width: w * 0.49, height: h * 0.38),
        facePaint);

    // Hair front/top (spiky or simple fringe)
    final hairFrontPaint = Paint()..color = const Color(0xFF3D2010);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.28), width: w * 0.52, height: h * 0.15),
        hairFrontPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1A0A00);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.38, h * 0.44), width: w * 0.09, height: h * 0.07),
        eyePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.62, h * 0.44), width: w * 0.09, height: h * 0.07),
        eyePaint);
    // Eye shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.40, h * 0.42), w * 0.03, shinePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.42), w * 0.03, shinePaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFD4896A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.38, h * 0.52)
      ..quadraticBezierTo(w * 0.5, h * 0.60, w * 0.62, h * 0.52);
    canvas.drawPath(smilePath, smilePaint);

    // Hoodie body (blue instead of orange)
    final hoodiePaint = Paint()..color = const Color(0xFF2196F3);
    final hoodPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.08, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.92, h * 0.85)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hoodPath, hoodiePaint);

    // Neck
    final neckPaint = Paint()..color = const Color(0xFFFDBCB4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: w * 0.16, height: h * 0.09),
        const Radius.circular(5),
      ),
      neckPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
