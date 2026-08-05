import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../models/post_model.dart';

class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  Future<void> _deletePost(String id, String contentSnippet) async {
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await FirebaseFirestore.instance.collection('posts').doc(id).delete();
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Delete Post',
          targetContent: contentSnippet,
          targetId: id,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _togglePinPost(String id, bool isCurrentlyPinned, String contentSnippet) async {
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await FirebaseFirestore.instance.collection('posts').doc(id).update({
        'isPinned': !isCurrentlyPinned,
      });
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: !isCurrentlyPinned ? 'Pin Post' : 'Unpin Post',
          targetContent: contentSnippet,
          targetId: id,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isCurrentlyPinned ? 'Post pinned successfully.' : 'Post unpinned successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pin/unpin: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCommentsDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => _AdminCommentsDialog(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading posts: ${snapshot.error}', style: AppTextStyles.bodyMedium));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data?.docs ?? [];
          if (posts.isEmpty) {
            return Center(child: Text('No posts available.', style: AppTextStyles.bodyMedium));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postData = posts[index].data() as Map<String, dynamic>;
              final post = PostModel.fromMap(postData, posts[index].id);
              final isPinned = postData['isPinned'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: post.authorPhotoUrl.isNotEmpty ? NetworkImage(post.authorPhotoUrl) : null,
                            child: post.authorPhotoUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post.authorName,
                              style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPinned)
                            const Icon(Icons.push_pin, color: AppColors.primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post.content,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showCommentsDialog(post.postId),
                            icon: const Icon(Icons.comment_outlined),
                            label: const Text('Comments'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _togglePinPost(
                              post.postId,
                              isPinned,
                              post.content.length > 20 ? '${post.content.substring(0, 20)}...' : post.content,
                            ),
                            icon: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                            label: Text(isPinned ? 'Unpin' : 'Pin'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isPinned ? AppColors.textSecondary : AppColors.primary,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _deletePost(
                              post.postId,
                              post.content.length > 20 ? '${post.content.substring(0, 20)}...' : post.content,
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminCommentsDialog extends ConsumerStatefulWidget {
  final String postId;
  const _AdminCommentsDialog({required this.postId});

  @override
  ConsumerState<_AdminCommentsDialog> createState() => _AdminCommentsDialogState();
}

class _AdminCommentsDialogState extends ConsumerState<_AdminCommentsDialog> {
  Future<void> _deleteComment(String commentId, String content) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('comments').doc(commentId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 400,
        height: 500,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('comments')
                    .where('contentId', isEqualTo: widget.postId)
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('No comments found.'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: data['authorPhotoUrl'] != null && data['authorPhotoUrl'].toString().isNotEmpty
                              ? NetworkImage(data['authorPhotoUrl'])
                              : null,
                          child: data['authorPhotoUrl'] == null || data['authorPhotoUrl'].toString().isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(data['authorName'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['text'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _deleteComment(docs[index].id, data['text'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

