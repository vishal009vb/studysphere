import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';

final adminStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(firestoreServiceProvider).getAdminStats();
});

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Overview', style: AppTextStyles.headingMedium),
              const SizedBox(height: 24),
              _buildStatsGrid(stats),
              const SizedBox(height: 32),
              Text('Content Distribution', style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              _buildContentChart(stats),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildStatsGrid(Map<String, int> stats) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(title: 'Total Users', value: '${stats['users'] ?? 0}', icon: Icons.people_outline, color: AppColors.primary),
        _StatCard(title: 'Total Notes', value: '${stats['notes'] ?? 0}', icon: Icons.article_outlined, color: AppColors.accent),
        _StatCard(title: 'Total Posts', value: '${stats['posts'] ?? 0}', icon: Icons.dynamic_feed_outlined, color: AppColors.success),
        _StatCard(title: 'Total Comments', value: '${stats['comments'] ?? 0}', icon: Icons.comment_outlined, color: AppColors.warning),
        _StatCard(title: 'Total Reports', value: '${stats['reports'] ?? 0}', icon: Icons.flag_outlined, color: AppColors.error),
        const _StatCard(title: 'Total Downloads', value: 'N/A', icon: Icons.download_outlined, color: Colors.teal),
      ],
    );
  }

  Widget _buildContentChart(Map<String, int> stats) {
    final notes = (stats['notes'] ?? 0).toDouble();
    final posts = (stats['posts'] ?? 0).toDouble();
    final comments = (stats['comments'] ?? 0).toDouble();
    final total = notes + posts + comments;

    if (total == 0) return const Center(child: Text('No content yet.'));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(value: notes, color: AppColors.primary, title: 'Notes', radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
            PieChartSectionData(value: posts, color: AppColors.accent, title: 'Posts', radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
            PieChartSectionData(value: comments, color: AppColors.success, title: 'Comments', radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0a000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: AppTextStyles.headingMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
