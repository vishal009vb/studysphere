import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _communityNotifs = true;
  bool _aiNotifs = true;
  bool _announcements = true;
  bool _uploadsNotifs = true;
  bool _courseNotifs = true;
  bool _updatesNotifs = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _communityNotifs = prefs.getBool('notif_community') ?? true;
      _aiNotifs = prefs.getBool('notif_ai') ?? true;
      _announcements = prefs.getBool('notif_announcements') ?? true;
      _uploadsNotifs = prefs.getBool('notif_uploads') ?? true;
      _courseNotifs = prefs.getBool('notif_courses') ?? true;
      _updatesNotifs = prefs.getBool('notif_updates') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Notification Settings', style: AppTextStyles.headingMedium),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose which notifications you would like to receive. Critical safety alerts will always be delivered.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('General Preferences'),
                _buildSwitchTile(
                  title: 'Global Announcements',
                  subtitle: 'Official news, system maintenance, and platform announcements',
                  icon: Icons.campaign_rounded,
                  value: _announcements,
                  onChanged: (val) {
                    setState(() => _announcements = val);
                    _saveSetting('notif_announcements', val);
                  },
                ),
                _buildSwitchTile(
                  title: 'Community Activity',
                  subtitle: 'Likes on your posts/notes, comments, and new followers',
                  icon: Icons.forum_rounded,
                  value: _communityNotifs,
                  onChanged: (val) {
                    setState(() => _communityNotifs = val);
                    _saveSetting('notif_community', val);
                  },
                ),
                _buildSwitchTile(
                  title: 'Upload Approvals & Reviews',
                  subtitle: 'Updates on your uploaded notes and question papers status',
                  icon: Icons.upload_file_rounded,
                  value: _uploadsNotifs,
                  onChanged: (val) {
                    setState(() => _uploadsNotifs = val);
                    _saveSetting('notif_uploads', val);
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Learning & AI Alerts'),
                _buildSwitchTile(
                  title: 'AI Credits & Daily Limit',
                  subtitle: 'Reminders when your daily AI queries reset or hit limits',
                  icon: Icons.smart_toy_rounded,
                  value: _aiNotifs,
                  onChanged: (val) {
                    setState(() => _aiNotifs = val);
                    _saveSetting('notif_ai', val);
                  },
                ),
                _buildSwitchTile(
                  title: 'Course & Exam Alerts',
                  subtitle: 'New course materials, syllabus updates, and exam alerts',
                  icon: Icons.school_rounded,
                  value: _courseNotifs,
                  onChanged: (val) {
                    setState(() => _courseNotifs = val);
                    _saveSetting('notif_courses', val);
                  },
                ),
                _buildSwitchTile(
                  title: 'App Updates & Enhancements',
                  subtitle: 'New features releases and force update notices',
                  icon: Icons.rocket_launch_rounded,
                  value: _updatesNotifs,
                  onChanged: (val) {
                    setState(() => _updatesNotifs = val);
                    _saveSetting('notif_updates', val);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
