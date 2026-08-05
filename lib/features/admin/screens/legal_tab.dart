import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../core/widgets/animated_transition.dart';

class LegalTab extends ConsumerStatefulWidget {
  const LegalTab({super.key});

  @override
  ConsumerState<LegalTab> createState() => _LegalTabState();
}

class _LegalTabState extends ConsumerState<LegalTab> {
  final _termsController = TextEditingController();
  final _privacyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void dispose() {
    _termsController.dispose();
    _privacyController.dispose();
    super.dispose();
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final terms = await svc.getLegalDoc('terms_of_service');
      final privacy = await svc.getLegalDoc('privacy_policy');
      if (mounted) {
        _termsController.text = terms;
        _privacyController.text = privacy;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load docs: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDocs() async {
    setState(() => _isSaving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      await svc.saveLegalDoc('terms_of_service', _termsController.text.trim());
      await svc.saveLegalDoc('privacy_policy', _privacyController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documents saved successfully'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save docs: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Legal Documents', style: AppTextStyles.headingMedium),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDocs,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Manage Terms of Service and Privacy Policy content.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          
          AnimatedTransition.slideUp(
            _buildDocEditor('Terms of Service', _termsController),
            delay: const Duration(milliseconds: 0),
          ),
          const SizedBox(height: 24),
          AnimatedTransition.slideUp(
            _buildDocEditor('Privacy Policy', _privacyController),
            delay: const Duration(milliseconds: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildDocEditor(String title, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(title, style: AppTextStyles.headingSmall),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              maxLines: 15,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter Markdown or Text content here...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
