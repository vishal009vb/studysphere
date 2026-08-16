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
      body: const SingleChildScrollView(
        child: Column(
          children: [
            LegalHeroHeader(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'Your privacy matters to us.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Colors.blueGrey,
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      body: const SingleChildScrollView(
        child: Column(
          children: [
            LegalHeroHeader(
              icon: Icons.description_rounded,
              title: 'Terms & Conditions',
              subtitle: 'Please read these terms carefully before using StudySphere.',
              lastUpdated: 'Last updated: August 7, 2026',
              color: Colors.indigo,
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LegalSection(
                    title: '1. Acceptance of Terms',
                    content:
                        'By registering, downloading, or using StudySphere ("the App"), you agree to be legally bound by these Terms and Conditions ("Terms") and our Privacy Policy.\n\nIf you do not agree with any part of these Terms, you must immediately stop using StudySphere. Continued use of the App after any changes to these Terms constitutes your acceptance of the updated Terms.\n\nStudySphere is operated by an independent developer team based in India and is intended for students enrolled in higher education institutions.',
                  ),
                  LegalSection(
                    title: '2. Eligibility & Account Registration',
                    content:
                        'To use StudySphere, you must:\n• Be at least 13 years of age\n• Be a student or associated with an educational institution\n• Provide accurate and complete information during registration\n• Have a valid email address or Google account\n\nUsername Rules:\n• Your username must be unique and not already taken\n• Usernames must contain only lowercase letters (a–z), numbers (0–9), underscores (_), and dots (.)\n• Usernames must be at least 3 characters long\n• Usernames cannot impersonate other users, public figures, or brands\n• Usernames cannot contain offensive or inappropriate words\n• Once chosen, usernames cannot be changed frequently — choose wisely\n\nYou are responsible for keeping your account credentials (password, etc.) secure. Do not share your account with others.',
                  ),
                  LegalSection(
                    title: '3. What StudySphere Offers',
                    content:
                        'StudySphere is a student-centric educational platform that provides:\n\n📚 Notes & Study Materials\nAccess notes, PDFs, and study resources uploaded by students from your college and across India.\n\n📄 Question Papers\nDownload previous year question papers to prepare for exams.\n\n🤖 AI Assistant\nGet academic help powered by Google Gemini AI. Ask questions, summarize notes, and get explanations.\n\n🏘️ Community Feed\nPost questions, share updates, interact with fellow students, and build your academic network.\n\n🏆 Reputation Points\nEarn reputation points by uploading quality content, getting likes and saves, and contributing to the community.\n\n🔔 Notifications\nReceive alerts about community activity, new notes, and important app updates.',
                  ),
                  LegalSection(
                    title: '4. Account Rules & User Responsibilities',
                    content:
                        'As a StudySphere user, you agree to:\n\n✅ You MUST:\n• Use the app only for genuine educational purposes\n• Provide accurate information in your profile\n• Respect other users and their content\n• Report any content that violates these terms\n• Keep your login credentials secure\n• Notify us immediately if your account is compromised\n\n❌ You MUST NOT:\n• Create multiple accounts for the same person\n• Share your account credentials with anyone\n• Use the app for commercial purposes without written permission\n• Attempt to hack, reverse-engineer, or disrupt the app\n• Use bots, scrapers, or automated tools to access the app\n• Impersonate StudySphere staff, teachers, or other users\n• Violate any applicable laws of India or your country',
                  ),
                  LegalSection(
                    title: '5. Notes & Content Upload Rules',
                    content:
                        'StudySphere allows students to upload notes and study materials. By uploading content, you confirm that:\n\n• You are the original creator of the content OR you have explicit permission to share it\n• The content is educational and relevant to academic subjects\n• The content does not infringe any copyright, trademark, or intellectual property rights\n• The content does not contain personal information of any individual without consent\n• The content does not include adult/explicit material, hate speech, or illegal information\n• The content is not malware, spam, or advertising material\n\nContent that gets removed:\nWe may remove any uploaded content without prior notice if it violates these rules. Repeated violations will result in account suspension.\n\nReputation Points for Uploads:\nWhen you upload notes that are liked or saved by other users, you earn reputation points. If your content is removed for violations, reputation points may be deducted.',
                  ),
                  LegalSection(
                    title: '6. Community Feed Rules',
                    content:
                        'The StudySphere Community Feed is a space for academic discussion and peer support. The following rules apply:\n\n✅ Allowed:\n• Academic questions and discussions\n• Sharing helpful resources and links\n• Constructive feedback on other users\' posts\n• Encouragement and motivational posts for students\n• Announcements about exams, results, or college events\n\n❌ Not Allowed:\n• Bullying, harassment, or threatening any user\n• Posting offensive, hateful, racist, or discriminatory content\n• Spreading fake news, misinformation, or rumors\n• Spamming — repetitive posts or irrelevant content\n• Sharing another person\'s personal information without consent\n• Promoting political parties, religions, or divisive content\n• Posting illegal content of any kind\n\nViolations may result in post removal, temporary suspension, or permanent ban depending on severity.',
                  ),
                  LegalSection(
                    title: '7. AI Assistant — Usage Policy',
                    content:
                        'The StudySphere AI Assistant is powered by Google Gemini. By using the AI Assistant, you agree to:\n\n• Use it only for legitimate academic assistance (understanding concepts, summarizing notes, solving problems)\n• Not use it to generate content for plagiarism or academic dishonesty\n• Not attempt to bypass daily usage limits or rate limits\n• Not enter sensitive personal information (Aadhaar, bank details, passwords, etc.)\n• Not use it to generate harmful, offensive, or illegal content\n• Understand that AI responses may not always be 100% accurate — verify important information independently\n\nDaily Usage Limits:\nFree-tier users have a daily limit on AI queries. Attempting to bypass these limits will result in temporary or permanent account suspension.\n\nData Note:\nAI conversations are processed via Google Gemini APIs. We do not permanently store raw AI chat messages beyond your session.',
                  ),
                  LegalSection(
                    title: '8. Reputation Points System',
                    content:
                        'StudySphere uses a Reputation Points system to reward quality contributions:\n\nHow you earn points:\n• Uploading notes that receive likes ➜ +points per like\n• Your uploaded notes being saved by others ➜ +points per save\n• Community posts receiving engagement ➜ +points\n• Consistent high-quality contributions ➜ bonus points\n\nHow you can lose points:\n• Your uploaded content being removed for violations ➜ -points\n• Accounts found to be manipulating points through fake activity will have points reset\n\nReputation points do not have any monetary value. They are for recognition and community standing only. StudySphere reserves the right to adjust the points system at any time.',
                  ),
                  LegalSection(
                    title: '9. Account Suspension & Termination',
                    content:
                        'We may suspend or permanently ban your account if you:\n• Violate any section of these Terms\n• Upload copyright-infringing or prohibited content\n• Harass, bully, or threaten other users\n• Attempt to hack or disrupt the app or its servers\n• Create multiple accounts\n• Manipulate the reputation points system\n\nSuspension types:\n• Temporary Suspension: 24 hours to 30 days depending on violation severity\n• Permanent Ban: For serious or repeated violations\n\nYou may appeal a suspension by contacting us at vishalbhoi475@gmail.com within 7 days. We will review your appeal and respond within 5 business days.',
                  ),
                  LegalSection(
                    title: '10. Intellectual Property',
                    content:
                        'StudySphere\'s branding, logo, app design, interface, and original platform content are protected under Indian intellectual property laws.\n\nYour content: You retain ownership of notes and content you upload. However, by uploading, you grant StudySphere a non-exclusive, royalty-free, worldwide license to host, display, distribute, and make your content available to other users within the platform.\n\nOther users\' content: You may view and download content for personal academic use only. You may not redistribute, sell, or republish others\' content without their permission.',
                  ),
                  LegalSection(
                    title: '11. Copyright & DMCA Policy',
                    content:
                        'StudySphere respects intellectual property rights and expects users to do the same.\n\nIf you believe content on our platform infringes your copyright, please send a takedown notice to vishalbhoi475@gmail.com with:\n• Your name and contact information\n• A description of the copyrighted work\n• The location (URL/title) of the infringing content in the app\n• A statement that you have a good-faith belief the use is unauthorized\n• Your electronic signature\n\nWe will review and remove infringing content within 7 business days.',
                  ),
                  LegalSection(
                    title: '12. Privacy & Data Collection',
                    content:
                        'By using StudySphere, you consent to the collection and use of your data as described in our Privacy Policy.\n\nWe collect:\n• Account information (name, email, username, profile photo)\n• Educational details (college, state, district)\n• Content you upload (notes, posts, comments)\n• Usage analytics (anonymized, for app improvement)\n\nWe do NOT:\n• Sell your personal data to third parties\n• Use your data for targeted advertising\n• Store AI chat messages permanently\n\nFor full details, please read our Privacy Policy.',
                  ),
                  LegalSection(
                    title: '13. Digital Personal Data Protection Act, 2023 (India)',
                    content:
                        'StudySphere is fully compliant with the Digital Personal Data Protection Act, 2023 (DPDP Act) enacted by the Government of India.\n\nYour rights under the DPDP Act:\n✅ Right to Access: You can request to know what personal data we hold about you.\n✅ Right to Correction: You can request correction of inaccurate personal data.\n✅ Right to Erasure: You can request deletion of your personal data at any time.\n✅ Right to Grievance Redressal: You can file a complaint with us within 30 days of any data-related concern.\n✅ Right to Withdraw Consent: You may withdraw your consent at any time. Withdrawal of consent may limit your ability to use certain features.\n✅ Right to Nominate: You may nominate another individual to exercise your rights in case of incapacity.\n\nOur obligations:\n• We collect your personal data only with your free, informed, and specific consent\n• We use your data only for the purpose it was collected\n• We implement appropriate security measures to protect your data\n• We do not retain your data beyond what is necessary\n• We notify you in case of any data breach that may affect your rights\n\nData Fiduciary:\nStudySphere acts as the Data Fiduciary responsible for processing your personal data.\n\nGrievance Officer:\nFor any DPDP Act-related concerns, contact: vishalbhoi475@gmail.com\nWe will respond within 30 days as mandated by law.',
                  ),
                  LegalSection(
                    title: '14. Limitation of Liability',
                    content:
                        'StudySphere is provided "as is" without any warranties, express or implied. We do not guarantee:\n• Uninterrupted or error-free operation of the app\n• The accuracy of user-uploaded notes or AI-generated responses\n• That the app will be available at all times\n\nTo the maximum extent permitted by Indian law, StudySphere shall not be liable for:\n• Any loss of data\n• Indirect, incidental, or consequential damages\n• Damages arising from reliance on AI-generated content\n• Actions of other users on the platform\n\nAlways verify important academic information from official sources.',
                  ),
                  LegalSection(
                    title: '15. Changes to These Terms',
                    content:
                        'We may update these Terms from time to time. When we make significant changes:\n• We will notify you via in-app notification or email\n• The updated Terms will be published in the app with the new effective date\n• Continued use of the app after the effective date means you accept the updated Terms\n\nWe encourage you to review these Terms periodically.',
                  ),
                  LegalSection(
                    title: '16. Governing Law & Disputes',
                    content:
                        'These Terms shall be governed by the laws of India. Any disputes arising out of or in connection with these Terms shall be subject to the exclusive jurisdiction of the courts in India.\n\nBefore approaching courts, we encourage you to contact us first at vishalbhoi475@gmail.com to resolve any disputes amicably.',
                  ),
                  LegalSection(
                    title: '17. Contact Us',
                    content:
                        'For any questions, concerns, or feedback regarding these Terms and Conditions:\n\n📧 Email: vishalbhoi475@gmail.com\n📱 In-App: Profile → Contact Support\n\nWe aim to respond to all queries within 3 business days.',
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

