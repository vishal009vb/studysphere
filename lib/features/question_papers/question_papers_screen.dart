import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/question_paper_model.dart';
import '../../models/user_model.dart';

class QuestionPapersScreen extends ConsumerStatefulWidget {
  const QuestionPapersScreen({super.key});

  @override
  ConsumerState<QuestionPapersScreen> createState() =>
      _QuestionPapersScreenState();
}

class _QuestionPapersScreenState extends ConsumerState<QuestionPapersScreen> {
  // Drill-down navigation state
  String? _selectedCourse;
  String? _selectedSemester;
  String? _selectedSubject;

  List<QuestionPaperModel> _papers = [];
  bool _isLoading = false;
  String _selectedTier = 'Global';
  UserModel? _userProfile;

  static const List<Map<String, dynamic>> _courses = [
    {'name': 'BCA', 'icon': Icons.computer_rounded},
    {'name': 'B.Sc CS', 'icon': Icons.science_rounded},
    {'name': 'MCA', 'icon': Icons.terminal_rounded},
    {'name': 'B.Tech', 'icon': Icons.engineering_rounded},
    {'name': 'MBA', 'icon': Icons.business_center_rounded},
    {'name': 'B.Com', 'icon': Icons.account_balance_rounded},
    {'name': 'BA', 'icon': Icons.menu_book_rounded},
  ];

  static const List<Map<String, dynamic>> _semesters = [
    {'name': 'Semester 1', 'icon': Icons.looks_one_rounded},
    {'name': 'Semester 2', 'icon': Icons.looks_two_rounded},
    {'name': 'Semester 3', 'icon': Icons.looks_3_rounded},
    {'name': 'Semester 4', 'icon': Icons.looks_4_rounded},
    {'name': 'Semester 5', 'icon': Icons.looks_5_rounded},
    {'name': 'Semester 6', 'icon': Icons.looks_6_rounded},
  ];

  static const List<Map<String, dynamic>> _subjects = [
    {'name': 'Mathematics', 'icon': Icons.calculate_rounded},
    {'name': 'Computer Networks', 'icon': Icons.network_wifi_rounded},
    {'name': 'Software Engineering', 'icon': Icons.code_rounded},
    {'name': 'Data Structures', 'icon': Icons.account_tree_rounded},
    {'name': 'Operating Systems', 'icon': Icons.dns_rounded},
    {'name': 'Database Management', 'icon': Icons.storage_rounded},
    {'name': 'Web Technology', 'icon': Icons.web_rounded},
    {'name': 'General Studies', 'icon': Icons.auto_stories_rounded},
    {'name': 'C++ Programming', 'icon': Icons.code_rounded},
    {'name': 'Python Programming', 'icon': Icons.integration_instructions_rounded},
    {'name': 'Ethical Hacking', 'icon': Icons.security_rounded},
    {'name': 'Environmental Studies', 'icon': Icons.eco_rounded},
    {'name': 'Graphics Design', 'icon': Icons.brush_rounded},
    {'name': 'English', 'icon': Icons.language_rounded},
    {'name': 'Marathi', 'icon': Icons.translate_rounded},
    {'name': 'Constitution', 'icon': Icons.gavel_rounded},
    {'name': 'JavaScript', 'icon': Icons.javascript_rounded},
    {'name': 'Microprocessor', 'icon': Icons.memory_rounded},
    {'name': 'Essential of Computers', 'icon': Icons.computer_rounded},
    {'name': 'Office Management Tools', 'icon': Icons.work_rounded},
    {'name': 'Artificial Intelligence', 'icon': Icons.smart_toy_rounded},
    {'name': 'Employability Skills', 'icon': Icons.engineering_rounded},
    {'name': 'E-Commerce', 'icon': Icons.shopping_cart_rounded},
    {'name': 'Cloud Computing', 'icon': Icons.cloud_rounded},
    {'name': 'Web Development', 'icon': Icons.language_rounded},
    {'name': 'Data Analytics', 'icon': Icons.analytics_rounded},
    {'name': 'Machine Learning', 'icon': Icons.psychology_rounded},
    {'name': 'Entrepreneurship Development', 'icon': Icons.business_rounded},
    {'name': 'Cyber Security', 'icon': Icons.shield_rounded},
    {'name': 'Android Development', 'icon': Icons.phone_android_rounded},
    {'name': 'Data Mining', 'icon': Icons.dataset_rounded},
  ];

