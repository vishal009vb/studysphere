import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'legal_shared_widgets.dart';

class CopyrightPolicyScreen extends StatelessWidget {
  const CopyrightPolicyScreen({super.key});

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
        title: Text('Copyright Policy', style: AppTextStyles.headingSmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            LegalHeroHeader(
              icon: Icons.copyright_rounded,
              title: 'Copyright & Content Policy',
              subtitle: 'We respect intellectual property rights.',
              lastUpdated: 'Last updated: July 20, 2026',
              color: Colors.deepOrange,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LegalSection(
                    title: '1. Copyright Notice',
                    content:
                        'StudySphere and its original content, features, and design are the intellectual property of StudySphere and are protected by applicable copyright laws. The StudySphere name, logo, and all associated branding are trademarks of StudySphere.\n\nUnauthorized reproduction, distribution, or use of our proprietary material without written permission is strictly prohibited.',
                  ),
                  LegalSection(
                    title: '2. Respect Intellectual Property',
                    content:
                        'All users of StudySphere must respect the intellectual property rights of others. When uploading notes, question papers, or any study materials:\n\n• Only upload content you have created or have permission to share\n• Do not upload copyrighted textbook content, publisher materials, or exam question papers whose distribution is restricted\n• Properly attribute content that is not your own original work\n• Do not use StudySphere to distribute pirated educational materials',
                  ),
                  LegalSection(
                    title: '3. Reporting Copyright Infringement',
                    content:
                        'If you believe that your copyrighted work has been uploaded to StudySphere without authorization, please submit a copyright infringement notice to:\n\nEmail: vishalbhoi475@gmail.com\n\nYour notice should include:\n• Your name and contact information\n• A description of the copyrighted work you believe has been infringed\n• The URL or exact location of the infringing content on StudySphere\n• A statement that you have a good-faith belief that the use is unauthorized\n• A declaration that the information you have provided is accurate',
                  ),
                  LegalSection(
                    title: '4. Content Review Process',
                    content:
                        'Upon receiving a valid copyright infringement notice, StudySphere will:\n\n1. Acknowledge receipt within 2 business days\n2. Review the reported content against the copyright claim\n3. Temporarily restrict access to the content if the claim appears valid\n4. Notify the content uploader of the complaint\n5. Give the uploader an opportunity to provide a counter notice',
                  ),
                  LegalSection(
                    title: '5. Content Removal Process',
                    content:
                        'If a copyright claim is verified:\n• The infringing content will be permanently removed from StudySphere\n• The uploader will receive a formal warning\n• Repeated violations will result in account suspension or permanent ban\n• We will notify both parties of the final decision within 7 business days of receiving all documentation',
                  ),
                  LegalSection(
                    title: '6. Repeat Violations',
                    content:
                        'StudySphere enforces a strict repeat violation policy:\n• First violation: Formal warning + content removal\n• Second violation: 7-day account suspension + content removal\n• Third violation: Permanent account ban\n\nAccounts that repeatedly infringe copyrights will be permanently banned without further notice.',
                  ),
                  LegalSection(
                    title: '7. Counter Notice',
                    content:
                        'If you believe your content was incorrectly removed, you may submit a counter notice to vishalbhoi475@gmail.com stating:\n\n• Your contact information\n• Identification of the removed content\n• A statement under penalty of perjury that you have a good-faith belief the content was removed in error\n• Your consent to jurisdiction of the Indian courts\n\nWe will review counter notices within 10 business days.',
                  ),
                  LegalSection(
                    title: '8. Contact',
                    content:
                        'For all copyright-related matters:\n\nEmail: vishalbhoi475@gmail.com\nApp: Profile → Contact Support → Copyright Issue',
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
}
