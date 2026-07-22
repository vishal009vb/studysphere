import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../core/widgets/animated_transition.dart';

class BannersTab extends ConsumerStatefulWidget {
  const BannersTab({super.key});

  @override
  ConsumerState<BannersTab> createState() => _BannersTabState();
}

class _BannersTabState extends ConsumerState<BannersTab> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _uploadBanner() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final redirectInfo = await _showRedirectInfoDialog();
    if (redirectInfo == null) return; // User cancelled

    setState(() => _isUploading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Not authenticated');

      final file = File(pickedFile.path);
      final url = await ref.read(storageServiceProvider).uploadImage(file, 'banners_${user.uid}');
      
      // Get current max order
      final snap = await FirebaseFirestore.instance.collection('banners').orderBy('order', descending: true).limit(1).get();
      int nextOrder = 0;
      if (snap.docs.isNotEmpty) {
        nextOrder = (snap.docs.first.data()['order'] as int? ?? 0) + 1;
      }

      await ref.read(firestoreServiceProvider).addBanner(
        url, 
        nextOrder,
        redirectInfo['type'],
        redirectInfo['data'],
      );
      
      await ref.read(adminLogServiceProvider).logAction(
        adminId: user.uid,
        adminName: user.displayName ?? 'Admin',
        action: 'Banner Upload',
        targetContent: 'Order: $nextOrder, Type: ${redirectInfo['type']}',
        targetId: 'new_banner',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner uploaded successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<Map<String, dynamic>?> _showRedirectInfoDialog() async {
    String type = 'none';
    String url = '';
    String course = '';
    String semester = '';
    String subject = '';
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Banner Redirect Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(value: 'notes', child: Text('Notes Filter')),
                        DropdownMenuItem(value: 'url', child: Text('External URL')),
                      ],
                      onChanged: (val) => setStateDialog(() => type = val!),
                      decoration: const InputDecoration(labelText: 'Redirect Type'),
                    ),
                    if (type == 'url')
                      TextField(
                        onChanged: (val) => url = val,
                        decoration: const InputDecoration(labelText: 'Target URL'),
                      ),
                    if (type == 'notes') ...[
                      TextField(
                        onChanged: (val) => course = val,
                        decoration: const InputDecoration(labelText: 'Course'),
                      ),
                      TextField(
                        onChanged: (val) => semester = val,
                        decoration: const InputDecoration(labelText: 'Semester'),
                      ),
                      TextField(
                        onChanged: (val) => subject = val,
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Map<String, dynamic> redirectData = {};
                    if (type == 'url') redirectData = {'url': url};
                    if (type == 'notes') {
                      redirectData = {'course': course, 'semester': semester, 'subject': subject};
                    }
                    Navigator.pop(context, {
                      'type': type,
                      'data': redirectData,
                    });
                  },
                  child: const Text('Continue Upload'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _deleteBanner(String id) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      await ref.read(firestoreServiceProvider).deleteBanner(id);
      
      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Delete Banner',
          targetContent: 'Banner ID: $id',
          targetId: id,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner deleted'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _seedBanners() async {
    setState(() => _isUploading = true);
    try {
      final banners = [
        {
          'url': 'https://res.cloudinary.com/dgsvrdmze/image/upload/v1781435942/b8cbzfzyxach7dewjupx.jpg',
          'type': 'notes',
          'data': {'course': 'All', 'semester': 'All', 'subject': ''},
        },
        {
          'url': 'https://res.cloudinary.com/dgsvrdmze/image/upload/v1781435956/ft6vwkkis5kkoueplbic.jpg',
          'type': 'none',
          'data': <String, dynamic>{},
        },
        {
          'url': 'https://res.cloudinary.com/dgsvrdmze/image/upload/v1781435972/py8z6fgf73xizpcjy44z.jpg',
          'type': 'none',
          'data': <String, dynamic>{},
        },
      ];

      // Get current max order
      final snap = await FirebaseFirestore.instance.collection('banners').orderBy('order', descending: true).limit(1).get();
      int nextOrder = 0;
      if (snap.docs.isNotEmpty) {
        nextOrder = (snap.docs.first.data()['order'] as int? ?? 0) + 1;
      }

      for (var b in banners) {
        await ref.read(firestoreServiceProvider).addBanner(
          b['url'] as String,
          nextOrder++,
          b['type'] as String,
          b['data'] as Map<String, dynamic>,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hero banners seeded successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Banner Management', style: AppTextStyles.headingMedium),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isUploading ? null : _seedBanners,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Seed 3 Hero Banners'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadBanner,
                    icon: _isUploading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.upload_rounded),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Banner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Manage home screen promotional banners.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('banners').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(child: Text('No banners uploaded yet.')),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final imageUrl = data['imageUrl'] ?? '';
                  final order = data['order'] ?? 0;

                  return AnimatedTransition.slideUp(
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: Image.network(
                              imageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order: $order', style: AppTextStyles.headingSmall),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: () => _deleteBanner(id),
                                  tooltip: 'Delete Banner',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    delay: Duration(milliseconds: 50 * index),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
