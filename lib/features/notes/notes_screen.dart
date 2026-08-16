import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_cache_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/note_model.dart';
import '../../models/user_model.dart';
import '../../core/widgets/shimmer_widgets.dart';
import '../upload/upload_bottom_sheet.dart';
import 'package:flutter/services.dart';

class NotesScreen extends ConsumerStatefulWidget {
  final String? initialCourse;
  final String? initialSemester;
  final String? initialSearch;

  const NotesScreen({
    super.key,
    this.initialCourse,
    this.initialSemester,
    this.initialSearch,
  });

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCourse = '';
  String _selectedSemester = '';
  String _sortBy = 'createdAt';
  String _searchQuery = '';
  String _selectedTier = 'Global'; // 'My College', 'My District', 'My State', 'Global'
  List<NoteModel> _notes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreNotes = true;
  Timer? _searchDebounce;
  // Cursor for real pagination. Previously each page re-fetched every prior
  // page by growing limit (15, 30, 45...), which is quadratic.
  DocumentSnapshot? _lastNoteDoc;

  UserModel? _userProfile;
  late AnimationController _fabAnimCtrl;
  final ScrollController _scrollController = ScrollController();

  static const List<String> _courses = [
    'All',
    'BCA',
    'B.Sc CS',
    'MCA',
    'B.Tech',
    'MBA',
    'B.Com',
    'BA',
  ];

  // Subject mapping for all courses
  static const Map<String, Map<String, List<String>>> _courseSubjects = {
    'BCA': {
      'Semester 1': ['Problem Solving Using Computers', 'Business Communication', 'Principles of Management', 'Mathematics-I', 'Digital Computer Fundamentals', 'Lab: C Programming'],
      'Semester 2': ['C Programming', 'Financial Accounting', 'Organizational Behavior', 'Mathematics-II', 'Data Structures', 'Lab: Data Structures'],
      'Semester 3': ['Object Oriented Programming (C++)', 'DBMS', 'Software Engineering', 'Discrete Mathematics', 'Computer Networks', 'Lab: C++ & DBMS'],
      'Semester 4': ['Java Programming', 'Operating Systems', 'Web Technologies', 'Computer Graphics', 'Statistical Methods', 'Lab: Java & Web'],
      'Semester 5': ['Python Programming', 'Internet & E-Commerce', 'Artificial Intelligence', 'Computer Architecture', 'Elective-I', 'Lab: Python'],
      'Semester 6': ['Cloud Computing', 'Cyber Security', 'Mobile App Development', 'Project Work', 'Elective-II', 'Lab: Project'],
    },
    'B.Sc CS': {
      'Semester 1': ['Computer Fundamentals', 'Digital Logic', 'Programming in C'],
      'Semester 2': ['Data Structures', 'Mathematics for CS', 'Advanced C'],
      'Semester 3': ['DBMS', 'C++ Programming', 'Software Engineering'],
      'Semester 4': ['Operating Systems', 'Java Programming', 'Computer Networks'],
      'Semester 5': ['Web Technologies', 'Python', 'Microprocessors'],
      'Semester 6': ['Artificial Intelligence', 'Project', 'Cyber Security'],
    },
    'MCA': {
      'Semester 1': ['Advanced Data Structures', 'Advanced DBMS', 'Java'],
      'Semester 2': ['Advanced OS', 'Cloud Computing', 'Machine Learning'],
      'Semester 3': ['Deep Learning', 'Big Data Analytics', 'Mini Project'],
      'Semester 4': ['Major Project', 'Internship'],
    },
    'B.Tech': {
      'Semester 1': ['Engineering Physics', 'Engineering Maths I', 'Basic Electronics'],
      'Semester 2': ['Engineering Chemistry', 'Engineering Maths II', 'C Programming'],
      'Semester 3': ['Data Structures', 'Digital Electronics', 'Discrete Math'],
      'Semester 4': ['Design & Analysis of Algorithms', 'OS', 'DBMS'],
      'Semester 5': ['Computer Networks', 'Automata Theory', 'Software Eng'],
      'Semester 6': ['Compiler Design', 'AI', 'Machine Learning'],
      'Semester 7': ['Cloud Computing', 'Cryptography', 'Elective'],
      'Semester 8': ['Major Project', 'Internship'],
    },
    'MBA': {
      'Semester 1': ['Management Principles', 'Managerial Economics', 'Accounting'],
      'Semester 2': ['Financial Management', 'Marketing Management', 'HRM'],
      'Semester 3': ['Strategic Management', 'Business Analytics', 'Elective I'],
      'Semester 4': ['Entrepreneurship', 'Project Work', 'Elective II'],
    },
    'B.Com': {
      'Semester 1': ['Financial Accounting', 'Business Organization', 'Economics'],
      'Semester 2': ['Business Law', 'Cost Accounting', 'Business Maths'],
      'Semester 3': ['Corporate Accounting', 'Income Tax Law', 'Auditing'],
      'Semester 4': ['Management Accounting', 'Business Communication'],
      'Semester 5': ['Financial Management', 'E-Commerce'],
      'Semester 6': ['GST & Customs Law', 'Project'],
    },
    'BA': {
      'Semester 1': ['History-I', 'Political Science-I', 'English'],
      'Semester 2': ['History-II', 'Political Science-II', 'Sociology'],
      'Semester 3': ['Public Administration', 'Economics-I', 'Literature'],
      'Semester 4': ['Modern History', 'Economics-II'],
      'Semester 5': ['Indian Polity', 'International Relations'],
      'Semester 6': ['Project / Dissertation', 'Elective'],
    },
  };

