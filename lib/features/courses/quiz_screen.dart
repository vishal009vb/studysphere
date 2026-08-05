import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'models/course_model.dart';

class QuizScreen extends StatefulWidget {
  final CourseModule module;

  const QuizScreen({super.key, required this.module});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _showResult = false;
  int? _selectedAnswerIndex;
  bool _isAnswerCorrect = false;

  final List<Map<String, dynamic>> _dummyQuestions = [
    {
      'question': 'What is Flutter?',
      'options': ['A bird', 'A UI Toolkit by Google', 'A database', 'A game engine'],
      'answer': 1,
    },
    {
      'question': 'Which programming language is used in Flutter?',
      'options': ['Java', 'Swift', 'Dart', 'Kotlin'],
      'answer': 2,
    },
    {
      'question': 'What does a StatefulWidget do?',
      'options': ['Builds UI once', 'Manages internal state', 'Handles API calls', 'Nothing'],
      'answer': 1,
    }
  ];

  void _submitAnswer(int index) {
    if (_selectedAnswerIndex != null) return; // Already answered

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswerCorrect = index == _dummyQuestions[_currentQuestionIndex]['answer'];
      if (_isAnswerCorrect) _score++;
    });

    HapticFeedback.selectionClick();

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _dummyQuestions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswerIndex = null;
          _isAnswerCorrect = false;
        });
      } else {
        setState(() {
          _showResult = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.module.title, style: AppTextStyles.headingMedium),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _dummyQuestions.length,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: _showResult ? _buildResultView() : _buildQuestionView(),
    );
  }

  Widget _buildQuestionView() {
    final question = _dummyQuestions[_currentQuestionIndex];
    final options = question['options'] as List<String>;
    final correctAnswer = question['answer'] as int;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_dummyQuestions.length}',
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            question['question'] as String,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(options.length, (index) {
            final isSelected = _selectedAnswerIndex == index;
            final isCorrectOption = index == correctAnswer;
            
            Color bgColor = Colors.white;
            Color borderColor = AppColors.border;
            Color textColor = AppColors.textPrimary;

            if (_selectedAnswerIndex != null) {
              if (isCorrectOption) {
                bgColor = AppColors.success.withValues(alpha: 0.1);
                borderColor = AppColors.success;
                textColor = AppColors.success;
              } else if (isSelected && !isCorrectOption) {
                bgColor = AppColors.error.withValues(alpha: 0.1);
                borderColor = AppColors.error;
                textColor = AppColors.error;
              }
            }

            return GestureDetector(
              onTap: () => _submitAnswer(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        options[index],
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_selectedAnswerIndex != null && isCorrectOption)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success)
                    else if (_selectedAnswerIndex != null && isSelected && !isCorrectOption)
                      const Icon(Icons.cancel_rounded, color: AppColors.error),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              'Quiz Completed!',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $_score out of ${_dummyQuestions.length}',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
