import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'models/course_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'providers/enrollment_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseModule? _activeModule;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initDefaultPlayer();
  }

  void _initDefaultPlayer() {
    String? firstVideoId;
    CourseModule? firstModule;

    // 1. Try to get clean 11-char video ID from modules
    if (widget.course.modules.isNotEmpty) {
      for (var mod in widget.course.modules) {
        final vid = _extractVideoId(mod.youtubeVideoId);
        if (vid != null && vid.length == 11) {
          firstVideoId = vid;
          firstModule = mod;
          break;
        }
      }
    }

    // 2. Guaranteed fallback video ID per category (prevents Error 152-4 from loadPlaylist)
    if (firstVideoId == null) {
      final title = widget.course.title.toLowerCase();
      if (title.contains('python')) {
        firstVideoId = 'gfxD6v14k88';
      } else if (title.contains('web')) {
        firstVideoId = 'nu_pCVPKzTk';
      } else if (title.contains('java')) {
        firstVideoId = 'eIrMbAQSU34';
      } else if (title.contains('c++') || title.contains('cpp')) {
        firstVideoId = 'vLnPwxZdW4w';
      } else {
        firstVideoId = 'R6V9p_Z1i30';
      }

      firstModule = CourseModule(
        id: 'main_video',
        title: widget.course.title,
        youtubeVideoId: firstVideoId,
        duration: widget.course.duration,
      );
    }

    _activeModule = firstModule;
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: firstVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  // ─── Extractors ───────────────────────────────────────────────────────────

  String? _extractPlaylistId(String input) {
    if (input.isEmpty) return null;
    final trimmed = input.trim();

    if (trimmed.contains('list=')) {
      try {
        final uri = Uri.parse(trimmed);
        final id = uri.queryParameters['list'];
        if (id != null && id.isNotEmpty) return id;
      } catch (_) {}
      final idx = trimmed.indexOf('list=');
      final raw = trimmed.substring(idx + 5).split('&').first;
      if (raw.isNotEmpty) return raw;
    }

    if (trimmed.startsWith('PL') ||
        trimmed.startsWith('UU') ||
        trimmed.startsWith('FL') ||
        trimmed.startsWith('RD')) {
      return trimmed;
    }

    return null;
  }

  String? _extractVideoId(String input) {
    if (input.isEmpty) return null;
    final trimmed = input.trim();

    if (trimmed.contains('videoseries') ||
        (trimmed.contains('list=') && !trimmed.contains('watch?v='))) {
      return null;
    }

    final converted = YoutubePlayerController.convertUrlToId(trimmed);
    if (converted != null && converted.isNotEmpty) return converted;

    if (trimmed.contains('youtu.be/')) {
      return trimmed.split('youtu.be/').last.split('?').first.split('/').first;
    }

    if (trimmed.contains('?v=') || trimmed.contains('&v=')) {
      try {
        final uri = Uri.parse(trimmed);
        final v = uri.queryParameters['v'];
        if (v != null && v.length == 11) return v;
      } catch (_) {}
    }

    if (trimmed.length == 11 && !trimmed.contains('/')) return trimmed;

    return null;
  }

  // ─── Playback & App Launcher ───────────────────────────────────────────────

  void _playVideo(CourseModule module) {
    String? videoId = _extractVideoId(module.youtubeVideoId);

    if (videoId == null || videoId.length != 11) {
      final title = widget.course.title.toLowerCase();
      if (title.contains('python')) {
        videoId = 'gfxD6v14k88';
      } else if (title.contains('web')) {
        videoId = 'nu_pCVPKzTk';
      } else if (title.contains('java')) {
        videoId = 'eIrMbAQSU34';
      } else {
        videoId = 'R6V9p_Z1i30';
      }
    }

    _youtubeController?.close();
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        enableCaption: false,
      ),
    );

    setState(() {
      _activeModule = module;
    });

    _tabController.animateTo(1);
  }

  void _playFullPlaylist() {
    if (_displayModules.isNotEmpty) {
      _playVideo(_displayModules.first);
    } else {
      _openInYoutubeApp(widget.course.youtubePlaylistUrl);
    }
  }

  Future<void> _openInYoutubeApp(String urlOrId) async {
    String targetUrl = urlOrId;
    final playlistId = _extractPlaylistId(urlOrId);
    final videoId = _extractVideoId(urlOrId);

    if (playlistId != null) {
      targetUrl = 'https://www.youtube.com/playlist?list=$playlistId';
    } else if (videoId != null) {
      targetUrl = 'https://www.youtube.com/watch?v=$videoId';
    } else if (!targetUrl.startsWith('http')) {
      targetUrl = 'https://www.youtube.com/watch?v=$targetUrl';
    }

    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  List<CourseModule> get _displayModules => widget.course.modules;

  bool get _hasPlaylistUrl =>
      _extractPlaylistId(widget.course.youtubePlaylistUrl) != null;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double headerHeight = (screenWidth * 9 / 16).clamp(210.0, 360.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: _activeModule == null ? headerHeight : null,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: innerBoxIsScrolled
                  ? Text(widget.course.title,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16))
                  : null,
              flexibleSpace: _activeModule == null
                  ? FlexibleSpaceBar(
                      background: Hero(
                        tag: 'course_image_${widget.course.id}',
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black),
                            Image.network(
                              widget.course.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: AppColors.surfaceLowest,
                                child: const Center(
                                    child: Icon(Icons.image_not_supported,
                                        color: Colors.white, size: 48)),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_displayModules.isNotEmpty) {
                                    _playVideo(_displayModules.first);
                                  } else {
                                    _playFullPlaylist();
                                  }
                                },
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      size: 44, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
              bottom: _activeModule != null
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(headerHeight),
                      child: Container(
                        height: headerHeight,
                        width: double.infinity,
                        color: Colors.black,
                        child: _youtubeController != null
                            ? Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: YoutubePlayer(controller: _youtubeController!),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: InkWell(
                                      onTap: () {
                                        final target = _activeModule?.youtubeVideoId ?? widget.course.youtubePlaylistUrl;
                                        _openInYoutubeApp(target);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.open_in_new_rounded, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('YouTube App',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                      ),
                    )
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(20),
                      child: Container(
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _badge(widget.course.category,
                            AppColors.primary.withValues(alpha: 0.1), AppColors.primary),
                        const SizedBox(width: 8),
                        _badge(widget.course.level,
                            AppColors.secondary.withValues(alpha: 0.1),
                            AppColors.secondary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.course.title,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _displayModules.length > 1
                              ? '${_displayModules.length} Lessons'
                              : _hasPlaylistUrl
                                  ? 'Full Playlist'
                                  : '${widget.course.totalVideos} Videos',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.schedule_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 6),
                        Text(widget.course.formattedDuration,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, child) {
                        final enrolledIds = ref.watch(enrollmentProvider);
                        final isEnrolled = enrolledIds.contains(widget.course.id);

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!isEnrolled) {
                                ref.read(enrollmentProvider.notifier).enroll(widget.course.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enrolled! Go to Videos tab to start learning. 🎓')),
                                );
                                _tabController.animateTo(1);
                              } else {
                                if (_displayModules.isNotEmpty) {
                                  _playVideo(_displayModules.first);
                                } else {
                                  _playFullPlaylist();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                                isEnrolled ? 'Start Learning' : 'Enroll Now',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Videos'),
                    Tab(text: 'Notes'),
                    Tab(text: 'Q&A'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Overview Tab ────────────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About this course',
                      style: AppTextStyles.headingSmall),
                  const SizedBox(height: 12),
                  Text(
                    widget.course.description,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Text('Instructor / Channel',
                      style: AppTextStyles.headingSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        radius: 24,
                        child: const Icon(Icons.ondemand_video_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.course.channelName,
                        style: AppTextStyles.labelMedium.copyWith(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Videos Tab ──────────────────────────────────────────────────
            Builder(
              builder: (context) {
                if (_displayModules.isNotEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _displayModules.length,
                    itemBuilder: (context, index) {
                      return _buildModuleTile(_displayModules[index], index);
                    },
                  );
                }

                // If no modules, show playlist launcher card
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      widget.course.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
                                    ),
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.35),
                                    ),
                                    Center(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _playFullPlaylist();
                                        },
                                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                        label: const Text('Play Course Video in App',
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.playlist_play_rounded,
                                            color: AppColors.primary, size: 28),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.course.title,
                                              style: AppTextStyles.labelMedium.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Full Playlist • Watch in App or YouTube',
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _openInYoutubeApp(widget.course.youtubePlaylistUrl),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                    label: const Text('Open Full Playlist on YouTube App'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                );
              },
            ),

            // ── Notes Tab ───────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Notes coming soon!',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

            // ── Q&A Tab ─────────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_rounded,
                        size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Q&A coming soon!',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleTile(CourseModule module, int index) {
    final isPlaying = _activeModule?.id == module.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPlaying ? AppColors.primary : AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: isPlaying ? Colors.white : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          module.title,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
            color: isPlaying ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        subtitle: module.duration.isNotEmpty
            ? Text('${module.duration} min', style: AppTextStyles.bodySmall)
            : null,
        onTap: () {
          HapticFeedback.lightImpact();
          _playVideo(module);
        },
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppTextStyles.labelSmall
              .copyWith(color: fg, fontWeight: FontWeight.bold)),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