  String _selectedSubject = '';

  List<String> get _currentSubjects {
    if (_selectedCourse.isEmpty || _selectedCourse == 'All') return [];
    
    final courseMap = _courseSubjects[_selectedCourse] ?? {};
    if (courseMap.isEmpty) return [];

    final sem = _selectedSemester;
    if (sem.isEmpty || sem == 'All') {
      // Return all subjects for this course flattened
      return courseMap.values.expand((s) => s).toSet().toList();
    }
    return courseMap[sem] ?? [];
  }

  List<String> get _semesters {
    if (_selectedCourse.isEmpty || _selectedCourse == 'All') {
      return ['All', ...List.generate(6, (i) => 'Semester ${i + 1}')];
    }
    final courseMap = _courseSubjects[_selectedCourse];
    if (courseMap != null && courseMap.isNotEmpty) {
      final maxSem = courseMap.keys.length;
      return ['All', ...List.generate(maxSem, (i) => 'Semester ${i + 1}')];
    }
    return ['All', ...List.generate(6, (i) => 'Semester ${i + 1}')];
  }

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.initialCourse ?? '';
    _selectedSemester = widget.initialSemester ?? '';
    _searchQuery = widget.initialSearch ?? '';
    _selectedSubject = '';
    
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreNotes();
      }
    });
    
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      // Reuse the shared cached profile instead of issuing another read for a
      // document the app has already fetched.
      _userProfile = await ref.read(userProfileProvider.future);
    } catch (e) {
      // ignore
    } finally {
      _loadNotes();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fabAnimCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Tier filters, shared by the first page and by _loadMoreNotes so both apply
  // the same constraints.
  String? _tierCollegeId() =>
      (_selectedTier == 'My College' && (_userProfile?.collegeId.isNotEmpty ?? false))
          ? _userProfile!.collegeId
          : null;

  String? _tierDistrict() =>
      (_selectedTier == 'My District' && (_userProfile?.district.isNotEmpty ?? false))
          ? _userProfile!.district
          : null;

  String? _tierState() =>
      (_selectedTier == 'My State' && (_userProfile?.state.isNotEmpty ?? false))
          ? _userProfile!.state
          : null;

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _hasMoreNotes = true;
      _lastNoteDoc = null; // reset the pagination cursor for a fresh query
    });
    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      final page = await firestoreService.fetchNotesPage(
        course: _selectedCourse.isEmpty || _selectedCourse == 'All' ? null : _selectedCourse,
        semester: _selectedSemester.isEmpty || _selectedSemester == 'All' ? null : _selectedSemester,
        sortBy: _sortBy,
        collegeId: _tierCollegeId(),
        district: _tierDistrict(),
        state: _tierState(),
        limit: 15,
      );
      final notes = page.notes;
      _lastNoteDoc = page.lastDoc;

      // We handle client side subject filtering by loading more if needed but for phase 1 we just keep it simple
      if (_selectedSubject.isNotEmpty || _searchQuery.isNotEmpty) {
        _hasMoreNotes = false; // Disable pagination on search/subject filter
        final filtered = notes.where((n) {
          final q = _searchQuery.toLowerCase();
          final s = _selectedSubject.toLowerCase();
          return (s.isEmpty || n.subject.toLowerCase().contains(s) || n.title.toLowerCase().contains(s)) &&
                 (q.isEmpty || n.title.toLowerCase().contains(q) || n.subject.toLowerCase().contains(q) || n.description.toLowerCase().contains(q));
        }).toList();
        setState(() => _notes = filtered);
      } else {
        setState(() {
          _notes = notes;
          if (notes.length < 15) _hasMoreNotes = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_isLoading || _isLoadingMore || !_hasMoreNotes || _selectedSubject.isNotEmpty || _searchQuery.isNotEmpty) return;
    
    setState(() => _isLoadingMore = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      // Cursor pagination: fetch only the next page. This also carries the tier
      // filters, which the old grow-the-limit version silently dropped (so
      // page 2 returned a different result set than page 1).
      final page = await firestoreService.fetchNotesPage(
        course: _selectedCourse.isEmpty || _selectedCourse == 'All' ? null : _selectedCourse,
        semester: _selectedSemester.isEmpty || _selectedSemester == 'All' ? null : _selectedSemester,
        sortBy: _sortBy,
        collegeId: _tierCollegeId(),
        district: _tierDistrict(),
        state: _tierState(),
        limit: 15,
        lastDoc: _lastNoteDoc,
      );

      setState(() {
        if (page.notes.isEmpty) {
          _hasMoreNotes = false;
        } else {
          _notes = [..._notes, ...page.notes];
          _lastNoteDoc = page.lastDoc;
        }
      });
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const UploadBottomSheet(),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA197F6), Color(0xFF8F85EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33A197F6),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFA197F6), size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Upload your notes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Share with the community',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showSortBottomSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.filter_list_rounded, color: Color(0xFF7C72E8), size: 22),
                  ),
                ),
              ),
            ],
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/header_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE9E7FC), Color(0xFFC7C2FA), Color(0xFFA197F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 50, 130, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Study Notes',
                            style: AppTextStyles.headingLarge.copyWith(
                              color: const Color(0xFF1E1E2E),
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Browse curated notes from top contributors',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: const Color(0xFF6E6D7A),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search notes, subjects...',
                    hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFA197F6)),
                    suffixIcon: Icon(Icons.tune_rounded, color: Color(0xFFA197F6)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    // Debounced: this used to fire a Firestore query on every
                    // keystroke, so a 15-character search cost 15 queries.
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 450),
                      () {
                        if (mounted) _loadNotes();
                      },
                    );
                  },
                ),
              ),
            ),

            // ── Tier Filter Chips (horizontal scroll) ──
            if (_userProfile != null && _userProfile!.collegeId.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ['Global', 'My State', 'My District', 'My College'].map((tier) {
                    final isSelected = _selectedTier == tier;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(tier),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedTier = tier);
                          _loadNotes();
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

            // ── Course Filter Chips (horizontal scroll) ──
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final isSelected = course == 'All'
                      ? _selectedCourse.isEmpty
                      : _selectedCourse == course;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: FilterChip(
                        label: Text(course),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCourse = course == 'All' ? '' : course;
                            final validSems = _semesters;
                            if (!validSems.contains(_selectedSemester)) {
                              _selectedSemester = '';
                            }
                          });
                          _loadNotes();
                        },
                        selectedColor: const Color(0xFFA197F6),
                        checkmarkColor: Colors.white,
                        showCheckmark: true,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF6E6D7A),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : const Color(0xFFE5E5EA),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Semester Filter Chips ──
            if (_semesters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _semesters.length,
                    itemBuilder: (context, index) {
                      String sem = _semesters[index];
                      // Transform "Semester 1" to "Sem 1" and "All" to "All Semesters"
                      String displaySem = sem;
                      if (sem == 'All') {
                        displaySem = 'All Semesters';
                      } else if (sem.startsWith('Semester ')) {
                        displaySem = sem.replaceFirst('Semester ', 'Sem ');
                      }
                      
                      final isSelected = sem == 'All'
                          ? _selectedSemester.isEmpty
                          : _selectedSemester == sem;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: isSelected ? const Icon(Icons.bookmark, color: Colors.white, size: 16) : null,
                          label: Text(displaySem),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedSemester = sem == 'All' ? '' : sem;
                            });
                            _loadNotes();
                          },
                          selectedColor: const Color(0xFFA197F6),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF6E6D7A),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── BCA Subject chips ──
            if (_currentSubjects.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _currentSubjects.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final subject = isAll ? 'All Subjects' : _currentSubjects[index - 1];
                    final isSelected = isAll
                        ? _selectedSubject.isEmpty
                        : _selectedSubject == subject;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(subject),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedSubject = isAll ? '' : subject;
                          });
                          _loadNotes();
                        },
                        selectedColor: AppColors.primary,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : const Color(0xFFE4E2FF),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // ── Results count ──
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '${_notes.length} notes found',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6E6D7A),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showSortBottomSheet,
                      child: Row(
                        children: [
                          Text(
                            'Sort by: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF9E9EA7),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _sortBy == 'createdAt' ? 'Latest' : (_sortBy == 'downloads' ? 'Popular' : 'Best'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFA197F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFA197F6), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // ── Notes List ──
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList()
                  : _notes.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _notes.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _notes.length) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ));
                              }
                              return _buildNoteCard(_notes[index], index);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (note.noteId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Invalid note. Please try again."),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          context.push('/notes/${note.noteId}');
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E7FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Color(0xFFA197F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.subject,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6E6D7A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9E7FC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              note.course.isNotEmpty ? note.course : 'General',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA197F6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${note.downloads} downloads',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9EA7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.bookmark_border_rounded, color: Color(0xFFC7C2FA), size: 22),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C2FA), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return const NoteListShimmer(count: 6);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 52,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text('No notes found', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          Text(
            'Try a different course, semester, or search term.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedCourse = '';
                _selectedSemester = '';
                _searchQuery = '';
              });
              _loadNotes();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 20),
            Text('Sort Notes By', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ...[
              ('createdAt', Icons.schedule_rounded, 'Latest First'),
              ('downloads', Icons.download_rounded, 'Most Downloaded'),
              ('likes', Icons.favorite_rounded, 'Most Liked'),
              ('qualityScore', Icons.star_rounded, 'Quality Score'),
            ].map((item) {
              final (value, icon, label) = item;
              return ListTile(
                leading: Icon(
                  icon,
                  color:
                      _sortBy == value ? AppColors.primary : AppColors.textSecondary,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: _sortBy == value
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: _sortBy == value
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == value
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = value);
                  _loadNotes();
                  Navigator.pop(context);
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            }),
          ],
        ),
      ),
    );
  }
}
