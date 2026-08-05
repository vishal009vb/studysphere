import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/note_model.dart';
import '../../models/comment_model.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  NoteModel? _note;
  UserModel? _uploaderProfile;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isDownloading = false;
  List<CommentModel> _comments = [];
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNoteDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNoteDetails() async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final db = FirebaseFirestore.instance;

      // Fetch note directly by ID with fallback
      DocumentSnapshot<Map<String, dynamic>> noteDoc;
      try {
        noteDoc = await db.collection('notes').doc(widget.noteId).get();
      } catch (_) {
        noteDoc = await db
            .collection('notes')
            .doc(widget.noteId)
            .get(const GetOptions(source: Source.serverAndCache));
      }

      if (!noteDoc.exists || noteDoc.data() == null) {
        throw Exception('Note not found');
      }
      final note = NoteModel.fromMap(noteDoc.data()!, noteDoc.id);

      final svc = ref.read(firestoreServiceProvider);
      UserModel? uploader;
      if (note.uploadedBy.isNotEmpty) {
        try {
          uploader = await svc.getUserProfile(note.uploadedBy);
        } catch (_) {}
      }

      // Increment view count asynchronously
      db.collection('notes').doc(widget.noteId).update({
        'views': FieldValue.increment(1),
      }).catchError((_) {});

      // Safely load top-level comments
      List<CommentModel> comments = [];
      try {
        final commentsSnap = await db
            .collection('comments')
            .where('contentId', isEqualTo: widget.noteId)
            .get();
        comments = commentsSnap.docs
            .where((doc) => doc.data()['parentId'] == null)
            .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
            .toList();
      } catch (_) {}

      // Check liked/bookmarked safely
      bool isLiked = false;
      bool isBookmarked = false;
      if (user != null) {
        try {
          final likedDoc = await db
              .collection('likes')
              .doc('${user.uid}_${widget.noteId}')
              .get();
          final bookmarkedDoc = await db
              .collection('bookmarks')
              .doc('${user.uid}_${widget.noteId}')
              .get();
          isLiked = likedDoc.exists;
          isBookmarked = bookmarkedDoc.exists;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _note = note;
          _uploaderProfile = uploader;
          _comments = comments;
          _isLiked = isLiked;
          _isBookmarked = isBookmarked;
          _isLoading = false;
        });

        // Log note view
        ref.read(analyticsServiceProvider).logNoteView(note.noteId, note.title);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load note: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final firestoreService = ref.read(firestoreServiceProvider);
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      if (_note != null) {
        _note = NoteModel(
          noteId: _note!.noteId,
          title: _note!.title,
          description: _note!.description,
          course: _note!.course,
          semester: _note!.semester,
          subject: _note!.subject,
          pdfUrl: _note!.pdfUrl,
          fileHash: _note!.fileHash,
          uploadedBy: _note!.uploadedBy,
          status: _note!.status,
          likes: wasLiked ? _note!.likes - 1 : _note!.likes + 1,
          downloads: _note!.downloads,
          createdAt: _note!.createdAt,
        );
      }
    });
    try {
      if (wasLiked) {
        await firestoreService.unlikeContent(user.uid, widget.noteId, 'note');
      } else {
        await firestoreService.likeContent(user.uid, widget.noteId, 'note');
      }
    } catch (e) {
      // Revert on failure
      setState(() {
        _isLiked = wasLiked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final bookmarkRef =
        db.collection('bookmarks').doc('${user.uid}_${widget.noteId}');
    final wasBookmarked = _isBookmarked;
    setState(() => _isBookmarked = !_isBookmarked);

    try {
      if (wasBookmarked) {
        await bookmarkRef.delete();
      } else {
        await bookmarkRef.set({
          'userId': user.uid,
          'contentId': widget.noteId,
          'contentType': 'note',
          'createdAt': FieldValue.serverTimestamp(),
          'noteTitle': _note?.title ?? '',
          'noteCourse': _note?.course ?? '',
          'noteSemester': _note?.semester ?? '',
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasBookmarked
                ? 'Removed from bookmarks'
                : '📌 Bookmarked successfully!'),
            backgroundColor:
                wasBookmarked ? AppColors.textSecondary : AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isBookmarked = wasBookmarked);
    }
  }

  Future<void> _downloadPDF() async {
    if (_note == null || _isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      // Increment Firestore download counter safely
      try {
        await ref
            .read(firestoreServiceProvider)
            .incrementDownloads(widget.noteId, 'note');
      } catch (_) {}

      // Log to analytics
      ref.read(analyticsServiceProvider).logNoteDownload(widget.noteId, _note!.title);

      final pdfUrl = _note!.pdfUrl;
      if (pdfUrl.isNotEmpty) {
        // Download PDF file bytes to local disk storage
        final dir = await getApplicationDocumentsDirectory();
        final sanitizedTitle = _note!.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
        final filePath = '${dir.path}/${sanitizedTitle}_${_note!.noteId}.pdf';
        final file = File(filePath);

        final res = await http.get(Uri.parse(pdfUrl));
        if (res.statusCode == 200) {
          await file.writeAsBytes(res.bodyBytes);

          // Save metadata entry for Offline Downloads screen
          final metaFile = File('${dir.path}/downloads_meta.txt');
          final line = '${_note!.noteId}|||${_note!.title}|||$pdfUrl|||${_note!.course}|||${_note!.semester}\n';
          await metaFile.writeAsString(line, mode: FileMode.append);
        } else {
          // Fallback launch if network download returns non-200
          final uri = Uri.parse(pdfUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }

      if (mounted) {
        setState(() {
          _note = NoteModel(
            noteId: _note!.noteId,
            title: _note!.title,
            description: _note!.description,
            course: _note!.course,
            semester: _note!.semester,
            subject: _note!.subject,
            pdfUrl: _note!.pdfUrl,
            fileHash: _note!.fileHash,
            uploadedBy: _note!.uploadedBy,
            status: _note!.status,
            likes: _note!.likes,
            downloads: _note!.downloads + 1,
            createdAt: _note!.createdAt,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded & saved to Offline Downloads! 📄'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed. Please check internet connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final comment = CommentModel(
      commentId: DateTime.now().millisecondsSinceEpoch.toString(),
      contentId: widget.noteId,
      authorId: user.uid,
      authorName: user.displayName ?? 'Student',
      authorPhotoUrl: user.photoURL ?? '',
      text: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(firestoreServiceProvider).addComment(comment);
      _commentController.clear();
      setState(() => _comments = [..._comments, comment]);
      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 200));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to comment: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showReportDialog() {
    String selectedReason = 'Spam';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Report Content', style: AppTextStyles.headingSmall),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Why are you reporting this note?',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              ...[
                'Wrong Content',
                'Duplicate Content',
                'Spam',
                'Copyright Issue',
                'Other'
              ].map((reason) => RadioListTile<String>(
                    title: Text(reason, style: AppTextStyles.bodyMedium),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: AppColors.primary,
                    onChanged: (val) =>
                        setDialogState(() => selectedReason = val!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final user = ref.read(authServiceProvider).currentUser;
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(firestoreServiceProvider).createReport(
                      ReportModel(
                        reportId:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        contentId: widget.noteId,
                        contentType: 'note',
                        reason: selectedReason,
                        reportedBy: user?.uid ?? '',
                        status: 'pending',
                        createdAt: DateTime.now(),
                      ),
                    );

                ref.read(analyticsServiceProvider).logReportContent(widget.noteId, 'note');

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Report submitted. Thank you!'),
                      backgroundColor: AppColors.success),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Note not found', style: AppTextStyles.headingSmall),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero App Bar ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildSubjectBadge(_note!.subject),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _note!.title,
                      style: AppTextStyles.headingMedium
                          .copyWith(color: Colors.white, fontSize: 20),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${_note!.course} · ${_note!.semester}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    _isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    key: ValueKey(_isBookmarked),
                    color: Colors.white,
                  ),
                ),
                onPressed: _toggleBookmark,
              ),
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                onPressed: _showReportDialog,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Stats Row ──
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // ── Uploader Info ──
                  if (_uploaderProfile != null) ...[
                    GestureDetector(
                      onTap: () {
                        // In real app, navigate to their profile
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              backgroundImage: _uploaderProfile!.photoUrl.isNotEmpty ? NetworkImage(_uploaderProfile!.photoUrl) : null,
                              child: _uploaderProfile!.photoUrl.isEmpty ? Text(_uploaderProfile!.name.isNotEmpty ? _uploaderProfile!.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_uploaderProfile!.name, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(_uploaderProfile!.contributorRank, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Description Card ──
                  if (_note!.description.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About this note',
                              style: AppTextStyles.headingSmall
                                  .copyWith(fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(_note!.description,
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Primary Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.menu_book_rounded,
                          label: 'Read Online',
                          color: AppColors.primary,
                          onTap: () => context.push('/pdf-viewer', extra: {
                            'pdfUrl': _note!.pdfUrl,
                            'title': _note!.title,
                            'isLocal': false,
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: _isDownloading
                              ? Icons.hourglass_top_rounded
                              : Icons.download_rounded,
                          label: _isDownloading ? 'Saving...' : 'Download',
                          color: AppColors.success,
                          onTap: _isDownloading ? null : _downloadPDF,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Like Button ──
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isLiked
                            ? AppColors.error.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isLiked ? AppColors.error : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              _isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey(_isLiked),
                              color: AppColors.error,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_note!.likes} ${_isLiked ? "Liked" : "Likes"}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Disclaimer Card ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Disclaimer',
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These notes are collected from publicly available online sources and are provided for educational purposes only. We do not claim ownership of third-party content. If you are the copyright owner and would like content removed, please contact us.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Comments Section ──
                  Row(
                    children: [
                      Text('Comments',
                          style: AppTextStyles.headingSmall
                              .copyWith(fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_comments.length}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Comments List ──
          _comments.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(
                        'No comments yet. Be the first!',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCommentTile(_comments[index]),
                    childCount: _comments.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ── Comment Input Bar ──
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _addComment,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBadge(String subject) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        subject,
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
            Icons.remove_red_eye_rounded, '${_note!.views}', 'Views'),
        const SizedBox(width: 10),
        _buildStatCard(
            Icons.download_rounded, '${_note!.downloads}', 'Downloads'),
        const SizedBox(width: 10),
        _buildStatCard(Icons.favorite_rounded, '${_note!.likes}', 'Likes'),
        const SizedBox(width: 10),
        _buildStatCard(Icons.star_rounded, '${_note!.qualityScore}', 'Score'),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String count, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              count,
              style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
            ),
            Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.border : color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.button.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: comment.authorPhotoUrl.isNotEmpty
                ? NetworkImage(comment.authorPhotoUrl)
                : null,
            child: comment.authorPhotoUrl.isEmpty
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(comment.text, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(comment.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
