import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/college_service.dart';
import 'widgets/college_search_dialog.dart';
import '../../core/widgets/animated_transition.dart';
import '../../core/utils/app_error_formatter.dart';
import 'dart:async';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _autoValidate = false;
  bool _termsAccepted = false;
  int _currentStep = 1;

  // Username check
  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  Timer? _usernameDebounce;

  // Gesture recognizers for clickable Terms & Privacy links
  final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer();
  final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer();

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
      ref.read(collegeServiceProvider).searchColleges(limit: 1);
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

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final cleaned = value.trim().toLowerCase();
    if (cleaned.length < 3) {
      setState(() { _usernameAvailable = null; _isCheckingUsername = false; });
      return;
    }
    final regex = RegExp(r'^[a-z0-9_.]+$');
    if (!regex.hasMatch(cleaned)) {
      setState(() { _usernameAvailable = null; _isCheckingUsername = false; });
      return;
    }
    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final available = await ref.read(firestoreServiceProvider).isUsernameAvailable(cleaned);
        if (mounted) setState(() { _usernameAvailable = available; _isCheckingUsername = false; });
      } catch (_) {
        if (mounted) setState(() { _usernameAvailable = null; _isCheckingUsername = false; });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _collegeSearchController.dispose();
    _collegeDisplayController.dispose();
    _debounce?.cancel();
    _usernameDebounce?.cancel();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Widget _buildUsernameStatusChip({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Conditions to continue')),
      );
      return;
    }

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
      // Final username availability check before submitting
      final username = _usernameController.text.trim().toLowerCase();
      final available = await ref.read(firestoreServiceProvider).isUsernameAvailable(username);
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username is already taken. Please choose another.'), backgroundColor: Colors.red),
          );
          setState(() { _isLoading = false; _currentStep = 1; });
        }
        return;
      }

      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        username: username,
        state: _selectedState!,
        district: _selectedDistrict!,
        taluka: _selectedTaluka!,
        collegeId: _selectedCollege!.college,
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
            content: Text(AppErrorFormatter.getFriendlyMessage(e)),
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
      initialValue: value,
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
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
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
                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                              ),
                              const SizedBox(height: 16),

                              // Username field with live availability check
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _usernameController,
                                    onChanged: _onUsernameChanged,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      hintText: 'e.g. vishal_123',
                                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                                      suffixIcon: _isCheckingUsername
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                              ),
                                            )
                                          : _usernameAvailable == null
                                              ? null
                                              : Icon(
                                                  _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                  color: _usernameAvailable! ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                                  size: 24,
                                                ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _usernameAvailable == null
                                              ? Colors.grey.shade400
                                              : _usernameAvailable!
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFEF4444),
                                          width: _usernameAvailable != null ? 2 : 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _usernameAvailable == null
                                              ? AppColors.primary
                                              : _usernameAvailable!
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFEF4444),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return 'Username is required';
                                      if (value.trim().length < 3) return 'At least 3 characters required';
                                      final regex = RegExp(r'^[a-z0-9_.]+$');
                                      if (!regex.hasMatch(value.trim().toLowerCase())) return 'Lowercase letters, numbers, _ and . only';
                                      if (_usernameAvailable == false) return 'Username already taken';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // --- Live availability status badge ---
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) => FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                    child: _isCheckingUsername
                                        ? _buildUsernameStatusChip(
                                            key: const ValueKey('checking'),
                                            icon: Icons.hourglass_top_rounded,
                                            label: 'Checking availability...',
                                            color: Colors.orange.shade600,
                                            bgColor: Colors.orange.shade50,
                                            borderColor: Colors.orange.shade200,
                                          )
                                        : _usernameAvailable == null
                                            ? _buildUsernameStatusChip(
                                                key: const ValueKey('hint'),
                                                icon: Icons.info_outline_rounded,
                                                label: 'Lowercase letters, numbers, _ and . only',
                                                color: Colors.grey.shade600,
                                                bgColor: Colors.grey.shade50,
                                                borderColor: Colors.grey.shade200,
                                              )
                                            : _usernameAvailable!
                                                ? _buildUsernameStatusChip(
                                                    key: const ValueKey('available'),
                                                    icon: Icons.check_circle_rounded,
                                                    label: 'Username is available! 🎉',
                                                    color: const Color(0xFF16A34A),
                                                    bgColor: const Color(0xFFF0FDF4),
                                                    borderColor: const Color(0xFF86EFAC),
                                                  )
                                                : _buildUsernameStatusChip(
                                                    key: const ValueKey('taken'),
                                                    icon: Icons.cancel_rounded,
                                                    label: 'Username already taken. Try another.',
                                                    color: const Color(0xFFDC2626),
                                                    bgColor: const Color(0xFFFFF1F2),
                                                    borderColor: const Color(0xFFFCA5A5),
                                                  ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),


                              // Email
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

                              // Password
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
                              const SizedBox(height: 16),

                              // Terms & Conditions checkbox
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _termsAccepted
                                      ? AppColors.primary.withValues(alpha: 0.06)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _termsAccepted
                                        ? AppColors.primary.withValues(alpha: 0.4)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _termsAccepted,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.5),
                                            children: [
                                              const TextSpan(text: 'I agree to the '),
                                              TextSpan(
                                                text: 'Terms & Conditions',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppColors.primary,
                                                ),
                                                recognizer: _termsRecognizer
                                                  ..onTap = () => context.push('/terms'),
                                              ),
                                              const TextSpan(text: ' and '),
                                              TextSpan(
                                                text: 'Privacy Policy',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppColors.primary,
                                                ),
                                                recognizer: _privacyRecognizer
                                                  ..onTap = () => context.push('/privacy'),
                                              ),
                                              const TextSpan(text: '.'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Next button
                              ElevatedButton(
                                onPressed: _isCheckingUsername ? null : () async {
                                  setState(() => _autoValidate = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  if (!_termsAccepted) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Please accept Terms & Conditions')),
                                    );
                                    return;
                                  }
                                  // If username not yet checked (user typed but debounce not fired), check now
                                  final username = _usernameController.text.trim().toLowerCase();
                                  if (_usernameAvailable == null && username.length >= 3) {
                                    setState(() => _isCheckingUsername = true);
                                    try {
                                      final available = await ref.read(firestoreServiceProvider).isUsernameAvailable(username);
                                      if (mounted) {
                                        setState(() { _usernameAvailable = available; _isCheckingUsername = false; });
                                      }
                                      if (!available) {
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Username already taken. Please choose another.'), backgroundColor: Colors.red),
                                        );
                                        return;
                                      }
                                    } catch (_) {
                                      if (mounted) setState(() { _isCheckingUsername = false; });
                                    }
                                  }
                                  if (_usernameAvailable == false) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Please choose a different username')),
                                    );
                                    return;
                                  }
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
