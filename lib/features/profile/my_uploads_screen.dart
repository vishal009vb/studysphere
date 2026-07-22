import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/note_model.dart';
import '../../models/question_paper_model.dart';
import '../../core/widgets/animated_transition.dart';

class MyUploadsScreen extends ConsumerStatefulWidget {
  const MyUploadsScreen({super.key});

  @override
  ConsumerState<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends ConsumerState<MyUploadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NoteModel> _notes = [];
  List<QuestionPaperModel> _papers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUploads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUploads() async {
    setState(() => _isLoading = true);
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    try {
      final svc = ref.read(firestoreServiceProvider);
      final results = await Future.wait([
        svc.fetchUserUploads(user.uid),
        svc.fetchUserPapers(user.uid),
      ]);

      if (mounted) {
        setState(() {
          _notes = results[0] as List<NoteModel>;
          _papers = results[1] as List<QuestionPaperModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load uploads: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _deleteItem(String id, bool isNote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Upload?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final svc = ref.read(firestoreServiceProvider);
      if (isNote) {
        await svc.deleteNote(id);
      } else {
        await svc.deleteQuestionPaper(id);
      }
      await _fetchUploads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Upload deleted.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _editItem(dynamic item, bool isNote) {
    // A simple edit dialog for Phase 3
    final titleCtrl = TextEditingController(text: item.title);
    final courseCtrl = TextEditingController(text: item.course);
    final semesterCtrl = TextEditingController(text: item.semester);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Metadata', style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseCtrl,
                decoration: const InputDecoration(labelText: 'Course'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: semesterCtrl,
                decoration: const InputDecoration(labelText: 'Semester'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final svc = ref.read(firestoreServiceProvider);
                    if (isNote) {
                      final updated = (item as NoteModel).copyWith(
                        title: titleCtrl.text,
                        course: courseCtrl.text,
                        semester: semesterCtrl.text,
                      );
                      await svc.updateNote(updated);
                    } else {
                      final updated = (item as QuestionPaperModel).copyWith(
                        title: titleCtrl.text,
                        course: courseCtrl.text,
                        semester: semesterCtrl.text,
                      );
                      await svc.updateQuestionPaper(updated);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchUploads();
                    }
                  } catch (e) {
                    // error
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Uploads'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Papers'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_notes, true),
                _buildList(_papers, false),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, bool isNote) {
    if (items.isEmpty) {
      return Center(
        child: Text('No uploads found.', style: AppTextStyles.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = isNote ? (item as NoteModel).noteId : (item as QuestionPaperModel).paperId;
        final status = isNote ? (item as NoteModel).status : (item as QuestionPaperModel).status;

        return AnimatedTransition.slideUp(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: Icon(
                isNote ? Icons.description_rounded : Icons.quiz_rounded,
                color: AppColors.primary,
              ),
              title: Text(item.title, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
              subtitle: Text('${item.course} • ${item.semester}\nStatus: ${status.toUpperCase()}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    _editItem(item, isNote);
                  } else if (val == 'delete') {
                    _deleteItem(id, isNote);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ),
          ),
          delay: Duration(milliseconds: index * 50),
        );
      },
    );
  }
}
