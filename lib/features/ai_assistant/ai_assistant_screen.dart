import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../models/user_model.dart';
import '../../services/analytics_service.dart';

// ─── Chat message model (local UI state) ─────────────────────────────────────

enum _MessageRole { user, assistant, error }

class _ChatEntry {
  final _MessageRole role;
  final String text;
  final DateTime time;
  final bool isTyping;

  const _ChatEntry({
    required this.role,
    required this.text,
    required this.time,
    this.isTyping = false,
  });
}

// ─── Riverpod: remaining quota ────────────────────────────────────────────────

final _remainingQuotaProvider = StateProvider<int>((ref) => 20);
final _isContributorProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────────────────────
// AIAssistantScreen
// ─────────────────────────────────────────────────────────────────────────────

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  UserModel? _userProfile;
  String _courseContext = '';

  // Animated gradient for the header
  late AnimationController _gradientAnimCtrl;

  // Quick-prompt suggestions shown when chat is empty
  static const _promptSuggestions = [
    ('Explain Concept', '🔬', 'Explain the concept of '),
    ('Generate MCQs', '📝', 'Generate 5 MCQs on the topic: '),
    ('Study Roadmap', '🗺️', 'Create a step-by-step study roadmap for '),
    ('Solve Doubt', '❓', 'Solve this doubt: '),
    ('Exam Tips', '🏆', 'Give me exam preparation tips for '),
    ('Summarize', '📖', 'Summarize this topic in simple points: '),
  ];

  @override
  void initState() {
    super.initState();
    _gradientAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _initialize();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _gradientAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    try {
      // Load profile
      final profile =
          await ref.read(firestoreServiceProvider).getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _courseContext = profile.coursePreference;
        });
        // Remaining quota from local profile (will be corrected by CF response)
        int remaining =
            (20 - profile.dailyAiUsage).clamp(0, 20).toInt();
        ref.read(_remainingQuotaProvider.notifier).state = remaining;
      }

      // Load chat history from Cloud Function
      final geminiSvc = ref.read(geminiServiceProvider);
      final history = await geminiSvc.fetchChatHistory(limit: 20);

      if (mounted) {
        final historyEntries = history
            .expand((msg) => [
                  _ChatEntry(
                    role: _MessageRole.user,
                    text: msg.question,
                    time: msg.timestamp ?? DateTime.now(),
                  ),
                  _ChatEntry(
                    role: _MessageRole.assistant,
                    text: msg.answer,
                    time: msg.timestamp ?? DateTime.now(),
                  ),
                ])
            .toList();

        setState(() {
          _messages.addAll(historyEntries);
          _isLoadingHistory = false;
        });
        _scrollToBottom(instant: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to delete all your AI chat history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      try {
        final geminiSvc = ref.read(geminiServiceProvider);
        await geminiSvc.clearChatHistory();
        if (mounted) {
          setState(() {
            _messages.clear();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to clear chat history.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (instant) {
          _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // ── Send Message ──────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    text = text.trim();
    if (text.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _inputController.clear();

    final now = DateTime.now();
    setState(() {
      _messages.add(_ChatEntry(
          role: _MessageRole.user, text: text, time: now));
      _isLoading = true;
      // Add typing indicator
      _messages.add(_ChatEntry(
          role: _MessageRole.assistant,
          text: '...',
          time: now,
          isTyping: true));
    });
    _scrollToBottom();

    try {
      final geminiSvc = ref.read(geminiServiceProvider);
      final answer = await geminiSvc.askGemini(
        text,
        courseContext: _courseContext,
      );
      
      // Log AI Query
      ref.read(analyticsServiceProvider).logAiQuery();

      if (mounted) {
        setState(() {
          // Replace typing indicator with real response
          _messages.removeLast();
          _messages.add(_ChatEntry(
              role: _MessageRole.assistant,
              text: answer,
              time: DateTime.now()));
        });

        // Update remaining quota (subtract 1)
        final current = ref.read(_remainingQuotaProvider);
        if (current < 9999) {
          final newLimit = (current - 1).clamp(0, 20);
          ref.read(_remainingQuotaProvider.notifier).state = newLimit;
          if (newLimit == 5) {
            _showLimitWarningDialog();
          }
        }
        _scrollToBottom();
      }
    } on GeminiRateLimitException catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast(); // Remove typing indicator
          ref.read(_remainingQuotaProvider.notifier).state = 0;
        });
        _showRateLimitDialog(e.message);
      }
    } on GeminiServiceException catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(_ChatEntry(
              role: _MessageRole.error,
              text: e.message,
              time: DateTime.now()));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(_ChatEntry(
              role: _MessageRole.error,
              text: 'Something went wrong. Please try again.',
              time: DateTime.now()));
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRateLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_clock_rounded,
                color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Daily Limit Reached'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.wb_sunny_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Limit resets at midnight IST',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPremiumGateway();
            },
            child: const Text('Get Premium', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPremiumGateway() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text('Upgrade to Premium', style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Unlock unlimited AI Study Buddy prompts and early access to new features!', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.6), padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium Plan is Coming Soon!')));
              },
              child: const Text('Premium Plan (Coming Soon)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad Loading... (Simulation)')));
                // Simulate ad watch
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    ref.read(_remainingQuotaProvider.notifier).state += 5;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Received 5 bonus AI prompts!')));
                  }
                });
              },
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch Ad (+5 Prompts)', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLimitWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Limit Low!'),
          ],
        ),
        content: const Text(
          'Your AI limit will be over soon (Only 5 prompts left). Please increase your limit to continue using the AI Study Buddy without interruption.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showPremiumGateway(); 
            },
            child: const Text('Increase Limit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(_remainingQuotaProvider);
    final isContributor = ref.watch(_isContributorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(remaining, isContributor),
          Expanded(
            child: _isLoadingHistory
                ? _buildLoadingHistory()
                : _messages.isEmpty
                    ? _buildWelcomeState()
                    : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int remaining, bool isContributor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // AI avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Powered by StudySphere AI',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Quota badge
          if (!isContributor)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: remaining == 0
                    ? Colors.red.withOpacity(0.2)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: remaining == 0
                      ? Colors.redAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Row(children: [
                Icon(
                  remaining == 0
                      ? Icons.lock_rounded
                      : Icons.auto_awesome_rounded,
                  size: 14,
                  color: remaining == 0 ? Colors.redAccent : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  remaining == 0 ? 'Limit reached' : '$remaining left',
                  style: TextStyle(
                    color: remaining == 0 ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ]),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.all_inclusive_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 5),
                Text(
                  'Unlimited',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          const SizedBox(width: 8),
          // Clear Chat Button
          IconButton(
            onPressed: _messages.isEmpty || _isLoading ? null : _clearChatHistory,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            tooltip: 'Clear Chat History',
          ),
          if (!isContributor)
            IconButton(
              onPressed: _showPremiumGateway,
              icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
              tooltip: 'Premium Plan',
            ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── Welcome State ─────────────────────────────────────────────────────────

  Widget _buildWelcomeState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff4f46e5), Color(0xff7c3aed)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('👋', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  'Hello${_userProfile?.name.isNotEmpty == true ? ", ${_userProfile!.name.split(' ').first}" : ""}!',
                  style: AppTextStyles.headingLarge
                      .copyWith(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  "I'm your AI Study Buddy. Ask me anything — concepts, MCQs, roadmaps, doubts. I'm here to help you ace your exams! 🚀",
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Quick Prompts', style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),

          // Prompt suggestion grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _promptSuggestions.length,
            itemBuilder: (context, index) {
              final (label, emoji, prefix) = _promptSuggestions[index];
              return GestureDetector(
                onTap: () {
                  _inputController.text = prefix;
                  _inputController.selection =
                      TextSelection.fromPosition(
                          TextPosition(
                              offset: _inputController.text.length));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTextStyles.headingSmall
                              .copyWith(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Message List ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final entry = _messages[index];
        return _MessageBubble(entry: entry, index: index);
      },
    );
  }

  Widget _buildLoadingHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xff7c3aed),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading your chat history...',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final remaining = ref.watch(_remainingQuotaProvider);
    final isContributor = ref.watch(_isContributorProvider);
    final isDisabled = !isContributor && remaining == 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7c3aed).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quota warning bar
          if (!isContributor)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDisabled ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(isDisabled ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 14, color: isDisabled ? AppColors.error : AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isDisabled ? 'Daily limit reached.' : '$remaining question${remaining == 1 ? '' : 's'} left today.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: isDisabled ? AppColors.error : AppColors.primary),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showPremiumGateway,
                    child: Text(
                      'Get More',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !isDisabled && !_isLoading,
                    maxLength: 1000,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: isDisabled
                          ? 'Daily limit reached.'
                          : 'Ask your study buddy anything...',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: isDisabled || _isLoading
                      ? null
                      : () => _sendMessage(_inputController.text),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDisabled || _isLoading
                          ? AppColors.border
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatEntry entry;
  final int index;

  const _MessageBubble({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _MessageRole.user;
    final isError = entry.role == _MessageRole.error;
    final isTyping = entry.isTyping;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)), child: child),
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                ),
              ],

              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : isError
                            ? AppColors.error.withOpacity(0.08)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 16 : 6),
                      topRight: Radius.circular(isUser ? 6 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isError
                                ? AppColors.error.withOpacity(0.3)
                                : const Color(0xFFE4E2FF),
                            width: 1.5,
                          ),
                  ),
                  child: isTyping
                      ? const _TypingIndicator()
                      : isError
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Flexible(
                                child: Text(
                                  entry.text,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          )
                        : SelectableText(
                            entry.text,
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                ),
              ),
              
              if (isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'O',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 60,
      child: Lottie.network(
        'https://assets3.lottiefiles.com/packages/lf20_t24tpvcu.json',
        fit: BoxFit.cover,
      ),
    );
  }
}
