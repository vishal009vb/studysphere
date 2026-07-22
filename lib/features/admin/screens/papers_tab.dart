import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../models/question_paper_model.dart';
import '../../upload/upload_bottom_sheet.dart';
import 'bulk_upload_dialog.dart';
import 'dart:async';

class PapersTab extends ConsumerStatefulWidget {
  const PapersTab({super.key});

  @override
  ConsumerState<PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends ConsumerState<PapersTab> {
  List<QuestionPaperModel> _papers = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _searchField = 'title'; // 'title' or 'subject'
  String _filterCourse = 'All';
  String _filterStatus = 'All';
  final Set<String> _selectedIds = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPapers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isFetchingMore && _hasMore) {
        _loadMorePapers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPapers() async {
    setState(() {
      _isLoading = true;
      _papers = [];
      _lastDoc = null;
      _hasMore = true;
      _selectedIds.clear();
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getPapersPaginated(
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        courseFilter: _filterCourse == 'All' ? null : _filterCourse,
        statusFilter: _filterStatus == 'All' ? null : _filterStatus,
      );
      
      if (mounted) {
        setState(() {
          _papers = result['papers'] as List<QuestionPaperModel>;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = _papers.length >= 50;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading papers: \$e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePapers() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getPapersPaginated(
        startAfter: _lastDoc,
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        courseFilter: _filterCourse == 'All' ? null : _filterCourse,
        statusFilter: _filterStatus == 'All' ? null : _filterStatus,
      );

      final newPapers = result['papers'] as List<QuestionPaperModel>;
      if (mounted) {
        setState(() {
          _papers.addAll(newPapers);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newPapers.length >= 50;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
      });
      _loadPapers();
    });
  }

  Future<void> _moderatePaper(String id, String decision, String title) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await firestoreService.moderateQuestionPaper(id, decision);
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: decision == 'approved' ? 'Approve Paper' : 'Reject Paper',
          targetContent: title,
          targetId: id,
        );
      }
      _loadPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paper \$decision successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: \$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deletePaper(String id, String title) async {
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await FirebaseFirestore.instance.collection('questionPapers').doc(id).delete();
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Delete Paper',
          targetContent: title,
          targetId: id,
        );
      }
      _loadPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper deleted successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: \$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _bulkAction(String action) async {
    final ids = _selectedIds.toList();
    final user = ref.read(authServiceProvider).currentUser;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (var id in ids) {
        final ref = FirebaseFirestore.instance.collection('questionPapers').doc(id);
        if (action == 'delete') {
          batch.delete(ref);
        } else {
          batch.update(ref, {'status': action});
        }
      }
      await batch.commit();
      
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Bulk \$action Papers',
          targetContent: '\${ids.length} items',
          targetId: 'bulk',
        );
      }
      
      _loadPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk \$action successful.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: \$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Papers', style: AppTextStyles.headingMedium),
                const SizedBox(height: 16),
                
                // Search & Filters
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search papers...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _searchField,
                      items: ['title', 'subject'].map((e) => DropdownMenuItem(value: e, child: Text('By \$e'))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _searchField = val);
                          if (_searchQuery.isNotEmpty) _loadPapers();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterCourse,
                        decoration: const InputDecoration(labelText: 'Course', border: OutlineInputBorder()),
                        items: ['All', 'BCA', 'Global']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterCourse = val);
                            _loadPapers();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: ['All', 'Pending', 'Approved', 'Rejected']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterStatus = val);
                            _loadPapers();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Text('\${_selectedIds.length} items selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          onPressed: () => _bulkAction('approved'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                          onPressed: () => _bulkAction('rejected'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          onPressed: () => _bulkAction('delete'),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _papers.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('No papers found matching criteria.', style: AppTextStyles.bodyMedium)))
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(AppColors.surface),
                              onSelectAll: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedIds.addAll(_papers.map((d) => d.paperId));
                                  } else {
                                    _selectedIds.clear();
                                  }
                                });
                              },
                              columns: const [
                                DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Course', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: [
                                ..._papers.map((paper) {
                                  final isApproved = paper.status == 'approved';
                                  return DataRow(
                                    selected: _selectedIds.contains(paper.paperId),
                                    onSelectChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(paper.paperId);
                                        } else {
                                          _selectedIds.remove(paper.paperId);
                                        }
                                      });
                                    },
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(paper.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                            IconButton(
                                              icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                                              onPressed: () {
                                                context.push('/pdf-viewer', extra: {
                                                  'pdfUrl': paper.pdfUrl,
                                                  'title': paper.title,
                                                  'isLocal': false,
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(paper.subject)),
                                      DataCell(Text(paper.course)),
                                      DataCell(Text(paper.year.toString())),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isApproved ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            paper.status.toUpperCase(),
                                            style: TextStyle(
                                              color: isApproved ? AppColors.success : AppColors.warning,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isApproved) ...[
                                              TextButton(
                                                onPressed: () => _moderatePaper(paper.paperId, 'approved', paper.title),
                                                child: const Text('Approve', style: TextStyle(color: AppColors.success)),
                                              ),
                                              TextButton(
                                                onPressed: () => _moderatePaper(paper.paperId, 'rejected', paper.title),
                                                child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                                              ),
                                            ],
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                              onPressed: () => _deletePaper(paper.paperId, paper.title),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                                if (_isFetchingMore)
                                  const DataRow(cells: [
                                    DataCell(CircularProgressIndicator()),
                                    DataCell(Text('Loading more...')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                  ])
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Single Paper Upload'),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const UploadBottomSheet(),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: const Text('Bulk Folder Upload'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const BulkUploadDialog(uploadType: 'Question Papers'),
                    );
                  },
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.upload, color: Colors.white),
        label: const Text('Upload Papers', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
