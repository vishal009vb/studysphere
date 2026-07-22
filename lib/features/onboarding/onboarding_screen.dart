import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _selectedRole = 'learner'; // default role

  Future<void> _saveRoleSelection() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      // Temporarily store role in state, then proceed to Preferences selection
      context.push('/preferences', extra: _selectedRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'How do you want to use StudySphere?',
                  style: AppTextStyles.headingLarge.copyWith(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a role that best suits your goals on the platform.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                
                // Learner Role Card
                GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'learner'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'learner' ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedRole == 'learner' ? AppColors.primary : AppColors.border,
                        width: _selectedRole == 'learner' ? 2.5 : 1.5,
                      ),
                      boxShadow: _selectedRole == 'learner' ? AppColors.softShadow : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.school_outlined, size: 36, color: AppColors.primary),
                            if (_selectedRole == 'learner')
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('I am a Learner', style: AppTextStyles.headingSmall.copyWith(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          'I want to view notes, study previous year papers, use the AI Assistant, and learn from top contributors.',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 8,
                          children: [
                            Chip(label: Text('Access Notes')),
                            Chip(label: Text('Download PYQs')),
                            Chip(label: Text('Gemini Assistant')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contributor Role Card
                GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'contributor'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'contributor' ? AppColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedRole == 'contributor' ? AppColors.primary : AppColors.border,
                        width: _selectedRole == 'contributor' ? 2.5 : 1.5,
                      ),
                      boxShadow: _selectedRole == 'contributor' ? AppColors.softShadow : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.auto_stories_outlined, size: 36, color: AppColors.primary),
                            if (_selectedRole == 'contributor')
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('I am a Contributor', style: AppTextStyles.headingSmall.copyWith(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          'I want to upload notes, share PYQs, post educational content, and earn reputation badges.',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 8,
                          children: [
                            Chip(label: Text('Upload Material')),
                            Chip(label: Text('Post Updates')),
                            Chip(label: Text('Reputation Ranks')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action button
                ElevatedButton(
                  onPressed: _saveRoleSelection,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Next Step', style: AppTextStyles.button.copyWith(fontSize: 16)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
