import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/admin_log_service.dart';
import '../../../services/auth_service.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _maintenanceMode = false;
  int _maxAiRequests = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('appConfig').doc('settings').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _maxAiRequests = data['maxAiRequestsPerDay'] ?? 10;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings(bool maintenanceMode, int maxAiRequests) async {
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await FirebaseFirestore.instance.collection('appConfig').doc('settings').set({
        'maintenanceMode': maintenanceMode,
        'maxAiRequestsPerDay': maxAiRequests,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Change Settings',
          targetContent: 'Maintenance: $maintenanceMode, AI Limit: $maxAiRequests',
          targetId: 'appConfig/settings',
        );
      }

      setState(() {
        _maintenanceMode = maintenanceMode;
        _maxAiRequests = maxAiRequests;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e'), backgroundColor: AppColors.error),
        );
      }
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
          Text('Platform Settings', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          Text('Manage global app configurations.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Maintenance Mode'),
                    subtitle: const Text('If enabled, regular users cannot access the app.'),
                    value: _maintenanceMode,
                    onChanged: (val) => _updateSettings(val, _maxAiRequests),
                    activeThumbColor: AppColors.error,
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Daily AI Request Limit'),
                    subtitle: const Text('Maximum Gemini prompts allowed per user per day.'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (_maxAiRequests > 0) _updateSettings(_maintenanceMode, _maxAiRequests - 1);
                          },
                        ),
                        Text('$_maxAiRequests', style: AppTextStyles.headingSmall),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _updateSettings(_maintenanceMode, _maxAiRequests + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
