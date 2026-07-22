import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Observers for routing
  FirebaseAnalyticsObserver getAnalyticsObserver() => 
      FirebaseAnalyticsObserver(analytics: _analytics);

  // Authentication Events
  Future<void> logLogin(String loginMethod) async {
    await _analytics.logLogin(loginMethod: loginMethod);
  }

  Future<void> logRegistration(String registrationMethod) async {
    await _analytics.logSignUp(signUpMethod: registrationMethod);
  }

  // App Usage Events
  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  // Content Events
  Future<void> logNoteView(String noteId, String noteTitle) async {
    await _analytics.logEvent(
      name: 'note_view',
      parameters: {
        'note_id': noteId,
        'note_title': noteTitle,
      },
    );
  }

  Future<void> logNoteDownload(String noteId, String noteTitle) async {
    await _analytics.logEvent(
      name: 'note_download',
      parameters: {
        'note_id': noteId,
        'note_title': noteTitle,
      },
    );
  }

  Future<void> logUpload(String contentType) async {
    await _analytics.logEvent(
      name: 'content_upload',
      parameters: {
        'content_type': contentType, // 'note', 'question_paper', 'post', 'banner'
      },
    );
  }

  // Community Events
  Future<void> logCommunityPost(String postId) async {
    await _analytics.logEvent(
      name: 'community_post_created',
      parameters: {
        'post_id': postId,
      },
    );
  }

  Future<void> logCommunityLike(String contentId, String contentType) async {
    await _analytics.logEvent(
      name: 'community_like',
      parameters: {
        'content_id': contentId,
        'content_type': contentType,
      },
    );
  }

  Future<void> logCommunityComment(String contentId) async {
    await _analytics.logEvent(
      name: 'community_comment',
      parameters: {
        'content_id': contentId,
      },
    );
  }

  Future<void> logCommunityShare(String contentId) async {
    await _analytics.logShare(
      contentType: 'post',
      itemId: contentId,
      method: 'in_app',
    );
  }

  // AI Assistant Events
  Future<void> logAiQuery() async {
    await _analytics.logEvent(
      name: 'ai_query',
    );
  }

  // Moderation Events
  Future<void> logReportContent(String contentId, String contentType) async {
    await _analytics.logEvent(
      name: 'content_report',
      parameters: {
        'content_id': contentId,
        'content_type': contentType,
      },
    );
  }
}
