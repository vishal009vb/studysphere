import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// A downloaded note entry parsed from the local meta file.
class _DownloadEntry {
  final String noteId;
  final String title;
  final String pdfUrl;
  final String course;
  final String semester;

  const _DownloadEntry({
    required this.noteId,
    required this.title,
    required this.pdfUrl,
    required this.course,
    required this.semester,
  });
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<_DownloadEntry> _downloads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/downloads_meta.txt');

      if (!await metaFile.exists()) {
        setState(() {
          _downloads = [];
          _isLoading = false;
        });
        return;
      }

      final lines = await metaFile.readAsLines();
      final entries = <_DownloadEntry>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|||');
        if (parts.length >= 5) {
          entries.add(_DownloadEntry(
            noteId: parts[0],
            title: parts[1],
            pdfUrl: parts[2],
            course: parts[3],
            semester: parts[4],
          ));
        }
      }

      // Deduplicate by noteId (keep latest)
      final seen = <String>{};
      final unique = entries.reversed
          .where((e) => seen.add(e.noteId))
          .toList()
          .reversed
          .toList();

      setState(() {
        _downloads = unique;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeDownload(_DownloadEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Download'),
        content: Text(
            'Remove "${entry.title}" from your offline downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove from meta file
      final dir = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/downloads_meta.txt');
      if (await metaFile.exists()) {
        final lines = await metaFile.readAsLines();
        final filtered = lines
            .where((line) => !line.startsWith('${entry.noteId}|||'))
            .toList();
        await metaFile.writeAsString(filtered.join('\n'));
      }

      // Remove actual PDF if it exists
      final pdfFile = File('${dir.path}/${entry.noteId}.pdf');
      if (await pdfFile.exists()) await pdfFile.delete();

      setState(() => _downloads.removeWhere((e) => e.noteId == entry.noteId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from downloads'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Downloads'),
        content: const Text(
            'This will remove all ${0} offline downloads. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/downloads_meta.txt');
      if (await metaFile.exists()) await metaFile.delete();

      // Delete all cached PDF files
      for (final entry in _downloads) {
        final pdfFile = File('${dir.path}/${entry.noteId}.pdf');
        if (await pdfFile.exists()) await pdfFile.delete();
      }

      setState(() => _downloads = []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: AppColors.warning,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xffd97706), Color(0xffeab308)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'My Downloads',
                      style: AppTextStyles.headingLarge.copyWith(
                          color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Available offline, no internet needed',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              if (_downloads.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.white),
                  onPressed: _clearAll,
                  tooltip: 'Clear all downloads',
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loadDownloads,
              ),
            ],
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _downloads.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadDownloads,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _downloads.length,
                      itemBuilder: (context, index) =>
                          _buildDownloadCard(_downloads[index], index),
                    ),
                  ),
      ),
    );
  }

  Widget _buildDownloadCard(_DownloadEntry entry, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffd97706), Color(0xffeab308)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.offline_pin_rounded,
                color: Colors.white, size: 26),
          ),
          title: Text(
            entry.title,
            style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildChip(entry.course, AppColors.primary),
                const SizedBox(width: 6),
                _buildChip(entry.semester, AppColors.accent),
                const Spacer(),
                const Icon(Icons.wifi_off_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text('Offline',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.success)),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'open') {
                context.push('/pdf-viewer', extra: {
                  'pdfUrl': entry.pdfUrl,
                  'title': entry.title,
                  'isLocal': false,
                });
              } else if (val == 'remove') {
                _removeDownload(entry);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'open',
                child: Row(children: [
                  Icon(Icons.menu_book_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Open PDF'),
                ]),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Remove',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
          onTap: () => context.push('/pdf-viewer', extra: {
            'pdfUrl': entry.pdfUrl,
            'title': entry.title,
            'isLocal': false,
          }),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.cloud_download_outlined,
                size: 56,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text('No Downloads Yet', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text(
              'Download notes from the Notes section\nto access them offline anytime.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Browse Notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
