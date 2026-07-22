import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import 'dart:ui';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  Map<String, int> _platformStats = {'users': 0, 'notes': 0, 'pyqs': 0, 'downloads': 0};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final stats = await firestoreService.getPlatformStats();
      if (mounted) {
        setState(() {
          _platformStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Platform Overview', style: AppTextStyles.headingMedium),
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              _buildPremiumStatTile('Total Users', _platformStats['users'].toString(), Icons.people_alt_rounded, const [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
              _buildPremiumStatTile('Total Notes', _platformStats['notes'].toString(), Icons.library_books_rounded, const [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
              _buildPremiumStatTile('Total PYQs', _platformStats['pyqs'].toString(), Icons.quiz_rounded, const [Color(0xFF10B981), Color(0xFF34D399)]),
              _buildPremiumStatTile('Total Colleges', _platformStats['colleges'].toString(), Icons.account_balance_rounded, const [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
              _buildPremiumStatTile('Pending Reviews', _platformStats['pending_reviews'].toString(), Icons.pending_actions_rounded, const [Color(0xFFEC4899), Color(0xFFF472B6)]),
              _buildPremiumStatTile('Reported Content', _platformStats['reported_content'].toString(), Icons.report_problem_rounded, const [Color(0xFFEF4444), Color(0xFFF87171)]),
              _buildPremiumStatTile('Storage Usage', '1.2 GB', Icons.storage_rounded, const [Color(0xFF6366F1), Color(0xFF818CF8)]),
              _buildPremiumStatTile('Downloads', _platformStats['downloads'].toString(), Icons.cloud_download_rounded, const [Color(0xFF14B8A6), Color(0xFF2DD4BF)]),
            ],
          ),
          const SizedBox(height: 32),
          Text('System Analytics', style: AppTextStyles.headingSmall),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, AppColors.surface.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Infrastructure', style: AppTextStyles.headingSmall),
                          const Text('Gemini Flash Model Status: Active', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildAnalyticRow('Total API Queries today', '856'),
                _buildAnalyticRow('Average Response Time', '1.4 seconds'),
                _buildAnalyticRow('Estimated Daily API Cost', '\$0.04'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPremiumStatTile(String title, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: AppTextStyles.headingMedium.copyWith(color: Colors.white, fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
