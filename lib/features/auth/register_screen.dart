import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/college_model.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/college_service.dart';
import 'widgets/college_search_dialog.dart';
import '../../core/widgets/animated_transition.dart';
import 'dart:async';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _autoValidate = false;
  int _currentStep = 1;

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedTaluka;
  CollegeData? _selectedCollege;

  List<String> _states = [];
  List<String> _districts = [];
  List<String> _talukas = [];
  
  Timer? _debounce;
  final TextEditingController _collegeSearchController = TextEditingController();
  final TextEditingController _collegeDisplayController = TextEditingController();

  final List<String> _disposableDomains = [
    'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'mailinator.com',
    'throwawaymail.com', 'temp-mail.org', 'yopmail.com', 'tempmail.net',
    'disposablemail.com', 'trashmail.com'
  ];

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _collegeSearchController.dispose();
    _collegeDisplayController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedState == null || _selectedDistrict == null || _selectedTaluka == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select State, District, and Taluka')));
      return;
    }
    
    if (_selectedCollege == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your College')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        state: _selectedState!,
        district: _selectedDistrict!,
        taluka: _selectedTaluka!,
        collegeId: _selectedCollege!.college, // Using name as ID if no unique ID
        collegeName: _selectedCollege!.college,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_unread_rounded, size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Verify Your Email', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 12),
                  Text(
                    'We\'ve sent a verification link to ${_emailController.text.trim()}.\nPlease check your inbox (and spam folder) to verify your account before logging in.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/login');
                      },
                      child: const Text('Go to Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
      isExpanded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedTransition.slideUp(
                  Card(
                    elevation: 0,
                    color: Colors.white.withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedTransition.scaleIn(const Icon(Icons.school_rounded, size: 48, color: AppColors.primary)),
                            const SizedBox(height: 12),
                            AnimatedTransition.fadeIn(
                              Text(
                                'Create Account',
                                style: AppTextStyles.headingMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Progress Bar
                            Row(
                              children: [
                                Expanded(child: Container(height: 6, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)))),
                                const SizedBox(width: 8),
                                Expanded(child: Container(height: 6, decoration: BoxDecoration(color: _currentStep == 2 ? AppColors.primary : Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Step $_currentStep of 2', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            
                            if (_currentStep == 1) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Please enter a valid email address.';
                                  final emailStr = value.trim();
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(emailStr)) return 'This email address format is invalid.';
                                  final parts = emailStr.split('@');
                                  if (parts.length > 1) {
                                    final domain = parts[1].toLowerCase();
                                    if (_disposableDomains.contains(domain)) return 'Temporary email addresses are not allowed.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _autoValidate = true);
                                  if (_formKey.currentState!.validate()) {
                                    setState(() {
                                      _currentStep = 2;
                                      _autoValidate = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Next', style: AppTextStyles.button.copyWith(fontSize: 16)),
                              ),
                            ] else ...[
                              Text('Location & College', style: AppTextStyles.headingSmall),
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
                                onChanged: (val) => setState(() => _selectedTaluka = val),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  final selected = await showCollegeSearchBottomSheet(
                                    context,
                                    ref,
                                    _selectedState,
                                    _selectedDistrict,
                                  );
                                  if (selected != null) {
                                    setState(() {
                                      _selectedCollege = selected;
                                      _collegeDisplayController.text = selected.college;
                                    });
                                  }
                                },
                                child: IgnorePointer(
                                  child: TextFormField(
                                    controller: _collegeDisplayController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Select College',
                                      hintText: 'Tap to select college',
                                      prefixIcon: const Icon(Icons.account_balance_rounded),
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) => _selectedCollege == null ? 'Please select a college' : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: OutlinedButton(
                                      onPressed: () => setState(() => _currentStep = 1),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text('Back'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text('Sign Up', style: AppTextStyles.button.copyWith(fontSize: 16)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Already have an account?', style: AppTextStyles.bodyMedium),
                                TextButton(
                                  onPressed: () => context.pop(),
                                  child: const Text(
                                    'Log In',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
