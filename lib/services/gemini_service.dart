import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import '../models/user_model.dart';
import '../core/config/app_config.dart';
import '../core/utils/input_validator.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(
    ref.read(authServiceProvider),
    ref.read(firestoreServiceProvider),
  );
});

/// Chat history message loaded from Firestore.
class ChatMessage {
  final String messageId;
  final String question;
  final String answer;
  final DateTime? timestamp;
  final String modelUsed;

  const ChatMessage({
    required this.messageId,
    required this.question,
    required this.answer,
    this.timestamp,
    this.modelUsed = 'unknown',
  });
}

class GeminiService {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  DateTime? _lastRequestTime;
  final _uuid = const Uuid();

  GeminiService(this._authService, this._firestoreService);

  // Supabase anon key is intentionally semi-public per Supabase security model.
  // Do NOT store the Gemini API key here â€” it lives in Supabase Secrets only.
  String get _supabaseUrl => AppConfig.supabaseUrl;
  String get _supabaseAnonKey => AppConfig.supabaseAnonKey;

  // â”€â”€ Rate Limit & Cooldown Check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<UserModel> _checkAndIncrementUsage() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw const GeminiServiceException('Please sign in to use the AI Assistant.');
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    final now = DateTime.now();

    int currentUsage = profile.dailyAiUsage;
    DateTime? lastReset = profile.lastUsageReset;

    // 24 hour reset logic
    if (lastReset == null || now.difference(lastReset).inHours >= 24) {
      currentUsage = 0;
      lastReset = now;
    }

    // Cooldown check (3 seconds)
    if (_lastRequestTime != null && now.difference(_lastRequestTime!).inSeconds < 3) {
      throw const GeminiServiceException('Cooldown active. Please wait a few seconds.');
    }

    // Daily limit check
    if (currentUsage >= 20) {
      throw const GeminiRateLimitException('Daily AI limit reached. Try again tomorrow.');
    }

    // Update state
    _lastRequestTime = now;
    final newUsage = currentUsage + 1;
    await _firestoreService.updateAiUsage(user.uid, newUsage, lastReset);

    return profile.copyWith(
      dailyAiUsage: newUsage,
      lastUsageReset: lastReset,
    );
  }

  // â”€â”€ Ask Gemini â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> askGemini(String question, {String courseContext = ''}) async {
    final promptValidation = InputValidator.validateAiPrompt(question);
    if (!promptValidation.isValid) {
      throw GeminiServiceException(promptValidation.error ?? 'Invalid prompt.');
    }
    final sanitizedQuestion = InputValidator.sanitize(question);

    // Pre-flight checks (increments usage)
    await _checkAndIncrementUsage();

    final user = _authService.currentUser;
    if (user == null) {
      throw const GeminiServiceException('Please sign in to use the AI Assistant.');
    }

    final prompt = courseContext.isNotEmpty
        ? 'Context: I am studying $courseContext.\nQuestion: $question'
        : question;

    String answer = '';
    String modelUsed = 'gemini-1.5-flash-edge';

    try {
      final idToken = await user.getIdToken(true);
      final uri = Uri.parse('$_supabaseUrl/functions/v1/gemini-chat');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'x-firebase-token': idToken ?? '',
        },
        body: jsonEncode({
          'prompt': prompt,
          'uid': user.uid,
          'history': [], // We can fetch history and pass it here, or omit for now
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        answer = data['reply'] ?? '';
      } else {
        String errMsg = 'API error (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          errMsg = errorData['error']?.toString() ?? errMsg;
        } catch (_) {
          errMsg = response.body;
        }
        throw GeminiServiceException(errMsg);
      }

      if (answer.isEmpty) {
        throw const GeminiServiceException('AI returned an empty response.');
      }
    } on GeminiServiceException catch (_) {
      rethrow;
    } on GeminiRateLimitException catch (_) {
      rethrow;
    } catch (e) {
      throw GeminiServiceException('Failed to reach AI service: $e');
    }

    // Save to Firestore
    final msgData = {
      'messageId': _uuid.v4(),
      'question': question,
      'answer': answer,
      'modelUsed': modelUsed,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _firestoreService.saveChatMessage(user.uid, msgData);

    return answer;
  }

  // â”€â”€ Fetch Chat History â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<ChatMessage>> fetchChatHistory({int limit = 20}) async {
    final user = _authService.currentUser;
    if (user == null) return [];

    try {
      final history = await _firestoreService.fetchChatHistory(user.uid, limit: limit);
      return history.map((map) {
        return ChatMessage(
          messageId: map['messageId'] as String? ?? '',
          question: map['question'] as String? ?? '',
          answer: map['answer'] as String? ?? '',
          modelUsed: map['modelUsed'] as String? ?? 'unknown',
          timestamp: (map['timestamp'] as dynamic)?.toDate(),
        );
      }).toList().reversed.toList(); // Reverse to oldest first for UI
    } catch (_) {
      return [];
    }
  }

  Future<void> clearChatHistory() async {
    final user = _authService.currentUser;
    if (user == null) return;
    await _firestoreService.clearChatHistory(user.uid);
  }
}

// â”€â”€â”€ Custom Exceptions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GeminiRateLimitException implements Exception {
  final String message;
  const GeminiRateLimitException(this.message);

  @override
  String toString() => 'GeminiRateLimitException: $message';
}

class GeminiServiceException implements Exception {
  final String message;
  const GeminiServiceException(this.message);

  @override
  String toString() => 'GeminiServiceException: $message';
}



