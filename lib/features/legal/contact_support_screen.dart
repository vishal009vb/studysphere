import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';

const _kSupportEmail = 'vishalbhoi475@gmail.com';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String? _selectedIssueType;
  bool _isSending = false;
  int _charCount = 0;

  static const List<String> _issueTypes = [
    'Bug Report',
    'Feature Request',
    'Notes Issue',
    'AI Assistant Issue',
    'Community Issue',
    'Account Problem',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() => _charCount = _messageController.text.length);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an issue type.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = user != null
          ? await FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          : null;
      final userName = userDoc?.data()?['name'] ?? user?.displayName ?? 'Unknown User';

      await FirebaseFirestore.instance.collection('supportTickets').add({
        'userId': user?.uid ?? 'anonymous',
        'userName': userName,
        'email': user?.email ?? _kSupportEmail,
        'issueType': _selectedIssueType,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isSending = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send. Please try again.\n$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              Text(
                'Ticket Submitted!',
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Your support request has been received. Our team will respond to your email within 24 hours.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _subjectController.clear();
                    _messageController.clear();
                    setState(() => _selectedIssueType = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Done', style: AppTextStyles.button),
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
        title: Text('Contact Support', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Section ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, size: 38, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help?',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Describe your issue and our team will get back to you.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Average Response Time: Within 24 Hours',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Support Email Tile
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: _kSupportEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email copied to clipboard!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryFixedDim),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.email_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Support Email', style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    _kSupportEmail,
                                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Issue Type Dropdown
                    _buildLabel('Issue Type *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedIssueType,
                      decoration: _inputDecoration('Select issue type', Icons.category_rounded),
                      items: _issueTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedIssueType = val),
                      validator: (val) => val == null ? 'Please select an issue type' : null,
                    ),
                    const SizedBox(height: 16),

                    // Subject Field
                    _buildLabel('Subject *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: _inputDecoration('e.g., App Crash, AI Not Responding', Icons.title_rounded),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter a subject';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Message Field
                    _buildLabel('Message *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: 'Describe your issue in detail...',
                        hintStyle: AppTextStyles.bodyMedium,
                        filled: true,
                        fillColor: AppColors.surfaceLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        counterText: '$_charCount / 1000',
                        counterStyle: AppTextStyles.bodySmall.copyWith(
                          color: _charCount > 900 ? AppColors.warning : AppColors.textSecondary,
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your message';
                        if (val.trim().length < 20) return 'Message must be at least 20 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Send Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendTicket,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Submit Ticket', style: AppTextStyles.button.copyWith(fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Footer note
                    Text(
                      'By submitting this form, you agree to our Terms & Conditions and Privacy Policy.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
