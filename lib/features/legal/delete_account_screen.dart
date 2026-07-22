import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'legal_shared_widgets.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _isDeleting = false;

  Future<void> _requestDeletion() async {
    if (!_confirmed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);

    try {
      // Store deletion request in Firestore (soft-delete approach)
      await FirebaseFirestore.instance.collection('deletionRequests').add({
        'userId': user.uid,
        'email': user.email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        setState(() => _isDeleting = false);
        _showConfirmationDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 44, color: AppColors.success),
              ),
              const SizedBox(height: 18),
              Text('Request Submitted', style: AppTextStyles.headingMedium),
              const SizedBox(height: 8),
              Text(
                'Your account deletion request has been received. Your account and data will be deleted within 30 days. You will receive a confirmation email at ${FirebaseAuth.instance.currentUser?.email ?? "your email"}.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Delete Account', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            LegalHeroHeader(
              icon: Icons.delete_forever_rounded,
              title: 'Delete Account',
              subtitle: 'We are sorry to see you go.',
              lastUpdated: 'Account deletion is permanent.',
              color: AppColors.error,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This action is permanent and cannot be undone. Your account and all associated data will be deleted.',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // What will be deleted
                  Text('What will be deleted:', style: AppTextStyles.headingSmall),
                  const SizedBox(height: 12),
                  _buildWillDeleteItem(Icons.person_rounded, 'Your profile and personal information', willDelete: true),
                  _buildWillDeleteItem(Icons.upload_rounded, 'Your uploaded notes and question papers', willDelete: true),
                  _buildWillDeleteItem(Icons.forum_rounded, 'Your community posts and comments', willDelete: true),
                  _buildWillDeleteItem(Icons.bookmark_rounded, 'Your bookmarks and saved items', willDelete: true),
                  _buildWillDeleteItem(Icons.star_rounded, 'Your reputation points and progress', willDelete: true),

                  const SizedBox(height: 16),
                  Text('What may be retained:', style: AppTextStyles.headingSmall),
                  const SizedBox(height: 12),
                  _buildWillDeleteItem(Icons.history_rounded, 'Anonymized usage logs (for legal/security purposes)', willDelete: false),
                  _buildWillDeleteItem(Icons.report_rounded, 'Reports you filed (anonymized)', willDelete: false),

                  const SizedBox(height: 20),

                  // Timeline
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your account and data will be permanently deleted within 30 days of your request.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirmation checkbox
                  GestureDetector(
                    onTap: () => setState(() => _confirmed = !_confirmed),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _confirmed ? AppColors.error : AppColors.border,
                          width: _confirmed ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _confirmed,
                            onChanged: (val) => setState(() => _confirmed = val ?? false),
                            activeColor: AppColors.error,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'I understand that deleting my account is permanent and all my data will be lost.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Delete Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_confirmed && !_isDeleting) ? _requestDeletion : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.error.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Request Account Deletion',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancel, Keep My Account',
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWillDeleteItem(IconData icon, String text, {required bool willDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: willDelete
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: willDelete ? AppColors.error : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
          Icon(
            willDelete ? Icons.close_rounded : Icons.info_outline_rounded,
            size: 16,
            color: willDelete ? AppColors.error : AppColors.warning,
          ),
        ],
      ),
    );
  }
}
