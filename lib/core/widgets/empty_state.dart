import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onActionTap;

  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.folder_open_outlined,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bubbly icon background for Claymorphism theme
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080f172a),
                  offset: Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.headingSmall.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onActionTap != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onActionTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionText!,
                style: AppTextStyles.button,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
