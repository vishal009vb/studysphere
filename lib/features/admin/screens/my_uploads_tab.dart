import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/auth_service.dart';

class MyUploadsAdminTab extends ConsumerStatefulWidget {
  const MyUploadsAdminTab({super.key});

  @override
  ConsumerState<MyUploadsAdminTab> createState() => _MyUploadsAdminTabState();
}

class _MyUploadsAdminTabState extends ConsumerState<MyUploadsAdminTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteDocument(String collection, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Upload'),
        content: const Text('Are you sure you want to delete this upload? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection(collection).doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Upload deleted successfully'),
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
  }

  void _editUpload(Map<String, dynamic> data, String id, String type) {
    // We can reuse the upload bottom sheet or show a dialog
    // For now, we will just show a dialog to edit title and subject
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final subjectCtrl = TextEditingController(text: data['subject'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseFirestore.instance.collection(type).doc(id).update({
                  'title': titleCtrl.text,
                  'subject': subjectCtrl.text,
                });
                navigator.pop();
                messenger.showSnackBar(const SnackBar(
                  content: Text('Updated successfully'),
                  backgroundColor: AppColors.success,
                ));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Failed to update: $e'),
                  backgroundColor: AppColors.error,
                  ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildList(String collection) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('uploadedBy', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data?.docs ?? [];
        // Optional: filter out books from notes if collection == 'notes'
        // For books, we just show empty since there's no books collection yet
        if (collection == 'books') {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_books, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('Books upload feature coming soon.', style: AppTextStyles.bodyLarge),
              ],
            ),
          );
        }

        if (docs.isEmpty) {
          return const Center(child: Text('No uploads found in this category.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final subject = data['subject'] ?? 'No subject';
            final status = data['status'] ?? 'pending';
            final pdfUrl = data['pdfUrl'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(collection == 'notes' ? Icons.description : Icons.quiz, color: AppColors.primary),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.headingSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    _buildStatusChip(status),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(subject, style: AppTextStyles.bodyMedium),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye, color: AppColors.primary),
                      tooltip: 'View PDF',
                      onPressed: () {
                        context.push('/pdf-viewer', extra: {
                          'pdfUrl': pdfUrl,
                          'title': title,
                          'isLocal': false,
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit Details',
                      onPressed: () => _editUpload(data, doc.id, collection),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      tooltip: 'Delete Upload',
                      onPressed: () => _deleteDocument(collection, doc.id),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Text('My Uploads', style: AppTextStyles.headingMedium),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Question Papers'),
            Tab(text: 'Books'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList('notes'),
              _buildList('questionPapers'),
              _buildList('books'),
            ],
          ),
        ),
      ],
    );
  }
}
