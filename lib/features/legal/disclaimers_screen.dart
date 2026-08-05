import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'legal_shared_widgets.dart';

// ── AI Disclaimer Screen ───────────────────────────────────────────────────

class AiDisclaimerScreen extends StatelessWidget {
  const AiDisclaimerScreen({super.key});

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
        title: Text('AI Disclaimer', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const LegalHeroHeader(
              icon: Icons.smart_toy_rounded,
              title: 'AI Disclaimer',
              subtitle: 'Important information about the StudySphere AI Assistant.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: AppColors.blue,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    icon: Icons.psychology_rounded,
                    title: 'AI May Generate Incorrect Answers',
                    body:
                        'The StudySphere AI Assistant is powered by Google Gemini, a large language model. While it is designed to be helpful, it can occasionally produce incorrect, outdated, or misleading information.\n\nAlways verify critical educational information from authoritative sources such as your textbooks, official curriculum materials, or your teachers before relying on AI-generated answers for exams or assignments.',
                    color: AppColors.warning,
                  ),
                  _buildCard(
                    icon: Icons.verified_rounded,
                    title: 'Students Should Verify Important Information',
                    body:
                        'AI-generated content should be treated as a starting point for learning, not as a definitive answer. For subjects that require precision — such as mathematics, science formulas, historical dates, or legal definitions — always cross-check with verified academic resources.',
                    color: AppColors.primary,
                  ),
                  _buildCard(
                    icon: Icons.school_rounded,
                    title: 'For Learning Assistance Only',
                    body:
                        'The AI Assistant is intended to help you understand concepts, explain topics, and assist with your study sessions. It is a learning tool, not a replacement for proper academic instruction.\n\nDo not use the AI Assistant to:\n• Complete assignments or exams meant to test your own understanding\n• Generate content for academic submission without proper disclosure\n• Replace professional academic guidance or tutoring',
                    color: AppColors.success,
                  ),
                  _buildCard(
                    icon: Icons.medical_information_rounded,
                    title: 'Not Professional Advice',
                    body:
                        'The AI Assistant does not provide professional medical, legal, financial, or psychological advice. Any responses related to these domains are for general educational understanding only.\n\nFor professional guidance in these areas, always consult a qualified professional.',
                    color: AppColors.error,
                  ),
                  _buildCard(
                    icon: Icons.security_rounded,
                    title: 'Data & Privacy',
                    body:
                        'Your conversations with the AI Assistant are processed via Google Gemini APIs. Do not share sensitive personal information, passwords, financial details, or confidential data with the AI Assistant.\n\nFor more information, please read our Privacy Policy.',
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── Content Disclaimer Screen ──────────────────────────────────────────────

class ContentDisclaimerScreen extends StatelessWidget {
  const ContentDisclaimerScreen({super.key});

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
        title: Text('Content Disclaimer', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const LegalHeroHeader(
              icon: Icons.folder_special_rounded,
              title: 'Content Disclaimer',
              subtitle: 'Important information about community content on StudySphere.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Colors.teal,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimerTile(
                    icon: Icons.upload_rounded,
                    title: 'Notes are Uploaded by Users',
                    body:
                        'All notes, question papers, and study materials available on StudySphere are uploaded by student contributors, not by the StudySphere team. We do not create, edit, or verify the accuracy of uploaded content.',
                  ),
                  _buildDisclaimerTile(
                    icon: Icons.fact_check_rounded,
                    title: 'Accuracy Not Guaranteed',
                    body:
                        'StudySphere does not guarantee the accuracy, completeness, or reliability of any user-uploaded study materials. Content may contain errors, outdated information, or regional curriculum differences. Always verify important information with your official textbooks, teachers, or academic institutions.',
                  ),
                  _buildDisclaimerTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Users Should Verify Educational Materials',
                    body:
                        'Before relying on any uploaded notes or question papers for examinations or academic work, we strongly recommend cross-referencing with:\n• Official textbooks and publications\n• Your college or university academic resources\n• Verified online educational platforms',
                  ),
                  _buildDisclaimerTile(
                    icon: Icons.forum_rounded,
                    title: 'Community Content is Not Endorsed by StudySphere',
                    body:
                        'Community posts, comments, and discussions represent the views and opinions of individual users. These do not represent the views of StudySphere, and we are not responsible for the accuracy or opinions expressed in community posts.',
                  ),
                  _buildDisclaimerTile(
                    icon: Icons.copyright_rounded,
                    title: 'Intellectual Property',
                    body:
                        'Users who upload content are responsible for ensuring they have the necessary rights to share that material. If you believe any content infringes your copyright, please use the Report function or contact us at vishalbhoi475@gmail.com.',
                  ),
                  _buildDisclaimerTile(
                    icon: Icons.report_problem_rounded,
                    title: 'Report Inaccurate Content',
                    body:
                        'If you find content that contains significant errors, is misleading, or violates our community guidelines, please report it using the Report button on the content. Our moderation team will review and take appropriate action.',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerTile({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(body, style: AppTextStyles.bodyMedium.copyWith(height: 1.7)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
