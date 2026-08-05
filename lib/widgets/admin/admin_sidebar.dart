import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSidebarWidget extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<String> titles;
  final List<IconData> icons;

  const AdminSidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.titles,
    required this.icons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 250,
      color: AppColors.surface,
      child: Column(
        children: [
          // Logo and Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            color: AppColors.primary,
            width: double.infinity,
            child: Column(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  'StudySphere Admin',
                  style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Nav Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: titles.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                return ListTile(
                  leading: Icon(
                    icons[index],
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    titles[index],
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          // Logout Button
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                context.go('/admin-login');
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
