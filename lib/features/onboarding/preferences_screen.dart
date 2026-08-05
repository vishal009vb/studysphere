import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../auth/widgets/college_search_dialog.dart';
import '../../services/college_service.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final List<String> _courses = ['BCA'];
  String _selectedCourse = 'BCA';
  
  bool _isLoading = false;
  CollegeData? _selectedCollege;

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedTaluka;

  List<String> _states = [];
  List<String> _districts = [];
  List<String> _talukas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStates();
    });
  }

  Future<void> _loadStates() async {
    try {
      final states = await ref.read(locationServiceProvider).getStates();
      if (mounted) setState(() => _states = states);
    } catch (e) {
      debugPrint("Failed to load states: $e");
    }
  }

  Future<void> _onStateChanged(String? newState) async {
    setState(() {
      _selectedState = newState;
      _selectedDistrict = null;
      _selectedTaluka = null;
      _districts = [];
      _talukas = [];
      _selectedCollege = null;
    });
    if (newState != null) {
      try {
        final dists = await ref.read(locationServiceProvider).getDistricts(newState);
        if (mounted) setState(() => _districts = dists);
      } catch (e) {
        debugPrint("Failed to load districts: $e");
      }
    }
  }

  Future<void> _onDistrictChanged(String? newDistrict) async {
    setState(() {
      _selectedDistrict = newDistrict;
      _selectedTaluka = null;
      _talukas = [];
      _selectedCollege = null;
    });
    if (newDistrict != null && _selectedState != null) {
      try {
        final tals = await ref.read(locationServiceProvider).getTalukas(_selectedState!, newDistrict);
        if (mounted) setState(() => _talukas = tals);
      } catch (e) {
        debugPrint("Failed to load talukas: $e");
      }
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedState == null || _selectedDistrict == null || _selectedTaluka == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select State, District, and Taluka.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_selectedCollege == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your college.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final selectedRole = GoRouterState.of(context).extra as String? ?? 'learner';

    setState(() => _isLoading = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateOnboardingData(
        user.uid, 
        selectedRole, 
        _selectedCourse,
        _selectedState!,
        _selectedDistrict!,
        _selectedTaluka!,
        _selectedCollege!.college, // Using name as ID
        _selectedCollege!.college,
      );
      
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      initialValue: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text('Profile Setup', style: AppTextStyles.headingLarge.copyWith(fontSize: 26), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Complete your personal information to personalize StudySphere.', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 32),

                // Personal Information Section
                Text('Personal Information', style: AppTextStyles.headingSmall),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: 'State',
                  value: _selectedState,
                  items: _states,
                  onChanged: _onStateChanged,
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: 'District',
                  value: _selectedDistrict,
                  items: _districts,
                  onChanged: _onDistrictChanged,
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: 'Taluka',
                  value: _selectedTaluka,
                  items: _talukas,
                  onChanged: (val) {
                    setState(() {
                      _selectedTaluka = val;
                    });
                  },
                ),
                
                const SizedBox(height: 32),
                
                // College Autocomplete
                Text('Search College', style: AppTextStyles.headingSmall),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final selected = await showCollegeSearchBottomSheet(
                      context,
                      ref,
                      _selectedState,
                      _selectedDistrict,
                    );
                    if (selected != null) {
                      setState(() => _selectedCollege = selected);
                    }
                  },
                  child: IgnorePointer(
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Select College',
                        hintText: _selectedCollege?.college ?? 'Tap to select college',
                        hintStyle: _selectedCollege != null 
                            ? const TextStyle(color: Colors.black87) 
                            : null,
                        prefixIcon: const Icon(Icons.account_balance_rounded),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                
                if (_selectedCollege != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Selected: ${_selectedCollege!.college}', style: AppTextStyles.bodyMedium)),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Course
                Text('Course', style: AppTextStyles.headingSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _courses.map((course) {
                    final isSelected = _selectedCourse == course;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCourse = course),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          course,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Get Started', style: AppTextStyles.button.copyWith(fontSize: 16)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
      ),
    );
  }
}
