import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'legal_shared_widgets.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

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
        title: Text('Community Guidelines', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const LegalHeroHeader(
              icon: Icons.people_rounded,
              title: 'Community Guidelines',
              subtitle: 'Keep StudySphere safe, respectful, and educational for everyone.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Color(0xFF7C3AED),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRule(
                    Icons.handshake_rounded,
                    'Respect Others',
                    'Treat every member of the StudySphere community with kindness and respect. Personal attacks, insults, or condescending behavior will not be tolerated.',
                    AppColors.primary,
                  ),
                  _buildRule(
                    Icons.block_rounded,
                    'No Hate Speech',
                    'Content that promotes hatred based on race, ethnicity, religion, gender, sexual orientation, disability, or any other characteristic is strictly prohibited.',
                    AppColors.error,
                  ),
                  _buildRule(
                    Icons.warning_rounded,
                    'No Harassment',
                    'Do not target, harass, or intimidate any user. Repeated unwanted contact, threatening messages, or targeted abuse will result in immediate account suspension.',
                    AppColors.warning,
                  ),
                  _buildRule(
                    Icons.mark_email_unread_rounded,
                    'No Spam',
                    'Do not post repetitive, irrelevant, or promotional content. This includes unsolicited links, advertisements, or off-topic messages in any section of the platform.',
                    AppColors.secondary,
                  ),
                  _buildRule(
                    Icons.fact_check_rounded,
                    'No Fake Information',
                    'Do not spread misinformation, false facts, or misleading educational content. Always verify information before sharing. Incorrect content that may harm students academically will be removed.',
                    AppColors.tertiary,
                  ),
                  _buildRule(
                    Icons.school_rounded,
                    'Educational Content Only',
                    'All posts, notes, and materials must be educational and relevant to academic study. Off-topic personal posts or unrelated commercial content are not allowed.',
                    AppColors.success,
                  ),
                  _buildRule(
                    Icons.no_adult_content_rounded,
                    'No Adult Content',
                    'Posting, sharing, or linking to sexually explicit, pornographic, or adult material is strictly prohibited and will result in immediate permanent ban.',
                    AppColors.error,
                  ),
                  _buildRule(
                    Icons.gavel_rounded,
                    'No Illegal Content',
                    'Do not post content that promotes, facilitates, or involves illegal activities, including piracy, academic fraud, drug use, or any form of criminal behavior.',
                    AppColors.textPrimary,
                  ),
                  _buildRule(
                    Icons.bug_report_rounded,
                    'No Malware',
                    'Do not upload files containing viruses, malware, spyware, or any harmful software. All uploads are subject to verification. Malicious uploads will result in a permanent ban.',
                    AppColors.error,
                  ),
                  _buildRule(
                    Icons.person_off_rounded,
                    'No Personal Information Sharing',
                    'Do not share personally identifiable information (phone numbers, addresses, financial details) of yourself or others. Protect your privacy and that of other users.',
                    AppColors.blue,
                  ),
                  _buildRule(
                    Icons.report_rounded,
                    'Report Abuse',
                    'If you see content or behavior that violates these guidelines, please report it immediately using the Report button on any post, note, or comment. Our moderation team reviews all reports within 24 hours.',
                    AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryFixedDim),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Violations of these guidelines may result in content removal, account warning, suspension, or permanent ban depending on severity.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildRule(IconData icon, String title, String body, Color color) {
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.headingSmall.copyWith(fontSize: 14, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                    ),
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
