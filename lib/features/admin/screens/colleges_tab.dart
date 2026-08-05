import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../models/college_model.dart';

class CollegesTab extends ConsumerStatefulWidget {
  const CollegesTab({super.key});

  @override
  ConsumerState<CollegesTab> createState() => _CollegesTabState();
}

class _CollegesTabState extends ConsumerState<CollegesTab> {
  List<CollegeModel> _colleges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    setState(() => _isLoading = true);
    try {
      final colleges = await ref.read(firestoreServiceProvider).getAllColleges();
      setState(() => _colleges = colleges);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading colleges: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCollege(CollegeModel college, bool val) async {
    try {
      await ref.read(firestoreServiceProvider).toggleCollegeStatus(college.collegeId, val);
      _loadColleges(); // Reload list to reflect changes
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_colleges.isEmpty) {
      return const Center(child: Text('No colleges found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Colleges Management', style: AppTextStyles.headingMedium),
                ElevatedButton.icon(
                  onPressed: _loadColleges,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.surface),
                  columns: const [
                    DataColumn(label: Text('College Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Short Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Toggle', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _colleges.map((college) {
                    return DataRow(
                      cells: [
                        DataCell(Text(college.collegeName, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(college.shortName)),
                        DataCell(Text('${college.subDistrict}, ${college.district}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: college.isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              college.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                color: college.isActive ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: college.isActive,
                            onChanged: (val) => _toggleCollege(college, val),
                            activeThumbColor: AppColors.success,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
