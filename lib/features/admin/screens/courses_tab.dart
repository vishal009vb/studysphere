import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/course_detail_screen.dart';
import 'course_form_sheet.dart';
import '../../../seed_courses.dart';

class AdminCoursesTab extends ConsumerWidget {
  const AdminCoursesTab({super.key});

  void _showCourseForm(BuildContext context, {CourseModel? course}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CourseFormSheet(existingCourse: course),
    );
  }

  Future<void> _softDeleteCourse(BuildContext context, CourseModel course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${course.title}"? It will be hidden from users.'),
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
        await FirebaseFirestore.instance.collection('courses').doc(course.id).update({
          'isDeleted': true,
          'isVisible': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course deleted successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _restoreCourse(BuildContext context, CourseModel course) async {
    try {
      await FirebaseFirestore.instance.collection('courses').doc(course.id).update({
        'isDeleted': false,
        'isVisible': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course restored successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(adminCoursesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Courses'),
        backgroundColor: Colors.white,
        actions: [
          // ── Seed all 38 built-in courses into Firestore ──
          TextButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.green, size: 18),
            label: const Text(
              'Seed Courses',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Seed All Courses?'),
                  content: const Text(
                    '38 built-in courses will be upserted into Firestore (merge mode).\n\n'
                    '✅ Existing courses are SAFE — their data is preserved.\n'
                    '✅ New courses will be added.\n'
                    '✅ Existing flags (isVisible, isDeleted) are NOT changed.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Seed Now', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⏳ Seeding courses to Firestore...')),
              );
              try {
                await seedUserProvidedCourses(force: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ 38 courses seeded successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          TextButton(
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting playlists... this may take a minute.')));
                await fixAllPlaylists();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlists extracted successfully!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Fix Playlists', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () => _showCourseForm(context),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (courses) {
          if (courses.isEmpty) {
            return const Center(child: Text('No courses found. Add some!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _buildCourseCard(context, course);
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, CourseModel course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    course.thumbnailUrl,
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      width: 100,
                      height: 60,
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: AppTextStyles.headingSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${course.category} • ${course.level}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (course.isDeleted) _buildBadge('Deleted', AppColors.error)
                else if (!course.isVisible) _buildBadge('Hidden', Colors.orange)
                else _buildBadge('Active', AppColors.success),
                const SizedBox(width: 8),
                if (course.isFeatured) _buildBadge('Featured', Colors.amber),
                
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.visibility, color: AppColors.primary, size: 20),
                  tooltip: 'Preview',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.secondary, size: 20),
                  tooltip: 'Edit',
                  onPressed: () => _showCourseForm(context, course: course),
                ),
                if (course.isDeleted)
                  IconButton(
                    icon: const Icon(Icons.restore, color: AppColors.success, size: 20),
                    tooltip: 'Restore',
                    onPressed: () => _restoreCourse(context, course),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _softDeleteCourse(context, course),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