  String get _currentStep {
    if (_selectedCourse == null) return 'course';
    if (_selectedSemester == null) return 'semester';
    if (_selectedSubject == null) return 'subject';
    return 'papers';
  }

  void _goBack() {
    if (_selectedSubject != null) {
      setState(() => _selectedSubject = null);
    } else if (_selectedSemester != null) {
      setState(() => _selectedSemester = null);
    } else if (_selectedCourse != null) {
      setState(() => _selectedCourse = null);
    } else {
      context.pop();
    }
  }

  List<Map<String, dynamic>> get _currentSubjects {
    switch (_selectedSemester) {
      case 'Semester 1':
        return [
          {'name': 'Essential of Computers', 'icon': Icons.computer_rounded},
          {'name': 'C++ Programming', 'icon': Icons.code_rounded},
          {'name': 'Web Technology', 'icon': Icons.web_rounded},
          {'name': 'Office Management Tools', 'icon': Icons.work_rounded},
          {'name': 'Mathematics', 'icon': Icons.calculate_rounded},
        ];
      case 'Semester 2':
        return [
          {'name': 'C++ Programming', 'icon': Icons.code_rounded},
          {'name': 'Operating Systems', 'icon': Icons.dns_rounded},
          {'name': 'Web Technology', 'icon': Icons.web_rounded},
          {'name': 'Graphics Design', 'icon': Icons.brush_rounded},
          {'name': 'Environmental Studies', 'icon': Icons.eco_rounded},
        ];
      case 'Semester 3':
        return [
          {'name': 'Data Structures', 'icon': Icons.account_tree_rounded},
          {'name': 'Python Programming', 'icon': Icons.integration_instructions_rounded},
          {'name': 'Ethical Hacking', 'icon': Icons.security_rounded},
        ];
      case 'Semester 4':
        return [
          {'name': 'Database Management', 'icon': Icons.storage_rounded},
          {'name': 'Artificial Intelligence', 'icon': Icons.smart_toy_rounded},
          {'name': 'Graphics Design', 'icon': Icons.brush_rounded},
        ];
      case 'Semester 5':
        return [
          {'name': 'Employability Skills', 'icon': Icons.engineering_rounded},
          {'name': 'E-Commerce', 'icon': Icons.shopping_cart_rounded},
          {'name': 'Cloud Computing', 'icon': Icons.cloud_rounded},
          {'name': 'Web Development', 'icon': Icons.language_rounded},
          {'name': 'Data Analytics', 'icon': Icons.analytics_rounded},
          {'name': 'Machine Learning', 'icon': Icons.psychology_rounded},
        ];
      case 'Semester 6':
        return [
          {'name': 'Entrepreneurship Development', 'icon': Icons.business_rounded},
          {'name': 'Cyber Security', 'icon': Icons.shield_rounded},
          {'name': 'Android Development', 'icon': Icons.phone_android_rounded},
          {'name': 'Web Development', 'icon': Icons.language_rounded},
          {'name': 'Data Mining', 'icon': Icons.dataset_rounded},
        ];
      default:
        return _subjects;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        _userProfile = await ref.read(firestoreServiceProvider).getUserProfile(user.uid);
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    try {
      String? filterCollegeId;
      String? filterDistrict;
      String? filterState;
      
      if (_userProfile != null) {
        if (_selectedTier == 'My College' && _userProfile!.collegeId.isNotEmpty) {
          filterCollegeId = _userProfile!.collegeId;
        } else if (_selectedTier == 'My District' && _userProfile!.district.isNotEmpty) {
          filterDistrict = _userProfile!.district;
        } else if (_selectedTier == 'My State' && _userProfile!.state.isNotEmpty) {
          filterState = _userProfile!.state;
        }
      }

      final papers = await ref.read(firestoreServiceProvider).fetchQuestionPapers(
            course: _selectedCourse,
            semester: _selectedSemester,
            subject: _selectedSubject,
            collegeId: filterCollegeId,
            district: filterDistrict,
            state: filterState,
          );
      setState(() => _papers = papers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 130,
              backgroundColor: AppColors.success,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _goBack,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Previous Year Papers',
                        style: AppTextStyles.headingLarge
                            .copyWith(color: Colors.white, fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select course → semester → subject',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                collapseMode: CollapseMode.parallax,
              ),
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Breadcrumb Navigation ──
              _buildBreadcrumbs(),

              // ── Step Indicator ──
              _buildStepIndicator(),

              // ── Tier Filter Chips ──
              if (_currentStep == 'papers' && _userProfile != null && _userProfile!.collegeId.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['Global', 'My State', 'My District', 'My College'].map((tier) {
                      final isSelected = _selectedTier == tier;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tier),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedTier = tier);
                            _loadPapers();
                          },
                          selectedColor: AppColors.success.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.success,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.success : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.success : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (_currentStep == 'papers') const SizedBox(height: 8),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final List<String> crumbs = ['PYQ'];
    if (_selectedCourse != null) crumbs.add(_selectedCourse!);
    if (_selectedSemester != null) crumbs.add(_selectedSemester!);
    if (_selectedSubject != null) crumbs.add(_selectedSubject!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: crumbs.asMap().entries.map((entry) {
            final isLast = entry.key == crumbs.length - 1;
            return Row(
              children: [
                GestureDetector(
                  onTap: isLast
                      ? null
                      : () {
                          // Navigate to that level
                          if (entry.key == 0) {
                            setState(() {
                              _selectedCourse = null;
                              _selectedSemester = null;
                              _selectedSubject = null;
                            });
                          } else if (entry.key == 1) {
                            setState(() {
                              _selectedSemester = null;
                              _selectedSubject = null;
                            });
                          } else if (entry.key == 2) {
                            setState(() => _selectedSubject = null);
                          }
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLast
                          ? AppColors.success.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      entry.value,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isLast
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textSecondary),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Course', 'Semester', 'Subject', 'Papers'];
    final currentIndex = ['course', 'semester', 'subject', 'papers']
        .indexOf(_currentStep);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final isDone = idx < currentIndex;
          final isCurrent = idx == currentIndex;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.primary
                                  : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isCurrent
                              ? AppColors.primary
                              : isDone
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color:
                          isDone ? AppColors.success : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 'course':
        return _buildSelectionGrid(
          items: _courses,
          onSelect: (name) => setState(() => _selectedCourse = name),
          color: AppColors.success,
        );
      case 'semester':
        return _buildSelectionGrid(
          items: _semesters,
          onSelect: (name) => setState(() => _selectedSemester = name),
          color: AppColors.primary,
        );
      case 'subject':
        return _buildSelectionGrid(
          items: _currentSubjects,
          onSelect: (name) {
            setState(() => _selectedSubject = name);
            _loadPapers();
          },
          color: AppColors.accent,
        );
      case 'papers':
        return _buildPapersList();
      default:
        return const SizedBox();
    }
  }

  Widget _buildSelectionGrid({
    required List<Map<String, dynamic>> items,
    required void Function(String) onSelect,
    required Color color,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.35,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 250 + index * 60),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
          ),
          child: GestureDetector(
            onTap: () => onSelect(item['name'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9), // Translucent glass
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['name'] as String,
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPapersList() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (_papers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                size: 72, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No question papers uploaded yet',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text(
              'Papers for $_selectedSubject\nwill appear here once uploaded.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _papers.length,
      itemBuilder: (context, index) {
        final paper = _papers[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + index * 80),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)), child: child),
          ),
          child: GestureDetector(
            onTap: () => context.push('/pdf-viewer', extra: {
              'pdfUrl': paper.pdfUrl,
              'title': '${paper.subject} ${paper.year}',
              'isLocal': false,
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.quiz_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paper.title.isNotEmpty
                              ? paper.title
                              : '${paper.subject} — ${paper.year}',
                          style: AppTextStyles.headingSmall
                              .copyWith(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildMiniChip(paper.year, AppColors.warning),
                            const SizedBox(width: 6),
                            _buildMiniChip(paper.course, AppColors.success),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
