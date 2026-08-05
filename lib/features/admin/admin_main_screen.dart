import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Placeholder imports for modules
import 'screens/dashboard_tab.dart';
import 'screens/users_tab.dart';
import 'screens/notes_tab.dart';
import 'screens/papers_tab.dart';
import 'screens/community_tab.dart';
import 'screens/reports_tab.dart';
import 'screens/analytics_tab.dart';
import 'screens/colleges_tab.dart';
import 'screens/notifications_tab.dart';
import 'screens/banners_tab.dart';
import 'screens/settings_tab.dart';
import 'screens/legal_tab.dart';
import 'screens/admin_logs_tab.dart';
import 'screens/my_uploads_tab.dart';
import 'screens/ai_scraper_tab.dart';
import 'screens/courses_tab.dart';
import 'screens/support_tickets_tab.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/admin/admin_sidebar.dart';

class AdminMainScreen extends StatefulWidget {
  final String? initialTab;
  const AdminMainScreen({super.key, this.initialTab});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  static const List<String> _tabPaths = [
    'dashboard', 'users', 'notes', 'ai-scraper', 'papers', 'community', 'colleges', 
    'reports', 'support-tickets', 'analytics', 'notifications', 'banners', 'settings', 
    'legal', 'logs', 'my-uploads', 'courses'
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = _tabPaths.indexOf(widget.initialTab ?? 'dashboard');
    if (_selectedIndex == -1) _selectedIndex = 0;
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data()?['role'] != 'admin') {
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) context.go('/');
    }
  }

  @override
  void didUpdateWidget(AdminMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      final newIndex = _tabPaths.indexOf(widget.initialTab ?? 'dashboard');
      if (newIndex != -1 && newIndex != _selectedIndex) {
        setState(() => _selectedIndex = newIndex);
      }
    }
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);
    context.go('/admin/${_tabPaths[index]}');
  }

  final List<String> _titles = [
    'Dashboard',
    'Users',
    'Notes',
    'AI Scraper',
    'Question Papers',
    'Community',
    'Colleges',
    'Reports',
    'Support Tickets',
    'Analytics',
    'Notifications',
    'Banners',
    'Settings',
    'Legal Pages',
    'Admin Logs',
    'My Uploads',
    'Courses',
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.people,
    Icons.description,
    Icons.smart_toy,
    Icons.quiz,
    Icons.forum,
    Icons.account_balance,
    Icons.report,
    Icons.support_agent,
    Icons.analytics,
    Icons.notifications,
    Icons.view_carousel,
    Icons.settings,
    Icons.gavel,
    Icons.history,
    Icons.cloud_upload,
    Icons.school,
  ];

  final List<Widget> _screens = [
    const DashboardTab(),
    const UsersTab(),
    const NotesTab(),
    const AiScraperTab(),
    const PapersTab(),
    const CommunityTab(),
    const CollegesTab(),
    const ReportsTab(),
    const SupportTicketsTab(),
    const AnalyticsTab(),
    const NotificationsTab(),
    const BannersTab(),
    const SettingsTab(),
    const LegalTab(),
    const AdminLogsTab(),
    const MyUploadsAdminTab(),
    const AdminCoursesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        body: Row(
          children: [
            AdminSidebarWidget(
              selectedIndex: _selectedIndex,
              onItemSelected: _onTabChanged,
              titles: _titles,
              icons: _icons,
            ),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text('Admin Console', style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
                ],
              ),
            ),
            for (int i = 0; i < _titles.length; i++)
              ListTile(
                leading: Icon(_icons[i], color: _selectedIndex == i ? AppColors.primary : AppColors.textSecondary),
                title: Text(
                  _titles[i],
                  style: TextStyle(
                    color: _selectedIndex == i ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: _selectedIndex == i ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: _selectedIndex == i,
                onTap: () {
                  _onTabChanged(i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}
