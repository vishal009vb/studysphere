import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../core/utils/app_error_formatter.dart';
import '../../core/widgets/animated_transition.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _autoValidate = false;
  String? _errorMessage; // visible error on screen

  final List<String> _disposableDomains = [
    'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'mailinator.com',
    'throwawaymail.com', 'temp-mail.org', 'yopmail.com', 'tempmail.net',
    'disposablemail.com', 'trashmail.com'
  ];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = AppErrorFormatter.getFriendlyMessage(e);
        setState(() => _errorMessage = errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signInWithGoogle();
      if (credential != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        final msg = AppErrorFormatter.getFriendlyMessage(e);
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
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

  void _showForgotPasswordBottomSheet() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool isResetting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reset Password', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your registered email address and we will send you a link to reset your password.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isResetting
                        ? null
                        : () async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid email address.'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(email)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('This email address format is invalid.'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            final parts = email.split('@');
                            if (parts.length > 1 && _disposableDomains.contains(parts[1].toLowerCase())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Temporary email addresses are not allowed.'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            setSheetState(() => isResetting = true);
                            try {
                              await ref.read(authServiceProvider).sendPasswordResetEmail(email);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password reset link sent! Please check your email.'), backgroundColor: AppColors.success),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to send reset link: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            } finally {
                              if (context.mounted) setSheetState(() => isResetting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isResetting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Send Reset Link', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8C82F8), // Vibrant purple
                  Color(0xFFB5AFFF), // Soft lavender-blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Corner Circle Blobs
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          
          // Polka Dot Grid
          const Positioned(
            left: 24,
            top: 100,
            child: CustomPaint(
              size: Size(60, 90),
              painter: DotGridPainter(),
            ),
          ),

          // Bottom Curve Waves
          const BottomWaveWidget(),

          // Main Body
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Icon (White cap logo from 2nd screenshot)
                    AnimatedTransition.scaleIn(
                      const Icon(
                        Icons.school_rounded,
                        size: 54,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedTransition.fadeIn(
                      Text(
                        'StudySphere',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      delay: const Duration(milliseconds: 100),
                    ),
                    const SizedBox(height: 2),
                    AnimatedTransition.fadeIn(
                      Text(
                        'Your complete AI Study Companion',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      delay: const Duration(milliseconds: 200),
                    ),
                    const SizedBox(height: 10),
                    // Indicator lines & dot
                    AnimatedTransition.fadeIn(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 30,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                      delay: const Duration(milliseconds: 250),
                    ),
                    const SizedBox(height: 14),
                    
                    // Form Glassmorphic Card
                    AnimatedTransition.slideUp(
                      Card(
                        elevation: 0,
                        color: Colors.white.withValues(alpha: 0.96),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome Back! 👋',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: const Color(0xFF717182),
                                    ),
                                    children: [
                                      const TextSpan(text: 'Login to continue your '),
                                      TextSpan(
                                        text: 'learning journey',
                                        style: GoogleFonts.dmSans(
                                          color: const Color(0xFF7C72E8),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: GoogleFonts.dmSans(color: const Color(0xFF1A1A2E), fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Email Address',
                                    hintStyle: GoogleFonts.dmSans(color: const Color(0xFF9B9ABD), fontSize: 15),
                                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF7C72E8), size: 20),
                                    filled: true,
                                    fillColor: const Color(0xFFF9F9FF),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFFEEECFF), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF7C72E8), width: 1.8),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 1.8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a valid email address.';
                                    }
                                    final emailStr = value.trim();
                                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(emailStr)) {
                                      return 'This email address format is invalid.';
                                    }
                                    final parts = emailStr.split('@');
                                    if (parts.length > 1) {
                                      final domain = parts[1].toLowerCase();
                                      if (_disposableDomains.contains(domain)) {
                                        return 'Temporary email addresses are not allowed.';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: GoogleFonts.dmSans(color: const Color(0xFF1A1A2E), fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: GoogleFonts.dmSans(color: const Color(0xFF9B9ABD), fontSize: 15),
                                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF7C72E8), size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: const Color(0xFF717182),
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9F9FF),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFFEEECFF), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF7C72E8), width: 1.8),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 1.8),
                                    ),
                                  ),
                                  validator: (value) => value == null || value.length < 6
                                      ? 'Password must be at least 6 characters'
                                      : null,
                                ),
                                
                                // ── Visible Error Banner ──────────────────
                                if (_errorMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            color: Colors.red.shade600, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _errorMessage = null),
                                          child: Icon(Icons.close_rounded,
                                              color: Colors.red.shade400, size: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordBottomSheet,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.dmSans(
                                        color: const Color(0xFF7C72E8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Animated Login Button
                                GestureDetector(
                                  onTapDown: (_) => _animationController.forward(),
                                  onTapUp: (_) {
                                    _animationController.reverse();
                                    _handleLogin();
                                  },
                                  onTapCancel: () => _animationController.reverse(),
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF7C72E8), Color(0xFF9F97F2)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7C72E8).withValues(alpha: 0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.login_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Login',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                
                                // OR Divider
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Color(0xFFEEECFF), thickness: 1)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE4E2FF), width: 1),
                                      ),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF9B9ABD),
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider(color: Color(0xFFEEECFF), thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                
                                // Google Sign In Button
                                OutlinedButton(
                                  onPressed: _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1A1A2E),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: const BorderSide(color: Color(0xFFE4E2FF), width: 1.5),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CustomPaint(
                                          painter: GoogleLogoPainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Continue with Google',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Footer Links (Inline Row)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style: GoogleFonts.dmSans(
                                        color: const Color(0xFF717182),
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => context.push('/register'),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Register Now',
                                              style: GoogleFonts.dmSans(
                                                color: const Color(0xFF7C72E8),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 15,
                                              color: Color(0xFF7C72E8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ), // End AnimatedTransition.slideUp
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painters & Decorative Widgets ───────────────────────────────────

/// CustomPainter to render a crisp vector Google 'G' Logo.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final Paint paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final Path pathRed = Path()
      ..moveTo(12.0, 5.04)
      ..cubicTo(13.66, 5.04, 15.2, 5.61, 16.38, 6.73)
      ..lineTo(19.65, 3.46)
      ..cubicTo(17.68, 1.54, 15.08, 1.0, 12.0, 1.0)
      ..cubicTo(7.24, 1.0, 3.2, 3.73, 1.2, 7.73)
      ..lineTo(5.05, 10.72)
      ..cubicTo(5.95, 8.03, 8.45, 6.04, 12.0, 5.04)
      ..close();
    canvas.drawPath(pathRed, paintRed);

    final Paint paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final Path pathYellow = Path()
      ..moveTo(4.64, 12.28)
      ..cubicTo(4.64, 11.51, 4.77, 10.76, 5.02, 10.04)
      ..lineTo(1.2, 7.05)
      ..cubicTo(0.43, 8.58, 0.0, 10.27, 0.0, 12.0)
      ..cubicTo(0.0, 13.73, 0.43, 15.42, 1.2, 16.95)
      ..lineTo(5.02, 13.99)
      ..cubicTo(4.77, 13.27, 4.64, 12.52, 4.64, 12.28)
      ..close();
    canvas.drawPath(pathYellow, paintYellow);

    final Paint paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final Path pathGreen = Path()
      ..moveTo(12.0, 18.96)
      ..cubicTo(8.45, 18.96, 5.95, 16.97, 5.05, 14.28)
      ..lineTo(1.2, 17.27)
      ..cubicTo(3.2, 21.27, 7.24, 24.0, 12.0, 24.0)
      ..cubicTo(15.08, 24.0, 17.68, 22.99, 19.57, 21.24)
      ..lineTo(15.88, 18.38)
      ..cubicTo(14.84, 19.06, 13.5, 19.46, 12.0, 19.46)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);

    final Paint paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Path pathBlue = Path()
      ..moveTo(23.49, 12.27)
      ..cubicTo(23.49, 11.46, 23.42, 10.68, 23.29, 9.91)
      ..lineTo(12.0, 9.91)
      ..lineTo(12.0, 14.42)
      ..lineTo(18.43, 14.42)
      ..cubicTo(18.15, 15.86, 17.34, 17.09, 16.12, 17.9)
      ..lineTo(19.81, 20.76)
      ..cubicTo(21.97, 18.77, 23.49, 15.84, 23.49, 12.27)
      ..close();
    canvas.drawPath(pathBlue, paintBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter to draw the polka dot grid layout.
class DotGridPainter extends CustomPainter {
  const DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    
    const double radius = 2.5;
    const double spacing = 14.0;
    
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 6; row++) {
        canvas.drawCircle(
          Offset(col * spacing, row * spacing),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom wavy shapes overlapping.
class BottomWaveWidget extends StatelessWidget {
  const BottomWaveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 120,
      child: CustomPaint(
        painter: _BottomWavePainter(),
      ),
    );
  }
}

class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paintBack = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final Path pathBack = Path();
    pathBack.moveTo(0, size.height);
    pathBack.lineTo(0, size.height * 0.4);
    pathBack.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.1,
      size.width * 0.55,
      size.height * 0.45,
    );
    pathBack.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.75,
      size.width,
      size.height * 0.35,
    );
    pathBack.lineTo(size.width, size.height);
    pathBack.close();
    canvas.drawPath(pathBack, paintBack);

    final Paint paintFront = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final Path pathFront = Path();
    pathFront.moveTo(0, size.height);
    pathFront.lineTo(0, size.height * 0.6);
    pathFront.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.3,
      size.width * 0.65,
      size.height * 0.65,
    );
    pathFront.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.8,
      size.width,
      size.height * 0.5,
    );
    pathFront.lineTo(size.width, size.height);
    pathFront.close();
    canvas.drawPath(pathFront, paintFront);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
