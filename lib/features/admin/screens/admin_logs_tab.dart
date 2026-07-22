import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/admin_log_service.dart';

class AdminLogsTab extends ConsumerWidget {
  const AdminLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminLogService = ref.read(adminLogServiceProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: adminLogService.getLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading logs.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No admin logs found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['adminName'] ?? 'Unknown Admin', style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
                      Text('${time.hour}:${time.minute.toString().padLeft(2, '0')} ${time.day}/${time.month}/${time.year}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Action: ${data['action']}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text('Target ID: ${data['targetId']}', style: AppTextStyles.bodySmall),
                  if (data['targetContent'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Details: ${data['targetContent']}', style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
