import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/animated_transition.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/note_model.dart';
import '../../models/user_model.dart';
import '../../core/widgets/shimmer_widgets.dart';
import '../upload/upload_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DocumentSnapshot? _lastDoc;
  
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
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        _userProfile = await ref.read(firestoreServiceProvider).getUserProfile(user.uid);
      }
    } catch (e) {
      // ignore
    } finally {
      _loadNotes();
    }
  }

  @override
  void dispose() {
    _fabAnimCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _lastDoc = null;
      _hasMoreNotes = true;
    });
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      String? filterCollegeId;
      String? filterDistrict;
      String? filterState;
      
      if (_userProfile != null) {
        if (_selectedTier == 'My College' && _userProfile!.collegeId != null && _userProfile!.collegeId!.isNotEmpty) {
          filterCollegeId = _userProfile!.collegeId;
        } else if (_selectedTier == 'My District' && _userProfile!.district != null && _userProfile!.district!.isNotEmpty) {
          filterDistrict = _userProfile!.district;
        } else if (_selectedTier == 'My State' && _userProfile!.state != null && _userProfile!.state!.isNotEmpty) {
          filterState = _userProfile!.state;
        }
      }

      final querySnapshot = await FirebaseFirestore.instance.collection('notes')
          .where('status', isEqualTo: 'approved')
          .limit(15).get(); // Quick fetch logic via custom paginated method below

      final notes = await firestoreService.fetchNotes(
        course: _selectedCourse.isEmpty || _selectedCourse == 'All' ? null : _selectedCourse,
        semester: _selectedSemester.isEmpty || _selectedSemester == 'All' ? null : _selectedSemester,
        sortBy: _sortBy,
        collegeId: filterCollegeId,
        district: filterDistrict,
        state: filterState,
        limit: 15,
      );

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
      // Wait we don't have the last doc because we sorted client side.
      // Since we sort client side, we can't easily do cursor pagination with firestore `startAfter`.
      // Let's fallback to limit offset if possible, but firestore doesn't support offset easily without reading all.
      // For now, in Phase 1, we fetch more items by increasing limit if sorting by likes etc, 
      // or we just rely on the first 30 items.
      final notes = await firestoreService.fetchNotes(
        course: _selectedCourse.isEmpty || _selectedCourse == 'All' ? null : _selectedCourse,
        semester: _selectedSemester.isEmpty || _selectedSemester == 'All' ? null : _selectedSemester,
        sortBy: _sortBy,
        limit: _notes.length + 15,
      );
      
      setState(() {
        if (notes.length <= _notes.length) {
          _hasMoreNotes = false;
        }
        _notes = notes;
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C72E8), Color(0xFF9F97F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C72E8).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Upload your notes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Share with the community',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
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
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Study Notes',
                      style: AppTextStyles.headingLarge
                          .copyWith(color: Colors.white, fontSize: 26),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Browse curated notes from top contributors',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.sort_rounded, color: Colors.white),
                onPressed: _showSortBottomSheet,
                tooltip: 'Sort',
              ),
            ],
          ),
        ],
        body: Column(
          children: [
            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search notes, subjects...',
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadNotes();
                  },
                ),
              ),
            ),

            // ── Tier Filter Chips (horizontal scroll) ──
            if (_userProfile != null && _userProfile!.collegeId != null && _userProfile!.collegeId!.isNotEmpty)
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
                        selectedColor: AppColors.success.withOpacity(0.15),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final isSelected = course == 'All'
                      ? _selectedCourse.isEmpty
                      : _selectedCourse == course;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Semester Filter Chips ──
            if (_semesters.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _semesters.length,
                itemBuilder: (context, index) {
                  final sem = _semesters[index];
                  final isSelected = sem == 'All'
                      ? _selectedSemester.isEmpty
                      : _selectedSemester == sem;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(sem),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedSemester = sem == 'All' ? '' : sem;
                        });
                        _loadNotes();
                      },
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '${_notes.length} notes found',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_sortBy != 'createdAt')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Sorted: ${_getSortLabel()}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon matching Figma
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note.subject,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              note.course.isNotEmpty ? note.course : 'General',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${note.downloads} downloads',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFC4C2E8), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

  Widget _statItem(IconData icon, String label,
      {Color color = AppColors.textSecondary}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
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
              color: AppColors.textSecondary.withOpacity(0.5),
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

  String _getSortLabel() {
    switch (_sortBy) {
      case 'downloads':
        return 'Most Downloaded';
      case 'likes':
        return 'Most Liked';
      case 'qualityScore':
        return 'Quality Score';
      default:
        return 'Latest';
    }
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
