import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'legal_shared_widgets.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
        title: Text('Privacy Policy', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const LegalHeroHeader(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'Your privacy matters to us.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Colors.blueGrey,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LegalSection(
                    title: '1. Introduction',
                    content:
                        'StudySphere ("we", "our", or "us") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and share your information when you use our mobile application and related services.\n\nBy using StudySphere, you agree to the practices described in this Privacy Policy. If you do not agree, please discontinue use of our services.',
                  ),
                  LegalSection(
                    title: '2. Information We Collect',
                    content:
                        'a) Account Information\nWhen you register, we collect your name, email address, and optional profile photo. You may also provide your college name, course preference, and location details.\n\nb) Uploaded Notes & Study Materials\nContent you upload (notes, question papers) is stored on our servers via Firebase and Cloudinary. You are responsible for ensuring you have rights to any content you upload.\n\nc) Community Posts\nPosts, comments, and interactions in the community feed are stored and may be visible to other users based on your settings.\n\nd) AI Chat Data\nYour messages to the StudySphere AI Assistant are temporarily processed via Google Gemini APIs. We do not permanently store raw AI chat messages on our servers beyond your session.\n\ne) Device Information\nWe may collect device type, operating system version, and unique device identifiers for analytics and troubleshooting.\n\nf) Analytics\nWe use anonymized usage data to understand how users interact with the app and to improve our service. This includes screen views, feature usage, and crash reports.',
                  ),
                  LegalSection(
                    title: '3. How We Use Your Information',
                    content:
                        'We use your data to:\n• Provide and personalize your study experience\n• Calculate and display reputation points\n• Power the community feed and messaging features\n• Process your AI assistant requests\n• Send important account and service notifications\n• Detect and prevent fraud and abuse\n• Improve our services through analytics\n• Comply with legal obligations',
                  ),
                  LegalSection(
                    title: '4. Third-Party Services',
                    content:
                        'StudySphere uses the following third-party services. Each has its own privacy policy:\n\n• Firebase (Google LLC) — Authentication, database, and cloud storage\n• Cloudinary — Media file storage and delivery\n• Google Gemini — AI language model for the AI Assistant feature\n• Google Analytics for Firebase — Anonymized usage analytics\n\nWe do not sell your personal data to third parties.',
                  ),
                  LegalSection(
                    title: '5. Data Storage & Retention',
                    content:
                        'Your data is stored on Firebase infrastructure, which is hosted on Google Cloud servers. Data may be stored in servers located outside your country of residence.\n\nWe retain your account data for as long as your account is active. If you request deletion of your account, we will delete or anonymize your personal data within 30 days, except where we are required to retain it for legal, regulatory, or security reasons.',
                  ),
                  LegalSection(
                    title: '6. Data Security',
                    content:
                        'We implement industry-standard security measures to protect your data, including:\n• Firebase Authentication with secure token-based sessions\n• Firestore security rules restricting access by role and ownership\n• HTTPS/TLS encryption for all data in transit\n• Secure API key management\n\nHowever, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security of your data.',
                  ),
                  LegalSection(
                    title: '7. Your Rights',
                    content:
                        'You have the right to:\n• Access the personal data we hold about you\n• Request correction of inaccurate data\n• Request deletion of your account and associated data\n• Object to or restrict processing of your data\n• Withdraw consent at any time\n\nTo exercise these rights, please contact us at vishalbhoi475@gmail.com or use the Contact Support feature in the app.',
                  ),
                  LegalSection(
                    title: '8. Delete Account',
                    content:
                        'You can request deletion of your account at any time from the Profile > Delete Account section of the app. Upon deletion:\n• Your profile, uploads, and community posts will be removed\n• Some data may be retained for up to 30 days in backup systems\n• Content that others have interacted with may remain in anonymized form',
                  ),
                  LegalSection(
                    title: '9. Children\'s Privacy',
                    content:
                        'StudySphere is intended for users aged 13 and above. We do not knowingly collect personal data from children under 13. If we discover that a child under 13 has provided us with personal information, we will promptly delete it.',
                  ),
                  LegalSection(
                    title: '10. Policy Updates',
                    content:
                        'We may update this Privacy Policy from time to time. We will notify you of significant changes via in-app notification or email. Continued use of StudySphere after changes take effect constitutes acceptance of the revised policy.',
                  ),
                  LegalSection(
                    title: '11. Contact Information',
                    content:
                        'For any privacy-related concerns or data requests, please contact us:\n\nEmail: vishalbhoi475@gmail.com\nApp: Profile → Contact Support',
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Terms & Conditions ─────────────────────────────────────────────────────

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
        title: Text('Terms & Conditions', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const LegalHeroHeader(
              icon: Icons.description_rounded,
              title: 'Terms & Conditions',
              subtitle: 'Please read these terms carefully before using StudySphere.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Colors.indigo,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LegalSection(
                    title: '1. Acceptance of Terms',
                    content:
                        'By downloading, installing, or using StudySphere, you agree to be bound by these Terms and Conditions and our Privacy Policy. If you do not agree with any part of these terms, you must not use our services.\n\nThese Terms constitute a legally binding agreement between you and StudySphere.',
                  ),
                  LegalSection(
                    title: '2. User Responsibilities',
                    content:
                        'You agree to:\n• Provide accurate registration information\n• Keep your login credentials secure\n• Not share your account with others\n• Notify us immediately of any unauthorized account access\n• Use StudySphere only for lawful educational purposes\n• Comply with all applicable laws and regulations',
                  ),
                  LegalSection(
                    title: '3. Educational Purpose',
                    content:
                        'StudySphere is an educational platform designed to help students access study materials, collaborate, and enhance their learning experience. All features must be used for genuine educational purposes. Commercial use of our platform or its content without written permission is strictly prohibited.',
                  ),
                  LegalSection(
                    title: '4. Community Rules',
                    content:
                        'When participating in the StudySphere community:\n• Treat all users with respect and dignity\n• Do not post offensive, hateful, or discriminatory content\n• Do not harass, bully, or threaten other users\n• Do not spread misinformation or fake information\n• Do not spam or post repetitive content\n• Do not share personal information of others without consent',
                  ),
                  LegalSection(
                    title: '5. Upload Rules',
                    content:
                        'By uploading content to StudySphere, you confirm that:\n• You own the content or have permission to share it\n• The content is educational and relevant to academic study\n• The content does not violate any copyright or intellectual property rights\n• The content does not contain malware, adult material, or illegal content\n\nWe reserve the right to remove any content that violates these rules without notice.',
                  ),
                  LegalSection(
                    title: '6. AI Usage Policy',
                    content:
                        'The StudySphere AI Assistant is powered by Google Gemini and is subject to the following:\n• Daily usage limits apply to free-tier users\n• Attempts to bypass rate limits will result in account suspension\n• Do not use the AI for plagiarism, cheating in examinations, or generating harmful content\n• AI responses are for educational assistance only and should be verified independently\n• Do not share sensitive personal information with the AI Assistant',
                  ),
                  LegalSection(
                    title: '7. Account Suspension & Termination',
                    content:
                        'We may suspend or terminate your account without prior notice if you:\n• Violate these Terms and Conditions\n• Upload infringing or prohibited content\n• Abuse platform features or other users\n• Attempt to hack or disrupt the service\n\nYou may appeal a suspension by contacting us at vishalbhoi475@gmail.com.',
                  ),
                  LegalSection(
                    title: '8. Intellectual Property',
                    content:
                        'All StudySphere branding, logos, app design, and original content created by our team are protected by intellectual property laws. You retain ownership of content you upload but grant StudySphere a non-exclusive, worldwide, royalty-free license to host, display, and distribute it within the platform.',
                  ),
                  LegalSection(
                    title: '9. Copyright Policy',
                    content:
                        'StudySphere respects intellectual property rights. If you believe any content on our platform infringes your copyright, please contact us at vishalbhoi475@gmail.com with:\n• Description of the copyrighted work\n• URL or location of the infringing content\n• Your contact information\n\nWe will review and remove infringing content within 7 business days.',
                  ),
                  LegalSection(
                    title: '10. Limitation of Liability',
                    content:
                        'StudySphere provides services "as is" without warranties of any kind. We do not guarantee:\n• The accuracy of community-uploaded notes or AI-generated content\n• Uninterrupted or error-free service\n• Security of data beyond commercially reasonable standards\n\nTo the maximum extent permitted by law, StudySphere shall not be liable for any indirect, incidental, or consequential damages arising from your use of our services.',
                  ),
                  LegalSection(
                    title: '11. No Warranty',
                    content:
                        'All content on StudySphere is provided for educational purposes only. We make no representations or warranties about the completeness, accuracy, or suitability of any study materials. Always cross-reference important educational content with official academic sources.',
                  ),
                  LegalSection(
                    title: '12. Governing Law',
                    content:
                        'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising from these Terms shall be subject to the exclusive jurisdiction of the courts in India.',
                  ),
                  LegalSection(
                    title: '13. Termination',
                    content:
                        'Either party may terminate this agreement at any time. You may terminate by deleting your account. We may terminate by suspending your access to StudySphere. Upon termination, your right to use the service ceases immediately.',
                  ),
                  LegalSection(
                    title: '14. Contact Information',
                    content:
                        'For any questions regarding these Terms and Conditions:\n\nEmail: vishalbhoi475@gmail.com\nApp: Profile → Contact Support',
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
