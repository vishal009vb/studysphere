import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/note_model.dart';
import 'dart:async';

class AiScraperTab extends ConsumerStatefulWidget {
  const AiScraperTab({super.key});

  @override
  ConsumerState<AiScraperTab> createState() => _AiScraperTabState();
}

class _AiScraperTabState extends ConsumerState<AiScraperTab> {
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _searchField = 'title'; // 'title' or 'subject'
  final Set<String> _selectedIds = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isFetchingMore && _hasMore) {
        _loadMoreNotes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _notes = [];
      _lastDoc = null;
      _hasMore = true;
      _selectedIds.clear();
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getNotesPaginated(
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        uploadedBy: 'AI_SCRAPER',
      );
      
      if (mounted) {
        setState(() {
          _notes = result['notes'] as List<NoteModel>;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = _notes.length >= 50;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading scraper notes: \$e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getNotesPaginated(
        startAfter: _lastDoc,
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        uploadedBy: 'AI_SCRAPER',
      );

      final newNotes = result['notes'] as List<NoteModel>;
      if (mounted) {
        setState(() {
          _notes.addAll(newNotes);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newNotes.length >= 50;
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
      _loadNotes();
    });
  }

  Future<void> _moderate(String id, String decision) async {
    try {
      await ref.read(firestoreServiceProvider).moderateNote(id, decision);
      _loadNotes();
    } catch (e) {
      debugPrint('Error: \$e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('notes').doc(id).delete();
      _loadNotes();
    } catch (e) {
      debugPrint('Error: \$e');
    }
  }

  Future<void> _bulkAction(String action) async {
    final ids = _selectedIds.toList();
    final user = ref.read(authServiceProvider).currentUser;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (var id in ids) {
        final ref = FirebaseFirestore.instance.collection('notes').doc(id);
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
          action: 'Bulk \$action Scraper Notes',
          targetContent: '\${ids.length} items',
          targetId: 'bulk',
        );
      }
      
      _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk \$action successful.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed: \$e'), backgroundColor: AppColors.error),
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
                Text('AI Scraper Uploads', style: AppTextStyles.headingMedium),
                const SizedBox(height: 16),
                
                // Search
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search scraper notes...',
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
                      items: ['title', 'subject'].map((e) => DropdownMenuItem(value: e, child: const Text('By \$e'))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _searchField = val);
                          if (_searchQuery.isNotEmpty) _loadNotes();
                        }
                      },
                    ),
                  ],
                ),
                
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Text('\${_selectedIds.length} items selected', style: TextStyle(fontWeight: FontWeight.bold)),
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
                : _notes.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('No AI Scraper uploads found.', style: AppTextStyles.bodyMedium)))
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
                              headingRowColor: WidgetStateProperty.all(AppColors.surface),
                              onSelectAll: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedIds.addAll(_notes.map((d) => d.noteId));
                                  } else {
                                    _selectedIds.clear();
                                  }
                                });
                              },
                              columns: const [
                                DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: [
                                ..._notes.map((note) {
                                  final createdAt = note.createdAt;
                                  final dateStr = "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

                                  
                                  return DataRow(
                                    selected: _selectedIds.contains(note.noteId),
                                    onSelectChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(note.noteId);
                                        } else {
                                          _selectedIds.remove(note.noteId);
                                        }
                                      });
                                    },
                                    cells: [
                                      DataCell(Text(note.title)),
                                      DataCell(Text(note.status.toUpperCase())),
                                      DataCell(Text(dateStr)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                                              onPressed: () {
                                                context.push('/pdf-viewer', extra: {
                                                  'pdfUrl': note.pdfUrl,
                                                  'title': note.title,
                                                  'isLocal': false,
                                                });
                                              },
                                            ),
                                            if (note.status != 'approved')
                                              TextButton(onPressed: () => _moderate(note.noteId, 'approved'), child: const Text('Approve')),
                                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(note.noteId)),
                                          ],
                                        )
                                      ),
                                    ],
                                  );
                                }),
                                if (_isFetchingMore)
                                  const DataRow(cells: [
                                    DataCell(CircularProgressIndicator()),
                                    DataCell(Text('Loading more...')),
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
    );
  }
}
